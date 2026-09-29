import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/detected_parcel_source.dart';
import 'package:riverside_atlas/data/services/parcel_schema.dart';

/// Results retain rejection reasons for manual selection and diagnostics.
final class ParcelInspection {
  const ParcelInspection(this.layers, this.rejections);
  final List<DetectedParcelSource> layers;
  final List<String> rejections;
}

/// Inspects schemas, samples and county coverage with at most four requests.
final class ParcelLayerInspector {
  ParcelLayerInspector(this.client);
  final http.Client client;
  int _active = 0;
  final List<Completer<void>> _waiting = [];

  Future<Map<String, Object?>> _read(
    Uri uri, [
    Map<String, String> parameters = const {},
  ]) async {
    if (_active >= 4) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _active++;
    }
    try {
      final response = await client
          .get(uri.replace(queryParameters: {'f': 'json', ...parameters}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, Object?>) {
        throw const FormatException('Invalid layer response');
      }
      if (json['error'] != null) throw StateError('ArcGIS: ${json['error']}');
      return json;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  Future<ParcelInspection> inspectService(
    Uri serviceUrl,
    CountySource county, {
    String? publisher,
    String origin = 'auto',
  }) async {
    final accepted = <DetectedParcelSource>[];
    final rejected = <String>[];
    try {
      final service = await _read(serviceUrl);
      final layerUris = service['fields'] is List
          ? [serviceUrl]
          : [
              for (final layer
                  in (service['layers'] as List? ?? const []).whereType<Map>())
                if (layer['id'] is num && layer['type'] != 'Group Layer')
                  Uri.parse('$serviceUrl/${layer['id']}'),
            ];
      // A service worker walks sequentially; the global semaphore also bounds
      // requests when several service inspections run at once.
      for (final uri in layerUris) {
        try {
          final layer = uri == serviceUrl ? service : await _read(uri);
          final name = layer['name']?.toString() ?? uri.pathSegments.last;
          if (layer['geometryType'] != 'esriGeometryPolygon') {
            rejected.add("Layer '$name' is not a polygon layer");
            continue;
          }
          if (!'${layer['capabilities'] ?? service['capabilities']}'
              .toLowerCase()
              .split(',')
              .map((s) => s.trim())
              .contains('query')) {
            rejected.add("Layer '$name' does not support Query");
            continue;
          }
          final fields = (layer['fields'] as List? ?? const [])
              .whereType<Map>()
              .map((f) => LayerField.fromJson(f.cast<String, Object?>()))
              .toList();
          final map = detectParcelFields(
            fields,
            objectIdField: layer['objectIdField'] as String?,
          );
          if (map == null) {
            rejected.add(
              "Layer '$name' needs a parcel-number field and a situs address",
            );
            continue;
          }
          accepted.add(
            await _verify(
              uri,
              layer,
              map,
              fields,
              county,
              publisher ?? uri.host,
              origin,
            ),
          );
        } on Object catch (error) {
          rejected.add('$uri: $error');
        }
      }
    } on Object catch (error) {
      rejected.add('$serviceUrl: $error');
    }
    return ParcelInspection(accepted, rejected);
  }

  Future<DetectedParcelSource> _verify(
    Uri uri,
    Map<String, Object?> layer,
    ParcelFieldMap map,
    List<LayerField> fields,
    CountySource county,
    String publisher,
    String origin,
  ) async {
    final bounds = county.extent;
    final spatial = {
      'geometry':
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
      'geometryType': 'esriGeometryEnvelope',
      'inSR': '4326',
      'spatialRel': 'esriSpatialRelIntersects',
    };
    final query = Uri.parse('$uri/query');
    final sample = await _read(query, {
      ...spatial,
      'where': '1=1',
      'outFields': map.outFields,
      'returnGeometry': 'false',
      'resultRecordCount': '${ArcGisService.fastPathRecordCount}',
    });
    var rows = arcGisFeatures(
      sample,
    ).map((f) => arcGisObject(f['attributes'])).toList();
    if (rows.isEmpty) throw StateError('No sample records in this county');
    var where = '1=1';
    final scope = map.countyScopeField;
    if (scope != null) {
      String normalized(String s) => s
          .toLowerCase()
          .replaceAll(RegExp(r'\b(county|parish|borough)\b'), '')
          .replaceAll(RegExp('[^a-z0-9]'), '');
      final matches =
          {
            for (final row in rows)
              if (row[scope] != null) row[scope],
          }.where((value) {
            final s = value.toString().trim();
            return normalized(s) ==
                    normalized(
                      county.place?.name ?? county.displayName.split(',').first,
                    ) ||
                s.padLeft(5, '0') == county.fips ||
                (RegExp(r'^\d{1,3}$').hasMatch(s) &&
                    s.padLeft(3, '0') == county.fips.substring(2));
          }).toList();
      if (matches.isEmpty) {
        throw StateError('County scope could not be verified');
      }
      final numeric =
          fields.firstWhere((f) => f.name == scope).type !=
          'esriFieldTypeString';
      final clauses = matches
          .map(
            (v) => numeric && num.tryParse('$v') != null
                ? '$scope = $v'
                : "$scope = '${v.toString().replaceAll("'", "''")}'",
          )
          .join(' OR ');
      where = '($clauses)';
      rows = rows.where((r) => matches.contains(r[scope])).toList();
    }
    var bestFilled = -1;
    for (final field in map.addressCandidates) {
      final filled = rows
          .where((r) => plausibleParcelAddress(r[field]?.toString() ?? ''))
          .length;
      if (filled > bestFilled) {
        bestFilled = filled;
        map = map.withAddress(field);
      }
    }
    if (rows.where((r) => map.value(r, 'apn').isNotEmpty).length / rows.length <
            .3 ||
        rows.where((r) => plausibleParcelAddress(map.address(r))).length /
                rows.length <
            .2) {
      throw StateError(
        'Too few populated parcel numbers or plausible situs addresses',
      );
    }
    final countJson = await _read(query, {
      ...spatial,
      'where': where,
      'returnCountOnly': 'true',
    });
    final count = countJson['count'];
    if (count is! num || count < 1000) {
      throw StateError(
        'Only ${count ?? 0} parcels in this county (minimum 1,000)',
      );
    }
    final advanced = arcGisObject(layer['advancedQueryCapabilities']);
    final text = rows.map(map.address).where(plausibleParcelAddress);
    return DetectedParcelSource(
      query: query,
      fields: map,
      bounds: bounds,
      publisherLabel: publisher,
      layerName: layer['name']?.toString() ?? '',
      count: count.toInt(),
      maxRecordCount: ((layer['maxRecordCount'] as num?)?.toInt() ?? 1000)
          .clamp(1, 1000),
      detectedAt: DateTime.now().toUtc(),
      countyWhere: where,
      supportsCentroid:
          advanced['supportsReturningGeometryCentroid'] == true ||
          layer['supportsReturningGeometryCentroid'] == true,
      supportsPagination: advanced['supportsPagination'] == true,
      uppercaseAddressSearch: text.any((s) => s != s.toUpperCase()),
      origin: origin,
    );
  }

  /// Fixed near-tie bands avoid a non-transitive pairwise 5% comparator.
  List<DetectedParcelSource> rank(
    Iterable<DetectedParcelSource> layers, {
    int? year,
  }) {
    final now = year ?? DateTime.now().year;
    double score(DetectedParcelSource source) {
      final title = '${source.query.path} ${source.layerName}'.toLowerCase();
      var score = source.count.toDouble();
      if (RegExp(
        'delinquent|lien|owned|church|flood|hazard|opportunity|municipal|government|unincorporated|zoning|sales|vacant',
      ).hasMatch(title)) {
        score *= .5;
      }
      if (RegExp(r'\b(?:19|20)\d{2}\b')
          .allMatches(title.replaceAll('_', ' '))
          .any((m) => int.parse(m[0]!) < now - 1)) {
        score *= .7;
      }
      return score;
    }

    final sorted = layers.toList()
      ..sort((a, b) {
        final diff = score(b).compareTo(score(a));
        return diff != 0
            ? diff
            : a.query.toString().compareTo(b.query.toString());
      });
    final result = <DetectedParcelSource>[];
    while (sorted.isNotEmpty) {
      final threshold = score(sorted.first) * .95;
      final band = sorted.takeWhile((s) => score(s) >= threshold).toList();
      sorted.removeRange(0, band.length);
      band.sort((a, b) {
        for (final difference in [
          (b.supportsPagination ? 1 : 0) - (a.supportsPagination ? 1 : 0),
          (b.supportsCentroid ? 1 : 0) - (a.supportsCentroid ? 1 : 0),
        ]) {
          if (difference != 0) return difference;
        }
        final host = a.query.host.compareTo(b.query.host);
        return host != 0
            ? host
            : a.query.toString().compareTo(b.query.toString());
      });
      result.addAll(band);
    }
    return result;
  }
}
