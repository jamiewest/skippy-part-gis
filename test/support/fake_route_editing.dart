import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';

RouteRoadSnap editableSnap(LatLng point) => RouteRoadSnap(
  position: point,
  label: 'Chosen Street',
  wayId: '123',
  road: [
    LatLng(point.latitude, point.longitude - 0.0001),
    LatLng(point.latitude, point.longitude + 0.0001),
  ],
);

RoutePath editablePath(List<RouteStop> stops, List<RouteShapingPoint> anchors) {
  final points = <LatLng>[stops.first.position];
  final ends = <int>[];
  for (var i = 0; i < stops.length - 1; i++) {
    for (final anchor in anchors.where((p) => p.legIndex == i)) {
      points.addAll([
        anchor.snap.road.first,
        anchor.snap.position,
        anchor.snap.road.last,
      ]);
    }
    points.add(stops[i + 1].position);
    ends.add(points.length - 1);
  }
  return RoutePath(
    points: points,
    legEndIndices: ends,
    maneuvers: [
      RouteManeuver(
        instruction: 'Drive along the chosen streets',
        point: stops.first.position,
        meters: 400,
        seconds: 100,
      ),
    ],
    meters: 400 + anchors.length * 100,
    seconds: 100 + anchors.length * 60,
  );
}

class FakeEditableRouting
    implements RoutingRepository, RouteRoadSnapRepository {
  final requests = <List<RouteShapingPoint>>[];
  final snapped = <LatLng>[];
  Completer<RouteRoadSnap>? pendingSnap;
  Completer<List<RoutePath>>? pendingRoute;
  bool failSnap = false, failRoute = false;
  @override
  Future<RouteRoadSnap> snap(LatLng point, {required double maxMeters}) async {
    snapped.add(point);
    if (failSnap) throw const RoutingException('No nearby street.');
    return pendingSnap?.future ?? editableSnap(point);
  }

  @override
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  }) async {
    requests.add(List.of(shapingPoints));
    if (failRoute) {
      throw const RoutingException('No route through chosen street.');
    }
    return pendingRoute?.future ?? [editablePath(stops, shapingPoints)];
  }
}
