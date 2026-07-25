import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/core/text_matching.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';

/// Reads owner names from Riverside County's public property-tax search.
///
/// The county's search endpoint answers with candidate tax-roll rows and
/// publishes the current owner only on a row's account summary, so a confirmed
/// match costs two requests.
final class RiversidePropertyOwnerService implements PropertyOwnerSource {
  /// Creates a service backed by the shared application HTTP client.
  RiversidePropertyOwnerService(this._client);

  static const _host = 'ca-riverside-ttc.publicaccessnow.com';
  static const _searchPath = '/DesktopModules/QuickSearch/API/Module/GetData';
  static const _summaryPath = '/AccountSearch/AccountSummary.aspx';
  static const _timeout = Duration(seconds: 12);

  final http.Client _client;

  @override
  Uri get sourceUri => Uri.https(_host, '/PropertySearch.aspx');

  @override
  Future<PropertyOwnership?> lookupByAddress(OwnerQuery query) async {
    if (!query.hasStreetAddress) {
      return null;
    }
    final keywords = [
      'Situsstreetnumber:${query.houseNumber}',
      'Situsstreetname:${query.streetName.trim()}',
      if (query.unit.trim().isNotEmpty) 'Situsunitnumber:${query.unit.trim()}',
    ].join(' ');
    final candidates = (await _search(
      keywords,
    )).where((candidate) => situsMatchesQuery(candidate.situs, query));
    final match = selectOwnerCandidate(candidates, preferredApn: query.apn);
    return match == null ? null : _loadOwner(match);
  }

  @override
  Future<PropertyOwnership?> lookupByApn(OwnerQuery query) async {
    final apn = query.normalizedApn;
    if (apn.isEmpty) {
      return null;
    }
    final candidates = (await _search(
      'ParcelID:$apn',
    )).where((candidate) => digitsOnly(candidate.parcelId) == apn);
    final match = selectOwnerCandidate(candidates, preferredApn: apn);
    return match == null ? null : _loadOwner(match);
  }

  Future<List<OwnerCandidate>> _search(String keywords) async {
    final searchUri = Uri.https(_host, _searchPath, {
      'keywords': keywords,
      'page': '1',
    });
    final response = await _client
        .get(
          searchUri,
          headers: {
            'Accept': 'application/json',
            'ModuleId': '671',
            'TabId': '93',
            'Referer': sourceUri.toString(),
          },
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Property search failed with HTTP ${response.statusCode}.',
        searchUri,
      );
    }
    return _parseCandidates(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PropertyOwnership?> _loadOwner(OwnerCandidate candidate) async {
    final summaryUri = Uri.https(_host, _summaryPath, {
      'p': candidate.parcelId,
      'a': candidate.recordKey,
      'm': '',
    });
    final summaryResponse = await _client
        .get(
          summaryUri,
          headers: {
            'Accept': 'text/html,application/xhtml+xml',
            'Referer': sourceUri.toString(),
          },
        )
        .timeout(_timeout);
    if (summaryResponse.statusCode != 200) {
      throw http.ClientException(
        'Property summary failed with HTTP ${summaryResponse.statusCode}.',
        summaryUri,
      );
    }

    final ownerName = parseOwnerName(summaryResponse.body);
    if (ownerName == null) {
      return null;
    }
    return PropertyOwnership(
      ownerName: ownerName,
      parcelId: candidate.parcelId,
      matchedAddress: candidate.situs,
      sourceUri: summaryUri,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  /// Extracts the published current owner from an account-summary document.
  static String? parseOwnerName(String html) {
    final match = RegExp(
      r'<b[^>]*>\s*Current\s+Owner:\s*</b>\s*<br\s*/?>\s*(.*?)\s*</h2>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }
    final text = decodeHtmlEntities(
      match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }

  /// Reads the active tax-roll rows out of a quick-search payload.
  ///
  /// Retired rows keep their situs address but no longer describe the current
  /// owner, so only rows the county still flags active are considered.
  static List<OwnerCandidate> _parseCandidates(Map<String, dynamic> payload) {
    final rawItems = payload['items'];
    if (rawItems is! List) {
      return const [];
    }
    final candidates = <OwnerCandidate>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        continue;
      }
      final fields = rawItem['fields'];
      if (fields is! Map) {
        continue;
      }
      final situs = fields['Situs']?.toString().trim() ?? '';
      final parcelId = fields['ParcelID']?.toString().trim() ?? '';
      final recordKey = fields['AlternateKey']?.toString().trim() ?? parcelId;
      final isActive = fields['Effstatus']?.toString() == 'A';
      if (isActive &&
          parcelId.isNotEmpty &&
          recordKey.isNotEmpty &&
          situs.isNotEmpty) {
        candidates.add(
          OwnerCandidate(
            parcelId: parcelId,
            recordKey: recordKey,
            situs: situs,
          ),
        );
      }
    }
    return candidates;
  }
}
