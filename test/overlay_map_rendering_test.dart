import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_image_tile_provider.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';

import 'support/fake_map_repositories.dart';

/// The map itself, not the picker: these drive the layers a switched-on
/// overlay actually adds to `FlutterMap`, which nothing else covers.

const _portal = GisPortal(
  root: 'https://gis.example.gov/arcgis/rest/services',
  publisher: 'Example County',
  tier: PortalTier.countyPortal,
);

CatalogService _service(String type) => CatalogService(
  portal: _portal,
  name: 'OpenData/Flood',
  type: type,
  themes: const ['flood & water'],
);

final class _StubCatalog implements LayerCatalogRepository {
  @override
  Future<List<CatalogService>> listServices(GisPortal portal) async => [
    _service('MapServer'),
  ];

  @override
  Future<Map<String, Object?>> describe(CatalogService service) async => {
    'layers': [
      {'id': 0, 'name': 'Zones'},
    ],
  };

  @override
  void forget(GisPortal portal) {}
}

final class _OneFeature implements OverlayFeatureRepository {
  @override
  Future<List<OverlayFeature>> queryViewport(
    Uri layerQuery,
    GeoBounds bounds, {
    int limit = 1200,
  }) async => const [
    OverlayFeature(
      rings: [
        [
          LatLng(33.9, -117.4),
          LatLng(33.9, -117.3),
          LatLng(34.0, -117.3),
          LatLng(33.9, -117.4),
        ],
      ],
      paths: [
        [LatLng(33.9, -117.4), LatLng(34.0, -117.3)],
      ],
      points: [LatLng(33.95, -117.35)],
      attributes: {'ZONE': 'AE'},
    ),
  ];
}

Future<GisMapViewModel> _pumpMap(WidgetTester tester) async {
  final viewModel = buildFakeMapViewModel(
    layerCatalog: _StubCatalog(),
    overlayFeatures: _OneFeature(),
    portals: const [_portal],
  );
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AtlasTheme.light,
      home: GisMapScreen(
        viewModel: viewModel,
        initialCenter: const LatLng(33.95, -117.35),
        initialBounds: const GeoBounds(
          west: -117.4,
          south: 33.9,
          east: -117.3,
          north: 34.0,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return viewModel;
}

/// Lets the viewport debounce fire so no timer outlives the widget tree.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a MapServer overlay adds an export tile layer to the map', (
    tester,
  ) async {
    final viewModel = await _pumpMap(tester);

    viewModel.toggleOverlay(_service('MapServer'));
    await _settle(tester);

    final tileLayers = tester
        .widgetList<TileLayer>(find.byType(TileLayer, skipOffstage: false))
        .where((layer) => layer.tileProvider is ArcGisExportTileProvider);
    expect(tileLayers, hasLength(1));
    expect(
      tileLayers.single.urlTemplate,
      'https://gis.example.gov/arcgis/rest/services/OpenData/Flood/MapServer',
    );
  });

  testWidgets('an ImageServer overlay uses the exportImage provider', (
    tester,
  ) async {
    final viewModel = await _pumpMap(tester);

    viewModel.toggleOverlay(_service('ImageServer'));
    await _settle(tester);

    expect(
      tester
          .widgetList<TileLayer>(find.byType(TileLayer, skipOffstage: false))
          .where((layer) => layer.tileProvider is ArcGisImageTileProvider),
      hasLength(1),
    );
  });

  testWidgets('a FeatureServer overlay draws its geometry', (tester) async {
    final viewModel = await _pumpMap(tester);

    viewModel.toggleOverlay(_service('FeatureServer'));
    await _settle(tester);
    await _settle(tester);

    expect(viewModel.activeOverlays.single.features, hasLength(1));
    final polygons = tester
        .widgetList<PolygonLayer>(
          find.byType(PolygonLayer, skipOffstage: false),
        )
        .expand((layer) => layer.polygons);
    expect(
      polygons.any(
        (polygon) => polygon.points.first == const LatLng(33.9, -117.4),
      ),
      isTrue,
    );
    expect(
      tester
          .widgetList<PolylineLayer>(
            find.byType(PolylineLayer, skipOffstage: false),
          )
          .expand((layer) => layer.polylines),
      isNotEmpty,
    );
    expect(
      tester
          .widgetList<CircleLayer>(
            find.byType(CircleLayer, skipOffstage: false),
          )
          .expand((layer) => layer.circles),
      isNotEmpty,
    );
  });

  testWidgets('turning an overlay off removes it from the map', (tester) async {
    final viewModel = await _pumpMap(tester);
    viewModel.toggleOverlay(_service('MapServer'));
    await _settle(tester);

    viewModel.toggleOverlay(_service('MapServer'));
    await _settle(tester);

    expect(
      tester
          .widgetList<TileLayer>(find.byType(TileLayer, skipOffstage: false))
          .where((layer) => layer.tileProvider is ArcGisExportTileProvider),
      isEmpty,
    );
  });

  testWidgets('overlays draw beneath the parcel layer', (tester) async {
    final viewModel = await _pumpMap(tester);
    viewModel.toggleOverlay(_service('FeatureServer'));
    await _settle(tester);
    await _settle(tester);

    // The overlay's polygon layer must come before the boundary and parcel
    // layers, or a layer switched on for context hides the property the user
    // is looking at.
    final layers = tester
        .widgetList<PolygonLayer>(
          find.byType(PolygonLayer, skipOffstage: false),
        )
        .toList();
    expect(layers.length, greaterThanOrEqualTo(2));
    expect(layers.first.polygons, isNotEmpty);
  });

  testWidgets('tapping a drawn overlay feature shows its attributes', (
    tester,
  ) async {
    // The reported symptom was dots that draw but yield nothing on tap. This
    // drives the real map: switch a layer on, tap where it drew, and read the
    // card. The stub's point sits at the camera centre, so tapping the middle
    // of the map is a tap on the dot.
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = await _pumpMap(tester);
    viewModel.toggleOverlay(_service('FeatureServer'));
    await _settle(tester);
    await _settle(tester);
    expect(viewModel.activeOverlays.single.features, hasLength(1));

    // The pump must outlast flutter_map's double-tap timeout, or the single
    // tap is still sitting in the gesture arena and never reaches onTap.
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(viewModel.identifiedOverlay?.title, 'Flood');
    expect(find.text('ZONE'), findsOneWidget);
    expect(find.text('AE'), findsOneWidget);

    await _settle(tester);
  });
}
