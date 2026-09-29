import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/widgets/layer_catalog_sheet.dart';

import 'support/fake_map_repositories.dart';

const _countyPortal = GisPortal(
  root: 'https://gis.example.gov/arcgis/rest/services',
  publisher: 'Example County',
  tier: PortalTier.countyPortal,
);

const _statewidePortal = GisPortal(
  root: 'https://services.gis.ca.gov/arcgis/rest/services',
  publisher: 'California State Geoportal',
  tier: PortalTier.statewide,
);

final class _FakeCatalog implements LayerCatalogRepository {
  _FakeCatalog({this.fails = false});

  final bool fails;
  final List<String> opened = [];

  @override
  Future<List<CatalogService>> listServices(GisPortal portal) async {
    opened.add(portal.root);
    if (fails) {
      throw Exception('unreachable');
    }
    return [
      CatalogService(
        portal: portal,
        name: 'OpenData/Assessor_Parcels',
        type: 'MapServer',
        themes: const ['parcels & assessor'],
      ),
      CatalogService(
        portal: portal,
        name: 'TLMA/FLOOD_ZONES',
        type: 'MapServer',
        themes: const ['flood & water'],
      ),
    ];
  }

  @override
  Future<Map<String, Object?>> describe(CatalogService service) async => {
    'layers': [
      {'id': 0, 'name': 'Layer'},
    ],
  };

  @override
  void forget(GisPortal portal) {}
}

GisMapViewModel _viewModel({
  required LayerCatalogRepository catalog,
  List<GisPortal> portals = const [_countyPortal, _statewidePortal],
  bool snapshotAvailable = false,
}) {
  return buildFakeMapViewModel(
    layerCatalog: catalog,
    portals: portals,
    snapshotAvailable: snapshotAvailable,
  );
}

