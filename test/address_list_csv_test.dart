import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/ui/features/map/address_list_csv.dart';

void main() {
  test('writes a header and one row per address', () {
    final csv = addressListCsv(
      addresses: [_address(fullAddress: '3641 6TH ST')],
      countyName: 'Riverside County',
    );

    final lines = csv.trim().split('\n');
    check(lines).length.equals(2);
    check(
      lines.first,
    ).equals('address,unit,city,state,zip,apn,units,latitude,longitude,county');
    check(lines.last).equals(
      '3641 6TH ST,,RIVERSIDE,CA,92501,213191035,1,33.983700,-117.372300,'
      'Riverside County',
    );
  });

  test('exports an empty area as a header alone', () {
    final csv = addressListCsv(addresses: const [], countyName: 'Example');

    check(csv.trim().split('\n')).length.equals(1);
  });

  test('quotes a field holding a comma or a quote', () {
    check(csvField('123 MAIN ST, APT 2')).equals('"123 MAIN ST, APT 2"');
    check(csvField('THE "OLD" MILL RD')).equals('"THE ""OLD"" MILL RD"');
    check(csvField('LINE\nBREAK')).equals('"LINE\nBREAK"');
    check(csvField('3641 6TH ST')).equals('3641 6TH ST');
  });

  test('keeps a comma inside a field from shifting the row', () {
    final csv = addressListCsv(
      addresses: [_address(fullAddress: '1 A ST, REAR')],
      countyName: 'Example',
    );

    check(csv).contains('"1 A ST, REAR",,RIVERSIDE,CA');
  });

  test('names the file after the county and the moment it was taken', () {
    final name = addressListFileName(
      countyName: 'San Bernardino County',
      timestamp: DateTime(2026, 8, 24, 9, 5, 3),
    );

    check(name).equals('san-bernardino-county-addresses-20260824-090503.csv');
  });
}

Address _address({required String fullAddress}) {
  return Address(
    objectId: 1,
    sourceId: 16055,
    fullAddress: fullAddress,
    houseNumber: 3641,
    streetName: '6TH',
    streetType: 'ST',
    unit: '',
    city: 'RIVERSIDE',
    zipCode: '92501',
    apn: '213191035',
    addressType: '6',
    numberOfUnits: 1,
    position: const LatLng(33.9837, -117.3723),
  );
}
