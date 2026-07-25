import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A longitude-latitude rectangle in WGS84 coordinates.
@immutable
class GeoBounds {
  /// Creates bounds from their western, southern, eastern, and northern edges.
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  /// The western longitude.
  final double west;

  /// The southern latitude.
  final double south;

  /// The eastern longitude.
  final double east;

  /// The northern latitude.
  final double north;

  /// Whether [point] falls inside or on this rectangle.
  bool contains(LatLng point) =>
      point.longitude >= west &&
      point.longitude <= east &&
      point.latitude >= south &&
      point.latitude <= north;

  /// Whether [other] falls entirely inside or on this rectangle.
  bool encloses(GeoBounds other) =>
      west <= other.west &&
      east >= other.east &&
      south <= other.south &&
      north >= other.north;

  /// This rectangle grown by [latitude] and [longitude] degrees on each side.
  GeoBounds inflate({required double latitude, required double longitude}) =>
      GeoBounds(
        west: math.max(-180, west - longitude),
        south: math.max(-90, south - latitude),
        east: math.min(180, east + longitude),
        north: math.min(90, north + latitude),
      );

  /// Whether this rectangle overlaps [other].
  bool intersects(GeoBounds other) =>
      west <= other.east &&
      east >= other.west &&
      south <= other.north &&
      north >= other.south;

  /// A rectangle containing every point in [rings].
  static GeoBounds enclosing(Iterable<Iterable<LatLng>> rings) {
    var west = double.infinity;
    var south = double.infinity;
    var east = double.negativeInfinity;
    var north = double.negativeInfinity;

    for (final ring in rings) {
      for (final point in ring) {
        west = math.min(west, point.longitude);
        south = math.min(south, point.latitude);
        east = math.max(east, point.longitude);
        north = math.max(north, point.latitude);
      }
    }

    return GeoBounds(west: west, south: south, east: east, north: north);
  }
}
