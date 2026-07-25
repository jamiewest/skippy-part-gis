import 'package:flutter/foundation.dart';

/// Owner information returned by a public property-tax record.
@immutable
final class PropertyOwnership {
  /// Creates a matched public ownership record.
  const PropertyOwnership({
    required this.ownerName,
    required this.parcelId,
    required this.matchedAddress,
    required this.sourceUri,
    required this.checkedAt,
    this.isSaved = false,
  });

  /// The current owner name published by the source.
  final String ownerName;

  /// The parcel identifier returned for the address.
  final String parcelId;

  /// The source's situs address used to confirm the match.
  final String matchedAddress;

  /// The public record that supplied the owner name.
  final Uri sourceUri;

  /// Time the public source was checked.
  final DateTime checkedAt;

  /// Whether this instance was restored from the persistent cache.
  final bool isSaved;
}
