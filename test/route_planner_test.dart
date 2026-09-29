import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'support/fake_routing.dart';

void main() {
  RouteCameraSnapshot snapshot({bool complete = true}) =>
      RouteCameraSnapshot(cameras: [testCamera()], complete: complete);

  for (final approaching in [true, false]) {
    for (final preference in [
      RoutePreference.lowerExposure,
      RoutePreference.avoidMappedCoverage,
    ]) {
      test(
        'detours around front/rear exposure ($approaching, $preference)',
        () async {
          final points = [routePoint(0, 200), routePoint(0, -200)];
          final detourPoints = [
            points.first,
            routePoint(200, 200),
            routePoint(200, -200),
            points.last,
          ];
          final direct = testRoute(
            points: approaching ? points : points.reversed.toList(),
          );
          final detour = testRoute(
            seconds: 200,
            points: approaching ? detourPoints : detourPoints.reversed.toList(),
          );
          final routing = FakeRouting([
            [direct],
            [detour],
          ]);
          final result =
              await RoutePlanner(
                routing: routing,
                cameras: FakeRouteCameras([snapshot()]),
              ).plan([
                RouteStop('Start', direct.points.first),
                RouteStop('Finish', direct.points.last),
              ], RouteOptions(preference: preference));
          expect(result.constraintsSatisfied, isTrue);
          expect(result.routes.first.path, same(detour));
          expect(result.routes.first.hits, isEmpty);
          expect(result.routes.every((r) => r.hits.isEmpty), isTrue);
          expect(routing.exclusions[1], hasLength(1));
        },
      );
    }
  }

  test(
    'requests facing-footprint detour and rechecks its entire corridor',
    () async {
      final routing = FakeRouting([
        [testRoute()],
        [testDetour()],
      ]);
      final cameras = FakeRouteCameras([snapshot()]);
      final result = await RoutePlanner(routing: routing, cameras: cameras)
          .plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.constraintsSatisfied, isTrue);
      expect(result.routes.first.path.seconds, 200);
      expect(routing.exclusions[1], hasLength(1));
      expect(
        routing.exclusions[1].single.every((p) => p.latitude >= 34),
        isTrue,
      );
      expect(cameras.requests, hasLength(2));
      expect(cameras.requests.last, hasLength(2));
    },
  );
  test(
    'a new camera on the detour prevents a false avoidance success',
    () async {
      final routing = FakeRouting([
        [testRoute()],
        [testDetour()],
      ]);
      final cameras = FakeRouteCameras([
        snapshot(),
        RouteCameraSnapshot(
          cameras: [
            testCamera(),
            testCamera(id: 2, point: routePoint(0, -250)),
          ],
          complete: true,
        ),
      ]);
      final result = await RoutePlanner(routing: routing, cameras: cameras)
          .plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.constraintsSatisfied, isFalse);
      expect(result.routes.every((r) => r.hits.isNotEmpty), isTrue);
      expect(result.notices.join(' '), contains('No candidate met'));
    },
  );
  test('detour limit cannot be silently relaxed', () async {
    final planner = RoutePlanner(
      routing: FakeRouting([
        [testRoute()],
        [testDetour(seconds: 1000)],
      ]),
      cameras: FakeRouteCameras([snapshot()]),
    );
    final result = await planner.plan(
      testStops,
      const RouteOptions(
        preference: RoutePreference.avoidMappedCoverage,
        maxDetourMinutes: 1,
      ),
    );
    expect(result.constraintsSatisfied, isFalse);
    expect(result.routes, hasLength(1));
  });
  RoutePath neighborhood(double north, double seconds) => testRoute(
    seconds: seconds,
    points: [
      testStops.first.position,
      routePoint(-200, north),
      routePoint(200, north),
      testStops.last.position,
    ],
  );

  test('duplicate exposed route broadens search into nearby streets', () async {
    final routing = FakeRouting([
      [testRoute()],
      [testRoute()],
      [testDetour()],
    ]);
    final cameras = FakeRouteCameras([snapshot()]);
    final result = await RoutePlanner(
      routing: routing,
      cameras: cameras,
    ).plan(testStops, const RouteOptions());
    expect(result.routes.single.path.seconds, 200);
    expect(result.routes.single.hits, isEmpty);
    expect(routing.localRoadRequests.first, isFalse);
    expect(routing.localRoadRequests.skip(1).every((local) => local), isTrue);
    expect(routing.exclusions[2], isNot(equals(routing.exclusions[1])));
    expect(cameras.requests, hasLength(2));
    expect(result.baselineSeconds, 100);
  });

  test(
    'continues after success and retains the three most efficient routes',
    () async {
      final routing = FakeRouting([
        [testRoute()],
        [neighborhood(-200, 300)],
        [
          neighborhood(-250, 240),
          neighborhood(-300, 180),
          neighborhood(-350, 210),
          neighborhood(-400, 170),
          neighborhood(-450, 1100),
        ],
      ]);
      final result = await RoutePlanner(
        routing: routing,
        cameras: FakeRouteCameras([snapshot()]),
      ).plan(testStops, const RouteOptions());
      expect(result.routes.map((r) => r.path.seconds), [170, 180, 210]);
      expect(result.routes.every((r) => r.hits.isEmpty), isTrue);
      expect(result.baselineSeconds, 100);
      expect(
        routing.exclusions[2].length,
        greaterThan(routing.exclusions[1].length),
      );
      expect(
        routing.calls,
        lessThanOrEqualTo(RoutePlanner.maxAvoidancePasses + 1),
      );
    },
  );

  test(
    'new branch cameras disqualify an apparently faster alternative',
    () async {
      final routing = FakeRouting([
        [testRoute()],
        [neighborhood(-200, 200)],
        [neighborhood(-350, 150)],
      ]);
      final result =
          await RoutePlanner(
            routing: routing,
            cameras: FakeRouteCameras([
              snapshot(),
              snapshot(),
              RouteCameraSnapshot(
                cameras: [
                  testCamera(),
                  testCamera(id: 2, point: routePoint(0, -400)),
                ],
                complete: true,
              ),
            ]),
          ).plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.routes.single.path.seconds, 200);
      expect(result.routes.single.hits, isEmpty);
    },
  );

  test(
    'an incomplete branch camera check cannot claim successful avoidance',
    () async {
      final result =
          await RoutePlanner(
            routing: FakeRouting([
              [testRoute()],
              [testDetour()],
              [neighborhood(-350, 150)],
            ]),
            cameras: FakeRouteCameras([
              snapshot(),
              snapshot(),
              RouteCameraSnapshot(cameras: const [], complete: false),
            ]),
          ).plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.cameraQueryComplete, isFalse);
      expect(result.constraintsSatisfied, isFalse);
      expect(result.routes.first.path.seconds, 100);
    },
  );

  test(
    'an unavailable branch does not discard success or stop other branches',
    () async {
      final result =
          await RoutePlanner(
            routing: _FailingBranchRouting([
              [testRoute()],
              [neighborhood(-200, 300)],
              [],
              [neighborhood(-350, 200)],
            ]),
            cameras: FakeRouteCameras([snapshot()]),
          ).plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.constraintsSatisfied, isTrue);
      expect(result.routes.map((r) => r.path.seconds), [200, 300]);
    },
  );

  test(
    'repeated geometry cannot make the graph search loop indefinitely',
    () async {
      final routing = FakeRouting([
        [testRoute()],
      ]);
      final result =
          await RoutePlanner(
            routing: routing,
            cameras: FakeRouteCameras([snapshot()]),
          ).plan(
            testStops,
            const RouteOptions(preference: RoutePreference.avoidMappedCoverage),
          );
      expect(result.constraintsSatisfied, isFalse);
      expect(
        routing.calls,
        lessThanOrEqualTo(RoutePlanner.maxAvoidancePasses + 1),
      );
      expect(result.routes, hasLength(1));
    },
  );
  test(
    'failed camera query returns ordinary routes with unverified coverage',
    () async {
      final routing = FakeRouting([
        [testRoute(), testDetour()],
      ]);
      final result = await RoutePlanner(
        routing: routing,
        cameras: FakeRouteCameras([
          RouteCameraSnapshot(
            cameras: const [],
            complete: false,
            notice: 'Source timed out',
          ),
        ]),
      ).plan(testStops, const RouteOptions());
      expect(result.cameraQueryComplete, isFalse);
      expect(result.constraintsSatisfied, isFalse);
      expect(result.routes.first.path.seconds, 100);
      expect(routing.calls, 1);
    },
  );
  test('Flock-only excludes other vendors; all includes them', () async {
    final cameras = FakeRouteCameras([
      RouteCameraSnapshot(cameras: [testCamera(flock: false)], complete: true),
    ]);
    final planner = RoutePlanner(
      routing: FakeRouting([
        [testRoute()],
      ]),
      cameras: cameras,
    );
    final flock = await planner.plan(
      testStops,
      const RouteOptions(cameraFilter: RouteCameraFilter.flock),
    );
    expect(flock.routes.single.hits, isEmpty);
    final all = await planner.plan(testStops, const RouteOptions());
    expect(all.routes.single.hits, hasLength(1));
  });
  test(
    'fastest route still reports exposure but does not request detours',
    () async {
      final routing = FakeRouting([
        [testDetour(), testRoute()],
      ]);
      final result =
          await RoutePlanner(
            routing: routing,
            cameras: FakeRouteCameras([snapshot()]),
          ).plan(
            testStops,
            const RouteOptions(preference: RoutePreference.fastest),
          );
      expect(result.routes.first.path.seconds, 100);
      expect(result.routes.first.hits, hasLength(1));
      expect(routing.calls, 1);
    },
  );
  test(
    'editing stops invalidates a pending route without late updates',
    () async {
      final routing = _DelayedRouting();
      final cameras = FakeRouteCameras([snapshot()]);
      final model = RouteViewModel(
        planner: RoutePlanner(routing: routing, cameras: cameras),
        geocoder: FakeRouteGeocoder(),
      );
      addTearDown(model.dispose);
      final pending = model.calculate(stops: testStops);
      model.setStop(0, RouteStop('New start', routePoint(-300, 100)));
      routing.pending.complete([testRoute()]);
      expect(await pending, isNull);
      expect(model.plan, isNull);
      expect(model.busy, isFalse);
      expect(cameras.requests, isEmpty);
    },
  );
  test('disposing while routing does not notify or query cameras', () async {
    final routing = _DelayedRouting();
    final cameras = FakeRouteCameras([snapshot()]);
    final model = RouteViewModel(
      planner: RoutePlanner(routing: routing, cameras: cameras),
      geocoder: FakeRouteGeocoder(),
    );
    final pending = model.calculate(stops: testStops);
    model.dispose();
    routing.pending.complete([testRoute()]);
    expect(await pending, isNull);
    expect(cameras.requests, isEmpty);
  });
  test('invalid settings fail before issuing network requests', () async {
    final routing = FakeRouting([
      [testRoute()],
    ]);
    final planner = RoutePlanner(
      routing: routing,
      cameras: FakeRouteCameras([snapshot()]),
    );
    await expectLater(
      planner.plan(testStops, const RouteOptions(maxDetourMinutes: -1)),
      throwsA(isA<RoutingException>()),
    );
    expect(routing.calls, 0);
  });
}

class _DelayedRouting implements RoutingRepository {
  final pending = Completer<List<RoutePath>>();
  @override
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  }) => pending.future;
}

class _FailingBranchRouting extends FakeRouting {
  _FailingBranchRouting(super.responses);

  @override
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  }) async {
    final result = await super.routes(
      stops,
      excludePolygons: excludePolygons,
      preferLocalRoads: preferLocalRoads,
    );
    if (calls == 3) throw const RoutingException('No route for this branch.');
    return result;
  }
}
