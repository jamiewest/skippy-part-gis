import 'package:riverside_atlas/data/services/portal_discovery_service.dart';
import 'package:riverside_atlas/data/services/gis_catalog_service.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/ui/features/map/property_clipboard_text.dart';
import 'package:riverside_atlas/ui/features/map/address_list_csv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/detected_parcel_source.dart';
import 'package:riverside_atlas/data/services/parcel_layer_inspector.dart';
import 'package:riverside_atlas/data/services/parcel_schema.dart';
import 'package:riverside_atlas/data/services/parcel_source_store.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/repositories/county_data_sources.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'support/fake_map_repositories.dart';

final county = CountySources.byFips('04013')!;
final queryUri = Uri.parse(
  'https://gis.example.gov/rest/services/Parcels/MapServer/1/query',
);
List<LayerField> schema(List<String> names) => [
  const LayerField(name: 'FID', type: 'esriFieldTypeOID'),
  for (final n in names) LayerField(name: n, type: 'esriFieldTypeString'),
];
DetectedParcelSource source({
  String origin = 'auto',
  int count = 1760474,
  String name = 'Parcel',
  bool pagination = true,
}) => DetectedParcelSource(
  query: queryUri,
  fields: detectParcelFields(
    schema(['APN', 'SITE_ADDRESS', 'CITY', 'ZIP', 'OWNER_NAME']),
  )!,
  bounds: county.extent,
  publisherLabel: 'Example County',
  layerName: name,
  count: count,
  detectedAt: DateTime.utc(2026, 9, 26),
  origin: origin,
  supportsPagination: pagination,
);
Map<String, Object?> fixture(String name) =>
    (jsonDecode(
              File(
                'test/fixtures/parcel_detection/$name.json',
              ).readAsStringSync(),
            )
            as Map)
        .cast<String, Object?>();
