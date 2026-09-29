import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/snapshot_status.dart';

/// One row the fake county service publishes, at a known position.
typedef _Feature = ({int objectId, double longitude, double latitude});

void main() {
  const region = GeoBounds(
    west: -117.2,
    south: 33.5,
    east: -117.1,
    north: 33.6,
  );
  const neighbouringRegion = GeoBounds(
    west: -117.1,
    south: 33.5,
    east: -117.0,
    north: 33.6,
  );

  /// Rows the fake county service publishes per layer.
  late Map<String, List<_Feature>> featuresByLayer;

  /// Every page request the fake service answered, in order.
  late List<({String layer, int offset, GeoBounds envelope})> pageRequests;

  http.Response respond(Object? payload) =>
      http.Response(jsonEncode(payload), 200);

  Map<String, Object?> addressFeature(_Feature feature) => {
    'attributes': {
      'OBJECTID': feature.objectId,
      'ADDRESS_ID': 900000 + feature.objectId,
      'ADDRESS': '${feature.objectId} TEMECULA PKWY',
      'HOUSE_NUMBER': feature.objectId,
      'STREET_NAME': 'TEMECULA',
      'STREET_TYPE': 'PKWY',
      'UNIT': '',
      'CITY': 'TEMECULA',
      'ZIP': '92592',
      'APN': '96100000${feature.objectId}',
      'ADDRESS_TYPE': '6',
      'NUMBER_OF_UNITS': 1,
    },
    'geometry': {'x': feature.longitude, 'y': feature.latitude},
  };

  Map<String, Object?> parcelFeature(_Feature feature) => {
    'attributes': {
      'OBJECTID': feature.objectId,
      'APN': '96100000${feature.objectId}',
      'SITUS_STREET': '${feature.objectId} TEMECULA PKWY',
      'CITY': 'TEMECULA',
      'ZIP_CODE': '92592',
      'CLASS_CODE': 'Single Family Residence',
      'ACREAGE': 0.2,
    },
    'geometry': {
      'rings': [
        [
          [feature.longitude - 0.0002, feature.latitude - 0.0002],
          [feature.longitude + 0.0002, feature.latitude - 0.0002],
          [feature.longitude + 0.0002, feature.latitude + 0.0002],
          [feature.longitude - 0.0002, feature.latitude + 0.0002],
          [feature.longitude - 0.0002, feature.latitude - 0.0002],
        ],
      ],
    },
  };

  /// A row shaped like the statewide layer's response: rings and a centroid.
  Map<String, Object?> statewideFeature(_Feature feature) => {
    'attributes': {
      'OBJECTID': feature.objectId,
      'PARCEL_APN': '01280614${feature.objectId}',
      'FIPS_CODE': '06037',
      'COUNTYNAME': 'LOS ANGELES',
      'SITE_ADDR': '1364 W RIALTO AVE',
      'SITE_CITY': 'RIALTO',
      'SITE_ZIP': '92376',
      'SITE_HOUSE_NUMBER': '1364',
      'SITE_DIRECTION': 'W',
      'SITE_STREET_NAME': 'RIALTO',
      'SITE_MODE': 'AVE',
    },
    'geometry': {
      'rings': [
        [
          [feature.longitude - 0.0002, feature.latitude - 0.0002],
          [feature.longitude + 0.0002, feature.latitude - 0.0002],
          [feature.longitude + 0.0002, feature.latitude + 0.0002],
          [feature.longitude - 0.0002, feature.latitude + 0.0002],
          [feature.longitude - 0.0002, feature.latitude - 0.0002],
        ],
      ],
    },
    'centroid': {'x': feature.longitude, 'y': feature.latitude},
  };

  GeoBounds parseEnvelope(String value) {
    final parts = value.split(',').map(double.parse).toList(growable: false);
    return GeoBounds(
      west: parts[0],
      south: parts[1],
      east: parts[2],
      north: parts[3],
    );
  }

  /// The fake county service, filtering and paging like a real feature layer.
  MockClient countyClient() {
    return MockClient((request) async {
      final fields = request.bodyFields;
      final layer = request.url.path.contains('/Assessor/')
          ? 'parcel'
          : 'address';
      final envelope = parseEnvelope(fields['geometry']!);
      final inside = (featuresByLayer[layer] ?? const <_Feature>[])
          .where(
            (feature) =>
                feature.longitude >= envelope.west &&
                feature.longitude <= envelope.east &&
                feature.latitude >= envelope.south &&
                feature.latitude <= envelope.north,
          )
          .toList(growable: false);
      if (fields['returnCountOnly'] == 'true') {
        return respond({'count': inside.length});
      }
      final offset = int.parse(fields['resultOffset']!);
      final limit = int.parse(fields['resultRecordCount']!);
      pageRequests.add((layer: layer, offset: offset, envelope: envelope));
      final page = inside.skip(offset).take(limit).toList(growable: false);
      return respond({
        'features': page
            .map(layer == 'parcel' ? parcelFeature : addressFeature)
            .toList(growable: false),
      });
    });
  }

  ({LocalGisStore store, SnapshotManager manager}) createManager({
    int tileFeatureLimit = 4,
    int pageSize = 2,
  }) {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = LocalGisStore(database);
    return (
      store: store,
      manager: SnapshotManager(
        service: ArcGisService(countyClient()),
        store: store,
        tileFeatureLimit: tileFeatureLimit,
        pageSize: pageSize,
      ),
    );
  }

  /// [count] rows spread evenly across [bounds], newest object ID last.
  List<_Feature> spread(GeoBounds bounds, int count, {int firstId = 1}) {
    return [
      for (var index = 0; index < count; index++)
        (
          objectId: firstId + index,
          longitude:
              bounds.west + (bounds.east - bounds.west) * (index + 0.5) / count,
          latitude:
              bounds.south +
              (bounds.north - bounds.south) * (index + 0.5) / count,
        ),
    ];
  }

  /// A fake statewide layer: one endpoint answering as addresses and parcels.
  MockClient statewideClient({
    required int rowCount,
    required GeoBounds bounds,
    int? reportedCount,
  }) {
    final rows = spread(bounds, rowCount);
    return MockClient((request) async {
      final fields = request.bodyFields;
      final envelope = parseEnvelope(fields['geometry']!);
      final inside = rows
          .where(
            (feature) =>
                feature.longitude >= envelope.west &&
                feature.longitude <= envelope.east &&
                feature.latitude >= envelope.south &&
                feature.latitude <= envelope.north,
          )
          .toList(growable: false);
      if (fields['returnCountOnly'] == 'true') {
        return respond({'count': reportedCount ?? inside.length});
      }
      final offset = int.parse(fields['resultOffset']!);
      final limit = int.parse(fields['resultRecordCount']!);
      pageRequests.add((
        layer: 'statewide',
        offset: offset,
        envelope: envelope,
      ));
      return respond({
        'features': inside
            .skip(offset)
            .take(limit)
            .map(statewideFeature)
            .toList(growable: false),
      });
    });
  }

  ({LocalGisStore store, SnapshotManager manager}) createStatewideManager({
    required int rowCount,
    required int pageSize,
    int? reportedCount,
  }) {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = LocalGisStore(database, countyId: 'ca_los_angeles');
    return (
      store: store,
      manager: SnapshotManager(
        service: ArcGisService(
          statewideClient(
            rowCount: rowCount,
            bounds: region,
            reportedCount: reportedCount,
          ),
          county: CountySources.byId('ca_los_angeles')!,
        ),
        store: store,
        tileFeatureLimit: 100000,
        pageSize: pageSize,
      ),
    );
  }

  setUp(() {
    pageRequests = [];
  });

  test('imports and activates the requested area', () async {
    featuresByLayer = {
      'address': spread(region, 3),
      'parcel': spread(region, 2, firstId: 10),
    };
    final harness = createManager();
    final reports = <SnapshotStatus>[];

    await harness.manager.download(region: region, onProgress: reports.add);
    final status = await harness.store.status();

    check(status.isAvailable).isTrue();
    check(status.addressCount).equals(3);
    check(status.parcelCount).equals(2);
    check(reports).isNotEmpty();
    check(reports.last.progress).isCloseTo(1, 0.001);
  });

  test('pages a tile until the layer stops returning rows', () async {
    featuresByLayer = {'address': spread(region, 3), 'parcel': const []};
    final harness = createManager(tileFeatureLimit: 100, pageSize: 2);

    await harness.manager.download(region: region, onProgress: (_) {});

    // Three rows at two per page: offsets 0 and 2, then stop on the short page.
    check(
      pageRequests
          .where((page) => page.layer == 'address')
          .map((page) => page.offset),
    ).deepEquals([0, 2]);
    check((await harness.store.status()).addressCount).equals(3);
  });

  test('subdivides an area too dense to page shallowly', () async {
    featuresByLayer = {'address': spread(region, 12), 'parcel': const []};
    final harness = createManager(tileFeatureLimit: 4, pageSize: 100);

    await harness.manager.download(region: region, onProgress: (_) {});

    final tiles = pageRequests.map((page) => page.envelope).toSet();
    check(
      tiles.length,
      because: 'twelve rows over a four-row tile limit must be quartered',
    ).isGreaterThan(1);
    for (final tile in tiles) {
      check(tile.east - tile.west).isLessThan(region.east - region.west);
    }
    check((await harness.store.status()).addressCount).equals(12);
  });

  test('replaces the active snapshot with a newly chosen area', () async {
    featuresByLayer = {
      'address': [
        ...spread(region, 3),
        ...spread(neighbouringRegion, 2, firstId: 4),
      ],
      'parcel': [
        ...spread(region, 2, firstId: 10),
        ...spread(neighbouringRegion, 2, firstId: 12),
      ],
    };
    final harness = createManager();

    await harness.manager.download(region: region, onProgress: (_) {});
    await harness.manager.download(
      region: neighbouringRegion,
      onProgress: (_) {},
    );
    final status = await harness.store.status();

    check(status.addressCount).equals(2);
    check(status.parcelCount).equals(2);
  });

  test('refuses an area larger than one snapshot holds', () async {
    // Counted, never fetched: the guard runs before any feature is downloaded.
    featuresByLayer = {
      'address': spread(region, SnapshotManager.maxFeatureCount),
      'parcel': spread(region, 10, firstId: 900000),
    };
    final harness = createManager();

    await check(
      harness.manager.download(region: region, onProgress: (_) {}),
    ).throws<SnapshotAreaTooLargeException>();
    final status = await harness.store.status();

    check(status.isAvailable).isFalse();
    check(harness.manager.isImporting).isFalse();
    check(pageRequests).isEmpty();
  });

  test('counts a shared address and parcel layer only once', () async {
    // A statewide county stores one row as both an address point and a parcel,
    // so counting it twice would halve the area a snapshot appears to accept.
    final losAngeles = CountySources.byId('ca_los_angeles')!;

    check(
      losAngeles.layers!.addressQuery,
    ).equals(losAngeles.layers!.parcelQuery);
    check(
      ArcGisService(countyClient(), county: losAngeles).sharesAddressLayer,
    ).isTrue();
    check(ArcGisService(countyClient()).sharesAddressLayer).isFalse();
  });

  test('reports honest progress downloading a shared layer', () async {
    // A statewide county stores each downloaded row twice — once as an address
    // point, once as a parcel — against a total that counts it once. Adding
    // both to the numerator drives progress to 100% at the halfway mark.
    final harness = createStatewideManager(rowCount: 4, pageSize: 2);
    final reports = <SnapshotStatus>[];

    await harness.manager.download(region: region, onProgress: reports.add);

    final downloading = reports
        .where((report) => report.parcelCount > 0)
        .toList(growable: false);
    check(downloading.first.progress).isCloseTo(0.5, 0.001);
    check(downloading.last.progress).isCloseTo(1, 0.001);
    check(
      downloading.map((report) => report.progress).toList(),
      because: 'progress must never run past the total it was measured against',
    ).every((report) => report.isLessOrEqual(1.0));

    final status = await harness.store.status();
    check(status.isAvailable).isTrue();
    check(status.addressCount).equals(4);
    check(status.parcelCount).equals(4);
  });

  test('stores a shared layer as both addresses and parcels', () async {
    final harness = createStatewideManager(rowCount: 4, pageSize: 100);

    await harness.manager.download(region: region, onProgress: (_) {});

    final addresses = await harness.store.addressesInBounds(region);
    final parcels = await harness.store.parcelsInBounds(region);
    check(addresses).length.equals(4);
    check(parcels).length.equals(4);
    check(addresses.first.fullAddress).equals('1364 W RIALTO AVE');
    check(addresses.first.position.latitude).isGreaterThan(region.south);
    check(parcels.first.rings).isNotEmpty();
  });

  test('refuses to activate a snapshot that covered too little', () async {
    // The layer under-delivers: it reports 40 rows and then serves 4. Paging
    // stops on the short page without an error, which is what makes an
    // unverified activation report a partial copy as complete.
    final harness = createStatewideManager(
      rowCount: 4,
      pageSize: 2,
      reportedCount: 40,
    );

    await check(
      harness.manager.download(region: region, onProgress: (_) {}),
    ).throws<SnapshotIncompleteException>();

    check((await harness.store.status()).isAvailable).isFalse();
  });

  test('tolerates a few rows shifting between the count and the pages', () {
    // The count is taken before the first page, so the county keeps editing in
    // between; a handful of rows must not fail an otherwise whole download.
    final harness = createStatewideManager(
      rowCount: 400,
      pageSize: 1000,
      reportedCount: 402,
    );

    check(
      harness.manager.download(region: region, onProgress: (_) {}),
    ).completes();
  });
}
