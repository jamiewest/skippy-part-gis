import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/route_camera_service.dart';
import 'package:riverside_atlas/data/services/route_geocoding_service.dart';
import 'package:riverside_atlas/data/services/valhalla_routing_service.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'support/fake_routing.dart';

void main() {
  Map<String, Object?> trip({String units = 'kilometers', int legs = 1}) => {
    'status': 0,
    'units': units,
    'summary': {'length': 2.5, 'time': 120},
    'legs': [
      for (var i = 0; i < legs; i++)
        {
          'shape': _encode([
            LatLng(34 + i * 0.001, -117),
            LatLng(34 + (i + 1) * 0.001, -117),
          ]),
          'maneuvers': [
            {
              'instruction': 'Head north',
              'begin_shape_index': 0,
              'length': 2.5,
              'time': 120,
            },
          ],
        },
    ],
  };
  test(
    'Valhalla sends exclusions in lon/lat and parses multi-leg alternatives',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['costing'], 'auto');
        expect(body['locations'], hasLength(3));
        expect(body['alternates'], 0);
        final polygon = (body['exclude_polygons'] as List).single as List;
        expect(polygon.first, [-117, 34]);
        expect(polygon.last, polygon.first);
        return http.Response(
          jsonEncode({
            'trip': trip(legs: 2),
            'alternates': [
              {'trip': trip(units: 'miles')},
            ],
          }),
          200,
        );
      });
      final result = await ValhallaRoutingService(client).routes(
        [...testStops, RouteStop('Third', routePoint(400, 500))],
        excludePolygons: [
          [
            const LatLng(34, -117),
            const LatLng(34.001, -117),
            const LatLng(34, -117.001),
          ],
        ],
      );
      expect(result, hasLength(2));
      expect(result.first.points, hasLength(3));
      expect(result.first.maneuvers.last.point, const LatLng(34.001, -117));
      expect(result.first.meters, 2500);
      expect(result.last.meters, closeTo(4023.36, 0.01));
    },
  );
  test(
    'polyline6 rejects truncated data rather than drawing a straight fallback',
    () {
      expect(() => decodePolyline6('_'), throwsFormatException);
      expect(() => decodePolyline6('!'), throwsFormatException);
      final points = decodePolyline6('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.first.latitude, closeTo(3.85, 1e-6));
      expect(points.last.longitude, closeTo(-12.6453, 1e-6));
    },
  );
  test(
    'neighborhood search uses local-road costing with driving restrictions',
    () async {
      for (final local in [false, true]) {
        final service = ValhallaRoutingService(
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            expect(body['costing'], 'auto');
            if (local) {
              expect(body['costing_options'], {
                'auto': {
                  'use_highways': 0,
                  'use_living_streets': 1,
                  'use_distance': 0.5,
                  'disable_hierarchy_pruning': true,
                },
              });
            } else {
              expect(body.containsKey('costing_options'), isFalse);
            }
            return http.Response(jsonEncode({'trip': trip()}), 200);
          }),
        );
        await service.routes(testStops, preferLocalRoads: local);
      }
    },
  );
  test('invalid and failed provider responses are visible errors', () async {
    for (final response in [
      http.Response('{}', 200),
      http.Response('no route', 400),
      http.Response(
        jsonEncode({
          'trip': {...trip(), 'status': 1},
        }),
        200,
      ),
    ]) {
      await expectLater(
        ValhallaRoutingService(
          MockClient((_) async => response),
        ).routes(testStops),
        throwsA(isA<RoutingException>()),
      );
    }
  });
  test('coordinate search works without sending a geocoding request', () async {
    var calls = 0;
    final geocoder = PhotonRouteGeocoder(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    expect(
      (await geocoder.search('34, -117')).single.position,
      const LatLng(34, -117),
    );
    await expectLater(
      geocoder.search('100, -117'),
      throwsA(isA<RoutingException>()),
    );
    expect(calls, 0);
  });
  test(
    'geocoding returns all candidates with coordinate order corrected',
    () async {
      final geocoder = PhotonRouteGeocoder(
        MockClient((request) async {
          expect(request.url.queryParameters['q'], 'City Hall');
          expect(request.headers['user-agent'], contains('Atlas/1.0'));
          expect(request.url.queryParameters['lat'], '34.0');
          return http.Response(
            jsonEncode({
              'features': [
                for (final city in ['Riverside', 'Redlands'])
                  {
                    'geometry': {
                      'coordinates': [-117.1, 34.1],
                    },
                    'properties': {
                      'name': 'City Hall',
                      'city': city,
                      'state': 'California',
                    },
                  },
              ],
            }),
            200,
          );
        }),
      );
      final places = await geocoder.search(
        'City Hall',
        near: const LatLng(34, -117),
      );
      expect(places, hasLength(2));
      expect(places.first.position, const LatLng(34.1, -117.1));
      expect(places.last.label, contains('Redlands'));
    },
  );
  test(
    'corridor tiles include segments between sparse vertices and padding',
    () {
      final tiles = OverpassRouteCameraService.corridorTiles([
        testRoute(points: [const LatLng(34, -117.2), const LatLng(34, -117)]),
      ]);
      expect(tiles.any((b) => b.contains(const LatLng(34, -117.1))), isTrue);
      expect(
        tiles.any((b) => b.contains(const LatLng(34.001, -117.1))),
        isTrue,
      );
    },
  );
  test(
    'oversized corridors explicitly report incomplete, without a partial query',
    () async {
      var calls = 0;
      final service = OverpassRouteCameraService(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final result = await service.along([
        testRoute(points: [const LatLng(34, -117), const LatLng(40, -74)]),
      ]);
      expect(result.complete, isFalse);
      expect(result.notice, contains('area limit'));
      expect(calls, 0);
    },
  );
  test(
    'Overpass runtime errors are never treated as an empty camera inventory',
    () async {
      final result = await OverpassRouteCameraService(
        MockClient((request) async {
          expect(request.body, contains('data='));
          return http.Response(
            jsonEncode({'elements': [], 'remark': 'runtime error: timeout'}),
            200,
          );
        }),
      ).along([testRoute()]);
      expect(result.complete, isFalse);
      expect(result.notice, contains('did not complete'));
    },
  );
  test(
    'camera cap and invalid records cannot produce verified empty coverage',
    () async {
      final elements = [
        for (var i = 0; i <= OverpassRouteCameraService.limit; i++)
          {
            'type': 'node',
            'id': i,
            'lat': 34,
            'lon': -117,
            'tags': {'direction': 'N'},
          },
      ];
      final capped = await OverpassRouteCameraService(
        MockClient(
          (_) async => http.Response(jsonEncode({'elements': elements}), 200),
        ),
      ).along([testRoute()]);
      expect(capped.complete, isFalse);
      final invalid = await OverpassRouteCameraService(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'elements': [
                {'type': 'node', 'id': 1},
              ],
            }),
            200,
          ),
        ),
      ).along([testRoute()]);
      expect(invalid.complete, isFalse);
    },
  );
}

String _encode(List<LatLng> points) {
  final text = StringBuffer();
  var lat = 0, lon = 0;
  void add(int delta) {
    var value = delta < 0 ? ~(delta << 1) : delta << 1;
    while (value >= 32) {
      text.writeCharCode((32 | (value & 31)) + 63);
      value >>= 5;
    }
    text.writeCharCode(value + 63);
  }

  for (final point in points) {
    final nextLat = (point.latitude * 1e6).round(),
        nextLon = (point.longitude * 1e6).round();
    add(nextLat - lat);
    add(nextLon - lon);
    lat = nextLat;
    lon = nextLon;
  }
  return text.toString();
}
