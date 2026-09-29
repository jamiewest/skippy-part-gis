import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_edit_layer.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_select_overlay.dart';

const _center = LatLng(34, -117);
const _circle = CircleArea(center: _center, radiusMeters: 700);
const _rectangle = RectangleArea(
  GeoBounds(west: -117.01, south: 33.993, east: -116.99, north: 34.007),
);

void main() {
  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('circle grows symmetrically from the initial $kind press', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      AreaShape? drawn;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // An offset map catches accidental global/local coordinate mixing.
            body: Padding(
              padding: const EdgeInsets.fromLTRB(70, 40, 30, 20),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: controller,
                    options: const MapOptions(
                      initialCenter: _center,
                      initialZoom: 14,
                    ),
                    children: const [],
                  ),
                  Positioned.fill(
                    child: AreaSelectOverlay(
                      mapController: controller,
                      tool: AreaTool.circle,
                      onDrawn: (shape) => drawn = shape,
                      onCancel: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(FlutterMap));
      final press = origin + const Offset(260, 230);
      final gesture = await tester.startGesture(press, kind: kind);
      await gesture.moveTo(press + const Offset(60, 0));
      await tester.pump();
      await gesture.moveTo(press + const Offset(100, 0));
      await tester.pump();
      final preview = tester.getRect(
        find.byKey(const Key('area-drawing-preview')),
      );
      expect(preview.center.dx, closeTo(press.dx, 0.01));
      expect(preview.center.dy, closeTo(press.dy, 0.01));
      expect(preview.width, closeTo(200, 0.01));
      await gesture.up();
      await tester.pump();
      final circle = drawn! as CircleArea;
      final screenCenter = controller.camera.latLngToScreenOffset(
        circle.center,
      );
      expect((screenCenter - (press - origin)).distance, lessThan(0.01));
      final edge = const Distance().offset(
        circle.center,
        circle.radiusMeters,
        90,
      );
      expect(
        (controller.camera.latLngToScreenOffset(edge) - screenCenter).distance,
        closeTo(100, 0.1),
      );
      expect(find.byKey(const Key('area-drawing-preview')), findsNothing);
    });
  }

  for (final shape in <AreaShape>[_circle, _rectangle]) {
    testWidgets('${shape.description} moves without panning and commits once', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      final commits = <AreaShape>[];
      await _pumpEditor(tester, controller, shape, commits.add);
      final cameraCenter = controller.camera.center;
      final handle = find.byKey(const Key('area-move-handle'));
      final press = tester.getCenter(handle);
      final gesture = await tester.startGesture(press);
      await gesture.moveTo(press + const Offset(35, 15));
      await tester.pump();
      await gesture.moveTo(press + const Offset(75, 35));
      await tester.pump();
      expect(commits, isEmpty);
      expect(controller.camera.center, cameraCenter);
      expect(
        (tester.getCenter(handle) - press - const Offset(75, 35)).distance,
        lessThan(0.1),
      );
      await gesture.up();
      await tester.pump();
      expect(commits, hasLength(1));
      if (shape is CircleArea) {
        expect((commits.single as CircleArea).radiusMeters, shape.radiusMeters);
      } else {
        final before = shape.bounds;
        final after = commits.single.bounds;
        expect(
          after.east - after.west,
          closeTo(before.east - before.west, 1e-8),
        );
      }
    });

    testWidgets('${shape.description} cancels a draft without committing', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      final commits = <AreaShape>[];
      await _pumpEditor(tester, controller, shape, commits.add);
      final handle = find.byKey(const Key('area-move-handle'));
      final press = tester.getCenter(handle);
      final gesture = await tester.startGesture(press);
      await gesture.moveTo(press + const Offset(60, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(commits, isEmpty);
      expect((tester.getCenter(handle) - press).distance, lessThan(0.1));
    });

    for (var corner = 0; corner < 4; corner++) {
      testWidgets(
        '${shape.description} resizes from handle $corner after zoom and rotation',
        (tester) async {
          final controller = MapController();
          addTearDown(controller.dispose);
          final commits = <AreaShape>[];
          await _pumpEditor(tester, controller, shape, commits.add);
          controller.move(_center, 14.5);
          controller.rotate(25);
          await tester.pump();
          final cameraCenter = controller.camera.center;
          final moveCenter = tester.getCenter(
            find.byKey(const Key('area-move-handle')),
          );
          final handle = find.byKey(Key('area-resize-$corner'));
          final press = tester.getCenter(handle);
          final delta = (press - moveCenter) * 0.25;
          final gesture = await tester.startGesture(press);
          await gesture.moveTo(press + delta * 0.6);
          await tester.pump();
          await gesture.moveTo(press + delta);
          await tester.pump();
          expect(commits, isEmpty);
          expect(controller.camera.center, cameraCenter);
          expect(
            (tester.getCenter(handle) - press - delta).distance,
            lessThan(0.5),
          );
          await gesture.up();
          await tester.pump();
          expect(commits, hasLength(1));
          switch (commits.single) {
            case CircleArea(:final center, :final radiusMeters):
              expect(center, _center);
              expect(radiusMeters, greaterThan(_circle.radiusMeters));
            case RectangleArea(:final ring):
              final opposite = (corner + 2) % 4;
              expect(
                ring[opposite].latitude,
                closeTo(_rectangle.ring[opposite].latitude, 1e-8),
              );
              expect(
                ring[opposite].longitude,
                closeTo(_rectangle.ring[opposite].longitude, 1e-8),
              );
          }
        },
      );
    }
  }

  testWidgets('map still pans outside handles and handles can be hidden', (
    tester,
  ) async {
    final controller = MapController();
    addTearDown(controller.dispose);
    final commits = <AreaShape>[];
    await _pumpEditor(tester, controller, _circle, commits.add);
    final before = controller.camera.center;
    await tester.dragFrom(const Offset(100, 100), const Offset(100, 40));
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(before));
    expect(commits, isEmpty);
    await _pumpEditor(
      tester,
      controller,
      _circle,
      commits.add,
      editable: false,
    );
    expect(find.byKey(const Key('area-move-handle')), findsNothing);
    expect(find.byKey(const Key('area-selection-rectangle')), findsOneWidget);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  MapController controller,
  AreaShape shape,
  ValueChanged<AreaShape> onChanged, {
  bool editable = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          mapController: controller,
          options: const MapOptions(initialCenter: _center, initialZoom: 14),
          children: [
            AreaEditLayer(
              shape: shape,
              onChanged: onChanged,
              editable: editable,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}
