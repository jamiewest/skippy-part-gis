import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// An administrative area polygon published by the county.
///
/// The application scopes itself to Riverside County, so this normally holds
/// the county outline. The same shape describes any incorporated place, which
/// keeps the type usable if a narrower area is ever selected.
@immutable
class RegionBoundary {
  /// Creates a region boundary from ArcGIS polygon rings.
  RegionBoundary({required this.name, required this.fips, required this.rings})
    : bounds = GeoBounds.enclosing(rings);

  /// The county-published area name.
  final String name;

  /// The published FIPS code, three characters for a county.
  final String fips;

  /// Polygon rings in WGS84 coordinates.
  final List<List<LatLng>> rings;

  /// The smallest rectangle containing the region.
  final GeoBounds bounds;

  /// Whether [point] is inside the region polygon.
  bool contains(LatLng point) {
    var inside = false;
    for (final ring in rings) {
      if (_ringContains(ring, point)) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool _ringContains(List<LatLng> ring, LatLng point) {
    var inside = false;
    for (
      var index = 0, previous = ring.length - 1;
      index < ring.length;
      previous = index++
    ) {
      final currentPoint = ring[index];
      final previousPoint = ring[previous];
      final crossesLatitude =
          (currentPoint.latitude > point.latitude) !=
          (previousPoint.latitude > point.latitude);
      final crossingLongitude =
          (previousPoint.longitude - currentPoint.longitude) *
              (point.latitude - currentPoint.latitude) /
              (previousPoint.latitude - currentPoint.latitude) +
          currentPoint.longitude;
      if (crossesLatitude && point.longitude < crossingLongitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}
