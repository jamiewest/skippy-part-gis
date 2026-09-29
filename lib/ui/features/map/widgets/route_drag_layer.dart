import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';

/// Hit tests only the selected route/handles, leaving the rest of the map free
/// to pan. Route geometry remains provider-owned throughout the gesture.
class RouteDragLayer extends StatefulWidget {
  const RouteDragLayer({super.key, required this.model, required this.enabled});
  final RouteViewModel model;
  final bool enabled;
  @override
  State<RouteDragLayer> createState() => _RouteDragLayerState();
}

class _RouteDragLayerState extends State<RouteDragLayer> {
  final _focus = FocusNode();
  int? _pointer;
  Offset? _down;
  Offset? _hover;
  MapCamera? _camera;
  bool _moved = false;

  @override
  void didUpdateWidget(RouteDragLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _pointer = null;
      _hover = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.model.cancelRouteEdit();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final camera = MapCamera.of(context);
    final selected = model.selected;
    if (selected == null) return const SizedBox.shrink();
    final points = selected.path.points
        .map(camera.latLngToScreenOffset)
        .toList();
    final handles = {
      for (final p in model.shapingPoints)
        p.id: camera.latLngToScreenOffset(p.snap.position),
    };
    final painter = _RouteHitPainter(
      points,
      handles,
      enabled: widget.enabled && (model.canShape || model.dragging),
    );
    final hover = _hover == null ? null : painter.nearest(_hover!);
    return Stack(
      children: [
        Positioned.fill(
          child: Focus(
            focusNode: _focus,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  model.editing) {
                _pointer = null;
                model.cancelRouteEdit();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              opaque: false,
              hitTestBehavior: HitTestBehavior.deferToChild,
              cursor: model.dragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              onHover: (e) => setState(() => _hover = e.localPosition),
              onExit: (_) => setState(() => _hover = null),
              child: RawGestureDetector(
                behavior: HitTestBehavior.deferToChild,
                gestures: {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(EagerGestureRecognizer.new, (_) {}),
                },
                child: Listener(
                  behavior: HitTestBehavior.deferToChild,
                  onPointerDown: (e) {
                    if (_pointer != null ||
                        e.buttons != kPrimaryButton ||
                        !widget.enabled) {
                      return;
                    }
                    final hit = painter.nearest(e.localPosition);
                    if (hit == null) return;
                    int? anchor;
                    for (final entry in handles.entries) {
                      if ((entry.value - e.localPosition).distance <= 14) {
                        anchor = entry.key;
                        break;
                      }
                    }
                    if (!model.beginRouteDrag(hit.position, anchorId: anchor)) {
                      return;
                    }
                    _focus.requestFocus();
                    _pointer = e.pointer;
                    _down = e.localPosition;
                    _camera = camera;
                    _moved = false;
                  },
                  onPointerMove: (e) {
                    if (_pointer != e.pointer || !model.dragging) return;
                    if (!_moved && (e.localPosition - _down!).distance < 4) {
                      return;
                    }
                    _moved = true;
                    _update(e.localPosition);
                  },
                  onPointerUp: (e) {
                    if (_pointer != e.pointer) return;
                    _pointer = null;
                    if (_moved && model.dragging) {
                      // The last move already scheduled this exact location. Keep
                      // its valid snap; only update if the release position differs.
                      final point = _camera!.screenOffsetToLatLng(
                        e.localPosition,
                      );
                      if (model.dragPoint != point) _update(e.localPosition);
                      model.finishRouteDrag();
                    } else {
                      model.cancelRouteEdit();
                    }
                  },
                  onPointerCancel: (e) {
                    if (_pointer == e.pointer) {
                      _pointer = null;
                      model.cancelRouteEdit();
                    }
                  },
                  child: CustomPaint(
                    key: const Key('route-drag-surface'),
                    painter: painter,
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: MarkerLayer(
            markers: [
              for (final p in model.visibleShapingPoints)
                Marker(
                  point: p.snap.position,
                  width: 18,
                  height: 18,
                  child: _handle(Key('route-shaping-point-${p.id}')),
                ),
              if (hover != null && !model.editing && widget.enabled)
                Marker(
                  point: camera.screenOffsetToLatLng(hover.point),
                  width: 14,
                  height: 14,
                  child: _handle(const Key('route-hover-handle')),
                ),
              if (model.draftSnap?.position ?? model.dragPoint
                  case final point?)
                Marker(
                  point: point,
                  width: 20,
                  height: 20,
                  child: _handle(const Key('route-draft-handle')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _handle(Key key) => DecoratedBox(
    key: key,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.blue.shade800, width: 3),
    ),
  );

  void _update(Offset point) {
    final camera = _camera!;
    final location = camera.screenOffsetToLatLng(point);
    final tolerance = const Distance().as(
      LengthUnit.Meter,
      location,
      camera.screenOffsetToLatLng(point + const Offset(24, 0)),
    );
    widget.model.updateRouteDrag(location, tolerance);
  }
}

class _RouteHitPainter extends CustomPainter {
  _RouteHitPainter(this.points, this.handles, {required this.enabled});
  final List<Offset> points;
  final Map<int, Offset> handles;
  final bool enabled;

  ({double position, Offset point})? nearest(Offset point) {
    var best = double.infinity;
    ({double position, Offset point})? hit;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], delta = points[i + 1] - a;
      final length = delta.distanceSquared;
      final t = length == 0
          ? 0.0
          : (((point.dx - a.dx) * delta.dx + (point.dy - a.dy) * delta.dy) /
                    length)
                .clamp(0.0, 1.0);
      final projected = a + delta * t;
      final distance = (point - projected).distanceSquared;
      if (distance < best) {
        best = distance;
        hit = (position: i + t, point: projected);
      }
    }
    final onHandle = handles.values.any((p) => (point - p).distance <= 14);
    return best <= math.pow(12, 2) || onHandle ? hit : null;
  }

  @override
  bool hitTest(Offset position) => enabled && nearest(position) != null;
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(_RouteHitPainter oldDelegate) => true;
}
