import 'package:checks/checks.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';

void main() {
  test('indexes active snapshot addresses and parcels', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = LocalGisStore(database);
    final snapshotId = await store.beginOrResumeSnapshot();

    await store.insertAddresses(snapshotId, const [
      Address(
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
      ),
    ]);
    await store.insertParcels(snapshotId, [
      Parcel(
        sourceId: 1819,
        apn: '213191035',
        situsAddress: '3641 6TH ST',
        city: 'RIVERSIDE',
        zipCode: '92501',
        landUse: 'Single Family Residence',
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
      ),
    ]);
    await store.activate(snapshotId, addressCount: 1, parcelCount: 1);

    final searchResults = await store.searchAddresses('3641 6TH');
    final addresses = await store.addressesInBounds(
      const GeoBounds(west: -117.38, south: 33.98, east: -117.37, north: 33.99),
    );
    final parcels = await store.parcelsInBounds(
      const GeoBounds(west: -117.38, south: 33.98, east: -117.37, north: 33.99),
    );

    check(searchResults).length.equals(1);
    check(searchResults.single.fullAddress).equals('3641 6TH ST');
    check(addresses).length.equals(1);
    check(parcels).length.equals(1);
    check(parcels.single.apn).equals('213191035');
  });

  test('stores San Bernardino rows that reuse one identifier', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = LocalGisStore(database, countyId: sanBernardinoCountyId);
    final snapshotId = await store.beginOrResumeSnapshot();

    await store.insertAddresses(snapshotId, const [
      Address(
        objectId: 36,
        sourceId: 36,
        fullAddress: '872 N Arrowhead Ave Unit 304',
        houseNumber: 872,
        streetName: 'N Arrowhead Ave',
        streetType: '',
        unit: 'UNIT 304',
        city: 'San Bernardino',
        zipCode: '92401',
        apn: '',
        addressType: '',
        numberOfUnits: 0,
        position: LatLng(34.11523, -117.29001),
      ),
      Address(
        objectId: 41,
        sourceId: 41,
        fullAddress: '359 W 8th St Unit E',
        houseNumber: 359,
        streetName: 'W 8th St',
        streetType: '',
        unit: 'UNIT E',
        city: 'San Bernardino',
        zipCode: '92401',
        apn: '',
        addressType: '',
        numberOfUnits: 0,
        position: LatLng(34.11328, -117.29103),
      ),
    ]);

    check(
      await store.existingAddressObjectIds(snapshotId),
    ).deepEquals({36, 41});
  });

  test('keeps each county snapshot separate in one database', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final riverside = LocalGisStore(database);
    final sanBernardino = LocalGisStore(
      database,
      countyId: sanBernardinoCountyId,
    );

    final riversideId = await riverside.beginOrResumeSnapshot();
    await riverside.insertAddresses(riversideId, const [
      Address(
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
      ),
    ]);
    await riverside.activate(riversideId, addressCount: 1, parcelCount: 0);

    final sanBernardinoId = await sanBernardino.beginOrResumeSnapshot();
    await sanBernardino.insertAddresses(sanBernardinoId, const [
      Address(
        objectId: 36,
        sourceId: 36,
        fullAddress: '872 N Arrowhead Ave',
        houseNumber: 872,
        streetName: 'N Arrowhead Ave',
        streetType: '',
        unit: '',
        city: 'San Bernardino',
        zipCode: '92401',
        apn: '013603128',
        addressType: '',
        numberOfUnits: 0,
        position: LatLng(34.11523, -117.29001),
      ),
    ]);
    await sanBernardino.activate(
      sanBernardinoId,
      addressCount: 1,
      parcelCount: 0,
    );

    check(sanBernardinoId).not((it) => it.equals(riversideId));
    final riversideResults = await riverside.searchAddresses('3641 6TH');
    final crossCounty = await sanBernardino.searchAddresses('3641 6TH');
    final sanBernardinoResults = await sanBernardino.searchAddresses(
      '872 N ARROWHEAD',
    );

    check(riversideResults).length.equals(1);
    check(crossCounty).isEmpty();
    check(sanBernardinoResults).length.equals(1);
    check(sanBernardinoResults.single.city).equals('San Bernardino');
    check((await riverside.status()).addressCount).equals(1);
    check((await sanBernardino.status()).addressCount).equals(1);
  });
}
