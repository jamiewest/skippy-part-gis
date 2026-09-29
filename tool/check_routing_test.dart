// Explicit online smoke test; not included in the normal offline test suite.
// Run: flutter test --no-pub tool/check_routing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/route_camera_service.dart';
import 'package:riverside_atlas/data/services/route_geocoding_service.dart';
import 'package:riverside_atlas/data/services/valhalla_routing_service.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';

void main() {
  test(
    'live Valhalla route, footprint exclusion, Photon and corridor cameras',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final routing = ValhallaRoutingService(client);
      const stops = [
        RouteStop('Riverside center', LatLng(33.9806, -117.3755)),
        RouteStop('Riverside west', LatLng(33.975, -117.39)),
      ];
      final paths = await routing.routes(stops);
      expect(paths.first.points.length, greaterThan(2));
      expect(paths.first.maneuvers, isNotEmpty);
      expect(paths.first.seconds, greaterThan(0));
      final midpoint = paths.first.points[paths.first.points.length ~/ 2];
      final excluded = await routing.routes(
        stops,
        preferLocalRoads: true,
        excludePolygons: [
          [
            for (final bearing in [0.0, 90.0, 180.0, 270.0])
              const Distance().offset(midpoint, 15, bearing),
          ],
        ],
      );
      expect(excluded.first.points, isNot(equals(paths.first.points)));
      final places = await PhotonRouteGeocoder(
        client,
      ).search('Riverside City Hall', near: stops.first.position);
      expect(places, isNotEmpty);
      final cameras = await OverpassRouteCameraService(
        client,
      ).along([...paths, ...excluded]);
      expect(cameras.complete, isTrue, reason: cameras.notice);
      // Counts are observations of a completed public query, not inventory claims.
      // ignore: avoid_print
      print(
        'Live route: ${paths.first.meters.round()} m, '
        '${paths.first.maneuvers.length} directions; exclusion changed geometry; '
        '${places.length} place candidates; ${cameras.cameras.length} mapped cameras.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
