import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Reads overlay geometry from a county `FeatureServer` layer.
///
/// Hosted feature services cannot be exported as an image — there is no
/// `/export` on a `FeatureServer` — so the 20,000-odd of them in the inventory
/// have to be queried and drawn. What comes back is geometry plus an
/// untouched attribute map: an arbitrary county layer's schema is unknown, and
/// parsing it into a domain model would be inventing meaning it does not have.
final class OverlayFeatureService implements OverlayFeatureRepository {
  /// Creates a feature reader over the shared HTTP client.
  const OverlayFeatureService(this._client);

  /// The most features one overlay draws at a time.
  ///
  /// A county layer at county zoom can be tens of thousands of polygons, which
  /// no amount of clever drawing makes useful. Overlays are capped and the
  /// panel says when the cap was hit, rather than freezing the map.
  static const featureLimit = 1200;

  final http.Client _client;

  @override
  Future<List<OverlayFeature>> queryViewport(
    Uri layerQuery,
    GeoBounds bounds, {
    int limit = featureLimit,
  }) async {
    final json = await _post(layerQuery, {
      'where': '1=1',
      'geometry':
          '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
      'geometryType': 'esriGeometryEnvelope',
      'inSR': '4326',
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': '*',
      'returnGeometry': 'true',
      'maxAllowableOffset': '${_pixelSize(bounds)}',
      'outSR': '4326',
      // Never ask a spatially filtered layer for a handful of rows: the same
      // query took 42 seconds at a limit of 1 and 0.3 seconds at 250. See
      // `ArcGisService.fastPathRecordCount`.
      'resultRecordCount':
          '${limit < ArcGisService.fastPathRecordCount ? ArcGisService.fastPathRecordCount : limit}',
      'f': 'json',
    });
    final features = arcGisFeatures(json);
    return [for (final feature in features.take(limit)) ?_feature(feature)];
  }

  OverlayFeature? _feature(Map<String, Object?> feature) {
    final geometry = arcGisObject(feature['geometry']);
    final rings = arcGisRings(geometry['rings']);
    final paths = _lines(geometry['paths']);
    final x = geometry['x'];
    final y = geometry['y'];
    final points = <LatLng>[
      if (x is num && y is num) LatLng(y.toDouble(), x.toDouble()),
    ];
    final overlay = OverlayFeature(
      rings: rings,
      paths: paths,
      points: points,
      attributes: arcGisObject(feature['attributes']),
    );
    return overlay.isEmpty ? null : overlay;
  }

  List<List<LatLng>> _lines(Object? raw) {
    if (raw is! List<Object?>) {
      return const [];
    }
    return [
      for (final path in raw)
        if (path is List<Object?>)
          [
            for (final point in path)
              if (point is List<Object?> && point.length >= 2)
                if (point[0] case final num x)
                  if (point[1] case final num y)
                    LatLng(y.toDouble(), x.toDouble()),
          ],
    ].where((line) => line.length > 1).toList(growable: false);
  }

  /// Roughly one screen pixel in degrees, used to generalize geometry.
  ///
  /// Overlay outlines are surveyed far finer than any screen shows. Asking the
  /// server to drop detail below a pixel cuts the response to a fraction and
  /// changes nothing a viewer could see.
  double _pixelSize(GeoBounds bounds) {
    const assumedViewportPixels = 1024;
    final width = (bounds.east - bounds.west).abs();
    return width <= 0 ? 0 : width / assumedViewportPixels;
  }

  Future<Map<String, Object?>> _post(
    Uri endpoint,
    Map<String, String> body,
  ) async {
    final response = await _client
        .post(
          endpoint,
          headers: const {'User-Agent': 'RiversideAtlas/1.0 (GIS prototype)'},
          body: body,
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw ArcGisException('The layer returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const ArcGisException('The layer returned an invalid response.');
    }
    if (decoded['error'] case final Map<String, Object?> error) {
      throw ArcGisException(
        arcGisString(
          error['message'],
          fallback: 'The layer rejected the query.',
        ),
      );
    }
    return decoded;
  }
}
