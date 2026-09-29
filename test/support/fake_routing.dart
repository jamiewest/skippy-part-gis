import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';

LatLng routePoint(double east, double north) => LatLng(
  34 + north / 111195,
  -117 + east / (111195 * math.cos(34 * math.pi / 180)),
);

RoutePath testRoute({double seconds = 100, List<LatLng>? points}) {
  final shape = points ?? [routePoint(-200, 50), routePoint(200, 50)];
  return RoutePath(
    points: shape,
    meters: 400,
    seconds: seconds,
    maneuvers: [
      RouteManeuver(
        instruction: 'Head east on Test Street',
        point: shape.first,
        meters: 400,
        seconds: seconds,
      ),
    ],
  );
}

RoutePath testDetour({double seconds = 200}) => testRoute(
  seconds: seconds,
  points: [
    routePoint(-200, 50),
    routePoint(-200, -200),
    routePoint(200, -200),
    routePoint(200, 50),
  ],
);
List<RouteStop> get testStops => [
  RouteStop('Start', routePoint(-200, 50)),
  RouteStop('Finish', routePoint(200, 50)),
];
AlprCamera testCamera({
  int id = 1,
  double? direction = 0,
  bool flock = true,
  LatLng? point,
}) => AlprCamera(
  osmType: 'node',
  osmId: id,
  position: point ?? routePoint(0, 0),
  direction: direction,
  manufacturer: flock ? 'Flock Safety' : 'Other',
);

class FakeRouting implements RoutingRepository {
  FakeRouting(this.responses);
  final List<List<RoutePath>> responses;
  final List<List<List<LatLng>>> exclusions = [];
  final List<bool> localRoadRequests = [];
  int calls = 0;
  @override
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  }) async {
    exclusions.add(excludePolygons);
    localRoadRequests.add(preferLocalRoads);
    return List.of(responses[math.min(calls++, responses.length - 1)]);
  }
}

class FakeRouteCameras implements RouteCameraRepository {
  FakeRouteCameras(this.snapshots);
  final List<RouteCameraSnapshot> snapshots;
  final List<List<RoutePath>> requests = [];
  @override
  Future<RouteCameraSnapshot> along(List<RoutePath> paths) async {
    requests.add(paths);
    return snapshots[math.min(requests.length - 1, snapshots.length - 1)];
  }
}

class FakeRouteGeocoder implements RouteGeocoder {
  @override
  Future<List<RouteStop>> search(String query, {LatLng? near}) async =>
      testStops;
}
