import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// An assessor parcel clipped to the Riverside prototype boundary.
@immutable
class Parcel {
  /// Creates a parcel and derives its bounds from [rings].
  Parcel({
    required this.sourceId,
    required this.apn,
    required this.situsAddress,
    required this.city,
    required this.zipCode,
    required this.landUse,
    required this.acreage,
    required this.rings,
  }) : bounds = GeoBounds.enclosing(rings);

  /// The source object identifier.
  final int sourceId;

  /// The assessor parcel number.
  final String apn;

  /// The published situs street.
  final String situsAddress;

  /// The published situs city.
  final String city;

  /// The published ZIP code.
  final String zipCode;

  /// The assessor class or land-use description.
  final String landUse;

  /// The assessed acreage, when available.
  final double? acreage;

  /// Polygon rings in WGS84 coordinates.
  final List<List<LatLng>> rings;

  /// The smallest rectangle containing the parcel.
  final GeoBounds bounds;

  /// Whether [point] is inside this parcel.
  bool contains(LatLng point) {
    var inside = false;
    for (final ring in rings) {
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
    }
    return inside;
  }
}
