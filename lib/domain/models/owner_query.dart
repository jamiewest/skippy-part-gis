import 'package:flutter/foundation.dart';
import 'package:riverside_atlas/core/text_matching.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';

/// The map selection an owner lookup started from.
enum OwnerQuerySubject {
  /// The user selected an address point.
  address,

  /// The user selected a parcel polygon.
  parcel,
}

/// A county-neutral request for the current owner of one property.
///
/// Every county source needs the same facts to search and to confirm a match,
/// but each reaches them through a different site. Flattening [Address] and
/// [Parcel] once here keeps county resolvers free of GIS models and gives the
/// owner cache a single place to derive its key.
@immutable
final class OwnerQuery {
  /// Creates a lookup request.
  const OwnerQuery({
    required this.countyId,
    required this.subject,
    required this.sourceId,
    required this.apn,
    this.houseNumber,
    this.streetName = '',
    this.streetType = '',
    this.unit = '',
    this.city = '',
    this.zipCode = '',
  });

  /// Describes [address] as published by the county named by [countyId].
  factory OwnerQuery.fromAddress(Address address, {required String countyId}) {
    return OwnerQuery(
      countyId: countyId,
      subject: OwnerQuerySubject.address,
      sourceId: address.sourceId,
      apn: address.apn,
      houseNumber: address.houseNumber,
      streetName: address.streetName,
      streetType: address.streetType,
      unit: address.unit,
      city: address.city,
      zipCode: address.zipCode,
    );
  }

  /// Describes [parcel] as published by the county named by [countyId].
  ///
  /// Parcel layers publish a single situs string rather than split house
  /// number and street components, so a parcel lookup is answered by its
  /// parcel number and the street fields stay empty.
  factory OwnerQuery.fromParcel(Parcel parcel, {required String countyId}) {
    return OwnerQuery(
      countyId: countyId,
      subject: OwnerQuerySubject.parcel,
      sourceId: parcel.sourceId,
      apn: parcel.apn,
      city: parcel.city,
      zipCode: parcel.zipCode,
    );
  }

  /// Identifier of the county whose source answers this request.
  final String countyId;

  /// Whether an address point or a parcel polygon was selected.
  final OwnerQuerySubject subject;

  /// The county's own identifier for the selected feature.
  final int sourceId;

  /// The assessor parcel number exactly as the GIS layer published it.
  final String apn;

  /// The numeric house component, when the county published one.
  final int? houseNumber;

  /// The street name component.
  final String streetName;

  /// The street type or suffix.
  final String streetType;

  /// The unit or suite component.
  final String unit;

  /// The situs city.
  final String city;

  /// The ZIP code.
  final String zipCode;

  /// The parcel number reduced to uppercase letters and digits for comparison and cache keys.
  String get normalizedApn => normalizeApn(apn);

  /// Whether enough street components are present to search by address.
  bool get hasStreetAddress =>
      houseNumber != null && streetName.trim().isNotEmpty;

  /// Stable cache key for this property, shared by both lookup subjects.
  ///
  /// A parcel number identifies the same property whichever feature the user
  /// clicked, so selecting an address and then its parcel reuses one saved
  /// result. Counties without a published parcel number fall back to their own
  /// feature identifier, which only ever matches the same subject.
  ///
  /// The format is part of the on-disk cache contract. Changing it orphans
  /// every row already saved in an installed database; schema 6 rewrites what
  /// was saved under the older California-only form.
  ///
  /// The state is no longer a separate segment because [countyId] carries it:
  /// `ca_riverside` says California where the old `ca:riverside` said it
  /// twice, and a Texas county could not have been spelled at all.
  String get cacheKey {
    final apn = normalizedApn;
    if (apn.isNotEmpty) {
      return 'us:$countyId:apn:$apn';
    }
    return 'us:$countyId:${subject.name}:$sourceId';
  }
}
