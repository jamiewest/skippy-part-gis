import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/snapshot_status.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('searches, selects, and shows an address detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Riverside Atlas'), findsOneWidget);
    expect(find.text('Address points'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('address-search-field')),
      '3641',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('1 matching addresses'), findsOneWidget);
    await tester.tap(find.text('3641 6TH ST'));
    await tester.pump();

    expect(find.text('213191035'), findsOneWidget);
    expect(find.text('County code 6'), findsOneWidget);
    expect(find.text('MISSION INN RIVERSIDE'), findsOneWidget);
    expect(find.text('Riverside County Address Points'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('starts with overlays off and toggles parcel boundaries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(viewModel.addressesVisible, isFalse);
    expect(viewModel.parcelsVisible, isFalse);
    await tester.tap(find.byKey(const Key('parcel-layer-switch')));
    await tester.pump();
    expect(viewModel.parcelsVisible, isTrue);

    await tester.tap(find.byKey(const Key('address-layer-switch')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(viewModel.addressesVisible, isTrue);
    expect(viewModel.mapMessage, 'Zoom in to explore property-level data');

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('toggles OpenStreetMap license-plate readers on', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(viewModel.alprCamerasVisible, isFalse);
    expect(
      find.byKey(
        Key('alpr-marker-${_FakeAlprCameraRepository.camera.sourceId}'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('alpr-layer-switch')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(viewModel.alprCamerasVisible, isTrue);
    expect(viewModel.alprCameraList, hasLength(1));
    expect(viewModel.alprMessage, isNull);
    expect(
      find.byKey(
        Key('alpr-marker-${_FakeAlprCameraRepository.camera.sourceId}'),
      ),
      findsOne,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('parcel selection checks and shows its owner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    viewModel.setParcelsVisible(true);
    await viewModel.selectParcelAt(const LatLng(33.9837, -117.3723));
    await tester.pump();

    expect(find.text('MISSION INN RIVERSIDE'), findsOneWidget);
    expect(find.text('213191035'), findsOneWidget);
    expect(
      find.text('Riverside County Treasurer–Tax Collector • saved locally'),
      findsOneWidget,
    );

    expect(find.text('STREET'), findsOneWidget);
    expect(find.text('3641 6TH ST'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('copies a selected parcel field by field and whole', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final clipboard = _FakeClipboard()..install(tester);
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    viewModel.setParcelsVisible(true);
    await viewModel.selectParcelAt(const LatLng(33.9837, -117.3723));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('copy-apn-button')));
    await tester.pump();
    expect(clipboard.text, '213191035');
    expect(find.text('APN copied'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-location-button')));
    await tester.pump();
    expect(clipboard.text, 'RIVERSIDE, CA 92501');

    await tester.tap(find.byKey(const Key('copy-owner-button')));
    await tester.pump();
    expect(clipboard.text, 'MISSION INN RIVERSIDE');

    await tester.tap(find.byKey(const Key('copy-selection-button')));
    await tester.pump();
    expect(
      clipboard.text,
      'ADDRESS: 3641 6TH ST\n'
      'LOCATION: RIVERSIDE, CA 92501\n'
      'APN: 213191035\n'
      'OWNER: MISSION INN RIVERSIDE\n'
      'LAND USE: Commercial\n'
      'ACREAGE: 0.18\n'
      'SOURCE: Riverside County Assessor',
    );
    expect(find.text('Property details copied'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('searches the selected address and owner in the side panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    Uri? requestedUri;

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          googleSearchViewBuilder: (context, uri) {
            requestedUri = uri;
            return const Center(child: Text('Embedded Google results'));
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('google-address-search-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('google-search-panel')), findsOneWidget);
    expect(find.text('Address • 3641 6TH ST, RIVERSIDE, CA 92501'), findsOne);
    expect(requestedUri?.host, 'www.google.com');
    expect(
      requestedUri?.queryParameters['q'],
      '3641 6TH ST, RIVERSIDE, CA 92501',
    );

    await tester.tap(find.byKey(const Key('google-owner-search-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Owner name • MISSION INN RIVERSIDE'), findsOne);
    expect(requestedUri?.queryParameters['q'], 'MISSION INN RIVERSIDE');

    await tester.tap(find.byKey(const Key('close-google-search-panel')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('google-search-panel')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('caps the Google side panel on compact windows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          googleSearchViewBuilder: (context, uri) =>
              const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('google-address-search-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(find.byKey(const Key('google-search-panel'))).width,
      560,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('keeps the map controls tappable under the compact search bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final searchBarBottom = tester
        .getRect(find.byKey(const Key('address-search-field')))
        .bottom;
    expect(
      tester.getRect(find.byTooltip('Zoom in')).top,
      greaterThanOrEqualTo(searchBarBottom),
    );

    expect(find.byTooltip('Zoom in').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Zoom out').hitTestable(), findsOneWidget);
    expect(
      find.byTooltip('Fit Riverside County').hitTestable(),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('starts on the street map and changes the background', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(viewModel.selectedImagery, isNull);
    await tester.drag(find.text('MAP LAYERS'), const Offset(0, -260));
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('imagery-year-menu-__street_map__'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    expect(
      find.text('2 Riverside County captures • most recent first'),
      findsOne,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final newestImagery = find.text('2020 aerial imagery').last;
    await tester.ensureVisible(newestImagery);
    await tester.tap(newestImagery);
    await tester.pumpAndSettle();

    expect(viewModel.selectedImagery?.year, 2020);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('writes a saved unclaimed-property check into the details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final query = UnclaimedPropertyQuery.fromOwner(
      ownerName: 'MISSION INN RIVERSIDE',
      city: 'RIVERSIDE',
      zipCode: '92501',
    );
    final viewModel = _viewModel(
      savedUnclaimedProperty: UnclaimedPropertySearchResult(
        query: query,
        found: true,
        resultCount: 2,
        checkedAt: DateTime(2026, 7, 24, 12),
        sourceUri: Uri.parse('https://claimit.ca.gov/app/claim-search'),
        isSaved: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pump();
    await tester.pump();

    expect(find.text('UNCLAIMED'), findsOneWidget);
    expect(
      find.text(
        'Possible match • 2 records returned • exact owner match reported • '
        'California ClaimIt checked 2026-07-24',
      ),
      findsOneWidget,
    );
    expect(find.text('Check ClaimIt'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('hides the county menu when no counties are offered', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CountyMenuButton), findsNothing);
    expect(find.text('Riverside County'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('switches counties from the workspace menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    CountyOption? chosen;

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          countySelection: CountySelection(
            options: _countyOptions,
            activeId: 'riverside',
            onSelected: (option) => chosen = option,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CountyMenuButton), findsOneWidget);

    await tester.tap(find.byType(CountyMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Bernardino County').last);
    await tester.pumpAndSettle();

    expect(chosen, isNotNull);
    expect(chosen!.id, 'san_bernardino');

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('blocks the county menu during a snapshot download', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel(importingSnapshot: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          countySelection: CountySelection(
            options: _countyOptions,
            activeId: 'riverside',
            onSelected: (_) => fail('the county must not change mid-download'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final button = tester.widget<CountyMenuButton>(
      find.byType(CountyMenuButton),
    );
    expect(button.enabled, isFalse);

    await tester.tap(find.byType(CountyMenuButton));
    await tester.pumpAndSettle();

    expect(find.text('San Bernardino County'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('offers the county menu in the compact tools sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    CountyOption? chosen;

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          countySelection: CountySelection(
            options: _countyOptions,
            activeId: 'riverside',
            onSelected: (option) => chosen = option,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CountyMenuButton), findsNothing);
    await tester.tap(find.byTooltip('Data and layer settings'));
    await tester.pumpAndSettle();

    expect(find.text('COUNTY'), findsOneWidget);
    expect(find.byType(CountyMenuButton), findsOneWidget);

    await tester.tap(find.byType(CountyMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Bernardino County').last);
    await tester.pumpAndSettle();

    expect(chosen?.id, 'san_bernardino');

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('swaps the workspace to the next county model', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final riverside = _viewModel();
    final sanBernardino = _viewModel(countyName: 'San Bernardino County');

    Widget workspace(GisMapViewModel viewModel, String countyId) {
      return MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          key: ValueKey(countyId),
          viewModel: viewModel,
          enableBaseMap: false,
        ),
      );
    }

    await tester.pumpWidget(workspace(riverside, 'riverside'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Riverside County'), findsOneWidget);

    await tester.pumpWidget(workspace(sanBernardino, 'san_bernardino'));
    await tester.pump();
    riverside.dispose();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('San Bernardino County'), findsOneWidget);
    expect(find.text('Riverside County'), findsNothing);
    expect(find.text('Search a San Bernardino County address'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    sanBernardino.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('filters the county picker down to what was typed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(
          viewModel: viewModel,
          enableBaseMap: false,
          countySelection: CountySelection(
            options: _countyOptions,
            activeId: 'riverside',
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('county-picker-button')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'San Bernardino County'), findsOne);

    await tester.enterText(
      find.byKey(const Key('county-filter-field')),
      'bernardino',
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'San Bernardino County'), findsOne);
    expect(find.widgetWithText(ListTile, 'Riverside County'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('hides historical imagery for a county without one', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The tools pane is a lazy list, so the imagery section only builds once
    // the pane is scrolled down to it.
    Future<void> pumpCounty(GisMapViewModel viewModel) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.text('MAP LAYERS'), const Offset(0, -260));
      await tester.pumpAndSettle();
    }

    final riverside = _viewModel();
    await pumpCounty(riverside);
    expect(find.text('HISTORICAL IMAGERY'), findsOne);
    await tester.pumpWidget(const SizedBox.shrink());
    riverside.dispose();

    // Only two counties in this build have an aerial history wired up; the
    // other 56 must not be offered an empty year list.
    final kern = _viewModel(withImagery: false, countyName: 'Kern County');
    await pumpCounty(kern);
    expect(find.text('HISTORICAL IMAGERY'), findsNothing);
    expect(find.text('OFFLINE SNAPSHOT'), findsOne);

    await tester.pumpWidget(const SizedBox.shrink());
    kern.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('names a parcel its county publishes no address for', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel(
      countyName: 'San Bernardino County',
      parcel: Parcel(
        sourceId: 4242,
        apn: '025031106',
        situsAddress: '',
        city: '',
        zipCode: '',
        landUse: 'Single Family Residence',
        acreage: 0.17,
        rings: const [
          [
            LatLng(34.0900, -117.4002),
            LatLng(34.0902, -117.4002),
            LatLng(34.0902, -117.4000),
            LatLng(34.0900, -117.4000),
            LatLng(34.0900, -117.4002),
          ],
        ],
      ),
      resolvedSitus: const SitusAddress(
        apn: '025031106',
        countyName: 'SAN BERNARDINO',
        streetAddress: '1366 W ORCHARD ST',
        city: 'BLOOMINGTON',
        zipCode: '92316',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    viewModel.setParcelsVisible(true);
    await viewModel.selectParcelAt(const LatLng(34.0901, -117.4001));
    await tester.pumpAndSettle();

    expect(
      find.text('1366 W ORCHARD ST, BLOOMINGTON, CA 92316'),
      findsOne,
    );
    expect(find.text('California statewide parcel fabric'), findsOne);
    expect(find.text('No address on record'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

}

const _riversideExtent = GeoBounds(
  west: -117.6764,
  south: 33.4259,
  east: -114.4348,
  north: 34.08,
);

const _sanBernardinoExtent = GeoBounds(
  west: -117.8025,
  south: 33.8711,
  east: -114.1308,
  north: 35.8092,
);

const _countyOptions = [
  CountyOption(
    id: 'riverside',
    label: 'Riverside County',
    extent: _riversideExtent,
  ),
  CountyOption(
    id: 'san_bernardino',
    label: 'San Bernardino County',
    extent: _sanBernardinoExtent,
  ),
];

final class _FakeSitusAddressRepository implements SitusAddressRepository {
  _FakeSitusAddressRepository([this.situs]);

  final SitusAddress? situs;

  @override
  Future<SitusAddress?> lookupAt(LatLng point) async => situs;
}

GisMapViewModel _viewModel({
  UnclaimedPropertySearchResult? savedUnclaimedProperty,
  bool importingSnapshot = false,
  String countyName = 'Riverside County',
  bool withImagery = true,
  SitusAddress? resolvedSitus,
  Parcel? parcel,
}) {
  final addresses = _FakeAddressRepository();
  final parcels = _FakeParcelRepository(parcel);
  return GisMapViewModel(
    countyName: countyName,
    countyExtent: _riversideExtent,
    liveAddresses: addresses,
    localAddresses: addresses,
    liveParcels: parcels,
    localParcels: parcels,
    boundaries: _FakeBoundaryRepository(),
    snapshotManager: _FakeSnapshotController(importing: importingSnapshot),
    propertyOwners: _FakePropertyOwnerRepository(),
    unclaimedProperties: _FakeUnclaimedPropertyRepository(
      savedUnclaimedProperty,
    ),
    imageryCatalog: withImagery ? _FakeImageryCatalogRepository() : null,
    situsAddresses: _FakeSitusAddressRepository(resolvedSitus),
    alprCameras: _FakeAlprCameraRepository(),
  );
}

/// Captures what the copy buttons write instead of touching the real
/// pasteboard, which no test platform provides.
final class _FakeClipboard {
  String? text;

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        text = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

final class _FakeAlprCameraRepository implements AlprCameraRepository {
  static const camera = AlprCamera(
    osmType: 'node',
    osmId: 12464814027,
    position: LatLng(33.9757, -117.3500),
    manufacturer: 'Flock Safety',
    direction: 250,
    mount: 'pole',
    zone: 'traffic',
  );

  @override
  Future<List<AlprCamera>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    return const [camera];
  }
}

final class _FakeUnclaimedPropertyRepository
    implements UnclaimedPropertyRepository {
  _FakeUnclaimedPropertyRepository(this.saved);

  UnclaimedPropertySearchResult? saved;

  @override
  Future<UnclaimedPropertySearchResult?> findSaved(
    UnclaimedPropertyQuery query,
  ) async {
    return saved?.query.cacheKey == query.cacheKey ? saved : null;
  }

  @override
  Future<void> remove(UnclaimedPropertyQuery query) async {
    if (saved?.query.cacheKey == query.cacheKey) {
      saved = null;
    }
  }

  @override
  Future<void> save(UnclaimedPropertySearchResult result) async {
    saved = result;
  }
}

final class _FakeAddressRepository implements AddressRepository {
  static const address = Address(
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

  @override
  Future<List<Address>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    return bounds.contains(address.position) ? const [address] : const [];
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) async {
    return query.startsWith('3641') ? const [address] : const [];
  }
}

final class _FakeParcelRepository implements ParcelRepository {
  _FakeParcelRepository([this.fixedParcel]);

  final Parcel? fixedParcel;

  @override
  Future<Parcel?> hitTest(LatLng point) async =>
      fixedParcel ??
      Parcel(
    sourceId: 1819,
    apn: '213191035',
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

  @override
  Future<List<Parcel>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    return const [];
  }
}

final class _FakePropertyOwnerRepository implements PropertyOwnerRepository {
  @override
  Future<PropertyOwnership?> lookupAddress(Address address) async {
    return PropertyOwnership(
      ownerName: 'MISSION INN RIVERSIDE',
      parcelId: address.apn,
      matchedAddress: '3641 6TH ST RIVERSIDE CA 92501',
      sourceUri: Uri.parse(
        'https://ca-riverside-ttc.publicaccessnow.com/'
        'AccountSearch/AccountSummary.aspx?p=${address.apn}',
      ),
      checkedAt: DateTime.utc(2026, 7, 24),
    );
  }

  @override
  Future<PropertyOwnership?> lookupParcel(Parcel parcel) async {
    return PropertyOwnership(
      ownerName: 'MISSION INN RIVERSIDE',
      parcelId: parcel.apn,
      matchedAddress: parcel.situsAddress,
      sourceUri: Uri.parse(
        'https://ca-riverside-ttc.publicaccessnow.com/'
        'AccountSearch/AccountSummary.aspx?p=${parcel.apn}',
      ),
      checkedAt: DateTime.utc(2026, 7, 24),
    );
  }

  @override
  Future<PropertyOwnership?> refreshAddress(Address address) {
    return lookupAddress(address);
  }

  @override
  Future<PropertyOwnership?> refreshParcel(Parcel parcel) {
    return lookupParcel(parcel);
  }
}

final class _FakeImageryCatalogRepository implements ImageryCatalogRepository {
  @override
  Future<List<ImageryLayer>> list({GeoBounds? coverage}) async {
    return [
      ImageryLayer(
        id: 'riverside-2020',
        title: 'Riverside_County_2020_WM',
        year: 2020,
        serviceUri: Uri(
          scheme: 'https',
          host: 'example.com',
          path: '/Riverside_County_2020_WM/ImageServer',
        ),
        description: 'Six-inch county aerial imagery.',
        extent: GeoBounds(west: -117.7, south: 33.4, east: -114.4, north: 34.1),
      ),
      ImageryLayer(
        id: 'riverside-2012',
        title: 'Riverside_County_2012_WM',
        year: 2012,
        serviceUri: Uri(
          scheme: 'https',
          host: 'example.com',
          path: '/Riverside_County_2012_WM/ImageServer',
        ),
        description: 'One-foot county aerial imagery.',
        extent: GeoBounds(west: -117.7, south: 33.4, east: -115.9, north: 34.1),
      ),
    ];
  }
}

final class _FakeBoundaryRepository implements BoundaryRepository {
  @override
  Future<RegionBoundary> getCountyBoundary() async {
    return RegionBoundary(
      name: 'RIVERSIDE',
      fips: '065',
      rings: const [
        [
          LatLng(33.8, -117.6),
          LatLng(34.1, -117.6),
          LatLng(34.1, -117.1),
          LatLng(33.8, -117.1),
          LatLng(33.8, -117.6),
        ],
      ],
    );
  }
}

final class _FakeSnapshotController implements GisSnapshotController {
  _FakeSnapshotController({this.importing = false});

  final bool importing;

  @override
  bool get isImporting => importing;

  @override
  void cancel() {}

  @override
  Future<int> estimate(GeoBounds region) async => 0;

  @override
  Future<void> download({
    required GeoBounds region,
    required void Function(SnapshotStatus status) onProgress,
  }) async {}

  @override
  Future<SnapshotStatus> status() async => importing
      ? SnapshotStatus.empty.copyWith(isImporting: true)
      : SnapshotStatus.empty;
}
