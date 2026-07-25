import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A county address point normalized for map and search experiences.
@immutable
class Address {
  /// Creates a normalized address point.
  const Address({
    required this.objectId,
    required this.sourceId,
    required this.fullAddress,
    required this.houseNumber,
    required this.streetName,
    required this.streetType,
    required this.unit,
    required this.city,
    required this.zipCode,
    required this.apn,
    required this.addressType,
    required this.numberOfUnits,
    required this.position,
    this.sourceUpdatedAt,
  });

  /// The ArcGIS object identifier used for deterministic batch downloads.
  final int objectId;

  /// The stable identifier supplied by Riverside County.
  final int sourceId;

  /// The primary street address without city and state.
  final String fullAddress;

  /// The numeric house component, when published.
  final int? houseNumber;

  /// The street name component.
  final String streetName;

  /// The street type or suffix.
  final String streetType;

  /// The unit or suite component.
  final String unit;

  /// The published situs city.
  final String city;

  /// The ZIP code.
  final String zipCode;

  /// The assessor parcel number, when linked by the source.
  final String apn;

  /// The county's raw address-type code.
  final String addressType;

  /// The number of units reported at this point.
  final int numberOfUnits;

  /// The WGS84 point geometry.
  final LatLng position;

  /// The source's last edit timestamp.
  final DateTime? sourceUpdatedAt;

  /// A user-facing address including unit, city, state, and ZIP.
  String get displayAddress {
    final unitSuffix = unit.isEmpty ? '' : ' Unit $unit';
    return '$fullAddress$unitSuffix, $city, CA $zipCode';
  }
}
