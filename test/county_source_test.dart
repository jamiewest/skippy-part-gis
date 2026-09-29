import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

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
              'attributes': {'NAME': 'San Bernardino County', 'GEOID': '06071'},
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

    // Every county in the country reads its outline from the one Census
    // layer that publishes them all, keyed on the five-digit FIPS code. A
    // three-digit county code would name a different county in each state.
    check(
      captured.url.path,
    ).endsWith('/TIGERweb/State_County/MapServer/1/query');
    check(captured.bodyFields['where']!).equals("GEOID='06071'");
    check(boundary.name).equals('San Bernardino County');
    check(boundary.fips).equals('06071');
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
      CountySources.sanBernardino.layers!.parcelFields.contains('OwnerName'),
    ).isFalse();
  });

  test('scopes each configured county to its own snapshot identifier', () {
    check(_california).length.equals(58);
    check(CountySources.byId(sanBernardinoCountyId)).isNotNull();
    check(_california.map((source) => source.id).toSet()).length.equals(58);
  });

  test('keeps the two shipped county identifiers verbatim', () {
    // County ids scope offline snapshots and cached owner lookups on disk, so
    // renaming one orphans every row already saved under the old name. These
    // gained their `ca_` prefix when the application went national; schema 6
    // rewrites what an install already had.
    check(CountySources.riverside.id).equals('ca_riverside');
    check(CountySources.sanBernardino.id).equals('ca_san_bernardino');
  });

  test('gives every California county a source and a distinct FIPS', () {
    check(_california.map((source) => source.fips).toSet()).length.equals(58);
    for (final source in _california) {
      check(source.fips, because: source.id).startsWith('06');
      check(source.fips.length, because: source.id).equals(5);
    }
  });

  test('covers every county in the country with a boundary at least', () {
    // A county outside a state with a parcel fabric still gets its outline,
    // its catalogues and the national overlay tiers -- what it does not get
    // is a parcel query that could only ever answer nothing.
    final harris = CountySources.byFips('48201')!;

    check(harris.displayName).equals('Harris County, TX');
    check(harris.hasParcelCoverage).isFalse();
    check(harris.layers).isNull();
    check(harris.isStatewideSourced).isFalse();
    check(harris.boundaryFilter).equals("GEOID='48201'");
    check(harris.effectiveBoundaryQuery).equals(CountySources.usCountiesQuery);
    // The national tier is what stops the layer panel opening empty.
    check(harris.portals).isNotEmpty();
  });

  test('tells two counties of the same name in different states apart', () {
    final california = CountySources.byId('ca_riverside')!;
    final montana = CountySources.byFips('30075')!;

    check(montana.displayName).endsWith(', MT');
    check(california.id).not((it) => it.equals(montana.id));
    check(california.fips).not((it) => it.equals(montana.fips));
  });

  test('reads counties without their own service through the state layer', () {
    final losAngeles = CountySources.byId('ca_los_angeles')!;
    final layers = losAngeles.layers!;

    check(losAngeles.displayName).equals('Los Angeles County, CA');
    check(losAngeles.isStatewideSourced).isTrue();
    check(losAngeles.hasParcelCoverage).isTrue();
    check(layers.countyFilter).equals("FIPS_CODE='06037'");
    check(losAngeles.boundaryFilter).equals("GEOID='06037'");
    check(losAngeles.imageryCatalog).isNull();
    check(losAngeles.ownerSource).isNull();
    // The address layer is the parcel layer read through its centroids.
    check(layers.addressQuery).equals(layers.parcelQuery);
    check(layers.addressQueryParameters['returnCentroid']).equals('true');
    check(layers.uppercaseAddressSearch).isFalse();
  });

  test('keeps the counties with their own services off the state layer', () {
    check(CountySources.riverside.isStatewideSourced).isFalse();
    check(CountySources.sanBernardino.isStatewideSourced).isFalse();
    check(CountySources.riverside.layers!.countyFilter).equals('1=1');
  });

  test(
    'every generated city catalogue is well-formed and inside its county',
    () {
      var cities = 0;
      for (final source in _california) {
        for (final city in source.cities) {
          cities++;
          check(city.portals, because: city.name).isNotEmpty();
          for (final portal in city.portals) {
            check(portal.tier, because: portal.root).equals(PortalTier.city);
            // https wherever the server offers it; a handful of city servers
            // are still genuinely cleartext-only, and Dart's own client (not
            // ATS) is what reads them, so http is tolerated rather than lost.
            final uri = Uri.parse(portal.root);
            check(
              uri.isScheme('https') || uri.isScheme('http'),
              because: portal.root,
            ).isTrue();
            check(uri.host, because: portal.root).isNotEmpty();
          }
          // The city rectangle must overlap its county's, or the catalogue
          // could never light up. Overlap rather than containment: a city
          // boundary can nick past the county extent by a rounding margin.
          check(
            city.bounds.intersects(source.extent),
            because: '${city.name} in ${source.id}',
          ).isTrue();
        }
      }
      check(cities).isGreaterThan(100);
    },
  );

  test('city portals never repeat a county or statewide root', () {
    final registered = {
      for (final source in _california)
        for (final portal in source.portals) portal.root.toLowerCase(),
    };
    for (final source in _california) {
      for (final city in source.cities) {
        for (final portal in city.portals) {
          check(
            registered,
            because: '${city.name}: ${portal.root}',
          ).not((it) => it.contains(portal.root.toLowerCase()));
        }
      }
    }
  });
}

/// Every California county as a configured source.
///
/// The application no longer builds all 3,235 counties eagerly -- a session
/// reads one -- so the tests that assert something about a whole state build
/// that state's slice themselves.
final _california = [
  for (final county in UsGeography.countiesIn('06'))
    CountySources.forCounty(county),
];
