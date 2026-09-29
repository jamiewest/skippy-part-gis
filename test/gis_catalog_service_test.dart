import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/gis_catalog_service.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

const _portal = GisPortal(
  root: 'https://gis.example.gov/arcgis/rest/services',
  publisher: 'Example County',
  tier: PortalTier.countyPortal,
);

/// Shaped after a real county catalogue: folders at the root, services inside,
/// and non-map service types mixed in with the map layers.
http.Client _catalogue({List<String>? recorded}) {
  return MockClient((request) async {
    recorded?.add(request.url.toString());
    final path = request.url.path;
    if (path.endsWith('/rest/services')) {
      return http.Response(
        jsonEncode({
          'currentVersion': 11.5,
          'folders': ['OpenData', 'TLMA'],
          'services': [
            {'name': 'RiversideGeocoder', 'type': 'GeocodeServer'},
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/OpenData')) {
      return http.Response(
        jsonEncode({
          'services': [
            {'name': 'OpenData/Assessor', 'type': 'MapServer'},
            {'name': 'OpenData/ADDRESS', 'type': 'FeatureServer'},
            {'name': 'OpenData/Utilities', 'type': 'GPServer'},
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/TLMA')) {
      return http.Response(
        jsonEncode({
          'services': [
            {'name': 'TLMA/FLOOD_ZONES', 'type': 'MapServer'},
          ],
        }),
        200,
      );
    }
    return http.Response('{}', 404);
  });
}

void main() {
  group('GisCatalogService', () {
    test('lists services from the root and every folder', () async {
      final service = GisCatalogService(_catalogue());

      final services = await service.listServices(_portal);

      expect(
        services.map((entry) => entry.name),
        containsAll(<String>[
          'OpenData/Assessor',
          'OpenData/ADDRESS',
          'TLMA/FLOOD_ZONES',
        ]),
      );
    });

    test('drops service types that are not map layers', () async {
      final service = GisCatalogService(_catalogue());

      final services = await service.listServices(_portal);

      expect(
        services.map((entry) => entry.type),
        isNot(anyElement(anyOf('GPServer', 'GeocodeServer'))),
      );
    });

    test('reads a catalogue once per session', () async {
      final recorded = <String>[];
      final service = GisCatalogService(_catalogue(recorded: recorded));

      await service.listServices(_portal);
      final requestsAfterFirst = recorded.length;
      await service.listServices(_portal);

      expect(recorded, hasLength(requestsAfterFirst));
    });

    test('forget makes the catalogue read again', () async {
      final recorded = <String>[];
      final service = GisCatalogService(_catalogue(recorded: recorded));

      await service.listServices(_portal);
      final requestsAfterFirst = recorded.length;
      service.forget(_portal);
      await service.listServices(_portal);

      expect(recorded.length, requestsAfterFirst * 2);
    });

    test(
      'a folder that fails does not lose the rest of the catalogue',
      () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/rest/services')) {
            return http.Response(
              jsonEncode({
                'currentVersion': 11.5,
                'folders': ['Broken', 'OpenData'],
                'services': <Object>[],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/Broken')) {
            return http.Response('gateway timeout', 504);
          }
          return http.Response(
            jsonEncode({
              'services': [
                {'name': 'OpenData/Assessor', 'type': 'MapServer'},
              ],
            }),
            200,
          );
        });

        final services = await GisCatalogService(client).listServices(_portal);

        expect(services.single.name, 'OpenData/Assessor');
      },
    );
  });

  group('CatalogService', () {
    test('titles a service from its last path segment', () {
      const service = CatalogService(
        portal: _portal,
        name: 'TLMA/FLOOD_ZONES',
        type: 'MapServer',
        themes: [],
      );

      expect(service.title, 'FLOOD ZONES');
      expect(service.folder, 'TLMA');
    });

    test('chooses a render path from the service type', () {
      CatalogService of(String type) => CatalogService(
        portal: _portal,
        name: 'X',
        type: type,
        themes: const [],
      );

      expect(of('MapServer').render, OverlayRender.exportImage);
      expect(of('ImageServer').render, OverlayRender.imageServer);
      expect(of('FeatureServer').render, OverlayRender.featureQuery);
      expect(of('SceneServer').render, OverlayRender.unsupported);
      expect(of('SceneServer').isDrawable, isFalse);
    });
  });
}
