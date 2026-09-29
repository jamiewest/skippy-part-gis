import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/domain/services/route_shaping.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'support/fake_route_editing.dart';
import 'support/fake_routing.dart';

void main() {
  late FakeEditableRouting backend;
  late FakeRouteCameras cameras;
  late RouteViewModel model;
  setUp(() async {
    backend = FakeEditableRouting();
    cameras = FakeRouteCameras([
      RouteCameraSnapshot(cameras: [], complete: true),
    ]);
    model = RouteViewModel(
      planner: RoutePlanner(routing: backend, cameras: cameras),
      geocoder: FakeRouteGeocoder(),
    );
    await model.calculate(
      stops: testStops,
      settings: const RouteOptions(preference: RoutePreference.fastest),
    );
  });
  tearDown(() => model.dispose());

  test('map gesture options change only at drag boundaries', () {
    var changes = 0;
    model.dragActivity.addListener(() => changes++);
    model.beginRouteDrag(0.5);
    expect(model.dragActivity.value, isTrue);
    for (var i = 0; i < 20; i++) {
      model.updateRouteDrag(routePoint(0, 100 + i.toDouble()), 50);
    }
    expect(changes, 1);
    model.cancelRouteEdit();
    expect(model.dragActivity.value, isFalse);
    expect(changes, 2);
  });

  Future<void> drag(LatLng point, {double position = 0.5, int? id}) async {
    expect(model.beginRouteDrag(position, anchorId: id), isTrue);
    model.updateRouteDrag(point, 50);
    await model.finishRouteDrag();
  }

  test(
    'release retains stops, updates route metrics and rechecks new corridor without fitting',
    () async {
      final revision = model.cameraRevision;
      final oldPath = model.selected!.path;
      await drag(routePoint(0, 400));
      expect(
        model.stops.map((s) => s!.position),
        testStops.map((s) => s.position),
      );
      expect(model.shapingPoints, hasLength(1));
      expect(model.selected!.path.points, contains(routePoint(0, 400)));
      expect(model.selected!.path.seconds, 160);
      expect(model.plan!.baselineSeconds, 160);
      expect(cameras.requests, hasLength(2));
      expect(cameras.requests.last.single.points, isNot(oldPath.points));
      expect(model.cameraRevision, revision);
      expect(model.editing, isFalse);
    },
  );

  test(
    'repeat, move, remove, undo and reset retain ordered independent shaping points',
    () async {
      await drag(routePoint(0, 200));
      final first = model.shapingPoints.single;
      await drag(routePoint(-100, 300), position: 0.25);
      expect(model.shapingPoints.map((p) => p.id), [1, first.id]);
      expect(backend.requests.last.map((p) => p.id), [1, first.id]);
      await drag(routePoint(100, 400), id: first.id);
      expect(model.shapingPoints.last.id, first.id);
      expect(model.shapingPoints.last.snap.position, routePoint(100, 400));
      await model.removeShapingPoint(first.id);
      expect(model.shapingPoints, hasLength(1));
      await model.undoRouteEdit();
      expect(model.shapingPoints, hasLength(2));
      await model.resetRouteEdits();
      expect(model.shapingPoints, isEmpty);
      expect(model.plan!.baselineSeconds, 100);
      await model.undoRouteEdit();
      expect(model.shapingPoints, hasLength(2));
      expect(cameras.requests, hasLength(8));
    },
  );

  test(
    'failed snap or routing rolls back route and does not add undo history',
    () async {
      final original = model.plan;
      backend.failSnap = true;
      await drag(routePoint(0, 200));
      expect(model.plan, same(original));
      expect(model.error, contains('nearby street'));
      backend.failSnap = false;
      backend.failRoute = true;
      await drag(routePoint(0, 300));
      expect(model.plan, same(original));
      expect(model.shapingPoints, isEmpty);
      expect(model.canUndo, isFalse);
      expect(model.busy, isFalse);
    },
  );

  test('incomplete camera query commits changed route as unverified', () async {
    cameras.snapshots.add(RouteCameraSnapshot(cameras: [], complete: false));
    await drag(routePoint(0, 200));
    expect(model.shapingPoints, hasLength(1));
    expect(model.plan!.cameraQueryComplete, isFalse);
    expect(model.plan!.notices.join(), contains('incomplete'));
  });

  test('cancel during final snapping ignores late result', () async {
    final original = model.plan;
    backend.pendingSnap = Completer<RouteRoadSnap>();
    model.beginRouteDrag(0.5);
    model.updateRouteDrag(routePoint(0, 200), 50);
    final finish = model.finishRouteDrag();
    expect(model.editing, isTrue);
    model.cancel();
    backend.pendingSnap!.complete(editableSnap(routePoint(0, 200)));
    await finish;
    expect(model.plan, same(original));
    expect(model.shapingPoints, isEmpty);
    expect(cameras.requests, hasLength(1));
  });

  test('changing stops invalidates pending edit results', () async {
    backend.pendingRoute = Completer<List<RoutePath>>();
    model.beginRouteDrag(0.5);
    model.updateRouteDrag(routePoint(0, 200), 50);
    final finish = model.finishRouteDrag();
    await Future<void>.delayed(Duration.zero);
    final anchors = backend.requests.last;
    model.setStop(0, RouteStop('New start', routePoint(-300, 0)));
    backend.pendingRoute!.complete([editablePath(testStops, anchors)]);
    await finish;
    expect(model.plan, isNull);
    expect(model.shapingPoints, isEmpty);
    expect(model.busy, isFalse);
  });

  test(
    'options retain shaping points; replacing or reversing stops clears them',
    () async {
      await drag(routePoint(0, 200));
      model.setOptions(
        const RouteOptions(
          preference: RoutePreference.fastest,
          maxDetourMinutes: 20,
        ),
      );
      expect(model.shapingPoints, hasLength(1));
      await model.calculate();
      expect(backend.requests.last, hasLength(1));
      model.reverseStops();
      expect(model.shapingPoints, isEmpty);
      expect(model.canUndo, isFalse);
    },
  );

  test('multi-stop edit belongs to the clicked leg', () async {
    final stops = [...testStops, RouteStop('Third', routePoint(500, 500))];
    await model.calculate(stops: stops);
    await drag(routePoint(300, 400), position: 1.5);
    expect(model.shapingPoints.single.legIndex, 1);
    expect(model.selected!.path.legEndIndices, hasLength(2));
  });

  test(
    'camera avoidance never drops chosen street and baseline includes manual detour',
    () async {
      model.setOptions(
        const RouteOptions(
          preference: RoutePreference.avoidMappedCoverage,
          maxDetourMinutes: 0,
        ),
      );
      await model.calculate();
      cameras.snapshots.add(
        RouteCameraSnapshot(
          cameras: [testCamera(direction: null, point: routePoint(0, 500))],
          complete: true,
        ),
      );
      final before = backend.requests.length;
      await drag(routePoint(0, 500));
      expect(model.shapingPoints, hasLength(1));
      expect(backend.requests.skip(before).every((r) => r.length == 1), isTrue);
      expect(model.plan!.baselineSeconds, 160);
      expect(model.selected!.hits, hasLength(1));
      expect(model.selectedConstraintsSatisfied, isFalse);
    },
  );

  testWidgets(
    'preview is debounced, skips cameras, and ignores stale snap after movement',
    (tester) async {
      model.beginRouteDrag(0.5);
      model.updateRouteDrag(routePoint(0, 100), 50);
      await tester.pump(const Duration(milliseconds: 200));
      expect(backend.snapped, isEmpty);
      backend.pendingSnap = Completer<RouteRoadSnap>();
      await tester.pump(const Duration(milliseconds: 200));
      expect(backend.snapped, hasLength(1));
      model.updateRouteDrag(routePoint(0, 300), 50);
      backend.pendingSnap!.complete(editableSnap(routePoint(0, 100)));
      await tester.pump();
      expect(model.draftSnap, isNull);
      expect(model.preview, isNull);
      expect(cameras.requests, hasLength(1));
      model.cancelRouteEdit();
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('live preview follows roads and commit checks cameras', (
    tester,
  ) async {
    model.beginRouteDrag(0.5);
    model.updateRouteDrag(routePoint(0, 200), 50);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(model.preview!.points, contains(routePoint(0, 200)));
    expect(model.shapingPoints, isEmpty);
    expect(cameras.requests, hasLength(1));
    await model.finishRouteDrag();
    expect(model.shapingPoints, hasLength(1));
    expect(cameras.requests, hasLength(2));
    expect(
      backend.snapped,
      hasLength(1),
      reason: 'reuse exact final preview snap',
    );
  });

  test(
    'geometry rejects crossing or parallel adjacent roads and accepts ordered loop visits',
    () {
      final snap = editableSnap(routePoint(0, 0));
      final anchor = RouteShapingPoint(id: 1, legIndex: 0, snap: snap);
      RoutePath path(List<LatLng> points) => RoutePath(
        points: points,
        maneuvers: testRoute().maneuvers,
        meters: 100,
        seconds: 100,
        legEndIndices: [points.length - 1],
      );
      expect(
        constrainRoutePath(path([routePoint(0, -100), routePoint(0, 100)]), [
          anchor,
        ]),
        isNull,
      );
      expect(
        constrainRoutePath(path([routePoint(-100, 7), routePoint(100, 7)]), [
          anchor,
        ]),
        isNull,
      );
      final loop = path([
        routePoint(-100, 0),
        routePoint(100, 0),
        routePoint(100, 100),
        routePoint(-100, 100),
        routePoint(-100, 0),
        routePoint(100, 0),
      ]);
      final middle = RouteShapingPoint(
        id: 2,
        legIndex: 0,
        snap: editableSnap(routePoint(0, 100)),
      );
      final again = RouteShapingPoint(id: 3, legIndex: 0, snap: snap);
      final result = constrainRoutePath(loop, [anchor, middle, again])!;
      expect(result.shapingPositions[1], lessThan(result.shapingPositions[2]!));
      expect(result.shapingPositions[2], lessThan(result.shapingPositions[3]!));
    },
  );
}
