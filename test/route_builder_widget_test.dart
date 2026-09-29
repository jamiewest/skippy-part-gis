import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'support/fake_map_repositories.dart';
import 'support/fake_routing.dart';

void main() {
  RouteViewModel routeModel(FakeRouting backend) => RouteViewModel(
    planner: RoutePlanner(
      routing: backend,
      cameras: FakeRouteCameras([
        RouteCameraSnapshot(cameras: [testCamera()], complete: true),
      ]),
    ),
    geocoder: FakeRouteGeocoder(),
  );

  for (final size in [
    const Size(1400, 900),
    const Size(390, 844),
    const Size(667, 375),
  ]) {
    testWidgets('route results fit and directions are interactive at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final routing = routeModel(
        FakeRouting([
          [testRoute(), testDetour()],
        ]),
      );
      final model = buildFakeMapViewModel(routing: routing);
      addTearDown(model.dispose);
      await routing.calculate(stops: testStops);
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
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('route-builder-panel')), findsOneWidget);
      expect(find.byKey(const Key('selected-route-layer')), findsOneWidget);
      expect(find.byKey(const Key('route-stop-marker-0')), findsOneWidget);
      final frame = tester.getRect(find.byType(FlutterMap));
      final panel = tester.getRect(
        find.byKey(const Key('route-builder-panel')),
      );
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      for (final point in [
        routing.selected!.path.points.first,
        routing.selected!.path.points.last,
      ]) {
        expect(
          panel.contains(frame.topLeft + camera.latLngToScreenOffset(point)),
          isFalse,
          reason: 'Route endpoints must remain visible outside the panel',
        );
      }
      await tester.ensureVisible(find.text('Head east on Test Street'));
      await tester.tap(find.text('Head east on Test Street'));
      await tester.pumpAndSettle();
      expect(
        routing.focusedManeuver,
        routing.selected!.path.maneuvers.first.point,
      );
      final map = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(map.camera.zoom, 17);
      await tester.tap(find.byTooltip('Close route builder'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route-builder-panel')), findsNothing);
      expect(find.byKey(const Key('selected-route-layer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'place search, map picking, stop editing and route building share state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final routing = routeModel(
        FakeRouting([
          [testRoute(), testDetour()],
        ]),
      );
      final model = buildFakeMapViewModel(routing: routing);
      addTearDown(model.dispose);
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
      await tester.tap(find.byKey(const Key('open-route-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose start'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Address, place, or lat, lon'),
        'Start',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Start'));
      await tester.pumpAndSettle();
      expect(routing.stops.first!.label, 'Start');
      await tester.tap(find.byTooltip('Pick stop 2 on map'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route-builder-panel')), findsNothing);
      final rect = tester.getRect(find.byType(FlutterMap));
      await tester.tapAt(rect.center + const Offset(60, 40));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(routing.stops.last, isNotNull);
      expect(routing.pickingStop, isNull);
      expect(find.byKey(const Key('route-builder-panel')), findsOneWidget);
      await tester.tap(find.text('Add stop'));
      await tester.pumpAndSettle();
      expect(routing.stops, hasLength(3));
      await tester.tap(find.byTooltip('Edit stop 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove stop'));
      await tester.pumpAndSettle();
      expect(routing.stops, hasLength(2));
      await tester.ensureVisible(find.byKey(const Key('calculate-route')));
      await tester.tap(find.byKey(const Key('calculate-route')));
      await tester.pumpAndSettle();
      expect(routing.plan, isNotNull);
      expect(find.byKey(const Key('selected-route-layer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dragging a stop changes its coordinates and recalculates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = FakeRouting([
      [testRoute(), testDetour()],
    ]);
    final routing = routeModel(backend);
    final model = buildFakeMapViewModel(routing: routing);
    addTearDown(model.dispose);
    await routing.calculate(stops: testStops);
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
    final original = routing.stops.first!.position;
    final callsBeforeDrag = backend.calls;
    await tester.drag(
      find.byKey(const Key('route-stop-marker-0')),
      const Offset(40, 40),
    );
    await tester.pumpAndSettle();
    expect(routing.stops.first!.position, isNot(original));
    expect(backend.calls, greaterThan(callsBeforeDrag));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(routing.plan, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
