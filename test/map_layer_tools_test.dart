import 'dart:async';

import 'package:extensions/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/map_layer_tools.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

import 'support/fake_map_repositories.dart';

const _bounds = GeoBounds(west: -117.4, south: 33.9, east: -117.3, north: 34);
const _portal = GisPortal(
  root: 'https://example.gov/arcgis/rest/services',
  publisher: 'Example GIS',
  tier: PortalTier.countyPortal,
);
const _lidar = CatalogService(
  portal: _portal,
  name: 'Terrain/Lidar',
  type: 'ImageServer',
  themes: ['Basemaps & terrain'],
);

AlprCamera _camera(int id, {LatLng? position, bool flock = true}) => AlprCamera(
  osmType: 'node',
  osmId: id,
  position: position ?? const LatLng(33.95, -117.35),
  manufacturer: flock ? 'Flock Safety' : null,
  operatorName: 'Example agency',
  direction: 90,
);

void main() {
  late MapWorkspace workspace;
  late GisMapViewModel model;
  late _Cameras cameras;
  late _Catalog catalog;
  late List<AIFunction> tools;

  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) async =>
      await tools
              .firstWhere((tool) => tool.name == name)
              .invoke(AIFunctionArguments()..addAll(args))
          as Map<String, Object?>;

  setUp(() {
    cameras = _Cameras();
    catalog = _Catalog();
    model = buildFakeMapViewModel(
      alprCameras: cameras,
      layerCatalog: catalog,
      portals: [_portal],
      snapshotAvailable: true,
    );
    workspace = MapWorkspace()..attach(model, CountySources.riverside);
    tools = buildMapLayerTools(workspace).whereType<AIFunction>().toList();
  });
  tearDown(() {
    model.dispose();
    workspace.dispose();
  });

  test(
    'capabilities expose hidden cameras, source limitations and layer tools',
    () async {
      final result = await call('get_map_capabilities');
      final osm = result['openStreetMap'] as Map;
      expect(osm['available'], isTrue);
      expect(osm['enabled'], isFalse);
      expect(osm['queryTool'], 'query_map_cameras');
      expect(osm['note'], contains('not a complete camera inventory'));
      expect(
        (result['publishedLayers'] as Map)['metadataTool'],
        'describe_map_layer',
      );
    },
  );

  test(
    'queries hidden cameras and excludes padded results outside the circle',
    () async {
      cameras.values = [
        _camera(1),
        _camera(2, flock: false),
        _camera(3, position: const LatLng(33.956, -117.343)),
        _camera(4, position: const LatLng(34.2, -117.35)),
      ];
      const shape = CircleArea(
        center: LatLng(33.95, -117.35),
        radiusMeters: 800,
      );
      expect(shape.bounds.contains(cameras.values[2].position), isTrue);
      expect(shape.contains(cameras.values[2].position), isFalse);
      await model.selectArea(shape);
      final result = await call('query_map_cameras');
      expect(result['matchedInSourceResults'], 2);
      expect(result['scope'], 'drawnArea');
      final rows = result['cameras'] as List;
      expect(
        (rows.first as Map)['sourceUrl'],
        'https://www.openstreetmap.org/node/1',
      );
      expect((rows.first as Map)['operator'], 'Example agency');
      expect((rows.first as Map)['directionDegrees'], 90);
      expect(model.alprCamerasVisible, isFalse);
      final flock = await call('query_map_cameras', {'flockOnly': true});
      expect(flock['matchedInSourceResults'], 1);
    },
  );

  test(
    'viewport scope overrides the drawn shape and clips padded results',
    () async {
      model.updateViewport(_bounds, 13);
      await model.selectArea(
        const CircleArea(center: LatLng(33.95, -117.35), radiusMeters: 100),
      );
      cameras.values = [
        _camera(1),
        _camera(2, position: const LatLng(33.98, -117.35)),
        _camera(3, position: const LatLng(35, -117.35)),
      ];
      final result = await call('query_map_cameras', {'scope': 'viewport'});
      expect(result['matchedInSourceResults'], 2);
      expect(result['scope'], 'viewport');
    },
  );

  test('paginates cameras without losing the source limit warning', () async {
    await model.selectArea(const RectangleArea(_bounds));
    cameras.values = [for (var i = 0; i < 2000; i++) _camera(i)];
    final first = await call('query_map_cameras');
    final second = await call('query_map_cameras', {
      'offset': first['nextOffset'],
    });
    expect(first['sourceMayBeTruncated'], isTrue);
    expect(first['matchedInSourceResults'], 2000);
    expect(first['listed'], 60);
    expect(second['nextOffset'], 120);
    final ids = [
      ...first['cameras'] as List,
      ...second['cameras'] as List,
    ].map((row) => (row as Map)['id']).toSet();
    expect(ids, hasLength(120));
  });

  test('does not query a missing, oversized or offline extent', () async {
    expect((await call('query_map_cameras'))['status'], 'unavailable');
    await model.selectArea(
      const RectangleArea(
        GeoBounds(west: -120, south: 33, east: -115, north: 35),
      ),
    );
    expect(
      (await call('query_map_cameras'))['status'],
      'areaTooLargeOrInvalid',
    );
    await model.initialize();
    await model.setMode(DataMode.offline);
    expect((await call('query_map_cameras'))['status'], 'unavailable');
    expect(cameras.calls, 0);
  });

  test(
    'reports source failures separately from a successful empty query',
    () async {
      await model.selectArea(const RectangleArea(_bounds));
      cameras.fail = true;
      final failed = await call('query_map_cameras');
      expect(failed['status'], 'unavailable');
      expect(failed.containsKey('matchedInSourceResults'), isFalse);
      cameras.fail = false;
      final empty = await call('query_map_cameras');
      expect(empty['status'], 'ready');
      expect(empty['matchedInSourceResults'], 0);
      expect(
        empty['note'],
        contains('does not establish that no cameras exist'),
      );
    },
  );

  test(
    'rejects camera results when the focus changes during the request',
    () async {
      await model.selectArea(const RectangleArea(_bounds));
      cameras.pending = Completer<List<AlprCamera>>();
      final result = call('query_map_cameras');
      await model.selectArea(
        const CircleArea(center: LatLng(33.95, -117.35), radiusMeters: 100),
      );
      cameras.pending!.complete([_camera(1)]);
      expect((await result)['status'], 'focusChanged');
    },
  );

  test('existing tools follow a county switch', () async {
    final replacement = buildFakeMapViewModel();
    addTearDown(replacement.dispose);
    workspace.attach(replacement, CountySources.riverside);
    await replacement.selectArea(const RectangleArea(_bounds));
    cameras.values = [_camera(1)];
    expect((await call('query_map_cameras'))['matchedInSourceResults'], 0);
    expect(cameras.calls, 0);
  });

  test(
    'discovers inactive lidar, inspects metadata, and changes visibility idempotently',
    () async {
      final portals = await call('list_map_layers');
      expect(
        (portals['portals'] as List).single,
        containsPair('portalRoot', _portal.root),
      );
      final listed = await call('list_map_layers', {
        'portalRoot': _portal.root,
        'query': 'lidar',
      });
      final layer = (listed['layers'] as List).single as Map;
      expect(layer['enabled'], isFalse);
      expect(layer['layerId'], _lidar.id);
      final detail = await call('describe_map_layer', {
        'layerId': layer['layerId'],
      });
      expect((detail['metadata'] as Map)['capabilities'], 'Image,Metadata');
      expect(detail['publisher'], 'Example GIS');
      for (var i = 0; i < 2; i++) {
        await call('set_map_layer_visibility', {
          'layerId': _lidar.id,
          'visible': true,
        });
      }
      expect(model.activeOverlays, hasLength(1));
      final snapshot = await call('get_map_capabilities');
      expect(
        ((snapshot['publishedLayers'] as Map)['active'] as List).single,
        containsPair('layerId', _lidar.id),
      );
      await call('set_map_layer_visibility', {
        'layerId': _lidar.id,
        'visible': false,
      });
      expect(model.activeOverlays, isEmpty);
    },
  );

  test(
    'paginates layers and rejects unlisted portal URLs and layer IDs',
    () async {
      catalog.values = [
        for (var i = 0; i < 61; i++)
          CatalogService(
            portal: _portal,
            name: 'Lidar_$i',
            type: 'ImageServer',
            themes: [],
          ),
      ];
      final first = await call('list_map_layers', {'portalRoot': _portal.root});
      expect(first['nextOffset'], 60);
      final second = await call('list_map_layers', {
        'portalRoot': _portal.root,
        'offset': 60,
      });
      expect(second['layers'] as List, hasLength(1));
      expect(second['nextOffset'], isNull);
      expect(
        (await call('list_map_layers', {
          'portalRoot': 'https://unlisted.test',
        }))['status'],
        'unknownPortal',
      );
      expect(
        (await call('describe_map_layer', {'layerId': 'made-up'}))['status'],
        'unknownLayer',
      );
      expect(
        (await call('set_map_layer_visibility', {
          'layerId': 'made-up',
          'visible': true,
        }))['status'],
        'unknownLayer',
      );
    },
  );

  test('camera visibility uses the actual map controls', () async {
    for (var i = 0; i < 2; i++) {
      await call('set_map_layer_visibility', {
        'layerId': 'alpr_cameras',
        'visible': true,
      });
    }
    expect(model.alprCamerasVisible, isTrue);
    await call('set_map_layer_visibility', {
      'layerId': 'alpr_cameras',
      'visible': false,
    });
    expect(model.alprCamerasVisible, isFalse);
  });

  test(
    'failed catalog listing is surfaced instead of reported as no lidar',
    () async {
      catalog.fail = true;
      final result = await call('list_map_layers', {
        'portalRoot': _portal.root,
      });
      expect(result['status'], 'message');
      expect(result['message'], contains('could not be read'));
    },
  );
}

class _Cameras implements AlprCameraRepository {
  List<AlprCamera> values = [];
  int calls = 0;
  bool fail = false;
  Completer<List<AlprCamera>>? pending;
  @override
  Future<List<AlprCamera>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    calls++;
    if (fail) throw StateError('unavailable');
    return pending == null ? values : await pending!.future;
  }
}

class _Catalog implements LayerCatalogRepository {
  List<CatalogService> values = [_lidar];
  bool fail = false;
  @override
  Future<List<CatalogService>> listServices(GisPortal portal) async {
    if (fail) throw StateError('unavailable');
    return values;
  }

  @override
  Future<Map<String, Object?>> describe(CatalogService service) async => {
    'description': 'Published lidar terrain raster',
    'capabilities': 'Image,Metadata',
    'pixelType': 'F32',
  };
  @override
  void forget(GisPortal portal) {}
}
