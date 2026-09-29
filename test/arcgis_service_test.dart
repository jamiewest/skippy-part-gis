import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

void main() {
  const desertBounds = GeoBounds(
    west: -116.6,
    south: 33.6,
    east: -116.2,
    north: 33.9,
  );

  test('reads the Riverside County polygon from the counties layer', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {'NAME': 'Riverside County', 'GEOID': '06065'},
              'geometry': {
                'rings': [
                  [
                    [-117.67, 33.42],
                    [-114.43, 33.42],
                    [-114.43, 34.08],
                    [-117.67, 34.08],
                    [-117.67, 33.42],
                  ],
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final boundary = await ArcGisService(client).fetchCountyBoundary();

    check(
      captured.url.path,
    ).endsWith('/TIGERweb/State_County/MapServer/1/query');
    check(captured.bodyFields['where']!).equals("GEOID='06065'");
    check(captured.bodyFields['outFields']!).equals('NAME,GEOID');
    check(boundary.name).equals('Riverside County');
    check(boundary.fips).equals('06065');
    check(boundary.bounds.west).isCloseTo(-117.67, 0.001);
    check(boundary.bounds.east).isCloseTo(-114.43, 0.001);
  });

  test('searches addresses across the county, incorporated or not', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {
                'OBJECTID': 1,
                'ADDRESS_ID': 900001,
                'ADDRESS': '37995 HIGHWAY 78',
                'HOUSE_NUMBER': 37995,
                'STREET_NAME': 'HIGHWAY 78',
                'STREET_TYPE': '',
                'UNIT': '',
                'CITY': 'BLYTHE',
                'ZIP': '92225',
                'APN': '879070001',
                'ADDRESS_TYPE': '6',
                'NUMBER_OF_UNITS': 1,
              },
              'geometry': {'x': -114.65, 'y': 33.63},
            },
          ],
        }),
        200,
      );
    });

    final results = await ArcGisService(client).searchAddresses('37995 high');

    check(
      captured.bodyFields['where']!,
    ).equals("UPPER(ADDRESS) LIKE '37995 HIGH%'");
    check(
      captured.bodyFields['where']!,
    ).not((it) => it.contains('INCORPORATED'));
    check(results).length.equals(1);
    check(results.single.city).equals('BLYTHE');
  });

  test('keeps every parcel the county returns for a viewport', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'features': [
            {
              'attributes': {
                'OBJECTID': 71,
                'APN': '609260012',
                'SITUS_STREET': '73510 FRED WARING DR',
                'CITY': 'PALM DESERT',
                'ZIP_CODE': '92260',
                'CLASS_CODE': 'Commercial',
                'ACREAGE': 1.4,
              },
              'geometry': {
                'rings': [
                  [
                    [-116.38, 33.72],
                    [-116.37, 33.72],
                    [-116.37, 33.73],
                    [-116.38, 33.73],
                    [-116.38, 33.72],
                  ],
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final parcels = await ArcGisService(
      client,
    ).fetchParcelsInBounds(desertBounds);

    check(captured.bodyFields['where']!).equals('1=1');
    check(parcels).length.equals(1);
    check(parcels.single.city).equals('PALM DESERT');
  });

  test('scopes snapshot object IDs to an envelope', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'objectIds': [7, 3, 5],
        }),
        200,
      );
    });

    final objectIds = await ArcGisService(
      client,
    ).fetchAddressObjectIds(desertBounds);

    check(captured.bodyFields['geometryType']!).equals('esriGeometryEnvelope');
    check(captured.bodyFields['geometry']!).equals('-116.6,33.6,-116.2,33.9');
    check(objectIds).deepEquals([3, 5, 7]);
  });
}
