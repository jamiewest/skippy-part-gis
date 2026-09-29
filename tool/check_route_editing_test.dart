// Explicit online check: flutter test --no-pub tool/check_route_editing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/route_camera_service.dart';
import 'package:riverside_atlas/data/services/valhalla_routing_service.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';

void main() {
  test(
    'live street snapping, through routing and fresh corridor camera check',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final routing = ValhallaRoutingService(client);
      const stops = [
        RouteStop('Riverside center', LatLng(33.9806, -117.3755)),
        RouteStop('Riverside west', LatLng(33.975, -117.39)),
      ];
      final original = (await routing.routes(stops)).first;
      final middle = original.points[original.points.length ~/ 2];
      final snap = await routing.snap(
        const Distance().offset(middle, 100, 0),
        maxMeters: 75,
      );
      final anchor = RouteShapingPoint(id: 0, legIndex: 0, snap: snap);
      final plan =
          await RoutePlanner(
            routing: routing,
            cameras: OverpassRouteCameraService(client),
          ).plan(
            stops,
            const RouteOptions(preference: RoutePreference.fastest),
            shapingPoints: [anchor],
          );
      expect(plan.routes.first.path.shapingPositions, contains(0));
      expect(plan.routes.first.path.points, isNot(original.points));
      expect(plan.cameraQueryComplete, isTrue, reason: plan.notices.join('\n'));
      // ignore: avoid_print
      print(
        'Snapped to ${snap.label}; rerouted ${plan.routes.first.path.meters.round()} m; '
        'checked ${plan.cameras.length} mapped cameras.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
