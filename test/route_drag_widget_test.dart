import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'package:riverside_atlas/ui/features/map/widgets/route_map_layer.dart';
import 'support/fake_route_editing.dart';
import 'support/fake_routing.dart';

void main() {
  for (final size in [const Size(1000, 700), const Size(390, 600)]) {
    for (final rotation in [0.0, 35.0]) {
      testWidgets(
        'route drag, preview and stable map at $size, rotation $rotation',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final backend = FakeEditableRouting();
          final cameras = FakeRouteCameras([
            RouteCameraSnapshot(cameras: [testCamera()], complete: true),
          ]);
          final model = RouteViewModel(
            planner: RoutePlanner(routing: backend, cameras: cameras),
            geocoder: FakeRouteGeocoder(),
          );
          addTearDown(model.dispose);
          await model.calculate(
            stops: testStops,
            settings: const RouteOptions(preference: RoutePreference.fastest),
          );
          model.showPanel(false);
          final controller = MapController();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: routePoint(0, 50),
                    initialZoom: 16,
                  ),
                  children: [
                    RouteMapLayer(model: model, controller: controller),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          controller.rotate(rotation);
          await tester.pumpAndSettle();
          final before = controller.camera.center;
          final point = controller.camera.latLngToScreenOffset(
            routePoint(0, 50),
          );
          final gesture = await tester.startGesture(point);
          await gesture.moveBy(const Offset(0, -50));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          expect(model.dragging, isTrue);
          expect(model.preview, isNotNull);
          expect(cameras.requests, hasLength(1));
          expect(controller.camera.center, before);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(model.shapingPoints, hasLength(1));
          expect(cameras.requests, hasLength(2));
          expect(controller.camera.center, before);
          expect(
            find.byKey(const Key('route-shaping-point-0')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'off-route panning, escape, pointer cancellation and selection mode',
    (tester) async {
      final backend = FakeEditableRouting();
      final model = RouteViewModel(
        planner: RoutePlanner(
          routing: backend,
          cameras: FakeRouteCameras([
            RouteCameraSnapshot(cameras: [], complete: true),
          ]),
        ),
        geocoder: FakeRouteGeocoder(),
      );
      addTearDown(model.dispose);
      await model.calculate(
        stops: testStops,
        settings: const RouteOptions(preference: RoutePreference.fastest),
      );
      model.showPanel(false);
      final controller = MapController();
      var editable = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: routePoint(0, 50),
                    initialZoom: 16,
                  ),
                  children: [
                    RouteMapLayer(
                      model: model,
                      controller: controller,
                      editable: editable,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = controller.camera.center;
      await tester.dragFrom(const Offset(100, 100), const Offset(60, 10));
      await tester.pumpAndSettle();
      expect(controller.camera.center, isNot(before));
      expect(backend.snapped, isEmpty);
      Offset routePointOnScreen() =>
          controller.camera.latLngToScreenOffset(routePoint(0, 50));
      final gesture = await tester.startGesture(routePointOnScreen());
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(model.dragging, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(model.dragging, isFalse);
      expect(model.shapingPoints, isEmpty);
      final cancelled = await tester.startGesture(routePointOnScreen());
      await cancelled.moveBy(const Offset(0, 30));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(model.dragging, isFalse);
      rebuild(() => editable = false);
      await tester.pump();
      await tester.dragFrom(routePointOnScreen(), const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(model.shapingPoints, isEmpty);
      expect(backend.snapped, isEmpty);
    },
  );

  testWidgets('hover handle and primary mouse drag', (tester) async {
    final backend = FakeEditableRouting();
    final model = RouteViewModel(
      planner: RoutePlanner(
        routing: backend,
        cameras: FakeRouteCameras([
          RouteCameraSnapshot(cameras: [], complete: true),
        ]),
      ),
      geocoder: FakeRouteGeocoder(),
    );
    addTearDown(model.dispose);
    await model.calculate(
      stops: testStops,
      settings: const RouteOptions(preference: RoutePreference.fastest),
    );
    model.showPanel(false);
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: routePoint(0, 50),
              initialZoom: 16,
            ),
            children: [RouteMapLayer(model: model, controller: controller)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final point = controller.camera.latLngToScreenOffset(routePoint(0, 50));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: point);
    await mouse.moveTo(point);
    await tester.pump();
    expect(find.byKey(const Key('route-hover-handle')), findsOneWidget);
    await mouse.down(point);
    await mouse.moveTo(point + const Offset(0, -40));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(model.shapingPoints, hasLength(1));
    await mouse.removePointer();
  });
}
