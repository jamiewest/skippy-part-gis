import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';

/// Deliberately an estimated footprint, not physical line-of-sight evidence.
/// Include uncertainty around the illustrative 90m/50-degree display cone.
class RouteExposure {
  const RouteExposure();
  static const rangeMeters = 120.0;
  static const spreadDegrees = 70.0;
  static const unknownRadiusMeters = 150.0;
  static const note =
      'Estimated coverage: 120 m / 70° for mapped bearings; '
      '150 m around readers with unknown direction. Routes account for both '
      'front and rear plates: approaching and departing traffic within a '
      'reader\'s estimated coverage both count as exposure. Crowdsourced OpenStreetMap '
      'data is incomplete. No route is guaranteed camera-free. Facing direction '
      'does not establish lane coverage or front/rear plate visibility.';

  List<LatLng> footprint(AlprCamera camera) {
    if (camera.direction != null) {
      return camera.viewCone(
        lengthMeters: rangeMeters,
        spreadDegrees: spreadDegrees,
        arcSegments: 16,
      );
    }
    // Circumscribed polygon: the disk is not underestimated between vertices.
    return [
      for (var i = 0; i < 32; i++)
        const Distance().offset(
          camera.position,
          unknownRadiusMeters / math.cos(math.pi / 32),
          i * 360 / 32,
        ),
    ];
  }

  AssessedRoute assess(RoutePath route, Iterable<AlprCamera> cameras) {
    // Front plates may face a reader on approach and rear plates on departure.
    // Count footprint intersections regardless of the vehicle's travel heading.
    final hits = <RouteCameraHit>[];
    for (final camera in cameras) {
      final polygon = footprint(camera);
      final minLat = polygon.map((p) => p.latitude).reduce(math.min);
      final maxLat = polygon.map((p) => p.latitude).reduce(math.max);
      final minLon = polygon.map((p) => p.longitude).reduce(math.min);
      final maxLon = polygon.map((p) => p.longitude).reduce(math.max);
      final segments = <int>[];
      for (var i = 0; i < route.points.length - 1; i++) {
        final a = route.points[i], b = route.points[i + 1];
        if (math.max(a.latitude, b.latitude) < minLat ||
            math.min(a.latitude, b.latitude) > maxLat ||
            math.max(a.longitude, b.longitude) < minLon ||
            math.min(a.longitude, b.longitude) > maxLon) {
          continue;
        }
        if (_inside(a, polygon) ||
            _inside(b, polygon) ||
            List.generate(polygon.length, (j) => j).any(
              (j) => _intersects(
                a,
                b,
                polygon[j],
                polygon[(j + 1) % polygon.length],
              ),
            )) {
          segments.add(i);
        }
      }
      if (segments.isNotEmpty) hits.add(RouteCameraHit(camera, segments));
    }
    return AssessedRoute(route, hits);
  }

  bool _inside(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) *
                      (p.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _intersects(LatLng a, LatLng b, LatLng c, LatLng d) {
    double cross(LatLng p, LatLng q, LatLng r) =>
        (q.longitude - p.longitude) * (r.latitude - p.latitude) -
        (q.latitude - p.latitude) * (r.longitude - p.longitude);
    bool on(LatLng p, LatLng q, LatLng r) =>
        r.longitude >= math.min(p.longitude, q.longitude) - 1e-12 &&
        r.longitude <= math.max(p.longitude, q.longitude) + 1e-12 &&
        r.latitude >= math.min(p.latitude, q.latitude) - 1e-12 &&
        r.latitude <= math.max(p.latitude, q.latitude) + 1e-12;
    final abC = cross(a, b, c), abD = cross(a, b, d);
    final cdA = cross(c, d, a), cdB = cross(c, d, b);
    return (abC * abD < 0 && cdA * cdB < 0) ||
        (abC.abs() < 1e-14 && on(a, b, c)) ||
        (abD.abs() < 1e-14 && on(a, b, d)) ||
        (cdA.abs() < 1e-14 && on(c, d, a)) ||
        (cdB.abs() < 1e-14 && on(c, d, b));
  }
}
