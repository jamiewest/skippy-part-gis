import 'package:riverside_atlas/ui/features/map/widgets/route_map_layout.dart';
import 'package:riverside_atlas/ui/features/map/widgets/route_drag_layer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_exposure.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';

class RouteMapLayer extends StatefulWidget {
  const RouteMapLayer({
    super.key,
    required this.model,
    required this.controller,
    this.reserved = EdgeInsets.zero,
    this.editable = true,
    this.managedPanel = false,
  });
  final RouteViewModel model;
  final MapController controller;
  final EdgeInsets reserved;
  final bool editable;
  final bool managedPanel;
  @override
  State<RouteMapLayer> createState() => _RouteMapLayerState();
}

class _RouteMapLayerState extends State<RouteMapLayer> {
  int _revision = 0;
  int? _dragIndex;
  LatLng? _draft;
  Offset? _press, _startScreen;
  MapCamera? _dragCamera;
  int? _pointer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model;
      final camera = MapCamera.of(context);
      if (_revision != model.cameraRevision) {
        _revision = model.cameraRevision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final padding = widget.managedPanel
              ? widget.reserved + const EdgeInsets.all(20)
              : routeCameraPadding(
                  widget.controller.camera.nonRotatedSize,
                  widget.reserved,
                  model.panelOpen,
                );
          if (model.focusedManeuver case final point?) {
            widget.controller.move(
              point,
              17,
              offset: Offset(
                (padding.left - padding.right) / 2,
                (padding.top - padding.bottom) / 2,
              ),
            );
          } else if (model.selected case final selected?) {
            widget.controller.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(selected.path.points),
                padding: padding,
              ),
            );
          }
        });
      }
      final selected = model.selected;
      final plan = model.plan;
      return Stack(
        children: [
          if (plan != null) ...[
            PolygonLayer(
              polygons: [
                for (final c in plan.cameras)
                  Polygon(
                    points: const RouteExposure().footprint(c),
                    color: (c.direction == null ? Colors.orange : Colors.red)
                        .withValues(alpha: 0.12),
                    borderColor: c.direction == null
                        ? Colors.orange
                        : Colors.red,
                    borderStrokeWidth: 1,
                  ),
              ],
            ),
            PolylineLayer(
              key: const Key('route-alternatives-layer'),
              polylines: [
                for (final route in plan.routes)
                  if (route != selected)
                    Polyline(
                      points: route.path.points,
                      color: Colors.blueGrey.withValues(alpha: 0.65),
                      strokeWidth: 5,
                    ),
              ],
            ),
            if (selected != null)
              PolylineLayer(
                key: const Key('selected-route-layer'),
                polylines: [
                  Polyline(
                    points: selected.path.points,
                    color: Colors.blue.shade700,
                    strokeWidth: 6,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                  for (final hit in selected.hits)
                    for (final index in hit.segments)
                      Polyline(
                        points: selected.path.points.sublist(index, index + 2),
                        color: hit.uncertain ? Colors.orange : Colors.red,
                        strokeWidth: 7,
                      ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final c in plan.cameras)
                  Marker(
                    point: c.position,
                    width: 24,
                    height: 24,
                    child: Tooltip(
                      message: '${c.description}\nEstimated coverage',
                      child: Icon(
                        Icons.videocam,
                        size: 20,
                        color: c.direction == null
                            ? Colors.orange.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (model.preview case final preview?)
            IgnorePointer(
              child: PolylineLayer(
                polylines: [
                  Polyline(
                    points: preview.points,
                    color: Colors.purple,
                    strokeWidth: 5,
                    pattern: const StrokePattern.dotted(),
                  ),
                ],
              ),
            ),
          RouteDragLayer(
            model: model,
            enabled: widget.editable && model.pickingStop == null,
          ),
          MarkerLayer(
            markers: [
              for (var i = 0; i < model.stops.length; i++)
                if (model.stops[i] case final stop?) _marker(camera, stop, i),
            ],
          ),
        ],
      );
    },
  );

  Marker _marker(MapCamera camera, RouteStop stop, int index) => Marker(
    point: _dragIndex == index ? _draft ?? stop.position : stop.position,
    width: 42,
    height: 42,
    rotate: true,
    child: IgnorePointer(
      ignoring:
          !widget.editable ||
          widget.model.pickingStop != null ||
          widget.model.busy ||
          widget.model.dragging,
      child: Tooltip(
        message: '${stop.label}\nDrag to move stop ${index + 1}',
        child: RawGestureDetector(
          key: Key('route-stop-marker-$index'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
          },
          child: Listener(
            onPointerDown: (e) {
              if (!widget.editable ||
                  widget.model.pickingStop != null ||
                  widget.model.busy ||
                  widget.model.dragging ||
                  _pointer != null ||
                  e.buttons != kPrimaryButton) {
                return;
              }
              _pointer = e.pointer;
              _dragIndex = index;
              _press = e.position;
              _startScreen = camera.latLngToScreenOffset(stop.position);
              _dragCamera = camera;
            },
            onPointerMove: (e) {
              if (_pointer != e.pointer) return;
              setState(
                () => _draft = _dragCamera!.screenOffsetToLatLng(
                  _startScreen! + e.position - _press!,
                ),
              );
            },
            onPointerUp: (e) {
              if (_pointer != e.pointer) return;
              final point = _draft;
              setState(_resetDrag);
              if (point == null || !validRouteCoordinate(point)) return;
              widget.model.setStop(
                index,
                RouteStop(
                  '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                  point,
                ),
              );
              if (widget.model.ready) widget.model.calculate();
            },
            onPointerCancel: (e) {
              if (_pointer == e.pointer) setState(_resetDrag);
            },
            child: CircleAvatar(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              child: Text('${index + 1}'),
            ),
          ),
        ),
      ),
    ),
  );
  void _resetDrag() {
    _pointer = null;
    _dragIndex = null;
    _draft = null;
  }
}
