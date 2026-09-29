import 'package:flutter/foundation.dart';

/// The physical street address of record for one parcel.
///
/// A county assessor layer names a parcel by its assessor parcel number, and
/// several counties publish nothing else — no street, no city, no ZIP. This is
/// the resolved answer to "which building is that APN", assembled from a source
/// that carries both.
@immutable
final class SitusAddress {
  /// Creates a resolved situs address.
  const SitusAddress({
    required this.apn,
    required this.countyName,
    required this.streetAddress,
    required this.city,
    required this.zipCode,
  });

  /// The assessor parcel number the address was matched to.
  final String apn;

  /// The county the address falls in.
  final String countyName;

  /// The street line, unit designator included, such as `1364 W RIALTO AVE`.
  final String streetAddress;

  /// The situs city, such as `RIALTO`.
  final String city;

  /// The five-digit ZIP code.
  final String zipCode;

  /// The full mailable address, such as `1364 W RIALTO AVE, RIALTO, CA 92376`.
  String get fullAddress => formatAddress('CA');

  /// Formats a resolved situs in its workspace state.
  String formatAddress(String stateCode) {
    final tail = [
      if (city.isNotEmpty) city,
      [stateCode, if (zipCode.isNotEmpty) zipCode].join(' '),
    ].join(', ');
    return '$streetAddress, $tail';
  }
}
