import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/repositories/routing_repository.dart';

/// Search is submitted explicitly, not on each keystroke.
class PhotonRouteGeocoder implements RouteGeocoder {
  PhotonRouteGeocoder(this.client, {Uri? endpoint})
    : endpoint = endpoint ?? Uri.parse('https://photon.komoot.io/api/');
  final http.Client client;
  final Uri endpoint;

  @override
  Future<List<RouteStop>> search(String query, {LatLng? near}) async {
    final coordinate = parseRouteCoordinate(query);
    if (coordinate != null) return [RouteStop(query.trim(), coordinate)];
    if (query.trim().length < 3 || query.length > 300) {
      throw const RoutingException(
        'Enter an address, place, or latitude, longitude.',
      );
    }
    final headers = {
      'Accept': 'application/json',
      if (!kIsWeb) 'User-Agent': 'Atlas/1.0 (com.skippy.riversideAtlas)',
    };
    final response = await client
        .get(
          endpoint.replace(
            queryParameters: {
              ...endpoint.queryParameters,
              'q': query.trim(),
              'limit': '5',
              'lang': 'en',
              if (near != null) 'lat': '${near.latitude}',
              if (near != null) 'lon': '${near.longitude}',
            },
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw RoutingException(
        'Place search returned HTTP ${response.statusCode}.',
      );
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return [
        for (final feature in data['features'] as List) _stop(feature as Map),
      ];
    } catch (_) {
      throw const RoutingException('Place search returned invalid locations.');
    }
  }

  RouteStop _stop(Map feature) {
    final coordinates = feature['geometry']['coordinates'] as List;
    final point = LatLng(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
    if (!validRouteCoordinate(point)) throw const FormatException();
    final p = feature['properties'] as Map;
    final street = [
      p['housenumber'],
      p['street'],
    ].whereType<String>().join(' ');
    final label = <String>{
      if (p['name'] is String) p['name'] as String,
      if (street.isNotEmpty) street,
      ...[p['city'], p['state'], p['country']].whereType<String>(),
    }.join(', ');
    return RouteStop(
      label.isEmpty ? '${point.latitude}, ${point.longitude}' : label,
      point,
    );
  }
}

LatLng? parseRouteCoordinate(String text) {
  final parts = text.trim().split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim()),
      lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return null;
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 85 || lon.abs() > 180) {
    throw const RoutingException(
      'Latitude must be between −85 and 85; longitude between −180 and 180.',
    );
  }
  return LatLng(lat, lon);
}
