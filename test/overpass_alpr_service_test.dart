import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/overpass_alpr_service.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

const _viewport = GeoBounds(
  west: -117.45,
  south: 33.95,
  east: -117.35,
  north: 34.02,
);

final latitudePad = OverpassAlprService.padFor(
  _viewport.north - _viewport.south,
);
final longitudePad = OverpassAlprService.padFor(
  _viewport.east - _viewport.west,
);

/// The first `(south,west,north,east)` tuple in an Overpass query.
List<double> _boundingBoxIn(String query) {
  final match = RegExp(r'\(([-\d.,]+)\)').firstMatch(query)!;
  return match.group(1)!.split(',').map(double.parse).toList(growable: false);
}

void main() {
  group('AlprCamera', () {
    test('reads Flock tagging, direction, and mount from a node', () {
      final camera = AlprCamera.fromOverpassJson(_flockNode);

      expect(camera.sourceId, 'node/12464814027');
      expect(camera.isFlock, isTrue);
      expect(camera.direction, 250);
      expect(camera.mount, 'pole');
      expect(camera.description, contains('Faces W'));
    });

    test('recognizes Flock by Wikidata entity when brand text is absent', () {
      final camera = AlprCamera.fromOverpassJson(const {
        'type': 'node',
        'id': 5,
        'lat': 33.99,
        'lon': -117.4,
        'tags': {
          'man_made': 'surveillance',
          'surveillance:type': 'ALPR',
          'brand:wikidata': 'Q108485435',
        },
      });

      expect(camera.manufacturer, 'Flock Safety');
      expect(camera.isFlock, isTrue);
    });

    test('does not claim a toll gantry is Flock hardware', () {
      final camera = AlprCamera.fromOverpassJson(const {
        'type': 'node',
        'id': 9761577938,
        'lat': 33.9823,
        'lon': -117.5489,
        'tags': {
          'man_made': 'surveillance',
          'surveillance:type': 'ALPR',
          'highway': 'toll_gantry',
          'name': 'I-15 S Toll Gantry',
        },
      });

      expect(camera.isFlock, isFalse);
      expect(camera.description, startsWith('I-15 S Toll Gantry'));
    });

    test('uses the centroid Overpass reports for a mapped way', () {
      final camera = AlprCamera.fromOverpassJson(const {
        'type': 'way',
        'id': 77,
        'center': {'lat': 33.98, 'lon': -117.4},
        'tags': {'surveillance:type': 'ALPR', 'direction': 'NE'},
      });

      expect(camera.position.latitude, 33.98);
      expect(camera.direction, 45);
      expect(camera.sourceId, 'way/77');
    });
  });

  group('AlprCamera.viewCone', () {
    test('opens outward from the camera toward its bearing', () {
      final cone = AlprCamera.fromOverpassJson(_flockNode).viewCone();

      expect(cone.first, AlprCamera.fromOverpassJson(_flockNode).position);
      expect(cone, hasLength(10));

      final apex = cone.first;
      final distance = const Distance();
      for (final point in cone.skip(1)) {
        expect(distance.as(LengthUnit.Meter, apex, point), closeTo(90, 1));
      }

      final widthAcross = distance.as(LengthUnit.Meter, cone[1], cone.last);
      expect(widthAcross, greaterThan(70));
      expect(
        distance.bearing(apex, cone[cone.length ~/ 2]) % 360,
        closeTo(250, 1),
      );
    });

    test('is empty when the feature records no direction', () {
      final cone = AlprCamera.fromOverpassJson(const {
        'type': 'node',
        'id': 1,
        'lat': 33.9,
        'lon': -117.4,
        'tags': {'surveillance:type': 'ALPR'},
      }).viewCone();

      expect(cone, isEmpty);
    });
  });

  group('OverpassAlprService', () {
    test(
      'rejects HTTP 200 runtime errors without caching partial data',
      () async {
        var requests = 0;
        final service = OverpassAlprService(
          MockClient((_) async {
            requests++;
            return http.Response(
              jsonEncode({
                if (requests == 1) 'remark': 'runtime error: Query timed out',
                'elements': [_flockNode],
              }),
              200,
            );
          }),
        );
        await expectLater(
          service.queryViewport(_viewport),
          throwsFormatException,
        );
        expect(await service.queryViewport(_viewport), hasLength(1));
        expect(requests, 2);
      },
    );

    test('posts a bounded ALPR query and parses the elements', () async {
      String? sentBody;
      final client = MockClient((request) async {
        sentBody = request.body;
        return http.Response(
          jsonEncode({
            'elements': [_flockNode, 'not-an-element'],
          }),
          200,
        );
      });

      final cameras = await OverpassAlprService(
        client,
      ).queryViewport(_viewport);

      expect(cameras, hasLength(1));
      expect(cameras.single.isFlock, isTrue);
      final query = Uri.decodeQueryComponent(sentBody!.split('data=').last);
      expect(query, contains('"surveillance:type"="ALPR"'));
      expect(query, contains('out tags center 2000;'));
      expect(_boundingBoxIn(query), [
        closeTo(_viewport.south - latitudePad, 1e-9),
        closeTo(_viewport.west - longitudePad, 1e-9),
        closeTo(_viewport.north + latitudePad, 1e-9),
        closeTo(_viewport.east + longitudePad, 1e-9),
      ]);
    });

    test('reuses one response while the viewport stays inside it', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({
            'elements': [_flockNode],
          }),
          200,
        );
      });
      final service = OverpassAlprService(client);

      await service.queryViewport(_viewport);
      await service.queryViewport(
        const GeoBounds(
          west: -117.44,
          south: 33.96,
          east: -117.36,
          north: 34.01,
        ),
      );

      expect(requests, 1);
    });

    test('absorbs a quarter-screen pan at county-wide zoom', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(jsonEncode({'elements': []}), 200);
      });
      final service = OverpassAlprService(client);
      const wide = GeoBounds(
        west: -117.6,
        south: 33.8,
        east: -117.1,
        north: 34.1,
      );

      await service.queryViewport(wide);
      await service.queryViewport(
        const GeoBounds(
          west: -117.475,
          south: 33.875,
          east: -116.975,
          north: 34.175,
        ),
      );

      expect(requests, 1);
    });

    test('refetches once the viewport leaves the padded area', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(jsonEncode({'elements': []}), 200);
      });
      final service = OverpassAlprService(client);

      await service.queryViewport(_viewport);
      await service.queryViewport(
        const GeoBounds(west: -116.9, south: 33.6, east: -116.8, north: 33.7),
      );

      expect(requests, 2);
    });

    test('reports a rate-limited Overpass instance as a failure', () async {
      final client = MockClient((_) async => http.Response('slow down', 429));

      expect(
        OverpassAlprService(client).queryViewport(_viewport),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}

const _flockNode = {
  'type': 'node',
  'id': 12464814027,
  'lat': 33.9757804,
  'lon': -117.3500069,
  'tags': {
    'camera:mount': 'pole',
    'camera:type': 'fixed',
    'direction': '250',
    'man_made': 'surveillance',
    'manufacturer': 'Flock Safety',
    'manufacturer:wikidata': 'Q108485435',
    'surveillance': 'public',
    'surveillance:type': 'ALPR',
    'surveillance:zone': 'traffic',
  },
};
