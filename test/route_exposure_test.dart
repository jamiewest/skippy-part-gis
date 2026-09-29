import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/domain/services/route_exposure.dart';
import 'support/fake_routing.dart';

void main() {
  const exposure = RouteExposure();
  test('intersects a cone even when both route vertices lie outside it', () {
    final result = exposure.assess(testRoute(), [testCamera()]);
    expect(result.directionalCount, 1);
    expect(result.hits.single.segments, {0});
  });
  test('road behind a north-facing reader remains available', () {
    expect(exposure.assess(testDetour(), [testCamera()]).hits, isEmpty);
  });
  test('reversing travel does not remove front or rear plate exposure', () {
    final route = testRoute();
    expect(
      exposure.assess(testRoute(points: route.points.reversed.toList()), [
        testCamera(),
      ]).directionalCount,
      1,
    );
  });
  for (final approaching in [true, false]) {
    test(
      '${approaching ? 'front' : 'rear'} plates count when '
      '${approaching ? 'approaching' : 'departing'} within the viewing area',
      () {
        final points = [routePoint(0, 200), routePoint(0, 20)];
        final route = testRoute(
          points: approaching ? points : points.reversed.toList(),
        );
        final result = exposure.assess(route, [testCamera()]);
        expect(result.directionalCount, 1);
        expect(result.hits.single.segments, {0});
        // Plate placement does not give a reader a view behind itself.
        expect(
          exposure.assess(route, [testCamera(direction: 180)]).hits,
          isEmpty,
        );
        expect(
          exposure.assess(route, [testCamera(direction: null)]).unknownCount,
          1,
        );
      },
    );
  }
  test('changing the reader bearing changes exposure', () {
    expect(
      exposure.assess(testRoute(), [testCamera(direction: 180)]).hits,
      isEmpty,
    );
    expect(
      exposure.assess(testRoute(), [testCamera(direction: 359)]).hits,
      hasLength(1),
    );
  });
  test('unknown bearing uses a conservative footprint on both sides', () {
    final unknown = testCamera(direction: null);
    expect(exposure.assess(testRoute(), [unknown]).unknownCount, 1);
    final behind = testRoute(
      points: [routePoint(-200, -50), routePoint(200, -50)],
    );
    expect(exposure.assess(behind, [unknown]).unknownCount, 1);
    expect(exposure.assess(testDetour(), [unknown]).hits, isEmpty);
  });
  test('duplicate vertices and a route through the camera are handled', () {
    final p = routePoint(0, 0);
    expect(
      exposure.assess(testRoute(points: [p, p, routePoint(0, 200)]), [
        testCamera(),
      ]).hits,
      hasLength(1),
    );
  });
}
