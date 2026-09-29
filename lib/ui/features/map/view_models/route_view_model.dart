import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/domain/services/route_shaping.dart';

class RouteViewModel extends ChangeNotifier {
  RouteViewModel({required this.planner, required this.geocoder});
  final RoutePlanner planner;
  final RouteGeocoder geocoder;
  List<RouteStop?> _stops = [null, null];
  List<RouteStop?> get stops => List.unmodifiable(_stops);
  RouteOptions options = const RouteOptions();
  RoutePlan? plan;
  int selectedIndex = 0;
  int? pickingStop;
  bool panelOpen = false;
  bool busy = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  List<RouteShapingPoint> _shapingPoints = [];
  List<RouteShapingPoint> get shapingPoints =>
      List.unmodifiable(_shapingPoints);
  final List<List<RouteShapingPoint>> _undo = [];
  int _nextAnchorId = 0;
  _RouteDrag? _drag;
  final _dragActivity = ValueNotifier<bool>(false);

  /// The map only rebuilds its gesture options at drag boundaries, not on
  /// every pointer move (which would also rebuild parcel/overlay layers).
  ValueListenable<bool> get dragActivity => _dragActivity;
  Timer? _previewTimer;
  DateTime? _lastPreview;
  bool _previewRunning = false;
  int _pointerRevision = 0;
  RoutePath? preview;
  RouteRoadSnap? draftSnap;
  LatLng? dragPoint;
  List<RouteShapingPoint>? _pendingEdits;
  String? editMessage;
  bool get dragging => _drag != null;
  bool get editing => dragging || _pendingEdits != null;
  bool get canUndo => _undo.isNotEmpty && !busy && !dragging;
  bool get canShape =>
      !busy &&
      !dragging &&
      selected != null &&
      pickingStop == null &&
      planner.routing is RouteRoadSnapRepository;
  List<RouteShapingPoint> get visibleShapingPoints =>
      List.unmodifiable(_pendingEdits ?? _shapingPoints);

  /// [position] is a segment index plus fractional progress on the selected
  /// route. Anchor ordering follows this route, never straight-line distance.
  bool beginRouteDrag(double position, {int? anchorId}) {
    if (!canShape) return false;
    final path = selected!.path;
    final anchors = List<RouteShapingPoint>.of(_shapingPoints);
    int index, leg, id;
    if (anchorId != null) {
      index = anchors.indexWhere((p) => p.id == anchorId);
      if (index < 0) return false;
      final existing = anchors.removeAt(index);
      leg = existing.legIndex;
      id = existing.id;
    } else {
      if (anchors.length >= 8) {
        error = 'Use up to eight route edits. Remove an edit first.';
        notifyListeners();
        return false;
      }
      final ends = path.legEndIndices.isEmpty && _stops.length == 2
          ? [path.points.length - 1]
          : path.legEndIndices;
      leg = ends.indexWhere((end) => position < end);
      if (leg < 0) return false;
      index = anchors.indexWhere(
        (p) =>
            p.legIndex > leg ||
            (p.legIndex == leg &&
                (path.shapingPositions[p.id] ?? double.infinity) > position),
      );
      if (index < 0) index = anchors.length;
      id = _nextAnchorId++;
    }
    ++_generation;
    _drag = _RouteDrag(anchors, index, leg, id);
    _dragActivity.value = true;
    error = null;
    editMessage =
        'Drag onto a street · Preview has not been checked for cameras';
    notifyListeners();
    return true;
  }

  void updateRouteDrag(LatLng point, double maxMeters) {
    final drag = _drag;
    if (drag == null) return;
    drag.point = point;
    drag.maxMeters = math.min(75, maxMeters);
    dragPoint = point;
    draftSnap = null;
    ++_pointerRevision;
    editMessage = 'Finding street · Camera checks run on release';
    _queuePreview();
    notifyListeners();
  }

  void _queuePreview() {
    _previewTimer?.cancel();
    final elapsed = _lastPreview == null
        ? 1000
        : DateTime.now().difference(_lastPreview!).inMilliseconds;
    _previewTimer = Timer(
      Duration(milliseconds: math.max(350, 1000 - elapsed)),
      _runPreview,
    );
  }

