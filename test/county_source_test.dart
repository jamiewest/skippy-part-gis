import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

void main() {
  const valleyBounds = GeoBounds(
    west: -117.30,
    south: 34.10,
    east: -117.28,
    north: 34.12,
  );

  ArcGisService sanBernardinoService(MockClient client) =>
      ArcGisService(client, county: CountySources.sanBernardino);

  test('defaults to Riverside County when no county is supplied', () {
    final service = ArcGisService(
      MockClient((_) async => http.Response('', 200)),
    );

    check(service.source.id).equals(riversideCountyId);
  });

  test('reads the San Bernardino polygon from the counties layer', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {'County': 'San Bernardino', 'FIPS': '071'},
              'geometry': {
                'rings': [
                  [
                    [-117.80, 33.87],
                    [-114.13, 33.87],
                    [-114.13, 35.81],
                    [-117.80, 35.81],
                    [-117.80, 33.87],
                  ],
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final boundary = await sanBernardinoService(client).fetchCountyBoundary();

    check(captured.url.path).endsWith('/CA_Counties/FeatureServer/0/query');
    check(captured.bodyFields['where']!).equals("FIPS='071'");
    check(boundary.name).equals('San Bernardino');
    check(boundary.fips).equals('071');
    check(boundary.bounds.north).isCloseTo(35.81, 0.001);
  });

  test('searches San Bernardino addresses on its full-address field', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {
                'OBJECTID': 36,
                'ADDRNUM': '872',
                'UNITTYPE': 'UNIT',
                'UNITID': '304',
                'FULLNAME': 'N Arrowhead Ave',
                'FULLADDR': '872 N Arrowhead Ave Unit 304',
                'MUNICIPALITY': 'San Bernardino',
                'POINTTYPE': null,
                'ROV_ZIPC': '92401',
                'PRCLNUM': ' ',
                'LAST_EDITED_DATE': 1765833295000,
              },
              'geometry': {'x': -117.29001, 'y': 34.11523},
            },
          ],
        }),
        200,
      );
    });

    final results = await sanBernardinoService(
      client,
    ).searchAddresses('872 n arrowhead');

    check(captured.url.host).equals('maps.sbcounty.gov');
    check(
      captured.bodyFields['where']!,
    ).equals("UPPER(FULLADDR) LIKE '872 N ARROWHEAD%'");
    check(captured.bodyFields['orderByFields']!).equals('FULLADDR ASC');
    check(results).length.equals(1);
    final address = results.single;
    check(address.fullAddress).equals('872 N Arrowhead Ave Unit 304');
    check(address.houseNumber).equals(872);
    check(address.streetName).equals('N Arrowhead Ave');
    check(address.streetType).equals('');
    check(address.unit).equals('UNIT 304');
    check(address.city).equals('San Bernardino');
    check(address.zipCode).equals('92401');
    check(address.addressType).equals('');
    check(address.numberOfUnits).equals(0);
    check(address.position.latitude).isCloseTo(34.11523, 0.00001);
  });

  test('identifies San Bernardino addresses by their object ID', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {
                'OBJECTID': 36,
                'SITEADDID': 'SID-38',
                'FULLADDR': '872 N Arrowhead Ave',
                'PRCLNUM': '013603128',
              },
              'geometry': {'x': -117.29, 'y': 34.11},
            },
          ],
        }),
        200,
      );
    });

    final addresses = await sanBernardinoService(
      client,
    ).fetchAddressesInBounds(valleyBounds);

    check(addresses.single.sourceId).equals(36);
    check(addresses.single.objectId).equals(36);
    check(addresses.single.apn).equals('013603128');
  });

  test('maps San Bernardino parcels without situs or ZIP fields', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {
                'OBJECTID': 387939,
                'ParcelNumber': '013607109',
                'Jurisdiction': 'City of San Bernardino',
                'AssessDescription': 'SFR',
                'Acreage': 0.14,
              },
              'geometry': {
                'rings': [
                  [
                    [-117.29, 34.11],
                    [-117.28, 34.11],
                    [-117.28, 34.12],
                    [-117.29, 34.12],
                    [-117.29, 34.11],
                  ],
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final parcels = await sanBernardinoService(
      client,
    ).fetchParcelsInBounds(valleyBounds);

    check(captured.url.host).equals('services.arcgis.com');
    check(captured.bodyFields['where']!).equals('1=1');
    check(parcels).length.equals(1);
    final parcel = parcels.single;
    check(parcel.sourceId).equals(387939);
    check(parcel.apn).equals('013607109');
    check(parcel.city).equals('City of San Bernardino');
    check(parcel.landUse).equals('SFR');
    check(parcel.acreage).isNotNull().isCloseTo(0.14, 0.0001);
    check(parcel.situsAddress).equals('');
    check(parcel.zipCode).equals('');
    check(parcel.rings).length.equals(1);
  });

  test('never requests the redacted San Bernardino owner name', () {
    check(
      CountySources.sanBernardino.parcelFields,
    ).not((it) => it.contains('OwnerName'));
  });

  test('scopes each configured county to its own snapshot identifier', () {
    check(CountySources.all).length.equals(58);
    check(CountySources.byId(sanBernardinoCountyId)).isNotNull();
    check(
      CountySources.all.map((source) => source.id).toSet(),
    ).length.equals(58);
  });

  test('keeps the two shipped county identifiers verbatim', () {
    // County ids scope offline snapshots and cached owner lookups on disk, so
    // renaming one orphans every row already saved under the old name.
    check(CountySources.riverside.id).equals('riverside');
    check(CountySources.sanBernardino.id).equals('san_bernardino');
  });

  test('gives every California county a source and a distinct FIPS', () {
    check(
      CountySources.all.map((source) => source.fips).toSet(),
    ).length.equals(58);
    for (final source in CountySources.all) {
      check(source.fips, because: source.id).startsWith('06');
      check(source.fips.length, because: source.id).equals(5);
    }
  });

  test('reads counties without their own service through the state layer', () {
    final losAngeles = CountySources.byId('los_angeles')!;

    check(losAngeles.displayName).equals('Los Angeles County');
    check(losAngeles.isStatewideSourced).isTrue();
    check(losAngeles.countyFilter).equals("FIPS_CODE='06037'");
    check(losAngeles.boundaryFilter).equals("FIPS='037'");
    check(losAngeles.imageryCatalog).isNull();
    check(losAngeles.ownerSource).isNull();
    // The address layer is the parcel layer read through its centroids.
    check(losAngeles.addressQuery).equals(losAngeles.parcelQuery);
    check(losAngeles.addressQueryParameters['returnCentroid']).equals('true');
    check(losAngeles.uppercaseAddressSearch).isFalse();
  });

  test('keeps the counties with their own services off the state layer', () {
    check(CountySources.riverside.isStatewideSourced).isFalse();
    check(CountySources.sanBernardino.isStatewideSourced).isFalse();
    check(CountySources.riverside.countyFilter).equals('1=1');
  });
}