http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('schema detection', () {
    final cases = <String, List<String>>{
      'Maricopa': [
        'APN',
        'PropertyFullStreetAddress',
        'PropertyCity',
        'PropertyZipCode',
        'OwnerName',
      ],
      'assessor': ['APN', 'PHYSICAL_ADDRESS', 'OWNER_NAME'],
      'California': [
        'PARCEL_APN',
        'SITE_ADDR',
        'SITE_HOUSE_NUMBER',
        'SITE_STREET_NAME',
        'FIPS_CODE',
      ],
      'Riverside': ['APN', 'SITUS_STREET', 'CITY', 'ZIP_CODE'],
      'San Bernardino address schema': [
        'PRCLNUM',
        'FULLADDR',
        'ADDRNUM',
        'FULLNAME',
      ],
      'Harris': [
        'HCAD_NUM',
        'LOWPARCELID',
        'site_str_num',
        'site_str_name',
        'site_city',
        'site_zip',
        'owner_name_1',
      ],
      'King': ['PIN', 'ADDR_FULL', 'CTYNAME', 'ZIP5'],
      'Minnesota': ['state_pin', 'county_pin', 'anumber', 'st_name', 'co_name'],
      'Wake': ['PIN_NUM', 'SITE_ADDRESS'],
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        final detected = detectParcelFields(schema(entry.value));
        expect(detected, isNotNull);
        expect(
          ParcelFieldMap.fromJson(detected!.toJson()).toJson(),
          detected.toJson(),
        );
        expect(detected.objectIdField, 'FID');
      });
    }
    test('county PIN wins and mailing-only data is rejected', () {
      expect(
        detectParcelFields(schema(cases['Minnesota']!))!.apnField,
        'county_pin',
      );
      expect(
        detectParcelFields(schema(['APN', 'OWNER_ADDRESS', 'MAIL_ADDRESS'])),
        isNull,
      );
      expect(detectParcelFields(schema(['SUBDIVISION', 'ADDRESS'])), isNull);
    });
    test('aliases, plain APN and situs preference', () {
      final detected = detectParcelFields([
        ...schema(['APN_DASH', 'APN', 'OWNER_ADDRESS', 'MAIL_CITY']),
        const LayerField(name: 'S1', alias: 'Site Address'),
        const LayerField(name: 'C1', alias: 'Site City'),
      ])!;
      expect(detected.apnField, 'APN');
      expect(detected.fullAddressField, 'S1');
      expect(detected.fields['city'], 'C1');
      expect(
        detectParcelFields([
          ...schema(['APN', 'SITE_ADDRESS']),
          const LayerField(name: 'OWNER_ADDRESS', alias: 'Owner'),
        ])!.ownerField,
        isNull,
      );
    });
  });

  test(
    'captured King and Hennepin fields preserve complete situs components',
    () {
      final king = detectParcelFields(
        (fixture('king_parcels')['fields'] as List)
            .cast<Map>()
            .map((f) => LayerField.fromJson(f.cast<String, Object?>()))
            .toList(),
      )!;
      expect(king.apnField, 'PIN');
      expect(king.fullAddressField, 'ADDR_FULL');
      final mn = detectParcelFields(
        (fixture('hennepin_parcels')['fields'] as List)
            .cast<Map>()
            .map((f) => LayerField.fromJson(f.cast<String, Object?>()))
            .toList(),
      )!;
      expect(
        mn.address({'ANUMBER': 7850, 'ST_NAME': 'Metro', 'ST_POS_TYP': 'Pkwy'}),
        '7850 Metro Pkwy',
      );
      expect(mn.fields['city'], 'POSTCOMM');
    },
  );

  test(
    'shortlist cap retains broad parcel/address services and gates geography',
    () async {
      const root =
          'https://services.arcgis.com/ExampleOrg123/arcgis/rest/services';
      const government = 'https://gis.example.gov/arcgis/rest/services';
      final items = [
        for (var i = 0; i < 40; i++)
          {
            'url': '$root/AddressPoints$i/FeatureServer',
            'extent': [
              [-113, 33],
              [-112, 34],
            ],
          },
        {
          'url': '$government/Parcel/MapServer',
          'extent': [
            [-113, 33],
            [-112, 34],
          ],
        },
        {
          'url': '$root/PARCEL_ADDRESS_PUB_AREA_3069/FeatureServer',
          'extent': [
            [-113, 33],
            [-112, 34],
          ],
        },
        {
          'url': '$root/OtherStateParcels/FeatureServer',
          'extent': [
            [-70, 40],
            [-69, 41],
          ],
        },
      ];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/search')) {
          return jsonResponse({'results': items});
        }
        return jsonResponse({});
      });
      final candidates = await PortalDiscoveryService(client)
          .findParcelServiceCandidates(
            county: county.place!,
            state: county.state!,
            catalog: GisCatalogService(client),
          );
      expect(candidates, hasLength(25));
      expect(
        candidates.map((s) => s.name),
        containsAll(['Parcel', 'PARCEL_ADDRESS_PUB_AREA_3069']),
      );
      expect(
        candidates.map((s) => s.name),
        isNot(contains('OtherStateParcels')),
      );
    },
  );

  test('non-California formatting carries workspace state to exports', () {
    final mapper = DetectedParcelMapper(source().fields);
    final address = mapper.address({
      'attributes': {
        'FID': 1,
        'APN': '101C',
        'SITE_ADDRESS': '702 S 114TH LN',
        'CITY': 'AVONDALE',
        'ZIP': '85323',
      },
      'centroid': {'x': -112.3, 'y': 33.4},
    });
    expect(address.formatAddress('AZ'), contains('AVONDALE, AZ 85323'));
    expect(
      propertyLocationLine(
        city: address.city,
        zipCode: address.zipCode,
        stateCode: 'AZ',
      ),
      'AVONDALE, AZ 85323',
    );
    expect(
      addressListCsv(
        addresses: [address],
        countyName: county.displayName,
        stateCode: 'AZ',
      ),
      contains('AVONDALE,AZ,85323'),
    );
  });

  group('inspection', () {
    MockClient client({int count = 1760474, bool point = false}) =>
        MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/MapServer')) {
            return jsonResponse(fixture('maricopa_service'));
          }
          if (path.endsWith('/0')) {
            return jsonResponse(fixture('maricopa_subdivision'));
          }
          if (path.endsWith('/1')) {
            return jsonResponse({
              ...fixture('maricopa_parcels'),
              if (point) 'geometryType': 'esriGeometryPoint',
            });
          }
          if (request.url.queryParameters['returnCountOnly'] == 'true') {
            return jsonResponse({'count': count});
          }
          expect(request.url.queryParameters['resultRecordCount'], '250');
          expect(request.url.queryParameters['inSR'], '4326');
          return jsonResponse(fixture('maricopa_sample'));
        });
    test(
      'walks layer 1, rejects Subdivision and reads MapServer OID/capabilities',
      () async {
        final result = await ParcelLayerInspector(
          client(),
        ).inspectService(Uri.parse('https://example.gov/MapServer'), county);
        expect(result.layers, hasLength(1));
        expect(result.layers.single.query.path, '/MapServer/1/query');
        expect(result.layers.single.supportsCentroid, isFalse);
        expect(result.layers.single.supportsPagination, isTrue);
        expect(result.layers.single.uppercaseAddressSearch, isFalse);
        expect(result.rejections, isNotEmpty);
      },
    );
    test('rejects subsets below minimum and point geometries', () async {
      final small = await ParcelLayerInspector(
        client(count: 690),
      ).inspectService(Uri.parse('https://example.gov/MapServer'), county);
      expect(small.layers, isEmpty);
      expect(small.rejections.join(), contains('690'));
      final point = await ParcelLayerInspector(
        client(point: true),
      ).inspectService(Uri.parse('https://example.gov/MapServer'), county);
      expect(point.layers, isEmpty);
    });
    test('sample chooses populated address and county scope', () async {
      final client = MockClient((request) async {
        if (!request.url.path.endsWith('/query')) {
          return jsonResponse({
            'name': 'Minnesota parcels',
            'geometryType': 'esriGeometryPolygon',
            'capabilities': 'Query',
            'fields': [
              for (final f in schema([
                'county_pin',
                'SITE_ADDR',
                'PHYSICAL_ADDRESS',
                'co_name',
              ]))
                {'name': f.name, 'type': f.type},
            ],
          });
        }
        if (request.url.queryParameters['returnCountOnly'] == 'true') {
          expect(
            request.url.queryParameters['where'],
            "(co_name = 'Maricopa')",
          );
          return jsonResponse({'count': 4000});
        }
        return jsonResponse({
          'features': List.generate(
            250,
            (_) => {
              'attributes': {
                'FID': 1,
                'county_pin': '101C',
                'SITE_ADDR': ', , ',
                'PHYSICAL_ADDRESS': '12 Main St',
                'co_name': 'Maricopa',
              },
            },
          ),
        });
      });
      final result = await ParcelLayerInspector(
        client,
      ).inspectService(Uri.parse('https://example.gov/MapServer/0'), county);
      expect(result.layers.single.fields.fullAddressField, 'PHYSICAL_ADDRESS');
      expect(result.layers.single.uppercaseAddressSearch, isTrue);
    });
    test(
      'ranks full coverage above subsets and uses deterministic near-ties',
      () {
        final inspector = ParcelLayerInspector(
          MockClient((_) async => jsonResponse({})),
        );
        final ranked = inspector.rank([
          source(count: 690, name: 'Lien'),
          source(count: 196000, name: 'Unincorporated'),
          source(),
          source(count: 1770000, name: 'Parcel 2010'),
        ], year: 2026);
        expect(ranked.first.layerName, 'Parcel');
        expect(
          inspector
              .rank([
                source(count: 1020, pagination: false),
                source(count: 1000),
              ])
              .first
              .supportsPagination,
          isTrue,
        );
      },
    );
    test('global inspection concurrency never exceeds four', () async {
      var active = 0, maximum = 0;
      final inspector = ParcelLayerInspector(
        MockClient((_) async {
          active++;
          if (active > maximum) maximum = active;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
          return jsonResponse({'layers': []});
        }),
      );
      await Future.wait(
        List.generate(
          12,
          (i) => inspector.inspectService(
            Uri.parse('https://example.gov/$i'),
            county,
          ),
        ),
      );
      expect(maximum, 4);
    });
  });

  test('component mapper uses real OID and polygon fallback', () {
    final map = detectParcelFields(
      schema(['HCAD_NUM', 'site_str_num', 'site_str_name', 'site_city']),
    )!;
    final mapper = DetectedParcelMapper(map);
    final feature = <String, Object?>{
      'attributes': {
        'FID': 8,
        'HCAD_NUM': '101C',
        'site_str_num': 12,
        'site_str_name': 'MAIN',
        'site_city': 'HOUSTON',
      },
      'geometry': {
        'rings': [
          [
            [-96.0, 29.0],
            [-95.0, 29.0],
            [-95.0, 30.0],
            [-96.0, 29.0],
          ],
        ],
      },
    };
    expect(mapper.address(feature).objectId, 8);
    expect(mapper.address(feature).fullAddress, '12 MAIN');
    expect(mapper.address(feature).position.longitude, -95.5);
    expect(mapper.parcel(feature).apn, '101C');
  });

  test('owner APNs retain letters and quote published values safely', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['where'], contains("APN = '101C''X'"));
      return jsonResponse({
        'features': [
          {
            'attributes': {
              'FID': 1,
              'APN': "101C'X",
              'SITE_ADDRESS': '12 MAIN ST',
              'OWNER_NAME': 'PUBLIC OWNER',
            },
          },
        ],
      });
    });
    final q = OwnerQuery(
      countyId: county.id,
      subject: OwnerQuerySubject.parcel,
      sourceId: 1,
      apn: "101C'X",
    );
    expect(q.normalizedApn, '101CX');
    expect(
      (await DetectedOwnerSource(client, source()).lookupByApn(q))!.ownerName,
      'PUBLIC OWNER',
    );
    expect(
      const OwnerQuery(
        countyId: 'ca_riverside',
        subject: OwnerQuerySubject.parcel,
        sourceId: 1,
        apn: '123-456',
      ).cacheKey,
      'us:ca_riverside:apn:123456',
    );
  });
  test('ambiguous address owner is never guessed', () async {
    final client = MockClient(
      (_) async => jsonResponse({
        'features': [
          for (final apn in ['1C', '1'])
            {
              'attributes': {
                'FID': apn,
                'APN': apn,
                'SITE_ADDRESS': '12 MAIN ST',
                'OWNER_NAME': 'OWNER $apn',
              },
            },
        ],
      }),
    );
    final q = OwnerQuery(
      countyId: county.id,
      subject: OwnerQuerySubject.address,
      sourceId: 1,
      apn: '',
      houseNumber: 12,
      streetName: 'MAIN',
    );
    expect(
      await DetectedOwnerSource(client, source()).lookupByAddress(q),
      isNull,
    );
  });

  test(
    'source persistence round-trip, manual precedence, staleness and forget',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ParcelSourceStore(db);
      await store.save(county.id, source(origin: 'manual'));
      await store.save(county.id, source());
      expect((await store.load(county.id))!.origin, 'manual');
      expect(
        (await store.load(county.id))!.toJson(),
        source(origin: 'manual').toJson(),
      );
      await store.markStale(county.id, queryUri);
      expect((await store.load(county.id))!.expired, isTrue);
      await store.forget(county.id);
      expect(await store.load(county.id), isNull);
    },
  );

  test(
    'detected address search is spatially scoped and component-aware',
    () async {
      final component = DetectedParcelSource.fromJson({
        ...source().toJson(),
        'fields': detectParcelFields(
          schema(['APN', 'site_str_num', 'site_str_name']),
        )!.toJson(),
      });
      final client = MockClient((request) async {
        final body = Uri.splitQueryString(request.body);
        expect(body['geometry'], isNotEmpty);
        expect(body['where'], contains("site_str_num = '12'"));
        expect(body['where'], contains("UPPER(site_str_name) LIKE 'MAIN%'"));
        return jsonResponse({'features': []});
      });
      await ArcGisService(
        client,
        county: county.withDetectedParcels(component),
      ).searchAddresses('12 Main');
    },
  );

  test(
    'non-paginated snapshots use sorted ID slices and omit centroid',
    () async {
      final client = MockClient((request) async {
        final body = Uri.splitQueryString(request.body);
        if (body['returnIdsOnly'] == 'true') {
          return jsonResponse({
            'objectIds': [7, 4, 9],
          });
        }
        expect(body['objectIds'], '7');
        expect(body, isNot(contains('resultOffset')));
        expect(body, isNot(contains('returnCentroid')));
        return jsonResponse({'features': []});
      });
      await ArcGisService(
        client,
        county: county.withDetectedParcels(source(pagination: false)),
      ).fetchCombinedPage(county.extent, offset: 1, limit: 1);
    },
  );

  CountyDataSources bundle(GisMapViewModel model) => CountyDataSources(
    liveAddresses: model.liveAddresses,
    localAddresses: model.localAddresses,
    liveParcels: model.liveParcels,
    localParcels: model.localParcels,
    snapshotManager: model.snapshotManager,
    propertyOwners: model.propertyOwners,
    situsAddresses: model.situsAddresses,
    parcelsAvailable: true,
    parcelSourceLabel: 'Example · Parcel (detected)',
  );
  test(
    'runtime search adopts coverage and notifies; disposed search is safe',
    () async {
      final stream = StreamController<CountyDataSources>();
      final model = buildFakeMapViewModel(
        parcelsAvailable: false,
        resolveParcelSource: (_) => stream.stream,
      );
      var notifications = 0;
      model.addListener(() {
        notifications++;
      });
      final pending = model.discoverParcelSource();
      expect(model.parcelSourceStatus, ParcelSourceStatus.searching);
      stream.add(bundle(model));
      await stream.close();
      await pending;
      expect(model.parcelsAvailable, isTrue);
      expect(model.parcelSourceStatus, ParcelSourceStatus.detected);
      expect(notifications, greaterThan(1));
      model.dispose();
      final late = StreamController<CountyDataSources>();
      final disposed = buildFakeMapViewModel(
        parcelsAvailable: false,
        resolveParcelSource: (_) => late.stream,
      );
      final done = disposed.discoverParcelSource();
      final sources = bundle(disposed);
      disposed.dispose();
      late.add(sources);
      await late.close();
      await done;
      expect(disposed.parcelsAvailable, isFalse);
    },
  );
  test(
    'a late automatic resolution cannot replace a manual selection',
    () async {
      final stream = StreamController<CountyDataSources>();
      final base = buildFakeMapViewModel();
      addTearDown(base.dispose);
      final manual = bundle(base);
      final model = buildFakeMapViewModel(
        parcelsAvailable: false,
        resolveParcelSource: (_) => stream.stream,
        selectParcelSource: (_) async => manual,
      );
      addTearDown(model.dispose);
      final pending = model.discoverParcelSource();
      final result = await model.useAsParcelSource(
        const CatalogService(
          portal: GisPortal(
            root: 'https://example.gov/rest/services',
            publisher: 'Example',
            tier: PortalTier.countyPortal,
          ),
          name: 'Parcel',
          type: 'MapServer',
          themes: [],
        ),
      );
      expect(result, startsWith('Using'));
      stream.add(
        CountyDataSources(
          liveAddresses: base.liveAddresses,
          localAddresses: base.localAddresses,
          liveParcels: base.liveParcels,
          localParcels: base.localParcels,
          snapshotManager: base.snapshotManager,
          propertyOwners: base.propertyOwners,
          situsAddresses: base.situsAddresses,
          parcelsAvailable: false,
        ),
      );
      await stream.close();
      await pending;
      expect(model.parcelsAvailable, isTrue);
      expect(model.parcelSourceLabel, manual.parcelSourceLabel);
    },
  );
}
