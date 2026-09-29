import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/focused_gis_discovery.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';

import 'support/fake_map_repositories.dart';

const _root = 'https://example.test/rest/services';
const _county = CountySource(
  id: 'example',
  displayName: 'Example County',
  fips: '00001',
  initialCenter: LatLng(34, -117),
  extent: GeoBounds(west: -118, south: 33, east: -116, north: 35),
  boundaryFilter: '1=1',
);
const _portal = GisPortal(
  root: _root,
  publisher: 'County GIS',
  tier: PortalTier.countyPortal,
);

MapWorkspace _workspace() {
  final model = buildFakeMapViewModel(
    portals: [_portal],
    parcelsAvailable: false,
  );
  final workspace = MapWorkspace()..attach(model, _county);
  addTearDown(model.dispose);
  addTearDown(workspace.dispose);
  return workspace;
}

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

Map<String, Object?> _layer({bool spatial = true}) => {
  'name': 'Land records',
  if (spatial) 'geometryType': 'esriGeometryPolygon',
  'capabilities': 'Query',
  'fields': [
    {'name': 'P_ID', 'alias': 'Parcel Number', 'type': 'esriFieldTypeString'},
    {'name': 'HOLDER', 'alias': 'Owner Name', 'type': 'esriFieldTypeString'},
    {
      'name': 'OWNER_ADDR',
      'alias': 'Owner Mailing Address',
      'type': 'esriFieldTypeString',
    },
    {'name': 'NAME', 'type': 'esriFieldTypeString'},
  ],
};

Map<String, Object?> _samples() => {
  'features': [
    {
      'attributes': {
        'P_ID': '123-456',
        'HOLDER': 'Example Family Trust',
        'OWNER_ADDR': '7 Main St',
        'NAME': 'Jane Example',
      },
      'geometry': {
        'rings': [
          [
            [-117.1, 33.9],
            [-117.0, 33.9],
            [-117.0, 34.0],
            [-117.1, 33.9],
          ],
        ],
      },
    },
    {
      'attributes': {'P_ID': '123-457', 'HOLDER': 'REDACTED', 'NAME': 'N/A'},
    },
  ],
};

