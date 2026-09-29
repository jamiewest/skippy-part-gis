import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';
import 'package:riverside_atlas/domain/services/route_shaping.dart';

/// The endpoint is the full /route URL, including any provider query options.
class ValhallaRoutingService
    implements RoutingRepository, RouteRoadSnapRepository {
  ValhallaRoutingService(this.client, {Uri? endpoint, this.snapEndpoint})
    : endpoint =
          endpoint ?? Uri.parse('https://valhalla1.openstreetmap.de/route');
  final http.Client client;
  final Uri endpoint;
  final Uri? snapEndpoint;
  Uri get locateEndpoint =>
      snapEndpoint ??
      endpoint.replace(
        path: endpoint.path.replaceFirst(RegExp(r'/[^/]*$'), '/locate'),
      );

  @override
  Future<List<RoutePath>> routes(
    List<RouteStop> stops, {
    List<List<LatLng>> excludePolygons = const [],
    bool preferLocalRoads = false,
    List<RouteShapingPoint> shapingPoints = const [],
  }) async {
    if (stops.length < 2 ||
        stops.length > 8 ||
        stops.any((s) => !validRouteCoordinate(s.position))) {
      throw const RoutingException('Choose 2–8 valid route stops.');
    }
    validateShapingPoints(shapingPoints, stops.length);
    if (excludePolygons.length > 100) {
      throw const RoutingException(
        'Too many camera areas for one avoidance request.',
      );
    }
    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (!kIsWeb) 'User-Agent': 'Atlas/1.0 (com.skippy.riversideAtlas)',
          },
          body: jsonEncode({
            'locations': [
              for (var i = 0; i < stops.length; i++) ...[
                {
                  'lat': stops[i].position.latitude,
                  'lon': stops[i].position.longitude,
                  'type': 'break',
                },
                for (final anchor in shapingPoints.where(
                  (p) => p.legIndex == i,
                ))
                  {
                    'lat': anchor.snap.position.latitude,
                    'lon': anchor.snap.position.longitude,
                    'type': 'through',
                    'radius': 4,
                    'search_cutoff': 10,
                    'node_snap_tolerance': 0,
                  },
              ],
            ],
            'costing': 'auto',
            if (preferLocalRoads)
              'costing_options': {
                'auto': {
                  'use_highways': 0,
                  'use_living_streets': 1,
                  'use_distance': 0.5,
                  'disable_hierarchy_pruning': true,
                },
              },
            'units': 'kilometers',
            'language': 'en-US',
            'alternates': stops.length == 2 && shapingPoints.isEmpty ? 2 : 0,
            if (excludePolygons.isNotEmpty)
              'exclude_polygons': [
                for (final polygon in excludePolygons)
                  [
                    for (final point in [...polygon, polygon.first])
                      [point.longitude, point.latitude],
                  ],
              ],
          }),
        )
        .timeout(const Duration(seconds: 35));
    if (response.statusCode != 200) {
      throw RoutingException(
        'Routing service returned HTTP ${response.statusCode}. '
        'A road route may be unavailable with these stops or exclusions.',
      );
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final trips = <Map<String, dynamic>>[
        data['trip'] as Map<String, dynamic>,
        for (final alternate in data['alternates'] as List? ?? const [])
          (alternate as Map)['trip'] as Map<String, dynamic>,
      ];
      final paths = trips
          .map(_parseTrip)
          .map((p) => constrainRoutePath(p, shapingPoints))
          .whereType<RoutePath>()
          .toList();
      if (paths.isEmpty) {
        throw const RoutingException(
          'No drivable route follows the chosen street. Try another point on the street.',
        );
      }
      return paths;
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException(
        'The routing service returned an invalid route.',
      );
    }
  }

  RoutePath _parseTrip(Map<String, dynamic> trip) {
    if (trip['status'] != 0) {
      throw const RoutingException(
        'The routing service could not find a road route.',
      );
    }
    final points = <LatLng>[];
    final maneuvers = <RouteManeuver>[];
    final legEnds = <int>[];
    final units = trip['units'];
    if (units != 'kilometers' && units != 'miles') {
      throw const FormatException('Unknown route units');
    }
    final scale = units == 'miles' ? 1609.344 : 1000.0;
    for (final leg in trip['legs'] as List) {
      final shape = decodePolyline6(leg['shape'] as String);
      if (shape.length < 2) throw const FormatException('Empty route leg');
      points.addAll(
        points.isNotEmpty && points.last == shape.first ? shape.skip(1) : shape,
      );
      legEnds.add(points.length - 1);
      for (final maneuver in leg['maneuvers'] as List) {
        final index = maneuver['begin_shape_index'] as int;
        maneuvers.add(
          RouteManeuver(
            instruction: maneuver['instruction'] as String,
            point: shape[index],
            meters: _nonnegative(maneuver['length']) * scale,
            seconds: _nonnegative(maneuver['time']),
          ),
        );
      }
    }
    if (points.length < 2 || maneuvers.isEmpty) {
      throw const FormatException('Missing route geometry or directions');
    }
    return RoutePath(
      points: points,
      maneuvers: maneuvers,
      legEndIndices: legEnds,
      meters: _nonnegative(trip['summary']['length']) * scale,
      seconds: _nonnegative(trip['summary']['time']),
    );
  }

  @override
  Future<RouteRoadSnap> snap(LatLng point, {required double maxMeters}) async {
    if (!validRouteCoordinate(point) || !maxMeters.isFinite || maxMeters <= 0) {
      throw const RoutingException('Invalid street snap location.');
    }
    final limit = math.min(75.0, maxMeters);
    try {
      final response = await client
          .post(
            locateEndpoint,
            headers: {
              'Content-Type': 'application/json',
              if (!kIsWeb)
                'User-Agent': 'Atlas/1.0 (com.skippy.riversideAtlas)',
            },
            body: jsonEncode({
              'locations': [
                {
                  'lat': point.latitude,
                  'lon': point.longitude,
                  'radius': limit,
                  'search_cutoff': limit,
                  'node_snap_tolerance': 0,
                },
              ],
              'costing': 'auto',
              'verbose': true,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw RoutingException(
          'Street snapping returned HTTP ${response.statusCode}. Try again.',
        );
      }
      final data = jsonDecode(response.body) as List;
      final candidates = <RouteRoadSnap>[];
      for (final raw in (data.single as Map)['edges'] as List? ?? const []) {
        final edge = raw as Map;
        final info = edge['edge_info'] as Map;
        final detail = edge['edge'] as Map;
        if ((detail['access'] as Map?)?['car'] != true ||
            detail['unreachable'] == true) {
          continue;
        }
        final position = LatLng(
          (edge['correlated_lat'] as num).toDouble(),
          (edge['correlated_lon'] as num).toDouble(),
        );
        if (!validRouteCoordinate(position) ||
            const Distance().as(LengthUnit.Meter, point, position) > limit) {
          continue;
        }
        final road = decodePolyline6(info['shape'] as String);
        if (road.length < 2) continue;
        final names = (info['names'] as List? ?? const [])
            .whereType<String>()
            .toList();
        candidates.add(
          RouteRoadSnap(
            position: position,
            label: names.isEmpty ? 'Chosen street' : names.join(' / '),
            road: road,
            wayId: info['way_id']?.toString(),
          ),
        );
      }
      candidates.sort(
        (a, b) => const Distance()(
          point,
          a.position,
        ).compareTo(const Distance()(point, b.position)),
      );
      if (candidates.isEmpty) {
        throw const RoutingException(
          'No drivable street close enough. Drag closer to a street.',
        );
      }
      return candidates.first;
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException(
        'Street snapping is unavailable. Try again.',
      );
    }
  }

  double _nonnegative(Object? value) {
    if (value is! num || !value.isFinite || value < 0) {
      throw const FormatException('Invalid distance/time');
    }
    return value.toDouble();
  }
}

List<LatLng> decodePolyline6(String encoded) {
  var cursor = 0, latitude = 0, longitude = 0;
  int next() {
    var result = 0, shift = 0;
    while (true) {
      if (cursor >= encoded.length || shift > 30) {
        throw const FormatException('Truncated or oversized polyline');
      }
      final byte = encoded.codeUnitAt(cursor++) - 63;
      if (byte < 0 || byte > 63) {
        throw const FormatException('Invalid polyline');
      }
      result |= (byte & 31) << shift;
      if (byte < 32) return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      shift += 5;
    }
  }

  final points = <LatLng>[];
  while (cursor < encoded.length) {
    latitude += next();
    longitude += next();
    final point = LatLng(latitude / 1e6, longitude / 1e6);
    if (!validRouteCoordinate(point)) {
      throw const FormatException('Invalid coordinates');
    }
    points.add(point);
    if (points.length > 200000) throw const FormatException('Oversized route');
  }
  return points;
}