  Future<void> _runPreview() async {
    final drag = _drag;
    if (drag == null || drag.point == null || _previewRunning) return;
    final revision = _pointerRevision, generation = _generation;
    final point = drag.point!, maxMeters = drag.maxMeters;
    _previewRunning = true;
    _lastPreview = DateTime.now();
    bool current() =>
        !_disposed &&
        _generation == generation &&
        _pointerRevision == revision &&
        identical(_drag, drag);
    try {
      final snap = await (planner.routing as RouteRoadSnapRepository).snap(
        point,
        maxMeters: maxMeters,
      );
      if (!current()) return;
      draftSnap = snap;
      editMessage = '${snap.label} · Preview has not been checked for cameras';
      notifyListeners();
      final anchors = drag.withSnap(snap);
      final paths =
          (await planner.routing.routes(
                _stops.cast<RouteStop>().toList(),
                shapingPoints: anchors,
              ))
              .map((p) => constrainRoutePath(p, anchors))
              .whereType<RoutePath>()
              .toList()
            ..sort((a, b) => a.seconds.compareTo(b.seconds));
      if (!current()) return;
      if (paths.isEmpty) {
        throw const RoutingException('No drivable route follows this street.');
      }
      preview = paths.first;
    } catch (e) {
      if (current()) {
        preview = null;
        draftSnap = null;
        editMessage = e is RoutingException
            ? e.message
            : 'Route preview unavailable. Release to retry.';
      }
    } finally {
      _previewRunning = false;
      if (current()) notifyListeners();
      if (!_disposed &&
          _drag != null &&
          (_generation != generation || _pointerRevision != revision)) {
        _queuePreview();
      }
    }
  }

