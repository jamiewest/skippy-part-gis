import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/arcgis_image_tile_provider.dart';
import 'package:riverside_atlas/data/services/imagery_catalog_service.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

void main() {
  group('ImageryCatalogService', () {
    test(
      'returns Riverside-covering Web Mercator captures newest first',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                _item(year: 2012),
                _item(
                  year: 2005,
                  extent: [
                    [-116.75, 33.58],
                    [-116.11, 34.03],
                  ],
                ),
                _item(year: 2020),
                {..._item(year: 2019), 'title': 'Riverside_County_2019_State'},
              ],
            }),
            200,
          ),
        );
        final layers = await ImageryCatalogService(client).list(
          coverage: const GeoBounds(
            west: -117.55,
            south: 33.85,
            east: -117.25,
            north: 34.05,
          ),
        );

        expect(layers.map((layer) => layer.year), [2020, 2012]);
        expect(layers.first.description, contains('2020'));
      },
    );
  });

  group('ArcGisImageTileProvider', () {
    test('converts an XYZ tile to a Web Mercator exportImage request', () {
      final provider = ArcGisImageTileProvider();
      final options = TileLayer(
        urlTemplate:
            'https://example.com/arcgis/rest/services/'
            'Riverside_2020/ImageServer',
      );

      final url = provider.getTileUrl(
        const TileCoordinates(22800, 52367, 17),
        options,
      );
      final uri = Uri.parse(url);

      expect(uri.path, endsWith('/ImageServer/exportImage'));
      expect(uri.queryParameters['bboxSR'], '3857');
      expect(uri.queryParameters['imageSR'], '3857');
      expect(uri.queryParameters['size'], '256,256');
      expect(uri.queryParameters['f'], 'image');
    });
  });
}

Map<String, Object> _item({
  required int year,
  List<List<double>> extent = const [
    [-117.70, 33.41],
    [-114.48, 34.10],
  ],
}) {
  return {
    'id': 'item-$year',
    'title': 'Riverside_County_${year}_WM',
    'url':
        'https://example.com/arcgis/rest/services/'
        'Riverside_County_${year}_WM/ImageServer',
    'snippet': 'Riverside County $year aerial imagery.',
    'extent': extent,
  };
}
