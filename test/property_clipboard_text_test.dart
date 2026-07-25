import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/ui/features/map/property_clipboard_text.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

void main() {
  group('propertyLocationLine', () {
    test('joins a published city and ZIP code', () {
      expect(
        propertyLocationLine(city: 'RIVERSIDE', zipCode: '92501'),
        'RIVERSIDE, CA 92501',
      );
    });

    test('leaves out a ZIP code the county does not publish', () {
      expect(
        propertyLocationLine(city: 'HESPERIA', zipCode: ''),
        'HESPERIA, CA',
      );
    });

    test('leaves out a missing city', () {
      expect(propertyLocationLine(city: '', zipCode: '92501'), 'CA 92501');
    });

    test('is empty when neither part exists', () {
      expect(propertyLocationLine(city: '', zipCode: ''), isEmpty);
    });
  });

  group('propertyClipboardText', () {
    test('returns null with nothing selected', () {
      expect(
        propertyClipboardText(
          countyName: 'Riverside County',
          address: null,
          parcel: null,
          ownership: null,
          ownerLookupStatus: OwnerLookupStatus.idle,
          unclaimedProperty: null,
        ),
        isNull,
      );
    });

    test('writes every published address field', () {
      expect(
        propertyClipboardText(
          countyName: 'Riverside County',
          address: _address,
          parcel: null,
          ownership: _ownership,
          ownerLookupStatus: OwnerLookupStatus.found,
          unclaimedProperty: null,
        ),
        'ADDRESS: 3641 6TH ST\n'
        'LOCATION: RIVERSIDE, CA 92501\n'
        'APN: 213191035\n'
        'OWNER: MISSION INN RIVERSIDE\n'
        'ADDRESS TYPE: County code 6\n'
        'UNITS: 1\n'
        'SOURCE: Riverside County Address Points',
      );
    });

    test('writes every published parcel field', () {
      expect(
        propertyClipboardText(
          countyName: 'Riverside County',
          address: null,
          parcel: _parcel,
          ownership: _ownership,
          ownerLookupStatus: OwnerLookupStatus.found,
          unclaimedProperty: null,
        ),
        'ADDRESS: 3641 6TH ST\n'
        'LOCATION: RIVERSIDE, CA 92501\n'
        'APN: 213191035\n'
        'OWNER: MISSION INN RIVERSIDE\n'
        'LAND USE: Commercial\n'
        'ACREAGE: 0.18\n'
        'SOURCE: Riverside County Assessor',
      );
    });

    test('omits the fields San Bernardino County does not publish', () {
      final parcel = Parcel(
        sourceId: 4471,
        apn: '0405121030000',
        situsAddress: '',
        city: 'HESPERIA',
        zipCode: '',
        landUse: 'Single Family Residential',
        acreage: null,
        rings: _parcel.rings,
      );

      expect(
        propertyClipboardText(
          countyName: 'San Bernardino County',
          address: null,
          parcel: parcel,
          ownership: null,
          ownerLookupStatus: OwnerLookupStatus.unavailable,
          unclaimedProperty: null,
        ),
        'LOCATION: HESPERIA, CA\n'
        'APN: 0405121030000\n'
        'LAND USE: Single Family Residential\n'
        'SOURCE: San Bernardino County Assessor',
      );
    });

    test('reports a saved unclaimed-property check alongside the owner', () {
      final text = propertyClipboardText(
        countyName: 'Riverside County',
        address: _address,
        parcel: null,
        ownership: _ownership,
        ownerLookupStatus: OwnerLookupStatus.found,
        unclaimedProperty: UnclaimedPropertySearchResult(
          query: UnclaimedPropertyQuery.fromOwner(
            ownerName: 'MISSION INN RIVERSIDE',
            city: 'RIVERSIDE',
            zipCode: '92501',
          ),
          found: true,
          resultCount: 2,
          checkedAt: DateTime(2026, 7, 24),
          sourceUri: Uri.parse('https://claimit.ca.gov/'),
        ),
      );

      expect(
        text,
        contains(
          'UNCLAIMED: Possible match • 2 records returned • exact owner '
          'match reported • California ClaimIt checked 2026-07-24',
        ),
      );
    });

    test('omits an owner whose lookup has not finished', () {
      final text = propertyClipboardText(
        countyName: 'Riverside County',
        address: _address,
        parcel: null,
        ownership: _ownership,
        ownerLookupStatus: OwnerLookupStatus.loading,
        unclaimedProperty: null,
      );

      expect(text, isNot(contains('OWNER')));
    });
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

final _parcel = Parcel(
  sourceId: 1819,
  apn: '213191035',
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

final _ownership = PropertyOwnership(
  ownerName: 'MISSION INN RIVERSIDE',
  parcelId: '213191035',
  matchedAddress: '3641 6TH ST RIVERSIDE CA 92501',
  sourceUri: Uri.parse('https://example.com/parcel/213191035'),
  checkedAt: DateTime.utc(2026, 7, 24),
);
