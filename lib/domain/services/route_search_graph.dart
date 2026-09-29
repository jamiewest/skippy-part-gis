import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';

/// Discovered directed road segments and complete, provider-validated paths.
/// Valhalla owns the full road graph and enforces access and turn restrictions.
/// Never splice these paths: a shared vertex does not establish a legal turn.
class RouteSearchGraph {
  final _paths = <String, RoutePath>{};
  final _outgoing = <String, Map<String, _RoadEdge>>{};
  final _deviations = <String, List<List<LatLng>>>{};
  final _triedBranches = <String>{};

  List<RoutePath> get paths => _paths.values.toList();

  bool add(RoutePath path, {List<List<LatLng>> deviations = const []}) {
    final key = _key(path);
    if (_paths.containsKey(key)) return false;
    _paths[key] = path;
    _deviations[key] = deviations;
    for (var i = 1; i < path.points.length; i++) {
      _outgoing
          .putIfAbsent(_pointKey(path.points[i - 1]), () => {})
          .putIfAbsent(
            _pointKey(path.points[i]),
            () => _RoadEdge(path.points[i - 1], path.points[i]),
          );
    }
    return true;
  }

  /// Explore three separated deviations from each successful path, fastest
  /// paths first. Each request is solved against the provider's full graph.
  List<List<LatLng>>? nextBranch(
    List<AssessedRoute> successful,
    List<RouteStop> stops,
  ) {
    final ranked = [...successful]
      ..sort((a, b) => a.path.seconds.compareTo(b.path.seconds));
    const distance = Distance();
    for (final route in ranked) {
      final path = route.path;
      final edges = [
        for (var i = 1; i < path.points.length; i++)
          _outgoing[_pointKey(path.points[i - 1])]![_pointKey(path.points[i])]!,
      ];
      final total = edges.fold(0.0, (sum, edge) => sum + edge.meters);
      for (final fraction in [0.5, 0.25, 0.75]) {
        var remaining = total * fraction;
        for (final edge in edges) {
          if (remaining > edge.meters || edge.meters == 0) {
            remaining -= edge.meters;
            continue;
          }
          final a = edge.from, b = edge.to;
          final ratio = remaining / edge.meters;
          final point = LatLng(
            a.latitude + (b.latitude - a.latitude) * ratio,
            a.longitude + (b.longitude - a.longitude) * ratio,
          );
          // Avoid blocking the only entrance/exit of a requested stop.
          if (stops.any(
            (stop) => distance.as(LengthUnit.Meter, point, stop.position) < 60,
          )) {
            break;
          }
          final from = _pointKey(a), to = _pointKey(b);
          // Polygon exclusions remove both directions of the same road.
          final edgeKey = [from, to]..sort();
          final inherited = _deviations[_key(path)]!;
          final context =
              inherited.map((ring) => ring.map(_pointKey).join(';')).toList()
                ..sort();
          final branchKey = '${edgeKey.join(':')}/${context.join('/')}';
          if (_triedBranches.add(branchKey)) {
            return [
              ...inherited,
              [
                for (var bearing = 0; bearing < 360; bearing += 45)
                  distance.offset(point, 12, bearing.toDouble()),
              ],
            ];
          }
          break;
        }
      }
    }
    return null;
  }

  String _key(RoutePath path) => path.points.map(_pointKey).join(';');
  String _pointKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
}

class _RoadEdge {
  _RoadEdge(this.from, this.to)
    : meters = const Distance().as(LengthUnit.Meter, from, to);

  final LatLng from;
  final LatLng to;
  final double meters;
}
