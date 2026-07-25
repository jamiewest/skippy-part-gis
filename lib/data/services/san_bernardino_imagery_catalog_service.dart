import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Reads San Bernardino County aerial imagery from its ArcGIS server.
///
/// Riverside publishes one searchable ArcGIS Online catalog, but San
/// Bernardino publishes a separate `ImageServer` per capture year, so the
/// year comes from the service name rather than from item metadata.
final class SanBernardinoImageryCatalogService
    implements ImageryCatalogRepository {
  /// Creates a catalog service backed by the shared HTTP client.
  const SanBernardinoImageryCatalogService(this._client);

  /// Root of the county's public imagery server.
  static final Uri servicesUri = Uri.parse(
    'https://maps.sbcounty.gov/img/rest/services',
  );

  /// Countywide coverage advertised for every yearly layer.
  ///
  /// The `ImageServer` metadata reports its extent in California State Plane
  /// (EPSG:2229), so the county boundary supplies WGS84 coverage instead.
  static const countyCoverage = GeoBounds(
    west: -117.81,
    south: 33.86,
    east: -114.12,
    north: 35.82,
  );

  static final _yearlyService = RegExp(r'^y(\d{4})_IS$');

  final http.Client _client;

  @override
  Future<List<ImageryLayer>> list({GeoBounds? coverage}) async {
    final uri = servicesUri.replace(queryParameters: const {'f': 'json'});
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
    if (payload is! Map<String, dynamic> || payload['services'] is! List) {
      throw const FormatException('Imagery catalog response is invalid.');
    }
    if (coverage != null && !countyCoverage.intersects(coverage)) {
      return const [];
    }

    final byYear = <int, ImageryLayer>{};
    for (final rawService in payload['services'] as List) {
      if (rawService is! Map || rawService['type'] != 'ImageServer') {
        continue;
      }
      final name = rawService['name']?.toString() ?? '';
      final match = _yearlyService.firstMatch(name);
      if (match == null) {
        continue;
      }
      final year = int.parse(match.group(1)!);
      byYear.putIfAbsent(year, () => _layer(name: name, year: year));
    }
    final layers = byYear.values.toList()
      ..sort((first, second) => second.year.compareTo(first.year));
    return layers;
  }

  ImageryLayer _layer({required String name, required int year}) {
    return ImageryLayer(
      id: name,
      title: '$year San Bernardino County Aerial',
      year: year,
      serviceUri: servicesUri.replace(
        path: '${servicesUri.path}/$name/ImageServer',
      ),
      description: 'County aerial imagery published as $name.',
      extent: countyCoverage,
    );
  }
}
