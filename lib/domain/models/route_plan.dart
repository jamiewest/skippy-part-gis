import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';

enum RoutePreference { fastest, lowerExposure, avoidMappedCoverage }

enum RouteCameraFilter { all, flock }

@immutable
class RouteStop {
  const RouteStop(this.label, this.position);
  final String label;
  final LatLng position;
}

/// A drivable road projected from a pointer location by the routing provider.
@immutable
class RouteRoadSnap {
  RouteRoadSnap({
    required this.position,
    required this.label,
    required Iterable<LatLng> road,
    this.wayId,
  }) : road = List.unmodifiable(road);
  final LatLng position;
  final String label;
  final String? wayId;
  final List<LatLng> road;
}

/// Ordered within [legIndex], independently of numbered destination stops.
@immutable
class RouteShapingPoint {
  const RouteShapingPoint({
    required this.id,
    required this.legIndex,
    required this.snap,
  });
  final int id;
  final int legIndex;
  final RouteRoadSnap snap;
}

@immutable
class RouteOptions {
  const RouteOptions({
    this.preference = RoutePreference.lowerExposure,
    this.cameraFilter = RouteCameraFilter.all,
    this.maxDetourMinutes = 15,
  });
  final RoutePreference preference;
  final RouteCameraFilter cameraFilter;
  final double maxDetourMinutes;
}

@immutable
class RouteManeuver {
  const RouteManeuver({
    required this.instruction,
    required this.point,
    required this.meters,
    required this.seconds,
  });
  final String instruction;
  final LatLng point;
  final double meters;
  final double seconds;
}

@immutable
class RoutePath {
  RoutePath({
    required Iterable<LatLng> points,
    required Iterable<RouteManeuver> maneuvers,
    required this.meters,
    required this.seconds,
    Iterable<int> legEndIndices = const [],
    Map<int, double> shapingPositions = const {},
  }) : points = List.unmodifiable(points),
       maneuvers = List.unmodifiable(maneuvers),
       legEndIndices = List.unmodifiable(legEndIndices),
       shapingPositions = Map.unmodifiable(shapingPositions);
  final List<LatLng> points;
  final List<RouteManeuver> maneuvers;
  final List<int> legEndIndices;

  /// Segment index plus fractional progress, keyed by shaping point ID.
  final Map<int, double> shapingPositions;
  final double meters;
  final double seconds;
}

@immutable
class RouteCameraHit {
  RouteCameraHit(this.camera, Iterable<int> segments)
    : segments = Set.unmodifiable(segments);
  final AlprCamera camera;

  /// Indices of the start points of potentially exposed shape segments.
  final Set<int> segments;
  bool get uncertain => camera.direction == null;
}

@immutable
class AssessedRoute {
  AssessedRoute(this.path, Iterable<RouteCameraHit> hits)
    : hits = List.unmodifiable(hits);
  final RoutePath path;
  final List<RouteCameraHit> hits;
  int get unknownCount => hits.where((hit) => hit.uncertain).length;
  int get directionalCount => hits.length - unknownCount;
}

/// `complete` means the source query completed, never a complete inventory.
@immutable
class RouteCameraSnapshot {
  RouteCameraSnapshot({
    required Iterable<AlprCamera> cameras,
    required this.complete,
    this.notice,
    DateTime? fetchedAt,
  }) : cameras = List.unmodifiable(cameras),
       fetchedAt = fetchedAt ?? DateTime.now().toUtc();
  final List<AlprCamera> cameras;
  final bool complete;
  final String? notice;
  final DateTime fetchedAt;
}

@immutable
class RoutePlan {
  RoutePlan({
    required Iterable<AssessedRoute> routes,
    required Iterable<AlprCamera> cameras,
    required this.baselineSeconds,
    required this.cameraQueryComplete,
    required this.constraintsSatisfied,
    required this.cameraCheckedAt,
    required Iterable<String> notices,
  }) : routes = List.unmodifiable(routes),
       cameras = List.unmodifiable(cameras),
       notices = List.unmodifiable(notices);
  final List<AssessedRoute> routes;
  final List<AlprCamera> cameras;
  final double baselineSeconds;
  final bool cameraQueryComplete;
  final bool constraintsSatisfied;
  final DateTime cameraCheckedAt;
  final List<String> notices;
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool validRouteCoordinate(LatLng point) =>
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude.abs() <= 85 &&
    point.longitude.abs() <= 180;
