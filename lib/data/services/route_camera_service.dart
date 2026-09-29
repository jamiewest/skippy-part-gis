import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/overpass_alpr_service.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';

/// Queries the entire candidate route corridor, regardless of map zoom/layers.
class OverpassRouteCameraService implements RouteCameraRepository {
  OverpassRouteCameraService(this.client, {Uri? endpoint})
    : endpoint = endpoint ?? OverpassAlprService.defaultEndpoint;
  final http.Client client;
  final Uri endpoint;
  static const limit = 10000;
  static const maxTiles = 120;
  static const tileDegrees = 0.05;

  @override
  Future<RouteCameraSnapshot> along(List<RoutePath> paths) async {
    try {
      final tiles = corridorTiles(paths);
      const filter = '["man_made"="surveillance"]["surveillance:type"="ALPR"]';
      final query =
          '[out:json][timeout:25];('
          '${tiles.map((b) => 'nwr$filter(${b.south},${b.west},${b.north},${b.east});').join()}'
          ');out tags center ${limit + 1};';
      final response = await client
          .post(
            endpoint,
            headers: {
              'Accept': 'application/json',
              if (!kIsWeb)
                'User-Agent': 'Atlas/1.0 (com.skippy.riversideAtlas)',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw RoutingException(
          'Camera query returned HTTP ${response.statusCode}.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['remark'] != null) {
        throw const RoutingException('Camera query did not complete.');
      }
      final elements = data['elements'] as List;
      var complete = elements.length <= limit;
      final cameras = <String, AlprCamera>{};
      for (final element in elements.take(limit)) {
        try {
          final camera = AlprCamera.fromOverpassJson(
            element as Map<String, dynamic>,
          );
          if (!validRouteCoordinate(camera.position) ||
              (camera.direction != null && !camera.direction!.isFinite)) {
            complete = false;
            continue;
          }
          cameras[camera.sourceId] = camera;
        } catch (_) {
          complete = false;
        }
      }
      return RouteCameraSnapshot(
        cameras: cameras.values,
        complete: complete,
        notice: complete
            ? null
            : 'Camera results were capped or contained invalid records.',
      );
    } catch (error) {
      return RouteCameraSnapshot(
        cameras: const [],
        complete: false,
        notice: error is RoutingException
            ? error.message
            : 'Camera coverage could not be checked.',
      );
    }
  }

  /// Small grid cells covering every segment plus at least 200m on each side.
  /// Reject oversized/antimeridian requests explicitly rather than sampling.
  static List<GeoBounds> corridorTiles(List<RoutePath> paths) {
    final keys = <(int, int)>{};
    for (final path in paths) {
      for (var i = 0; i < path.points.length - 1; i++) {
        final a = path.points[i], b = path.points[i + 1];
        if ((a.longitude - b.longitude).abs() > 180) {
          throw const RoutingException(
            'Camera analysis across the antimeridian is unavailable.',
          );
        }
        final padLon =
            0.002 /
            math.cos(
              math.max(a.latitude.abs(), b.latitude.abs()) * math.pi / 180,
            );
        final west =
            ((math.min(a.longitude, b.longitude) - padLon) / tileDegrees)
                .floor();
        final east =
            ((math.max(a.longitude, b.longitude) + padLon) / tileDegrees)
                .floor();
        final south = ((math.min(a.latitude, b.latitude) - 0.002) / tileDegrees)
            .floor();
        final north = ((math.max(a.latitude, b.latitude) + 0.002) / tileDegrees)
            .floor();
        for (var x = west; x <= east; x++) {
          for (var y = south; y <= north; y++) {
            keys.add((x, y));
            if (keys.length > maxTiles) {
              throw const RoutingException(
                'This route exceeds the camera-query area limit. Try a shorter trip.',
              );
            }
          }
        }
      }
    }
    if (keys.isEmpty) {
      throw const RoutingException('No route corridor to check.');
    }
    return [
      for (final (x, y) in keys)
        GeoBounds(
          west: (x * tileDegrees).clamp(-180, 180),
          south: (y * tileDegrees).clamp(-90, 90),
          east: ((x + 1) * tileDegrees).clamp(-180, 180),
          north: ((y + 1) * tileDegrees).clamp(-90, 90),
        ),
    ];
  }
}
