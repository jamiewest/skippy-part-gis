import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/statewide_parcel_source.dart';
import 'package:riverside_atlas/data/services/statewide_situs_service.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';

void main() {
  const bounds = GeoBounds(
    west: -117.41,
    south: 34.08,
    east: -117.39,
    north: 34.1,
  );

  /// A row shaped like the statewide layer's own response, captured live.
  Map<String, Object?> statewideFeature({
    String siteAddress = '535 PIERCE ST APT 3115',
    String? houseNumber = '535',
    String direction = '',
    String streetName = 'PIERCE',
    String mode = 'ST',
    String unitPrefix = 'APT',
    String unitNumber = '3115',
    String city = 'ALBANY',
    String zip = '94706',
  }) => {
    'attributes': {
      'OBJECTID': 2,
      'PARCEL_APN': '66-2763-16',
      'FIPS_CODE': '06001',
      'COUNTYNAME': 'ALAMEDA',
      'SITE_ADDR': siteAddress,
      'SITE_CITY': city,
      'SITE_ZIP': zip,
      'SITE_HOUSE_NUMBER': houseNumber,
      'SITE_DIRECTION': direction,
      'SITE_STREET_NAME': streetName,
      'SITE_MODE': mode,
      'SITE_UNIT_PREFIX': unitPrefix,
      'SITE_UNIT_NUMBER': unitNumber,
    },
    'geometry': {
      'rings': [
        [
          [-117.401, 34.089],
          [-117.399, 34.089],
          [-117.399, 34.091],
          [-117.401, 34.091],
          [-117.401, 34.089],
        ],
      ],
    },
    'centroid': {'x': -117.4001, 'y': 34.0903},
  };

  test('reads a statewide row as an address point at its centroid', () {
    final address = const StatewideAddressMapper().address(statewideFeature());

    check(address.fullAddress).equals('535 PIERCE ST APT 3115');
    check(address.houseNumber).equals(535);
    check(address.streetName).equals('PIERCE');
    check(address.streetType).equals('ST');
    check(
      address.unit,
      because: 'the unit is inside SITE_ADDR already',
    ).equals('');
    check(address.city).equals('ALBANY');
    check(address.zipCode).equals('94706');
    check(address.apn).equals('66-2763-16');
    check(address.position.latitude).isCloseTo(34.0903, 0.0001);
    check(address.position.longitude).isCloseTo(-117.4001, 0.0001);
  });

  test('keeps the unit out of the display address it is already inside', () {
    // `SITE_ADDR` carries the unit, so appending it again would render
    // "535 PIERCE ST APT 3115 Unit APT 3115".
    final address = const StatewideAddressMapper().address(statewideFeature());

    check(
      address.displayAddress,
    ).equals('535 PIERCE ST APT 3115, ALBANY, CA 94706');
  });

  test('joins a prefix direction onto the street name', () {
    final address = const StatewideAddressMapper().address(
      statewideFeature(
        siteAddress: '1364 W RIALTO AVE',
        houseNumber: '1364',
        direction: 'W',
        streetName: 'RIALTO',
        mode: 'AVE',
        unitPrefix: '',
        unitNumber: '',
        city: 'RIALTO',
        zip: '92376',
      ),
    );

    check(address.streetName).equals('W RIALTO');
    check(address.unit).equals('');
    check(address.displayAddress).equals('1364 W RIALTO AVE, RIALTO, CA 92376');
  });

  test('leaves land use and acreage empty rather than deriving them', () {
    final parcel = const StatewideParcelMapper().parcel(statewideFeature());

    check(parcel.apn).equals('66-2763-16');
    check(parcel.situsAddress).equals('535 PIERCE ST APT 3115');
    check(parcel.city).equals('ALBANY');
    check(parcel.zipCode).equals('94706');
    check(parcel.landUse).equals('');
    check(parcel.acreage).isNull();
    check(parcel.rings).length.equals(1);
  });

  test('reports no situs rather than the layer\'s empty placeholder', () {
    // The layer writes ", ,  " into FullStreetAddress for a parcel with no
    // address on record, which must never reach the screen as an address.
    final situs = statewideSitus(
      statewideFeature(siteAddress: '', city: '', zip: ''),
    );

    check(situs).isNull();
  });

  test('assembles a mailable address from a situs row', () {
    final situs = statewideSitus(
      statewideFeature(
        siteAddress: '1364 W RIALTO AVE',
        city: 'RIALTO',
        zip: '92376',
      ),
    )!;

    check(situs.fullAddress).equals('1364 W RIALTO AVE, RIALTO, CA 92376');
    check(situs.countyName).equals('ALAMEDA');
  });

  test('resolves a situs address from a point inside the parcel', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            statewideFeature(
              siteAddress: '300 S CEDAR AVE',
              city: 'RIALTO',
              zip: '92376',
            ),
          ],
        }),
        200,
      );
    });

    final situs = await StatewideSitusService(
      client,
    ).lookupAt(const LatLng(34.0941, -117.3968));

    check(captured.bodyFields['geometryType']!).equals('esriGeometryPoint');
    // Asking for one row drops the layer onto a path measured at 42s against
    // 0.3s for the same query at 250; see StatewideSitusService.
    check(
      int.parse(captured.bodyFields['resultRecordCount']!),
    ).isGreaterOrEqual(200);
    check(
      captured.bodyFields['geometry']!,
    ).equals('{"x":-117.3968,"y":34.0941}');
    check(situs).isNotNull();
    check(situs!.fullAddress).equals('300 S CEDAR AVE, RIALTO, CA 92376');
  });

  test('answers a repeated situs lookup without a second request', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'features': [statewideFeature()],
        }),
        200,
      );
    });
    final service = StatewideSitusService(client);
    const point = LatLng(34.0941, -117.3968);

    await service.lookupAt(point);
    await service.lookupAt(point);

    check(requests).equals(1);
  });

  test('scopes a statewide address search to the selected county', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'features': const []}), 200);
    });
    final losAngeles = CountySources.byId('ca_los_angeles')!;

    await ArcGisService(
      client,
      county: losAngeles,
    ).searchAddresses('1234 w 102');

    check(
      captured.bodyFields['where']!,
    ).equals("FIPS_CODE='06037' AND SITE_ADDR LIKE '1234 W 102%'");
    // Wrapping the column in UPPER() would stop the server using its index and
    // turn a sub-second prefix search into a scan of 13 million rows.
    check(captured.bodyFields['where']!).not((it) => it.contains('UPPER('));
    check(captured.bodyFields['returnCentroid']!).equals('true');
    check(captured.bodyFields['returnGeometry']!).equals('false');
  });

  test('leaves a viewport query unscoped so a pan keeps drawing', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'features': const []}), 200);
    });
    final losAngeles = CountySources.byId('ca_los_angeles')!;

    await ArcGisService(
      client,
      county: losAngeles,
    ).fetchParcelsInBounds(bounds);

    check(captured.bodyFields['where']!).equals('1=1');
    check(captured.bodyFields['maxAllowableOffset']).isNotNull();
  });

  test('generalizes viewport geometry to about one screen pixel', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'features': const []}), 200);
    });

    await ArcGisService(client).fetchParcelsInBounds(bounds);
    final offset = double.parse(captured.bodyFields['maxAllowableOffset']!);

    check(offset).isGreaterThan(0);
    check(offset).isLessThan((bounds.east - bounds.west) / 100);
  });

  test('asks a shared layer for rings and centroids in one page', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [statewideFeature()],
        }),
        200,
      );
    });
    final losAngeles = CountySources.byId('ca_los_angeles')!;

    final page = await ArcGisService(
      client,
      county: losAngeles,
    ).fetchCombinedPage(bounds, offset: 0, limit: 1000);

    check(captured.bodyFields['returnGeometry']!).equals('true');
    check(captured.bodyFields['returnCentroid']!).equals('true');
    check(captured.bodyFields['orderByFields']!).equals('OBJECTID ASC');
    check(page.addresses).length.equals(1);
    check(page.parcels).length.equals(1);
    check(page.parcels.single.rings).length.equals(1);
    check(page.addresses.single.position.latitude).isCloseTo(34.0903, 0.0001);
  });

  test('skips a stacked parcel with no address for one that has it', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'features': [
            statewideFeature(siteAddress: '', city: '', zip: ''),
            statewideFeature(
              siteAddress: '980 9TH ST',
              city: 'SACRAMENTO',
              zip: '95814',
            ),
          ],
        }),
        200,
      );
    });

    final situs = await StatewideSitusService(
      client,
    ).lookupAt(const LatLng(38.5811, -121.4949));

    check(situs).isNotNull();
    check(situs!.streetAddress).equals('980 9TH ST');
  });

  test(
    'asks a spatial query for enough rows to stay on the fast path',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'features': List.filled(300, statewideFeature())}),
          200,
        );
      });

      final parcels = await ArcGisService(
        client,
      ).fetchParcelsInBounds(bounds, limit: 20);

      check(
        int.parse(captured.bodyFields['resultRecordCount']!),
      ).equals(ArcGisService.fastPathRecordCount);
      check(
        parcels,
        because: 'the surplus is discarded, not shown',
      ).length.equals(20);
    },
  );

  test('leaves a large spatial request at the size it asked for', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'features': const []}), 200);
    });

    await ArcGisService(client).fetchParcelsInBounds(bounds, limit: 2000);

    check(captured.bodyFields['resultRecordCount']!).equals('2000');
  });

  test('formats a situs address with no ZIP on record', () {
    const situs = SitusAddress(
      apn: '012806148',
      countyName: 'SAN BERNARDINO',
      streetAddress: '1364 W RIALTO AVE',
      city: 'RIALTO',
      zipCode: '',
    );

    check(situs.fullAddress).equals('1364 W RIALTO AVE, RIALTO, CA');
  });
}
