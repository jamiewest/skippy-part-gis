import 'package:riverside_atlas/domain/models/geo_bounds.dart';
// Opt-in live check: flutter test tool/check_parcel_detection.dart
// --dart-define=PARCEL_COUNTIES=04013 limits it to Maricopa.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/detected_parcel_source.dart';
import 'package:riverside_atlas/data/services/gis_catalog_service.dart';
import 'package:riverside_atlas/data/services/parcel_layer_inspector.dart';
import 'package:riverside_atlas/data/services/portal_discovery_service.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';

void main() {
  const counties = String.fromEnvironment(
    'PARCEL_COUNTIES',
    defaultValue: '04013,48201,53033,27053,37183,39035',
  );
  for (final fips in counties.split(',')) {
    test('live parcel detection $fips', () async {
      final client = http.Client();
      addTearDown(client.close);
      final county = CountySources.byFips(fips)!;
      final inspector = ParcelLayerInspector(client);
      final candidates = await PortalDiscoveryService(client)
          .findParcelServiceCandidates(
            county: county.place!,
            state: county.state!,
            catalog: GisCatalogService(client),
            registered: county.portals,
          );
      // ignore: avoid_print
      print('${county.displayName}: ${candidates.length} candidate services');
      final verified = <DetectedParcelSource>[];
      var next = 0;
      Future<void> worker() async {
        while (next < candidates.length) {
          final candidate = candidates[next++];
          final result = await inspector.inspectService(
            candidate.uri,
            county,
            publisher: candidate.portal.publisher,
          );
          verified.addAll(result.layers);
          // ignore: avoid_print
          print(
            '${candidate.uri}: ${result.layers.length} verified; ${result.rejections.take(2).join('; ')}',
          );
        }
      }

      await Future.wait(List.generate(4, (_) => worker()));
      final winner = inspector.rank(verified).firstOrNull;
      if (winner == null) {
        // Discovery is observational: counties may not publish qualifying data.
        // ignore: avoid_print
        print('${county.displayName}: no qualifying layer');
        return;
      }
      // ignore: avoid_print
      print(
        '${county.displayName}: ${winner.query} (${winner.count}) ${jsonEncode(winner.fields.toJson())}',
      );
      final service = ArcGisService(
        client,
        county: county.withDetectedParcels(winner),
      );
      final parcels = await service.fetchParcelsInBounds(
        county.extent,
        limit: 3,
      );
      for (final parcel in parcels) {
        // ignore: avoid_print
        print(
          '${parcel.apn}: ${parcel.situsAddress}, ${parcel.city} ${county.state!.displayAbbreviation} ${parcel.zipCode}',
        );
      }
      if (fips == '04013') {
        final matches = await service.searchAddresses('702 S 114TH LN');
        expect(matches, isNotEmpty, reason: 'Known Avondale situs search');
        final address = matches.first;
        final area = await service.fetchAddressesInBounds(
          GeoBounds(
            west: address.position.longitude - .002,
            south: address.position.latitude - .002,
            east: address.position.longitude + .002,
            north: address.position.latitude + .002,
          ),
        );
        expect(area, isNotEmpty);
        final owner = await DetectedOwnerSource(
          client,
          winner,
        ).lookupByApn(OwnerQuery.fromAddress(address, countyId: county.id));
        // ignore: avoid_print
        print(
          'Avondale: ${address.formatAddress("AZ")}; APN ${address.apn}; owner ${owner?.ownerName}; ${area.length} area addresses',
        );
      }
      if (winner.fields.ownerField != null && parcels.isNotEmpty) {
        final owner = await DetectedOwnerSource(client, winner).lookupByApn(
          OwnerQuery.fromParcel(parcels.first, countyId: county.id),
        );
        // ignore: avoid_print
        print('Owner: ${owner?.ownerName ?? 'no unambiguous published owner'}');
      }
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
