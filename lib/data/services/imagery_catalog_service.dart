import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Reads Riverside County imagery metadata from its ArcGIS Online catalog.
final class ImageryCatalogService implements ImageryCatalogRepository {
  /// Creates a catalog service backed by the shared HTTP client.
  const ImageryCatalogService(this._client);

  static final Uri catalogUri = Uri.parse(
    'https://gisopendata-countyofriverside.opendata.arcgis.com/'
    'search?tags=imagery',
  );
  static final Uri _searchUri = Uri.parse(
    'https://www.arcgis.com/sharing/rest/search',
  );
  static const _query =
      'orgid:pWmBUdSlVpXStHU6 AND type:"Image Service" '
      'AND title:Riverside_County '
      'AND (tags:aerial OR tags:imagery OR tags:Images)';

  final http.Client _client;

  @override
  Future<List<ImageryLayer>> list({GeoBounds? coverage}) async {
    final uri = _searchUri.replace(
      queryParameters: const {'q': _query, 'num': '100', 'f': 'json'},
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Imagery catalog failed with HTTP ${response.statusCode}.',
        uri,
      );
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> || payload['results'] is! List) {
      throw const FormatException('Imagery catalog response is invalid.');
    }

    final byYear = <int, ImageryLayer>{};
    for (final rawResult in payload['results'] as List) {
      if (rawResult is! Map) {
        continue;
      }
      try {
        final layer = ImageryLayer.fromArcGisJson(
          rawResult.cast<String, dynamic>(),
        );
        if (!layer.title.endsWith('_WM') ||
            layer.id.isEmpty ||
            !layer.serviceUri.path.endsWith('/ImageServer') ||
            (coverage != null && !layer.extent.intersects(coverage))) {
          continue;
        }
        byYear.putIfAbsent(layer.year, () => layer);
      } on FormatException {
        continue;
      }
    }
    final layers = byYear.values.toList()
      ..sort((first, second) => second.year.compareTo(first.year));
    return layers;
  }
}
