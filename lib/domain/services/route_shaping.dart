import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';

/// Local projection used only for short snapping distances, never for routing.
({double fraction, double meters, LatLng point}) projectRoutePoint(
  LatLng point,
  LatLng a,
  LatLng b,
) {
  final scale = math.cos(point.latitude * math.pi / 180);
  final dx = (b.longitude - a.longitude) * scale;
  final dy = b.latitude - a.latitude;
  final length = dx * dx + dy * dy;
  final fraction = length == 0
      ? 0.0
      : (((point.longitude - a.longitude) * scale * dx +
                    (point.latitude - a.latitude) * dy) /
                length)
            .clamp(0.0, 1.0);
  final projected = LatLng(
    a.latitude + dy * fraction,
    a.longitude + (b.longitude - a.longitude) * fraction,
  );
  return (
    fraction: fraction,
    meters: const Distance().as(LengthUnit.Meter, point, projected),
    point: projected,
  );
}

void validateShapingPoints(List<RouteShapingPoint> points, int stopCount) {
  var previousLeg = 0;
  final ids = <int>{};
  if (points.length > 8) {
    throw const RoutingException(
      'Use up to eight route edits. Remove an edit first.',
    );
  }
  for (final point in points) {
    if (point.legIndex < previousLeg ||
        point.legIndex >= stopCount - 1 ||
        !ids.add(point.id) ||
        !validRouteCoordinate(point.snap.position) ||
        point.snap.road.length < 2 ||
        point.snap.road.any((p) => !validRouteCoordinate(p))) {
      throw const RoutingException('Invalid route shaping point.');
    }
    previousLeg = point.legIndex;
  }
}

/// Require nearby, parallel traversal of the snapped road. A line merely
/// crossing the chosen street (for example on an overpass) is not sufficient.
/// Positions are matched monotonically within each real stop-to-stop leg.
RoutePath? constrainRoutePath(RoutePath path, List<RouteShapingPoint> anchors) {
  if (anchors.isEmpty) return path;
  final matches = <int, double>{};
  var previous = 0.0;
  for (final anchor in anchors) {
    if (anchor.legIndex >= path.legEndIndices.length) return null;
    final start = anchor.legIndex == 0
        ? 0
        : path.legEndIndices[anchor.legIndex - 1];
    final end = path.legEndIndices[anchor.legIndex];
    final road = anchor.snap.road;
    var roadIndex = 0;
    var nearest = double.infinity;
    for (var i = 0; i < road.length - 1; i++) {
      final distance = projectRoutePoint(
        anchor.snap.position,
        road[i],
        road[i + 1],
      ).meters;
      if (distance < nearest) {
        nearest = distance;
        roadIndex = i;
      }
    }
    final ra = road[roadIndex], rb = road[roadIndex + 1];
    final scale = math.cos(anchor.snap.position.latitude * math.pi / 180);
    final rx = (rb.longitude - ra.longitude) * scale,
        ry = rb.latitude - ra.latitude;
    double? match;
    for (var i = math.max(start, previous.floor()); i < end; i++) {
      final a = path.points[i], b = path.points[i + 1];
      final projection = projectRoutePoint(anchor.snap.position, a, b);
      final position = i + projection.fraction;
      if (projection.meters > 4 || position < previous) continue;
      final dx = (b.longitude - a.longitude) * scale,
          dy = b.latitude - a.latitude;
      final norm = math.sqrt((rx * rx + ry * ry) * (dx * dx + dy * dy));
      if (norm == 0 || (rx * dx + ry * dy).abs() / norm < 0.9) continue;
      // Check actual overlap rather than accepting a parallel road endpoint.
      final length = const Distance().as(LengthUnit.Meter, a, b);
      if (length < 1) continue;
      final delta = math.min(8 / length, 1.0);
      final fractions = [
        (projection.fraction - delta).clamp(0.0, 1.0),
        (projection.fraction + delta).clamp(0.0, 1.0),
      ];
      if ((fractions.last - fractions.first) * length < math.min(5, length)) {
        continue;
      }
      if (fractions.any((t) {
        final sample = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        return !List.generate(
          road.length - 1,
          (j) => projectRoutePoint(sample, road[j], road[j + 1]).meters <= 4,
        ).any((v) => v);
      })) {
        continue;
      }
      match = position;
      break;
    }
    if (match == null) return null;
    matches[anchor.id] = match;
    previous = match;
  }
  return RoutePath(
    points: path.points,
    maneuvers: path.maneuvers,
    meters: path.meters,
    seconds: path.seconds,
    legEndIndices: path.legEndIndices,
    shapingPositions: matches,
  );
}
