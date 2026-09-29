import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/valhalla_routing_service.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'support/fake_routing.dart';

void main() {
  Map<String, Object?> edge(
    LatLng position, {
    bool car = true,
    bool unreachable = false,
  }) => {
    'correlated_lat': position.latitude,
    'correlated_lon': position.longitude,
    'edge': {
      'access': {'car': car},
      'unreachable': unreachable,
    },
    'edge_info': {
      'way_id': 123,
      'names': ['Main Street'],
      'shape': encode([routePoint(-100, 50), routePoint(100, 50)]),
    },
  };
  test(
    'locate retains endpoint query, filters driving access and chooses closest within tolerance',
    () async {
      final service = ValhallaRoutingService(
        MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.test/api/locate?key=test',
          );
          final body = jsonDecode(request.body) as Map;
          expect(body['costing'], 'auto');
          expect(body['verbose'], isTrue);
          expect(body['locations'][0]['radius'], 50);
          return http.Response(
            jsonEncode([
              {
                'edges': [
                  edge(routePoint(0, 50), car: false),
                  edge(routePoint(0, 51), unreachable: true),
                  edge(routePoint(0, 120)),
                  edge(routePoint(0, 75)),
                  edge(routePoint(0, 60)),
                ],
              },
            ]),
            200,
          );
        }),
        endpoint: Uri.parse('https://example.test/api/route?key=test'),
      );
      final result = await service.snap(routePoint(0, 50), maxMeters: 50);
      expect(result.position, routePoint(0, 60));
      expect(result.label, 'Main Street');
      expect(result.wayId, '123');
      expect(result.road, hasLength(2));
    },
  );

  test(
    'snap override, physical cap and unsupported or malformed results fail visibly',
    () async {
      for (final response in [
        http.Response('unavailable', 503),
        http.Response('{}', 200),
        http.Response('[{"edges":[]}]', 200),
        http.Response(
          jsonEncode([
            {
              'edges': [edge(routePoint(0, 150))],
            },
          ]),
          200,
        ),
      ]) {
        final service = ValhallaRoutingService(
          MockClient((request) async {
            expect(request.url.toString(), 'https://snap.test/custom');
            expect(
              jsonDecode(request.body)['locations'][0]['search_cutoff'],
              75,
            );
            return response;
          }),
          snapEndpoint: Uri.parse('https://snap.test/custom'),
        );
        await expectLater(
          service.snap(routePoint(0, 50), maxMeters: 1000),
          throwsA(isA<RoutingException>()),
        );
      }
    },
  );

  test(
    'through locations preserve numbered stop legs and reject geometry ignoring the chosen street',
    () async {
      final road = [routePoint(-50, 200), routePoint(50, 200)];
      final anchor = RouteShapingPoint(
        id: 42,
        legIndex: 0,
        snap: RouteRoadSnap(
          position: routePoint(0, 200),
          label: 'Chosen',
          road: road,
        ),
      );
      for (final valid in [true, false]) {
        final shape = [
          testStops.first.position,
          if (valid) ...road,
          testStops.last.position,
        ];
        final service = ValhallaRoutingService(
          MockClient((request) async {
            final body = jsonDecode(request.body);
            expect(body['locations'].map((dynamic p) => p['type']).toList(), [
              'break',
              'through',
              'break',
            ]);
            expect(body['locations'][1]['search_cutoff'], 10);
            expect(body['locations'][1]['node_snap_tolerance'], 0);
            expect(body['alternates'], 0);
            return http.Response(
              jsonEncode({
                'trip': {
                  'status': 0,
                  'units': 'kilometers',
                  'summary': {'length': 1, 'time': 200},
                  'legs': [
                    {
                      'shape': encode(shape),
                      'maneuvers': [
                        {
                          'instruction': 'Drive',
                          'begin_shape_index': 0,
                          'length': 1,
                          'time': 200,
                        },
                      ],
                    },
                  ],
                },
              }),
              200,
            );
          }),
        );
        if (valid) {
          final path = (await service.routes(
            testStops,
            shapingPoints: [anchor],
          )).single;
          expect(path.legEndIndices, [3]);
          expect(path.shapingPositions[42], closeTo(1.5, 0.01));
          expect(path.maneuvers, hasLength(1));
        } else {
          await expectLater(
            service.routes(testStops, shapingPoints: [anchor]),
            throwsA(isA<RoutingException>()),
          );
        }
      }
    },
  );
}

String encode(List<LatLng> points) {
  final output = StringBuffer();
  var lat = 0, lon = 0;
  void append(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 32) {
      output.writeCharCode((32 | (v & 31)) + 63);
      v >>= 5;
    }
    output.writeCharCode(v + 63);
  }

  for (final point in points) {
    final y = (point.latitude * 1e6).round(),
        x = (point.longitude * 1e6).round();
    append(y - lat);
    append(x - lon);
    lat = y;
    lon = x;
  }
  return output.toString();
}