Future<void> _pump(WidgetTester tester, GisMapViewModel viewModel) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: LayerCatalogSheet(viewModel: viewModel)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('manual rejection is readable above the catalogue', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      layerCatalog: _FakeCatalog(),
      portals: const [_countyPortal],
      selectParcelSource: (_) async =>
          throw StateError('Subdivision has no parcel-number field'),
    );
    addTearDown(viewModel.dispose);
    await _pump(tester, viewModel);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as parcel source'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Subdivision has no parcel-number field'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('County map layers'), findsOneWidget);
  });

  testWidgets('lists the first portal grouped by theme', (tester) async {
    final catalog = _FakeCatalog();
    final viewModel = _viewModel(catalog: catalog);
    addTearDown(viewModel.dispose);

    await _pump(tester, viewModel);

    expect(find.text('parcels & assessor'), findsOneWidget);
    expect(find.text('flood & water'), findsOneWidget);
    expect(catalog.opened, [_countyPortal.root]);
  });

  testWidgets('does not read a catalogue until it is opened', (tester) async {
    final catalog = _FakeCatalog();
    final viewModel = _viewModel(catalog: catalog);
    addTearDown(viewModel.dispose);

    await _pump(tester, viewModel);

    expect(catalog.opened, isNot(contains(_statewidePortal.root)));

    await tester.tap(find.text('California State Geoportal'));
    await tester.pump();
    await tester.pump();

    expect(catalog.opened, contains(_statewidePortal.root));
  });

  testWidgets('switching a layer on makes it an active overlay', (
    tester,
  ) async {
    final viewModel = _viewModel(catalog: _FakeCatalog());
    addTearDown(viewModel.dispose);
    await _pump(tester, viewModel);

    await tester.tap(find.text('Assessor Parcels'));
    await tester.pump();

    expect(viewModel.activeOverlays, hasLength(1));
    expect(viewModel.activeOverlays.single.service.title, 'Assessor Parcels');
    expect(find.text('1 layer on'), findsOneWidget);
  });

  testWidgets('opening the sheet does not rebuild listeners mid-build', (
    tester,
  ) async {
    // The map screen listens to the same view model and is already built when
    // the sheet is pushed. Reading the first catalogue from initState would
    // mark that listener dirty during the sheet's own mount, which the
    // framework rejects — this is the crash behind "Browse published layers".
    final viewModel = _viewModel(catalog: _FakeCatalog());
    addTearDown(viewModel.dispose);
    var showSheet = false;
    late StateSetter setOuterState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return showSheet
                    ? LayerCatalogSheet(viewModel: viewModel)
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    setOuterState(() => showSheet = true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('parcels & assessor'), findsOneWidget);
  });

  testWidgets('a city chip appears when the map moves over the city', (
    tester,
  ) async {
    const city = CityPortals(
      name: 'Example City',
      bounds: GeoBounds(west: -117.6, south: 33.8, east: -117.4, north: 33.9),
      portals: [
        GisPortal(
          root: 'https://services.arcgis.com/example/arcgis/rest/services',
          publisher: 'City of Example',
          tier: PortalTier.city,
        ),
      ],
    );
    final viewModel = buildFakeMapViewModel(
      layerCatalog: _FakeCatalog(),
      portals: const [_countyPortal, _statewidePortal],
      cities: const [city],
    );
    addTearDown(viewModel.dispose);
    await _pump(tester, viewModel);

    expect(find.text('City of Example'), findsNothing);

    viewModel.updateViewport(
      const GeoBounds(west: -117.55, south: 33.83, east: -117.45, north: 33.87),
      13,
    );
    // City availability is recomputed on the debounced viewport path, so the
    // chip appears only once that timer has fired.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('City of Example'), findsOneWidget);
  });

  testWidgets('search narrows across every theme', (tester) async {
    final viewModel = _viewModel(catalog: _FakeCatalog());
    addTearDown(viewModel.dispose);
    await _pump(tester, viewModel);

    await tester.enterText(find.byType(TextField), 'flood');
    await tester.pumpAndSettle();

    expect(find.text('FLOOD ZONES'), findsOneWidget);
    expect(find.text('Assessor Parcels'), findsNothing);
  });

  testWidgets('names the catalogue that failed rather than showing nothing', (
    tester,
  ) async {
    final viewModel = _viewModel(catalog: _FakeCatalog(fails: true));
    addTearDown(viewModel.dispose);

    await _pump(tester, viewModel);
    await tester.pump();

    expect(find.textContaining('gis.example.gov'), findsOneWidget);
  });

  testWidgets('says so when a county has no catalogue at all', (tester) async {
    final viewModel = _viewModel(catalog: _FakeCatalog(), portals: const []);
    addTearDown(viewModel.dispose);

    await _pump(tester, viewModel);

    expect(find.textContaining('No public map catalogue'), findsOneWidget);
  });

  test(
    'an overlay resolves its sub-layer query endpoints when switched on',
    () async {
      final viewModel = _viewModel(catalog: _FakeCatalog());
      addTearDown(viewModel.dispose);
      await viewModel.openPortal(_countyPortal);

      final feature = viewModel
          .servicesIn(_countyPortal)
          .map(
            (service) => CatalogService(
              portal: service.portal,
              name: service.name,
              type: 'FeatureServer',
              themes: service.themes,
            ),
          )
          .first;
      viewModel.toggleOverlay(feature);
      await Future<void>.delayed(Duration.zero);

      expect(
        viewModel.activeOverlays.single.featureQueries.single.toString(),
        endsWith('/FeatureServer/0/query'),
      );
    },
  );

  test('geo bounds still frame the county after overlays load', () {
    final viewModel = _viewModel(catalog: _FakeCatalog());
    addTearDown(viewModel.dispose);

    expect(viewModel.countyExtent, isA<GeoBounds>());
  });

  testWidgets('offline mode offers no layer to switch on', (tester) async {
    final viewModel = _viewModel(
      catalog: _FakeCatalog(),
      snapshotAvailable: true,
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();
    await viewModel.setMode(DataMode.offline);

    await _pump(tester, viewModel);
    await tester.pump();

    expect(viewModel.overlaysAvailable, isFalse);
    expect(find.textContaining('Unavailable offline'), findsOneWidget);
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Assessor Parcels'),
    );
    expect(tile.onChanged, isNull);
  });
}
