import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/repositories/gis_repository_implementations.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/property_owner_cache_store.dart';
import 'package:riverside_atlas/data/services/riverside_property_owner_service.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';

void main() {
  group('CachedPropertyOwnerRepository', () {
    test('reuses the saved APN record for an address and parcel', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      var requestCount = 0;
      final liveClient = MockClient((request) async {
        requestCount++;
        if (request.url.path.endsWith('/GetData')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'fields': {
                    'AlternateKey': 213191035,
                    'Effstatus': 'A',
                    'ParcelID': '213191035',
                    'Situs': '3641 6TH ST RIVERSIDE CA 92501',
                  },
                },
              ],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response(
          '<h2><b>Current Owner: </b><br/>MISSION INN RIVERSIDE</h2>',
          200,
        );
      });
      final firstRepository = CachedPropertyOwnerRepository(
        countyId: riversideCountyId,
        service: RiversidePropertyOwnerService(liveClient),
        cache: PropertyOwnerCacheStore(database),
      );

      final first = await firstRepository.lookupAddress(_address);
      expect(first?.ownerName, 'MISSION INN RIVERSIDE');
      expect(requestCount, 2);

      final offlineClient = MockClient((_) {
        fail('A fresh saved record must not make another HTTP request.');
      });
      final reconstructedRepository = CachedPropertyOwnerRepository(
        countyId: riversideCountyId,
        service: RiversidePropertyOwnerService(offlineClient),
        cache: PropertyOwnerCacheStore(database),
      );
      final second = await reconstructedRepository.lookupParcel(_parcel);

      expect(second?.ownerName, 'MISSION INN RIVERSIDE');
      expect(second?.isSaved, isTrue);
      expect(requestCount, 2);
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
