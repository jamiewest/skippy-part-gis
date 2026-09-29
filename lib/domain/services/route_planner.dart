import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';
import 'package:riverside_atlas/domain/services/route_exposure.dart';
import 'package:riverside_atlas/domain/services/route_search_graph.dart';
import 'package:riverside_atlas/domain/services/route_shaping.dart';

/// Bounded graph search for efficient, camera-checked road alternatives.
class RoutePlanner {
  RoutePlanner({required this.routing, required this.cameras});
  final RoutingRepository routing;
  final RouteCameraRepository cameras;
  static const exposure = RouteExposure();
  static const maxAvoidancePasses = 10;
  static const maxRetainedRoutes = 3;

  Future<RoutePlan> plan(
    List<RouteStop> stops,
    RouteOptions options, {
    bool Function()? cancelled,
    List<RouteShapingPoint> shapingPoints = const [],
  }) async {
    void checkCancelled() {
      if (cancelled?.call() ?? false) {
        throw const RoutingException('Route request cancelled.');
      }
    }

    if (stops.length < 2 ||
        stops.length > 8 ||
        stops.any((s) => !validRouteCoordinate(s.position)) ||
        !options.maxDetourMinutes.isFinite ||
        options.maxDetourMinutes < 0 ||
        options.maxDetourMinutes > 180) {
      throw const RoutingException(
        'Choose 2–8 stops and a detour limit from 0 to 180 minutes.',
      );
    }
    validateShapingPoints(shapingPoints, stops.length);
    final protectedStops = [
      ...stops,
      for (final p in shapingPoints) RouteStop(p.snap.label, p.snap.position),
    ];
    final candidates =
        (await routing.routes(stops, shapingPoints: shapingPoints))
            .map((p) => constrainRoutePath(p, shapingPoints))
            .whereType<RoutePath>()
            .toList();
    checkCancelled();
    if (candidates.isEmpty) {
      throw const RoutingException('No road route was returned.');
    }
    candidates.sort((a, b) => a.seconds.compareTo(b.seconds));
    final baseline = candidates.first.seconds;
    final ceiling = baseline + options.maxDetourMinutes * 60;
    final graph = RouteSearchGraph();
    for (final path in candidates) {
      graph.add(path);
    }
    final known = <String, AlprCamera>{};
    final excluded = <String, AlprCamera>{};
    final notices = <String>{RouteExposure.note};
    var complete = true;
    var checkedAt = DateTime.now().toUtc();
    List<AssessedRoute> assessed = [];
    var needsCameraQuery = true;
    var widening = 0;

    for (var pass = 0; pass <= maxAvoidancePasses; pass++) {
      checkCancelled();
      if (needsCameraQuery) {
        final snapshot = await cameras.along(graph.paths);
        checkCancelled();
        checkedAt = snapshot.fetchedAt;
        complete = complete && snapshot.complete;
        if (snapshot.notice != null) notices.add(snapshot.notice!);
        for (final camera in snapshot.cameras) {
          if (options.cameraFilter == RouteCameraFilter.all || camera.isFlock) {
            known[camera.sourceId] = camera;
          }
        }
        needsCameraQuery = false;
      }
      assessed = graph.paths
          .map((path) => exposure.assess(path, known.values))
          .toList();
      if (!complete ||
          options.preference == RoutePreference.fastest ||
          pass == maxAvoidancePasses) {
        break;
      }

      final before = excluded.length;
      for (final route in assessed.where((r) => r.path.seconds <= ceiling)) {
        for (final hit in route.hits) {
          excluded[hit.camera.sourceId] = hit.camera;
        }
      }
      final successful = assessed
          .where((r) => r.hits.isEmpty && r.path.seconds <= ceiling)
          .toList();
      List<List<LatLng>> deviations = const [];
      if (successful.isNotEmpty) {
        final branch = graph.nextBranch(successful, protectedStops);
        if (branch == null) break;
        deviations = branch;
      } else if (excluded.length == before) {
        // A duplicate path is a reason to broaden the search, not give up.
        if (widening == 2) break;
        widening++;
      }
      try {
        final detours = await routing.routes(
          stops,
          preferLocalRoads: true,
          shapingPoints: shapingPoints,
          excludePolygons: [
            for (final camera in excluded.values)
              _exclusion(camera, widening, protectedStops),
            ...deviations,
          ],
        );
        checkCancelled();
        for (final candidate in detours) {
          final path = constrainRoutePath(candidate, shapingPoints);
          if (path == null) continue;
          if (graph.add(path, deviations: deviations)) {
            needsCameraQuery = true;
          }
        }
      } on RoutingException catch (error) {
        checkCancelled();
        // One blocked branch does not invalidate other graph branches.
        if (successful.isNotEmpty) continue;
        notices.add('Avoidance search stopped: ${error.message}');
        break;
      } catch (_) {
        checkCancelled();
        notices.add(
          'Avoidance request failed; only the checked candidates are shown.',
        );
        break;
      }
    }
    var eligible = assessed
        .where((r) => r.path.seconds <= ceiling + 0.01)
        .toList();
    eligible.sort((a, b) {
      if (complete && options.preference != RoutePreference.fastest) {
        final count = a.hits.length.compareTo(b.hits.length);
        if (count != 0) return count;
      }
      final time = a.path.seconds.compareTo(b.path.seconds);
      return time != 0 ? time : a.path.meters.compareTo(b.path.meters);
    });
    if (complete && options.preference != RoutePreference.fastest) {
      final successful = eligible.where((r) => r.hits.isEmpty).toList();
      if (successful.isNotEmpty) eligible = successful;
    }
    eligible = eligible.take(maxRetainedRoutes).toList();
    final strict = options.preference == RoutePreference.avoidMappedCoverage;
    final satisfied =
        options.preference == RoutePreference.fastest ||
        (complete && (!strict || eligible.first.hits.isEmpty));
    if (!complete) {
      notices.add(
        'Camera analysis is incomplete. These are ordinary route candidates; '
        'camera avoidance has not been established.',
      );
    } else if (strict && !satisfied) {
      notices.add(
        'No candidate met mapped-camera avoidance within the detour limit. '
        'The displayed routes do not satisfy that request.',
      );
    }
    notices.add(
      'Searched the road graph with up to $maxAvoidancePasses neighborhood and '
      'camera-avoidance requests; kept up to $maxRetainedRoutes of the most efficient '
      'checked candidates. This is not an exhaustive search. '
      'Exclusions can remove both directions of '
      'a road that crosses a footprint. Travel times are estimates, not live traffic.',
    );
    if (options.cameraFilter == RouteCameraFilter.flock) {
      notices.add(
        'Only readers explicitly identified as Flock were assessed; unknown vendors were not included.',
      );
    }
    return RoutePlan(
      routes: eligible,
      cameras: known.values,
      baselineSeconds: baseline,
      cameraQueryComplete: complete,
      constraintsSatisfied: satisfied,
      cameraCheckedAt: checkedAt,
      notices: notices,
    );
  }

  /// Broaden only the search exclusion, never the reported camera footprint.
  /// Leave room around stops so a wider buffer does not swallow a destination.
  List<LatLng> _exclusion(
    AlprCamera camera,
    int widening,
    List<RouteStop> stops,
  ) {
    if (widening == 0) return exposure.footprint(camera);
    const distance = Distance();
    final nearestStop = stops
        .map((s) => distance.as(LengthUnit.Meter, camera.position, s.position))
        .reduce(math.min);
    final radius = math.min(widening == 1 ? 200.0 : 350.0, nearestStop - 40);
    if (radius < RouteExposure.unknownRadiusMeters) {
      return exposure.footprint(camera);
    }
    return [
      for (var i = 0; i < 32; i++)
        distance.offset(camera.position, radius, i * 360 / 32),
    ];
  }
}