void main() {
  test('can inspect later columns without accepting arbitrary URLs', () async {
    var requests = 0;
    final discovery = FocusedGisDiscovery(
      MockClient((request) async {
        requests++;
        final path = request.url.path;
        if (path == '/rest/services') {
          return _json({
            'services': [
              {'name': 'Records', 'type': 'MapServer'},
            ],
          });
        }
        if (path.endsWith('MapServer')) {
          return _json({
            'layers': [
              {'id': 0},
            ],
          });
        }
        if (path.endsWith('/query')) {
          return _json({
            'features': [
              {
                'attributes': {
                  for (var i = 0; i < 30; i++)
                    'column$i': i == 29 ? 'Unexpected Name LLC' : 'value$i',
                },
              },
            ],
          });
        }
        return _json({
          'name': 'Records',
          'geometryType': 'esriGeometryPoint',
          'fields': [
            for (var i = 0; i < 30; i++)
              {'name': 'column$i', 'type': 'esriFieldTypeString'},
          ],
        });
      }),
    );
    final workspace = _workspace();
    final result = await discovery.inspect(workspace);
    expect((result['sampledLayers'] as List).single['nextFieldOffset'], 24);
    final next = await discovery.inspect(
      workspace,
      sourceUrl: '$_root/Records/MapServer/0',
      fieldOffset: 24,
    );
    final layer = (next['sampledLayers'] as List).single as Map;
    expect(layer['nextFieldOffset'], isNull);
    expect(
      (layer['sampleAttributes'] as List).single['column29'],
      'Unexpected Name LLC',
    );
    expect(next['layersInspected'], 1);
    final count = requests;
    final invalid = await discovery.inspect(
      workspace,
      sourceUrl: 'https://unrelated.test/private/0',
    );
    expect(invalid['status'], 'invalidRequest');
    expect(requests, count);
  });

  test(
    'finds boundary-only parcels and owner aliases in inactive layers',
    () async {
      final requests = <Uri>[];
      final discovery = FocusedGisDiscovery(
        MockClient((request) async {
          requests.add(request.url);
          return switch (request.url.path) {
            '/rest/services' => _json({
              'services': [
                {'name': 'Records', 'type': 'MapServer'},
              ],
            }),
            '/rest/services/Records/MapServer' => _json({
              'layers': [
                {'id': 0},
              ],
            }),
            '/rest/services/Records/MapServer/0' => _json(_layer()),
            '/rest/services/Records/MapServer/0/query' => _json(_samples()),
            _ => http.Response('unexpected request', 404),
          };
        }),
      );
      final workspace = _workspace();
      final result = await discovery.inspect(workspace);
      expect(result['hasMore'], false);
      expect(result['failedRequests'], 0);
      final finding = (result['findings'] as List).single as Map;
      expect(finding['parcelOutlineCandidate'], true);
      expect(finding['sourceUrl'], '$_root/Records/MapServer/0');
      final owners = finding['ownerCandidates'] as List;
      expect(owners.map((o) => (o as Map)['value']), [
        'Example Family Trust',
        'Jane Example',
      ]);
      expect(owners.first['parcelIds'], {'P_ID': '123-456'});
      expect(owners.last['confidence'], contains('ambiguous'));
      expect(workspace.requireViewModel.activeOverlays, isEmpty);
      expect(workspace.requireViewModel.parcelsAvailable, false);
      final query = requests.last.queryParameters;
      expect(query['outFields'], '*');
      expect(query['resultRecordCount'], '5');
      expect(query['spatialRel'], 'esriSpatialRelIntersects');
      final count = requests.length;
      final cached = await discovery.inspect(workspace);
      expect(requests.length, count);
      expect(cached['findings'], result['findings']);
    },
  );

  test(
    'walks folders and every layer in bounded pages, including tables',
    () async {
      final queries = <String>[];
      final discovery = FocusedGisDiscovery(
        MockClient((request) async {
          final path = request.url.path;
          if (path == '/rest/services') {
            return _json({
              'folders': ['Land'],
              'services': [
                {'name': 'Aerial', 'type': 'ImageServer'},
              ],
            });
          }
          if (path == '/rest/services/Land') {
            return _json({
              'services': [
                {'name': 'Land/Records', 'type': 'FeatureServer'},
              ],
            });
          }
          if (path.endsWith('FeatureServer')) {
            return _json({
              'layers': [
                {'id': 0},
                {'id': 1},
              ],
              'tables': [
                {'id': 2},
              ],
            });
          }
          if (path.endsWith('/query')) {
            queries.add(path);
            return _json({'features': []});
          }
          return _json(_layer(spatial: !path.endsWith('/2')));
        }),
        pageSize: 1,
      );
      final workspace = _workspace();
      var result = await discovery.inspect(workspace);
      expect(result['status'], 'partial');
      for (var i = 0; result['hasMore'] == true && i < 10; i++) {
        result = await discovery.inspect(workspace);
      }
      expect(result['status'], 'complete');
      expect(result['layersInspected'], 3);
      expect(result['unsupportedServices'], 1);
      expect(queries, hasLength(2));
      expect(queries.any((q) => q.contains('/2/')), false);
      expect((result['findings'] as List).last['status'], 'schemaOnly');
    },
  );

  test('reports failed sources separately from empty samples', () async {
    final discovery = FocusedGisDiscovery(
      MockClient((request) async {
        if (request.url.path == '/rest/services') {
          return _json({
            'services': [
              {'name': 'Records', 'type': 'MapServer'},
            ],
          });
        }
        return _json({
          'error': {'code': 403, 'message': 'Access denied'},
        });
      }),
    );
    final result = await discovery.inspect(_workspace());
    expect(result['failedRequests'], 1);
    expect(result['layersInspected'], 0);
    expect((result['sampledLayers'] as List).single['status'], 'unavailable');
  });

  test(
    'uses circle geometry and discards results after a county switch',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      String? geometry;
      final discovery = FocusedGisDiscovery(
        MockClient((request) async {
          if (request.url.path == '/rest/services') {
            return _json({
              'services': [
                {'name': 'Records', 'type': 'MapServer'},
              ],
            });
          }
          if (request.url.path.endsWith('MapServer')) {
            return _json({
              'layers': [
                {'id': 0},
              ],
            });
          }
          if (request.url.path.endsWith('/query')) {
            geometry = request.url.queryParameters['geometry'];
            started.complete();
            await gate.future;
            return _json(_samples());
          }
          return _json(_layer());
        }),
      );
      final workspace = _workspace();
      await workspace.requireViewModel.selectArea(
        const CircleArea(center: LatLng(34, -117), radiusMeters: 500),
      );
      final pending = discovery.inspect(workspace);
      await started.future;
      final replacement = buildFakeMapViewModel();
      addTearDown(replacement.dispose);
      workspace.attach(replacement, _county);
      gate.complete();
      expect((jsonDecode(geometry!) as Map)['rings'][0], hasLength(73));
      expect((await pending)['status'], 'focusChanged');
      expect((await discovery.inspect(workspace))['findings'], isEmpty);
    },
  );
}