  Future<void> finishRouteDrag() async {
    final drag = _drag;
    if (drag == null || drag.point == null) {
      cancelRouteEdit();
      return;
    }
    final snap = draftSnap;
    _previewTimer?.cancel();
    _drag = null;
    _dragActivity.value = false;
    final generation = ++_generation;
    busy = true;
    _pendingEdits = List.of(_shapingPoints);
    editMessage = 'Recalculating route and checking cameras…';
    notifyListeners();
    try {
      final resolved =
          snap ??
          await (planner.routing as RouteRoadSnapRepository).snap(
            drag.point!,
            maxMeters: drag.maxMeters,
          );
      if (_disposed || generation != _generation) return;
      draftSnap = resolved;
      await _commitEdits(drag.withSnap(resolved), generation: generation);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is RoutingException
            ? e.message
            : 'Route edit failed. Try again.';
        _endEdit();
        notifyListeners();
      }
    }
  }

  Future<void> removeShapingPoint(int id) async {
    if (busy || dragging) return;
    if (!_shapingPoints.any((p) => p.id == id)) return;
    await _commitEdits(_shapingPoints.where((p) => p.id != id).toList());
  }

  Future<void> resetRouteEdits() async {
    if (busy || dragging || _shapingPoints.isEmpty) return;
    await _commitEdits([]);
  }

  Future<void> undoRouteEdit() async {
    if (!canUndo) return;
    await _commitEdits(_undo.last, undo: true);
  }

  Future<void> _commitEdits(
    List<RouteShapingPoint> anchors, {
    int? generation,
    bool undo = false,
  }) async {
    final request = generation ?? ++_generation;
    _pendingEdits = List.of(anchors);
    busy = true;
    error = null;
    editMessage = 'Recalculating route and checking cameras…';
    notifyListeners();
    try {
      final result = await planner.plan(
        _stops.cast<RouteStop>().toList(),
        options,
        shapingPoints: anchors,
        cancelled: () => _disposed || request != _generation,
      );
      if (_disposed || request != _generation) return;
      if (undo) {
        _undo.removeLast();
      } else {
        _undo.add(List.of(_shapingPoints));
      }
      _shapingPoints = List.of(anchors);
      plan = result;
      selectedIndex = 0;
      focusedManeuver = null;
      // Deliberately do not change cameraRevision: the map stays under the pointer.
    } catch (e) {
      if (!_disposed && request == _generation) {
        error = e is RoutingException
            ? e.message
            : 'Route edit failed. Try again.';
      }
    } finally {
      if (!_disposed && request == _generation) {
        _endEdit();
        notifyListeners();
      }
    }
  }

  void _endEdit() {
    _previewTimer?.cancel();
    _drag = null;
    _dragActivity.value = false;
    _pendingEdits = null;
    preview = null;
    draftSnap = null;
    dragPoint = null;
    editMessage = null;
    busy = false;
  }

  void cancelRouteEdit() {
    if (!editing) return;
    ++_generation;
    _endEdit();
    notifyListeners();
  }

  /// The map observes this revision to fit a new route or selected maneuver.
  int cameraRevision = 0;
  LatLng? focusedManeuver;
  AssessedRoute? get selected => plan?.routes.elementAtOrNull(selectedIndex);
  bool get selectedConstraintsSatisfied =>
      options.preference == RoutePreference.fastest ||
      (plan?.cameraQueryComplete == true &&
          (options.preference != RoutePreference.avoidMappedCoverage ||
              selected?.hits.isEmpty == true));
  bool get ready => _stops.every((stop) => stop != null) && !busy;

  void showPanel(bool value) {
    panelOpen = value;
    pickingStop = null;
    notifyListeners();
  }

  void pickStop(int index) {
    cancelRouteEdit();
    pickingStop = index;
    panelOpen = false;
    notifyListeners();
  }

  bool acceptMapPoint(LatLng point) {
    final index = pickingStop;
    if (index == null) return false;
    setStop(
      index,
      RouteStop(
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        point,
      ),
    );
    pickingStop = null;
    panelOpen = true;
    notifyListeners();
    return true;
  }

  void setStop(int index, RouteStop? stop) {
    if (index < 0 || index >= _stops.length) return;
    _stops[index] = stop;
    _invalidate();
  }

  void addStop() {
    if (_stops.length >= 8) return;
    _stops.insert(_stops.length - 1, null);
    _invalidate();
  }

  void removeStop(int index) {
    if (_stops.length <= 2) return;
    _stops.removeAt(index);
    _invalidate();
  }

  void moveStop(int from, int to) {
    final stop = _stops.removeAt(from);
    _stops.insert(to, stop);
    _invalidate();
  }

  void reverseStops() {
    _stops = _stops.reversed.toList();
    _invalidate();
  }

  void setOptions(RouteOptions value) {
    options = value;
    _invalidate(clearEdits: false);
  }

  void _invalidate({bool clearEdits = true}) {
    ++_generation;
    _endEdit();
    if (clearEdits) {
      _shapingPoints = [];
      _undo.clear();
    }
    busy = false;
    plan = null;
    error = null;
    focusedManeuver = null;
    notifyListeners();
  }

  void clear() {
    _stops = [null, null];
    pickingStop = null;
    _invalidate();
  }

  void cancel() {
    _endEdit();
    ++_generation;
    busy = false;
    notifyListeners();
  }

  Future<RoutePlan?> calculate({
    List<RouteStop>? stops,
    RouteOptions? settings,
  }) async {
    _endEdit();
    final generation = ++_generation;
    if (stops != null) {
      _stops = List.of(stops);
      _shapingPoints = [];
      _undo.clear();
    }
    if (settings != null) options = settings;
    panelOpen = true;
    pickingStop = null;
    plan = null;
    error = null;
    focusedManeuver = null;
    if (_stops.any((stop) => stop == null)) {
      error = 'Choose a location for every stop.';
      notifyListeners();
      return null;
    }
    busy = true;
    notifyListeners();
    try {
      final result = await planner.plan(
        _stops.cast<RouteStop>().toList(),
        options,
        shapingPoints: _shapingPoints,
        cancelled: () => _disposed || generation != _generation,
      );
      if (_disposed || generation != _generation) return null;
      plan = result;
      selectedIndex = 0;
      ++cameraRevision;
      return result;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e is RoutingException
            ? e.message
            : 'Routing is unavailable. Please try again.';
      }
      return null;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void select(int index) {
    if (busy ||
        dragging ||
        plan == null ||
        index < 0 ||
        index >= plan!.routes.length) {
      return;
    }
    selectedIndex = index;
    focusedManeuver = null;
    ++cameraRevision;
    notifyListeners();
  }

  void focusManeuver(LatLng point) {
    focusedManeuver = point;
    ++cameraRevision;
    notifyListeners();
  }

  void fit() {
    focusedManeuver = null;
    ++cameraRevision;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _disposed = true;
    _dragActivity.dispose();
    ++_generation;
    super.dispose();
  }
}

class _RouteDrag {
  _RouteDrag(this.anchors, this.index, this.leg, this.id);
  final List<RouteShapingPoint> anchors;
  final int index, leg, id;
  LatLng? point;
  double maxMeters = 75;
  List<RouteShapingPoint> withSnap(RouteRoadSnap snap) =>
      [...anchors]
        ..insert(index, RouteShapingPoint(id: id, legIndex: leg, snap: snap));
}
