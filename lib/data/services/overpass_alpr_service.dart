import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Reads crowdsourced license-plate readers from the OpenStreetMap Overpass
/// API, the same public dataset the DeFlock project maps.
///
/// Overpass is a shared volunteer service with per-client rate limits, unlike
/// the county's ArcGIS endpoints. Two habits keep this layer inside them: the
/// caller gates queries by zoom, and each request covers a padded area whose
/// result is reused while the viewport stays inside it.
final class OverpassAlprService implements AlprCameraRepository {
  /// Creates a service backed by the shared HTTP client.
  ///
  /// Pass [endpoint] to target a mirror, primarily in tests.
  OverpassAlprService(this._client, {Uri? endpoint})
    : _endpoint = endpoint ?? defaultEndpoint;

  /// The public Overpass instance queried by default.
  static final Uri defaultEndpoint = Uri.parse(
    'https://overpass-api.de/api/interpreter',
  );

  /// The share of the viewport span added to each edge before querying.
  ///
  /// Padding scales with the view so a pan of about half a screen still lands
  /// inside the cached area at any zoom.
  static const paddingRatio = 0.5;

  /// The narrowest padding applied to a viewport edge, in degrees.
  static const minimumPaddingDegrees = 0.01;

  /// The widest padding applied to a viewport edge, in degrees.
  ///
  /// Caps how much of the county one request can pull at low zoom.
  static const maximumPaddingDegrees = 0.15;

  static const _userAgent = 'riverside-atlas/1.0 (+com.skippy.riversideAtlas)';

  final http.Client _client;
  final Uri _endpoint;

  GeoBounds? _cachedArea;
  List<AlprCamera> _cachedCameras = const [];

  @override
  Future<List<AlprCamera>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    if (_cachedArea case final area? when area.encloses(bounds)) {
      return _cachedCameras;
    }
    final area = bounds.inflate(
      latitude: padFor(bounds.north - bounds.south),
      longitude: padFor(bounds.east - bounds.west),
    );
    final cameras = await _fetch(area, limit);
    _cachedArea = area;
    _cachedCameras = cameras;
    return cameras;
  }

  /// The padding applied to one viewport edge spanning [degrees].
  static double padFor(double degrees) => math.min(
    maximumPaddingDegrees,
    math.max(minimumPaddingDegrees, degrees.abs() * paddingRatio),
  );

  Future<List<AlprCamera>> _fetch(GeoBounds area, int limit) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': _userAgent,
          },
          body: {'data': _buildQuery(area, limit)},
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Overpass failed with HTTP ${response.statusCode}.',
        _endpoint,
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['elements'] is! List) {
      throw const FormatException('Overpass response is invalid.');
    }

    final cameras = <String, AlprCamera>{};
    for (final rawElement in payload['elements'] as List) {
      if (rawElement is! Map) {
        continue;
      }
      try {
        final camera = AlprCamera.fromOverpassJson(
          rawElement.cast<String, dynamic>(),
        );
        cameras[camera.sourceId] = camera;
      } on FormatException {
        continue;
      }
    }
    return cameras.values.toList(growable: false);
  }

  static String _buildQuery(GeoBounds area, int limit) {
    final box = '${area.south},${area.west},${area.north},${area.east}';
    const filter = '["man_made"="surveillance"]["surveillance:type"="ALPR"]';
    return '[out:json][timeout:25];'
        '(node$filter($box);way$filter($box););'
        'out tags center $limit;';
  }
}
