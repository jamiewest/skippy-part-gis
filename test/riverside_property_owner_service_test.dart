import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/riverside_property_owner_service.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';

void main() {
  const address = Address(
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

  test(
    'searches by address and returns owner from an exact situs match',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
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
          '<h2><b>Current Owner: </b><br/>MISSION INN &amp; RIVERSIDE</h2>',
          200,
        );
      });

      final result = await RiversidePropertyOwnerService(
        client,
      ).lookupByAddress(_queryFor(address));

      expect(result?.ownerName, 'MISSION INN & RIVERSIDE');
      expect(result?.parcelId, '213191035');
      expect(requests, hasLength(2));
      expect(
        requests.first.url.queryParameters['keywords'],
        'Situsstreetnumber:3641 Situsstreetname:6TH',
      );
      expect(requests.last.url.path, '/AccountSearch/AccountSummary.aspx');
      expect(requests.last.url.queryParameters['p'], '213191035');
    },
  );

  test('does not request owner details for an inexact city match', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'fields': {
                'AlternateKey': 999,
                'Effstatus': 'A',
                'ParcelID': '999',
                'Situs': '3641 6TH ST CORONA CA 92501',
              },
            },
          ],
          'total': 1,
        }),
        200,
      );
    });

    final result = await RiversidePropertyOwnerService(
      client,
    ).lookupByAddress(_queryFor(address));

    expect(result, isNull);
    expect(requestCount, 1);
  });

  test('parses whitespace and encoded characters in current owner', () {
    final result = RiversidePropertyOwnerService.parseOwnerName(
      '<h2><b> Current Owner: </b><br />'
      '  A &amp; B &#x54;RUST  </h2>',
    );

    expect(result, 'A & B TRUST');
  });

  test('searches a selected parcel by its normalized PIN', () async {
    final requestedKeywords = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/GetData')) {
        requestedKeywords.add(request.url.queryParameters['keywords']);
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
          }),
          200,
        );
      }
      return http.Response(
        '<h2><b>Current Owner: </b><br/>MISSION INN RIVERSIDE</h2>',
        200,
      );
    });
    final parcel = Parcel(
      sourceId: 1819,
      apn: '213-191-035',
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

    final result = await RiversidePropertyOwnerService(
      client,
    ).lookupByApn(OwnerQuery.fromParcel(parcel, countyId: riversideCountyId));

    expect(result?.ownerName, 'MISSION INN RIVERSIDE');
    expect(requestedKeywords, ['ParcelID:213191035']);
  });
}

OwnerQuery _queryFor(Address address) =>
    OwnerQuery.fromAddress(address, countyId: riversideCountyId);
