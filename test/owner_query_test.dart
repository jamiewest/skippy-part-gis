import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';

void main() {
  group('OwnerQuery cache keys', () {
    test('keeps the exact format already written to installed databases', () {
      final fromAddress = OwnerQuery.fromAddress(
        _address,
        countyId: riversideCountyId,
      );
      final fromParcel = OwnerQuery.fromParcel(
        _parcel,
        countyId: riversideCountyId,
      );

      expect(fromAddress.cacheKey, 'us:ca_riverside:apn:213191035');
      expect(fromParcel.cacheKey, 'us:ca_riverside:apn:213191035');
    });

    test('falls back to the county feature id per subject', () {
      final address = OwnerQuery.fromAddress(
        _addressWithoutApn,
        countyId: riversideCountyId,
      );
      final parcel = OwnerQuery.fromParcel(
        _parcelWithoutApn,
        countyId: riversideCountyId,
      );

      expect(address.cacheKey, 'us:ca_riverside:address:16055');
      expect(parcel.cacheKey, 'us:ca_riverside:parcel:1819');
    });

    test('ignores parcel-number punctuation', () {
      final dashed = OwnerQuery.fromParcel(
        _dashedParcel,
        countyId: riversideCountyId,
      );

      expect(dashed.cacheKey, 'us:ca_riverside:apn:213191035');
    });

    test('scopes saved results to one county', () {
      final riverside = OwnerQuery.fromAddress(
        _address,
        countyId: riversideCountyId,
      );
      final sanBernardino = OwnerQuery.fromAddress(
        _address,
        countyId: sanBernardinoCountyId,
      );

      expect(sanBernardino.cacheKey, 'us:ca_san_bernardino:apn:213191035');
      expect(sanBernardino.cacheKey, isNot(riverside.cacheKey));
    });
  });

  test('reports whether a street search is possible', () {
    expect(
      OwnerQuery.fromAddress(
        _address,
        countyId: riversideCountyId,
      ).hasStreetAddress,
      isTrue,
    );
    expect(
      OwnerQuery.fromParcel(
        _parcel,
        countyId: riversideCountyId,
      ).hasStreetAddress,
      isFalse,
    );
  });
}

const _address = Address(
  objectId: 42,
  sourceId: 16055,
  fullAddress: '3641 6TH ST',
  houseNumber: 3641,
  streetName: '6TH',
  streetType: 'ST',
  unit: '',
  city: 'RIVERSIDE',
  zipCode: '92501',
  apn: '213191035',
  addressType: '6',
  numberOfUnits: 1,
  position: LatLng(33.9837, -117.3723),
);

const _addressWithoutApn = Address(
  objectId: 42,
  sourceId: 16055,
  fullAddress: '3641 6TH ST',
  houseNumber: 3641,
  streetName: '6TH',
  streetType: 'ST',
  unit: '',
  city: 'RIVERSIDE',
  zipCode: '92501',
  apn: '',
  addressType: '6',
  numberOfUnits: 1,
  position: LatLng(33.9837, -117.3723),
);

final _parcel = _parcelWith('213191035');
final _dashedParcel = _parcelWith('213-191-035');
final _parcelWithoutApn = _parcelWith('');

Parcel _parcelWith(String apn) => Parcel(
  sourceId: 1819,
  apn: apn,
  situsAddress: '3641 6TH ST',
  city: 'RIVERSIDE',
  zipCode: '92501',
  landUse: 'Commercial',
  acreage: 0.18,
  rings: const [
    [
      LatLng(33.9836, -117.3724),
      LatLng(33.9838, -117.3724),
      LatLng(33.9838, -117.3722),
      LatLng(33.9836, -117.3722),
      LatLng(33.9836, -117.3724),
    ],
  ],
);
