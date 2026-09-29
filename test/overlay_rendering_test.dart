import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/arcgis_image_tile_provider.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/gis_portal_registry.g.dart';
import 'package:riverside_atlas/data/services/layer_themes.dart';
import 'package:riverside_atlas/data/services/overlay_feature_service.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

const _bounds = GeoBounds(west: -117.4, south: 33.9, east: -117.3, north: 34.0);

void main() {
  group('ArcGisExportTileProvider', () {
    test('asks a MapServer for a transparent Web Mercator tile', () {
      final url = ArcGisExportTileProvider().getTileUrl(
        const TileCoordinates(0, 0, 0),
        TileLayer(
          urlTemplate:
              'https://gis.example.gov/arcgis/rest/services/'
              'Flood/MapServer',
        ),
      );

      final query = Uri.parse(url).queryParameters;
      expect(Uri.parse(url).path, endsWith('/Flood/MapServer/export'));
      expect(query['transparent'], 'true');
      expect(query['format'], 'png32');
      expect(query['bboxSR'], '3857');
      expect(query['f'], 'image');
    });

    test('the world tile spans the whole Web Mercator extent', () {
      final url = ArcGisExportTileProvider().getTileUrl(
        const TileCoordinates(0, 0, 0),
        TileLayer(urlTemplate: 'https://example.gov/x/MapServer'),
      );

      final bbox = Uri.parse(url).queryParameters['bbox']!.split(',');
      expect(double.parse(bbox[0]), closeTo(-20037508.34, 0.1));
      expect(double.parse(bbox[3]), closeTo(20037508.34, 0.1));
    });

    test('names only the sub-layers it was asked for', () {
      final url = ArcGisExportTileProvider(visibleLayers: const [2, 5])
          .getTileUrl(
            const TileCoordinates(1, 2, 3),
            TileLayer(urlTemplate: 'https://example.gov/x/MapServer'),
          );

      expect(Uri.parse(url).queryParameters['layers'], 'show:2,5');
    });

    test('an ImageServer still exports through its own endpoint', () {
      final url = ArcGisImageTileProvider().getTileUrl(
        const TileCoordinates(1, 2, 3),
        TileLayer(urlTemplate: 'https://example.gov/y/ImageServer'),
      );

      expect(Uri.parse(url).path, endsWith('/ImageServer/exportImage'));
    });
  });

  group('OverlayFeatureService', () {
    test(
      'reads polygons, lines and points with untouched attributes',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'attributes': {'ZONE': 'AE', 'OBJECTID': 7},
                  'geometry': {
                    'rings': [
                      [
                        [-117.35, 33.95],
                        [-117.34, 33.95],
                        [-117.34, 33.96],
                        [-117.35, 33.95],
                      ],
                    ],
                  },
                },
                {
                  'attributes': <String, Object?>{},
                  'geometry': {
                    'paths': [
                      [
                        [-117.35, 33.95],
                        [-117.34, 33.96],
                      ],
                    ],
                  },
                },
                {
                  'attributes': <String, Object?>{},
                  'geometry': {'x': -117.35, 'y': 33.95},
                },
              ],
            }),
            200,
          );
        });

        final features = await OverlayFeatureService(client).queryViewport(
          Uri.parse('https://example.gov/x/FeatureServer/0/query'),
          _bounds,
        );

        expect(features, hasLength(3));
        expect(features[0].rings.single, hasLength(4));
        expect(features[0].attributes['ZONE'], 'AE');
        expect(features[1].paths.single, hasLength(2));
        expect(features[2].points.single.latitude, closeTo(33.95, 0.001));
      },
    );

    test(
      'never asks a spatial query for fewer rows than the fast path',
      () async {
        late Map<String, String> body;
        final client = MockClient((request) async {
          body = Uri.splitQueryString(request.body);
          return http.Response(jsonEncode({'features': <Object>[]}), 200);
        });

        await OverlayFeatureService(client).queryViewport(
          Uri.parse('https://example.gov/x/FeatureServer/0/query'),
          _bounds,
          limit: 5,
        );

        expect(
          int.parse(body['resultRecordCount']!),
          greaterThanOrEqualTo(250),
        );
      },
    );

    test('drops features carrying no geometry', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'features': [
              {
                'attributes': <String, Object?>{},
                'geometry': <String, Object?>{},
              },
            ],
          }),
          200,
        );
      });

      final features = await OverlayFeatureService(client).queryViewport(
        Uri.parse('https://example.gov/x/FeatureServer/0/query'),
        _bounds,
      );

      expect(features, isEmpty);
    });

    test('reports a rejected query rather than returning nothing', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Unable to complete operation.'},
          }),
          200,
        );
      });

      expect(
        () => OverlayFeatureService(client).queryViewport(
          Uri.parse('https://example.gov/x/FeatureServer/0/query'),
          _bounds,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('layer themes', () {
    test('files a service under the most useful theme it matches', () {
      expect(primaryThemeOf('OpenData/Assessor_Parcels'), 'parcels & assessor');
      expect(primaryThemeOf('TLMA/FLOOD_ZONES'), 'flood & water');
      expect(primaryThemeOf('Aerials_WGS/County_2020_WM'), 'aerial imagery');
    });

    test('a service matching nothing is filed as other', () {
      expect(primaryThemeOf('Form_11'), 'other');
    });

    test('a service can belong to several themes at once', () {
      expect(
        themesOf('Fire_Hazard_Evacuation_Routes'),
        containsAll(<String>['fire & hazard', 'transportation']),
      );
    });

    test('flood zones are water, not zoning', () {
      // `zone` on its own matched FLOOD_ZONES, HAZARD_ZONE and half the
      // hydrology layers in the county inventories, which put them all under
      // land use. Zoning has to be named to count.
      expect(themesOf('FLOOD_ZONES'), isNot(contains('zoning & land use')));
      expect(themesOf('Zoning_Districts'), contains('zoning & land use'));
    });
  });

  group('portal registry', () {
    test('the two hand-configured counties carry their own portals', () {
      for (final id in ['ca_riverside', 'ca_san_bernardino']) {
        expect(
          countyPortals[id],
          isNotNull,
          reason: '$id should have a generated portal list',
        );
        expect(
          countyPortals[id]!.any(
            (portal) => portal.tier == PortalTier.countyPortal,
          ),
          isTrue,
          reason: '$id should have at least one first-party portal',
        );
      }
    });

    test('offers a state agency only inside the state it covers', () {
      // CAL FIRE and the California State Geoportal describe California. A
      // Texas county listing them would attribute coverage their publishers
      // never claimed.
      expect(
        statePortals['06']!.map((portal) => portal.root),
        contains(contains('services.gis.ca.gov')),
      );
      expect(statePortals['48'], isNull);
      for (final portals in statePortals.values) {
        for (final portal in portals) {
          expect(portal.tier, PortalTier.statewide, reason: portal.root);
        }
      }
    });

    test('offers the federal tier in every county, in every state', () {
      // This is what stops a county outside California opening an empty panel.
      expect(
        nationalPortals.map((portal) => portal.root),
        contains(contains('tigerweb.geo.census.gov')),
      );
      for (final portal in nationalPortals) {
        expect(portal.tier, PortalTier.national, reason: portal.root);
      }
      final harris = CountySources.byFips('48201')!;
      final roots = harris.portals.map((portal) => portal.root).toList();
      expect(roots, contains(contains('tigerweb.geo.census.gov')));
      expect(roots, isNot(contains(contains('services.gis.ca.gov'))));
    });

    test('every registered root is an absolute REST catalogue', () {
      final roots = [
        ...nationalPortals,
        ...statePortals.values.expand((portals) => portals),
        ...countyPortals.values.expand((portals) => portals),
      ];
      for (final portal in roots) {
        expect(portal.uri.isAbsolute, isTrue, reason: portal.root);
        expect(portal.root, endsWith('/rest/services'), reason: portal.root);
      }
    });
  });
}
