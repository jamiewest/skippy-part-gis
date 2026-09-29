import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';

/// Displays the selected area with a move handle and resize handles.
///
/// The draft stays local during a drag. Releasing a handle commits once, so
/// address queries do not run for every pointer movement. The rest of the map
/// remains available for panning and selecting properties.
class AreaEditLayer extends StatefulWidget {
  /// Creates an editable selection inside a [FlutterMap].
  const AreaEditLayer({
    required this.shape,
    required this.onChanged,
    this.editable = true,
    super.key,
  });

  /// The committed geographic area.
  final AreaShape shape;

  /// Called once after a move or resize ends.
  final ValueChanged<AreaShape> onChanged;

  /// Whether handles are available, disabled while drawing another area.
  final bool editable;

  @override
  State<AreaEditLayer> createState() => _AreaEditLayerState();
}

class _AreaEditLayerState extends State<AreaEditLayer> {
  AreaShape? _draft;
  AreaShape? _original;
  MapCamera? _dragCamera;
  Offset? _press;
  int? _pointer;

  @override
  void didUpdateWidget(covariant AreaEditLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shape != oldWidget.shape || !widget.editable) {
      _reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final shape = _draft ?? widget.shape;
    final color = Theme.of(context).colorScheme.primary;
    final center = switch (shape) {
      CircleArea(:final center) => center,
      RectangleArea(:final bounds) => LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      ),
    };
    final edges = switch (shape) {
      CircleArea(:final center, :final radiusMeters) => [
        for (final bearing in [0.0, 90.0, 180.0, 270.0])
          const Distance().offset(center, radiusMeters, bearing),
      ],
      RectangleArea() => shape.ring,
    };
    return Stack(
      children: [
        PolygonLayer(
          key: const Key('area-selection-rectangle'),
          polygons: [
            Polygon(
              points: shape.ring,
              color: color.withValues(alpha: 0.07),
              borderColor: color,
              borderStrokeWidth: 2.5,
              pattern: StrokePattern.dashed(segments: const [10, 6]),
            ),
          ],
        ),
        if (widget.editable)
          MarkerLayer(
            markers: [
              for (var index = 0; index < edges.length; index++)
                _handle(camera, edges[index], index),
              _handle(camera, center, null),
            ],
          ),
      ],
    );
  }

  Marker _handle(MapCamera camera, LatLng point, int? corner) {
    final moving = corner == null;
    final label = moving ? 'Drag to move area' : 'Drag to resize area';
    final colors = Theme.of(context).colorScheme;
    return Marker(
      point: point,
      width: 44,
      height: 44,
      rotate: true,
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: MouseRegion(
            cursor: moving
                ? SystemMouseCursors.move
                : SystemMouseCursors.precise,
            child: RawGestureDetector(
              key: Key(moving ? 'area-move-handle' : 'area-resize-$corner'),
              behavior: HitTestBehavior.opaque,
              // Reserve a handle immediately. The map's scale recognizer
              // otherwise wins slow drags before a pan recognizer starts.
              gestures: {
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (_pointer != null || event.buttons != kPrimaryButton) {
                    return;
                  }
                  _pointer = event.pointer;
                  _original = widget.shape;
                  _dragCamera = camera;
                  _press = event.position;
                },
                // Global positions stay stable as the handle moves underneath
                // the pointer, including when the map itself is rotated.
                onPointerMove: (event) {
                  if (event.pointer == _pointer) {
                    _update(event.position, corner);
                  }
                },
                onPointerUp: (event) {
                  if (event.pointer == _pointer) _finish();
                },
                onPointerCancel: (event) {
                  if (event.pointer == _pointer) setState(_reset);
                },
                child: Center(
                  child: Container(
                    width: moving ? 30 : 16,
                    height: moving ? 30 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                      border: Border.all(color: colors.primary, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 3),
                      ],
                    ),
                    child: moving
                        ? Icon(Icons.open_with, size: 18, color: colors.primary)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _update(Offset pointer, int? corner) {
    final original = _original;
    final camera = _dragCamera;
    final press = _press;
    if (original == null || camera == null || press == null) return;
    final delta = pointer - press;
    if (_draft == null && delta.distance < 3) return;
    LatLng shifted(LatLng point) =>
        camera.screenOffsetToLatLng(camera.latLngToScreenOffset(point) + delta);

    final AreaShape next;
    switch (original) {
      case CircleArea(:final center, :final radiusMeters):
        if (corner == null) {
          next = CircleArea(
            center: shifted(center),
            radiusMeters: radiusMeters,
          );
        } else {
          final edge = shifted(
            const Distance().offset(center, radiusMeters, corner * 90.0),
          );
          if ((camera.latLngToScreenOffset(edge) -
                      camera.latLngToScreenOffset(center))
                  .distance <
              8) {
            return;
          }
          next = CircleArea(
            center: center,
            radiusMeters: const Distance().as(LengthUnit.Meter, center, edge),
          );
        }
      case RectangleArea():
        final ring = original.ring;
        final first = shifted(ring[corner ?? 0]);
        final opposite = corner == null
            ? shifted(ring[2])
            : ring[(corner + 2) % 4];
        final bounds = boundsFromCorners(first, opposite);
        // Check in projected coordinates so rotation cannot turn a valid
        // narrow rectangle into a zero-width diagonal on the screen.
        final extent =
            camera.projectAtZoom(first) - camera.projectAtZoom(opposite);
        if (extent.dx.abs() < 8 || extent.dy.abs() < 8) return;
        next = RectangleArea(bounds);
    }
    setState(() => _draft = next);
  }

  void _finish() {
    final draft = _draft;
    setState(_reset);
    if (draft != null) widget.onChanged(draft);
  }

  void _reset() {
    _draft = null;
    _original = null;
    _dragCamera = null;
    _press = null;
    _pointer = null;
  }
}
