import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/san_bernardino_imagery_catalog_service.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

void main() {
  MockClient catalogClient(void Function(http.Request) capture) {
    return MockClient((request) async {
      capture(request);
      return http.Response(
        jsonEncode({
          'currentVersion': 10.91,
          'folders': ['Hosted', 'Utilities'],
          'services': [
            {'name': 'y2024_IS', 'type': 'ImageServer'},
            {'name': 'y2025_IS', 'type': 'ImageServer'},
            {'name': 'y2023_IS', 'type': 'ImageServer'},
            {'name': 'y2025_COG', 'type': 'ImageServer'},
            {'name': 'Y2024_pua_cache', 'type': 'MapServer'},
            {'name': 'Hinkley_All_2023', 'type': 'ImageServer'},
            {'name': 'SBC_Roads', 'type': 'FeatureServer'},
          ],
        }),
        200,
      );
    });
  }

  test('lists one yearly ImageServer per capture year, newest first', () async {
    late http.Request captured;
    final client = catalogClient((request) => captured = request);

    final layers = await SanBernardinoImageryCatalogService(client).list();

    check(captured.url.host).equals('maps.sbcounty.gov');
    check(captured.url.queryParameters['f']).equals('json');
    check(
      layers.map((layer) => layer.year).toList(),
    ).deepEquals([2025, 2024, 2023]);
    check(layers.first.serviceUri.toString()).equals(
      'https://maps.sbcounty.gov/img/rest/services/y2025_IS/ImageServer',
    );
    check(layers.first.title).equals('2025 San Bernardino County Aerial');
  });

  test('drops imagery when the viewport is outside the county', () async {
    final client = catalogClient((_) {});

    final layers = await SanBernardinoImageryCatalogService(client).list(
      coverage: const GeoBounds(
        west: -122.5,
        south: 37.7,
        east: -122.4,
        north: 37.8,
      ),
    );

    check(layers).isEmpty();
  });

  test('rejects a catalog response without a service list', () async {
    final client = MockClient(
      (request) async => http.Response(jsonEncode({'folders': []}), 200),
    );

    await check(
      SanBernardinoImageryCatalogService(client).list(),
    ).throws<FormatException>();
  });
}
