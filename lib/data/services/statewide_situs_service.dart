import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:retry/retry.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/statewide_parcel_source.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Resolves the street address of a parcel through the statewide layer.
///
/// The lookup is spatial rather than by parcel number on purpose. Assessor
/// parcel numbers are formatted per county — San Bernardino's own layer writes
/// `0128-061-48` where the statewide fabric writes `012806148`, and Alameda
/// writes `66-2671-1` in both — so matching on the string would fail exactly
/// where this is most needed. A point inside the parcel has no such ambiguity.
final class StatewideSitusService implements SitusAddressRepository {
  /// Creates a situs resolver using an injected HTTP [client].
  StatewideSitusService(this._client);

  /// Rows requested for a lookup that wants one answer.
  ///
  /// Asking for a single row is what a point lookup wants and is the one thing
  /// this service must not do. Below roughly two hundred rows it abandons its
  /// fast path, and the identical query that answers in 0.3s at 250 takes 42s
  /// at 1 — measured repeatedly, at three separate points, against 13 million
  /// rows. A point intersects one parcel either way, so the larger request
  /// costs nothing and returns the same feature 126 times sooner.
  static const _fastPathRecordCount = 250;

  final http.Client _client;
  final RetryOptions _retryOptions = const RetryOptions(maxAttempts: 2);
  final Map<String, SitusAddress?> _cache = {};

  @override
  Future<SitusAddress?> lookupAt(LatLng point) async {
    final key =
        '${point.latitude.toStringAsFixed(6)},'
        '${point.longitude.toStringAsFixed(6)}';
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final response = await _retryOptions.retry(
      () => _client
          .post(
            statewideParcelQuery,
            headers: const {'User-Agent': 'RiversideAtlas/1.0 (GIS prototype)'},
            body: {
              'where': '1=1',
              'geometry': '{"x":${point.longitude},"y":${point.latitude}}',
              'geometryType': 'esriGeometryPoint',
              'inSR': '4326',
              'spatialRel': 'esriSpatialRelIntersects',
              'outFields': statewideSitusFields,
              'returnGeometry': 'false',
              'resultRecordCount': '$_fastPathRecordCount',
              'f': 'json',
            },
          )
          .timeout(const Duration(seconds: 20)),
      retryIf: (_) => true,
    );
    if (response.statusCode != 200) {
      throw ArcGisException(
        'The statewide parcel service returned ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const ArcGisException(
        'The statewide parcel service returned an invalid response.',
      );
    }
    if (decoded['error'] != null) {
      throw const ArcGisException(
        'The statewide parcel service rejected the query.',
      );
    }
    // Stacked parcels — condominium units share a footprint — put several
    // rows under one point. The first with an address on record is a better
    // answer than the first row, which may be the airspace parcel.
    SitusAddress? situs;
    for (final feature in arcGisFeatures(decoded)) {
      situs = statewideSitus(feature);
      if (situs != null) {
        break;
      }
    }
    return _cache[key] = situs;
  }
}
