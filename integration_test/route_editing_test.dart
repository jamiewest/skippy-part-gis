import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import '../test/support/fake_map_repositories.dart';
import '../test/support/fake_route_editing.dart';
import '../test/support/fake_routing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'drag selected route, release to check cameras, undo from panel',
    (tester) async {
      final backend = FakeEditableRouting();
      final cameras = FakeRouteCameras([
        RouteCameraSnapshot(cameras: [], complete: true),
      ]);
      final routing = RouteViewModel(
        planner: RoutePlanner(routing: backend, cameras: cameras),
        geocoder: FakeRouteGeocoder(),
      );
      final model = buildFakeMapViewModel(routing: routing);
      addTearDown(model.dispose);
      await routing.calculate(
        stops: testStops,
        settings: const RouteOptions(preference: RoutePreference.fastest),
      );
      routing.showPanel(false);
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(
            viewModel: model,
            enableBaseMap: false,
            initialBounds: const GeoBounds(
              west: -117.01,
              south: 33.99,
              east: -116.99,
              north: 34.01,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final before = map.camera.center;
      final frame = tester.getRect(find.byType(FlutterMap));
      final point =
          frame.topLeft + map.camera.latLngToScreenOffset(routePoint(0, 50));
      final gesture = await tester.startGesture(point);
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(routing.preview, isNotNull);
      expect(cameras.requests, hasLength(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(routing.shapingPoints, hasLength(1));
      expect(cameras.requests, hasLength(2));
      expect(map.camera.center, before);
      await tester.tap(find.byKey(const Key('open-route-builder')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(routing.shapingPoints, isEmpty);
      expect(cameras.requests, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );
}
