import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';

abstract interface class RoutingRepository {
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  });
}

abstract interface class RouteRoadSnapRepository {
  Future<RouteRoadSnap> snap(LatLng point, {required double maxMeters});
}

abstract interface class RouteGeocoder {
  Future<List<RouteStop>> search(String query, {LatLng? near});
}

abstract interface class RouteCameraRepository {
  Future<RouteCameraSnapshot> along(List<RoutePath> paths);
}
