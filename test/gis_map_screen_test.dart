import 'package:flutter/material.dart';
import 'package:riverside_atlas/ui/features/map/widgets/claimit_search_panel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/data/services/content_sharing.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
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

  // Phones open chat full screen instead; see the phone chat test below.
  for (final size in [
    const Size(1400, 900),
    const Size(1100, 800),
    const Size(800, 1000),
  ]) {
    testWidgets('chat keeps map controls and drawing usable at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final viewModel = _viewModel();
      final assistant = MapAssistant(
        unavailableReason: 'No provider configured.',
      );
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(
            viewModel: viewModel,
            assistant: assistant,
            initialBounds: const GeoBounds(
              west: -117.5,
              south: 33.8,
              east: -117.2,
              north: 34.1,
            ),
            enableBaseMap: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalMap = tester.getRect(find.byType(FlutterMap));
      final originalController = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      const pannedCenter = LatLng(34.5, -118.0);
      originalController.move(pannedCenter, 13);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-assistant-button')));
      await tester.pumpAndSettle();
      expect(originalController.camera.center, pannedCenter);
      expect(originalController.camera.zoom, 13);
      final panel = tester.getRect(find.byKey(const Key('assistant-panel')));
      final map = tester.getRect(find.byType(FlutterMap));
      expect(map.overlaps(panel), isFalse);
      for (final control in [
        find.byTooltip('Zoom in'),
        find.byTooltip('Zoom out'),
        find.byTooltip('Fit Riverside County'),
        find.byKey(const Key('area-select-tool-button')),
      ]) {
        expect(control.hitTestable(), findsOneWidget);
        expect(tester.getRect(control).overlaps(panel), isFalse);
      }
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final zoom = controller.camera.zoom;
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, greaterThan(zoom));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, closeTo(zoom, 0.001));
      await tester.tap(find.byTooltip('Fit Riverside County'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-select-tool-button')));
      await tester.pumpAndSettle();
      await _dragRectangle(
        tester,
        from: map.topLeft + Offset(map.width * 0.3, map.height * 0.4),
        to: map.topLeft + Offset(map.width * 0.6, map.height * 0.65),
      );
      await tester.pumpAndSettle();
      // Beside docked chat a narrow workspace previews the shape for editing
      // before it is committed, as a phone does.
      final confirm = find.byKey(const Key('confirm-area-draft-button'));
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }
      expect(viewModel.areaSelection, isNotNull);
      expect(find.byKey(const Key('area-selection-rectangle')), findsOneWidget);
      expect(find.byKey(const Key('assistant-panel')), findsOneWidget);
      final centerBeforeClosing = controller.camera.center;
      final zoomBeforeClosing = controller.camera.zoom;
      await tester.tap(find.byKey(const Key('assistant-close-button')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FlutterMap)), originalMap);
      expect(controller.camera.center, centerBeforeClosing);
      expect(controller.camera.zoom, zoomBeforeClosing);
      expect(viewModel.areaSelection, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  testWidgets('phone swipes can pan from California to the East Coast', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(controller.camera.center, 5);
    await tester.pump();

    // Exercise touch gestures through the phone's floating UI, including
    // viewport refreshes between swipes that could otherwise reset the map.
    for (var i = 0; i < 5; i++) {
      await tester.dragFrom(const Offset(310, 420), const Offset(-230, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }
    expect(controller.camera.center.longitude, greaterThan(-80));
    for (var i = 0; i < 5; i++) {
      await tester.dragFrom(const Offset(80, 420), const Offset(230, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }
    expect(controller.camera.center.longitude, lessThan(-114));

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('phone can zoom out to a country overview and pan freely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
    }
    expect(controller.camera.zoom, lessThanOrEqualTo(3));
    final bounds = controller.camera.visibleBounds;
    expect(bounds.east - bounds.west, greaterThan(60));

    // Puerto Rico is part of the country too, beyond the old states-only
    // fence. A swipe should keep moving rather than stop at its latitude.
    controller.move(const LatLng(20, -66), 5);
    await tester.pump();
    await tester.dragFrom(const Offset(195, 420), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(controller.camera.center.latitude, lessThan(18));

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('every county the workspace opens is searched for catalogues', (
    tester,
  ) async {
    // Switching county replaces the view model but not the widget tree, so
    // the card's State is reused and its initState does not run again. The
    // second county would otherwise report only its federal tier for ever.
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final searched = <String>[];
    GisMapViewModel build(String county) => _viewModel(
      countyName: county,
      portals: const [
        GisPortal(
          root: 'https://tigerweb.geo.census.gov/arcgis/rest/services',
          publisher: 'US Census Bureau',
          tier: PortalTier.national,
        ),
      ],
      portalDiscovery: () async {
        searched.add(county);
        return const [];
      },
    );

    final first = build('Dallas County');
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: first, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(searched, ['Dallas County']);

    final second = build('Cuyahoga County');
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: second, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(searched, ['Dallas County', 'Cuyahoga County']);

    // The map's viewport debounce leaves a timer pending; tearing the tree
    // down before the workspaces are disposed is what drains it.
    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();
    second.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('opens the layer catalogue without throwing', (tester) async {
    // The reported crash: tapping "Browse published layers" mounted the sheet,
    // whose initState read the first catalogue, which notified the map
    // screen's already-built listeners mid-build. Driving the real screen is
    // what proves it, because a sheet pumped on its own has no such listener.
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel(
      layerCatalog: _FakeLayerCatalog(),
      portals: const [
        GisPortal(
          root: 'https://gis.example.gov/arcgis/rest/services',
          publisher: 'Riverside County',
          tier: PortalTier.countyPortal,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-layer-catalog')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('open-layer-catalog')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('County map layers'), findsOneWidget);
    expect(find.text('parcels & assessor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

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

    expect(find.text('Atlas'), findsOneWidget);
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
    expect(find.text('ca-riverside-ttc.publicaccessnow.com'), findsOneWidget);

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

    expect(find.text('ca-riverside-ttc.publicaccessnow.com'), findsOneWidget);
    expect(find.textContaining('saved locally'), findsNothing);

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

    await tester.tap(find.byKey(const Key('claimit-owner-search-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('claimit-search-panel')), findsOneWidget);
    expect(find.byKey(const Key('google-search-panel')), findsNothing);
    expect(requestedUri.toString(), 'https://claimit.ca.gov/app/claim-search');
    final claimIt = tester.widget<ClaimItSearchPanel>(
      find.byType(ClaimItSearchPanel),
    );
    expect(claimIt.query.lastName, 'MISSION INN RIVERSIDE');
    expect(claimIt.query.firstName, isEmpty);
    expect(claimIt.query.city, isEmpty);
    expect(claimIt.query.zipCode, isEmpty);

    await tester.tap(find.byKey(const Key('google-owner-search-button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('claimit-search-panel')), findsNothing);
    expect(requestedUri?.host, 'www.google.com');

    await tester.tap(find.byKey(const Key('close-google-search-panel')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('google-search-panel')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final width in [420.0, 820.0]) {
    testWidgets('opens and closes ClaimIt at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final viewModel = _viewModel();
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(
            viewModel: viewModel,
            enableBaseMap: false,
            googleSearchViewBuilder: (context, uri) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const Key('claimit-owner-search-button')),
        findsNothing,
      );
      viewModel.selectAddress(_FakeAddressRepository.address);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      final claimIt = find.byKey(const Key('claimit-owner-search-button'));
      await tester.ensureVisible(claimIt);
      await tester.pumpAndSettle();
      await tester.tap(claimIt);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('claimit-search-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('close-claimit-search-panel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('claimit-search-panel')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('opens Google research full screen on a phone-width window', (
    tester,
  ) async {
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

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google-address-search-button')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('google-search-panel'))).width,
      700,
    );
    expect(tester.takeException(), isNull);

    // Closing returns to the same property.
    await tester.tap(find.byKey(const Key('close-google-search-panel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('google-search-panel')), findsNothing);
    expect(find.byKey(const Key('share-property-button')), findsOneWidget);

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
        .getRect(find.byKey(const Key('phone-header')))
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
            activeId: 'ca_riverside',
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
    expect(chosen!.id, 'ca_san_bernardino');

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
            activeId: 'ca_riverside',
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

  testWidgets('offers the county menu in the phone header', (tester) async {
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
            activeId: 'ca_riverside',
            onSelected: (option) => chosen = option,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byKey(const Key('phone-header')),
        matching: find.byType(CountyMenuButton),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(CountyMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('San Bernardino County').last);
    await tester.pumpAndSettle();

    expect(chosen?.id, 'ca_san_bernardino');

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

    await tester.pumpWidget(workspace(riverside, 'ca_riverside'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Riverside County'), findsOneWidget);

    await tester.pumpWidget(workspace(sanBernardino, 'ca_san_bernardino'));
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
            activeId: 'ca_riverside',
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

  testWidgets('says why a county with no parcel source draws none', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Most counties in the country are covered by no state parcel fabric and
    // publish no service of their own. Leaving the switches live would draw
    // an empty map that reads as broken rather than as uncovered.
    final harris = _viewModel(
      countyName: 'Harris County, TX',
      withImagery: false,
      parcelsAvailable: false,
    );
    addTearDown(harris.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: harris, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('coverage-notice')), findsOne);
    expect(find.text('No public parcel layer covers this county'), findsOne);
    final addressSwitch = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const Key('address-layer-switch')),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(addressSwitch.onChanged, isNull);

    // Nothing to snapshot, so the download that would reach a layer with no
    // endpoint is not offered at all.
    await tester.drag(find.text('MAP LAYERS'), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('OFFLINE SNAPSHOT'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('refuses a snapshot where nothing publishes parcels', (
    tester,
  ) async {
    final harris = _viewModel(
      countyName: 'Harris County, TX',
      parcelsAvailable: false,
    );
    addTearDown(harris.dispose);

    await harris.downloadCountySnapshot();

    expect(harris.errorMessage, contains('Harris County, TX'));
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

    expect(find.text('1366 W ORCHARD ST, BLOOMINGTON, CA 92316'), findsOne);
    expect(find.text('California statewide parcel fabric'), findsOne);
    expect(find.text('No address on record'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('opens the drawn area list from a pill on a compact window', (
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

    await viewModel.selectArea(RectangleArea(_riversideDowntown));
    await tester.pumpAndSettle();

    // The narrow layout has no side pane, so the list waits behind a pill.
    expect(find.text('1 address in the drawn area'), findsOneWidget);
    expect(find.byKey(const Key('area-address-16055')), findsNothing);

    await tester.tap(find.byKey(const Key('area-results-pill')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy-area-csv-button')), findsOneWidget);
    expect(find.byKey(const Key('area-address-16055')), findsOneWidget);

    await tester.tap(find.byKey(const Key('area-address-16055')));
    await tester.pumpAndSettle();

    // Tapping a row closes the sheet and shows the property on the map.
    expect(find.byKey(const Key('area-address-16055')), findsNothing);
    expect(find.text('Riverside County Address Points'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('floats the selected property over the map, not in the pane', (
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

    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pumpAndSettle();

    final card = tester.getTopLeft(
      find.byKey(const Key('copy-selection-button')),
    );
    expect(card.dx, greaterThan(380));
    // The pane keeps the tools it had rather than being taken over by the
    // property that is now shown on the map.
    expect(find.text('Address points'), findsOneWidget);
    expect(find.text('213191035'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('draws an area and lists the addresses inside it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final clipboard = _FakeClipboard()..install(tester);
    final viewModel = _viewModel(stateCode: 'AZ');

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('area-select-tool-button')));
    await tester.pump();
    expect(find.byKey(const Key('area-select-overlay')), findsOneWidget);

    await _dragRectangle(
      tester,
      from: const Offset(600, 260),
      to: const Offset(1180, 640),
    );
    await tester.pumpAndSettle();

    // The tool disarms itself and the rectangle stays drawn on the map.
    expect(find.byKey(const Key('area-select-overlay')), findsNothing);
    expect(find.text('1 address in the drawn area'), findsOneWidget);
    expect(find.byKey(const Key('area-address-16055')), findsOneWidget);
    expect(find.textContaining('RIVERSIDE, AZ 92501'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-area-csv-button')));
    await tester.pumpAndSettle();
    expect(clipboard.text, startsWith('address,unit,city,state,zip,apn'));
    expect(clipboard.text, contains('3641 6TH ST,,RIVERSIDE,AZ,92501'));

    await tester.tap(find.byKey(const Key('clear-area-selection-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 address in the drawn area'), findsNothing);
    expect(find.text('Address points'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final shape in <AreaShape>[
    const RectangleArea(_riversideDowntown),
    const CircleArea(center: LatLng(33.9837, -117.3723), radiusMeters: 700),
  ]) {
    testWidgets('moving ${shape.description} refreshes its address results', (
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
      await viewModel.selectArea(shape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('area-address-16055')), findsOneWidget);

      final handle = find.byKey(const Key('area-move-handle'));
      final press = tester.getCenter(handle);
      final gesture = await tester.startGesture(press);
      await gesture.moveTo(press + const Offset(60, 0));
      await tester.pump();
      await gesture.moveTo(press + const Offset(150, 0));
      await tester.pump();
      // Results remain committed while the user positions the draft.
      expect(viewModel.areaSelection!.shape, same(shape));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(viewModel.areaSelection!.shape, isNot(same(shape)));
      expect(viewModel.areaSelection!.status, AreaSelectionStatus.ready);
      expect(viewModel.areaSelection!.addresses, isEmpty);
      expect(find.byKey(const Key('area-address-16055')), findsNothing);
      expect(find.byKey(const Key('area-move-handle')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  testWidgets('replaces the list when a second area is drawn', (tester) async {
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

    await viewModel.selectArea(RectangleArea(_riversideDowntown));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-address-16055')), findsOneWidget);

    await viewModel.selectArea(RectangleArea(_riversideDesert));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('area-address-16055')), findsNothing);
    expect(find.text('No addresses here'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('ignores a click that draws no rectangle', (tester) async {
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

    await tester.tap(find.byKey(const Key('area-select-tool-button')));
    await tester.pump();
    await _dragRectangle(
      tester,
      from: const Offset(700, 400),
      to: const Offset(703, 402),
    );
    await tester.pumpAndSettle();

    // A stray click leaves the tool armed rather than reporting an empty area.
    expect(viewModel.areaSelection, isNull);
    expect(find.byKey(const Key('area-select-overlay')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('keeps the control pane beside the map on a tablet in portrait', (
    tester,
  ) async {
    // An iPad in portrait: too narrow for the desktop layout, far too roomy
    // for a phone's full-bleed map with everything floating over it.
    await tester.binding.setSurfaceSize(const Size(834, 1194));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The tools are in the pane, not behind the compact layout's sheet.
    expect(find.text('DATA SOURCE'), findsOneWidget);
    expect(find.byTooltip('Data and layer settings'), findsNothing);
    expect(find.text('Atlas'), findsOneWidget);

    // The pane leaves the map the majority of the width.
    final paneWidth = tester
        .getSize(find.byKey(const Key('address-search-field')))
        .width;
    expect(paneWidth, lessThan(834 / 2));

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('gives a phone held sideways the phone layout', (tester) async {
    // Wider than the desktop breakpoint and less than half as tall: a side
    // pane has nowhere to put its list, and navigation must not change
    // when the phone turns.
    await tester.binding.setSurfaceSize(const Size(956, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DATA SOURCE'), findsNothing);
    expect(find.byKey(const Key('phone-header')), findsOneWidget);
    expect(find.byKey(const Key('open-phone-layers')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('gives a phone in portrait the full-bleed map layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // No pane: the tools wait behind the bottom toolbar's sheets.
    expect(find.text('DATA SOURCE'), findsNothing);
    expect(find.byKey(const Key('open-phone-layers')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('riverside-map'))).width, 393);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('opens the Google panel over the map on a tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(834, 1194));
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
    final mapWidth = tester
        .getSize(find.byKey(const Key('riverside-map')))
        .width;

    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('google-address-search-button')));
    await tester.pump(const Duration(milliseconds: 300));

    // A tablet has no third column to give the panel, so it slides over the
    // map rather than squeezing it.
    expect(find.byKey(const Key('google-search-panel')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('riverside-map'))).width,
      mapWidth,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('disarms the area tool from the overlay, without a keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('area-select-tool-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-select-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-area-select-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('area-select-overlay')), findsNothing);
    expect(viewModel.areaSelectMode, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final size in [const Size(390, 844), const Size(667, 375)]) {
    testWidgets('phone chat opens full screen and returns to the same map '
        'at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final viewModel = _viewModel();
      final assistant = MapAssistant(
        unavailableReason: 'No provider configured.',
      );
      addTearDown(assistant.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(
            viewModel: viewModel,
            assistant: assistant,
            enableBaseMap: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      viewModel.selectAddress(_FakeAddressRepository.address);
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = controller.camera.center;
      final zoom = controller.camera.zoom;

      await tester.tap(find.byKey(const Key('open-assistant-button')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('assistant-panel'))).width,
        size.width,
      );
      // The conversation says what it is about.
      expect(
        find.descendant(
          of: find.byKey(const Key('assistant-panel')),
          matching: find.text(_FakeAddressRepository.address.fullAddress),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('assistant-map-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-panel')), findsNothing);
      expect(viewModel.selectedAddress, isNotNull);
      expect(find.byKey(const Key('compact-workspace-sheet')), findsOneWidget);
      expect(controller.camera.center, center);
      expect(controller.camera.zoom, zoom);

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  testWidgets('phone search frames the chosen property above its sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('open-phone-search')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('address-search-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '3641');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('3641 6TH ST'));
    await tester.pumpAndSettle();

    // Back on the map with the keyboard gone and the summary open.
    expect(field, findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    expect(viewModel.selectedAddress, isNotNull);
    final sheet = tester.getRect(
      find.byKey(const Key('compact-workspace-sheet')),
    );
    final header = tester.getRect(find.byKey(const Key('phone-header')));
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final point = controller.camera.latLngToScreenOffset(
      _FakeAddressRepository.address.position,
    );
    expect(point.dy, greaterThan(header.bottom));
    expect(point.dy, lessThan(sheet.top));

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('phone layers put active layers first and open their details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const portal = GisPortal(
      root: 'https://gis.example.gov/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
    );
    final viewModel = _viewModel(
      layerCatalog: _FakeLayerCatalog(),
      portals: const [portal],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final service = CatalogService(
      portal: portal,
      name: 'OpenData/Assessor_Parcels',
      type: 'MapServer',
      themes: const ['parcels & assessor'],
    );
    viewModel.toggleOverlay(service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-phone-layers')));
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('active-layer-${service.id}'));
    expect(tile, findsOneWidget);
    expect(
      tester.getRect(tile).top,
      lessThan(
        tester.getRect(find.byKey(const Key('address-layer-switch'))).top,
      ),
    );

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Layer details'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Layers & imagery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('phone shares a property and recovers from a failed share', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = _viewModel();
    final sharing = _FakeSharing();
    await tester.pumpWidget(
      SharingScope(
        service: sharing,
        child: MaterialApp(
          theme: AtlasTheme.light,
          home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    viewModel.selectAddress(_FakeAddressRepository.address);
    await tester.pumpAndSettle();

    // A dismissed share sheet returns normally: nothing to report.
    await tester.tap(find.byKey(const Key('share-property-button')));
    await tester.pumpAndSettle();
    expect(sharing.shared, hasLength(1));
    expect(sharing.shared.single, contains('3641 6TH ST'));
    expect(sharing.origins.single.isEmpty, isFalse);
    expect(find.textContaining('Could not share'), findsNothing);

    sharing.fails = true;
    await tester.tap(find.byKey(const Key('share-property-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not share'), findsOneWidget);
    expect(find.byKey(const Key('copy-selection-button')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets('phone property, layers and tools fit 200% text at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final viewModel = _viewModel();
      await tester.pumpWidget(
        MaterialApp(
          theme: AtlasTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: GisMapScreen(viewModel: viewModel, enableBaseMap: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      viewModel.selectAddress(_FakeAddressRepository.address);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Expand sheet'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final key in ['open-phone-layers', 'open-map-tools']) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: key);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      viewModel.dispose();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }
}

/// A rectangle around the fake address point, as the area tool would draw.
const _riversideDowntown = GeoBounds(
  west: -117.38,
  south: 33.98,
  east: -117.36,
  north: 33.99,
);

/// A rectangle in the east of the county, holding no fake address point.
const _riversideDesert = GeoBounds(
  west: -115.5,
  south: 33.6,
  east: -115.4,
  north: 33.7,
);

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
    id: 'ca_riverside',
    label: 'Riverside County',
    stateName: 'California',
    extent: _riversideExtent,
  ),
  CountyOption(
    id: 'ca_san_bernardino',
    label: 'San Bernardino County',
    stateName: 'California',
    extent: _sanBernardinoExtent,
  ),
];

final class _FakeSitusAddressRepository implements SitusAddressRepository {
  _FakeSitusAddressRepository([this.situs]);

  final SitusAddress? situs;

  @override
  Future<SitusAddress?> lookupAt(LatLng point) async => situs;
}

/// Drags a rectangle across the map the way the area tool is used.
Future<void> _dragRectangle(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(Offset(to.dx, from.dy));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
}

GisMapViewModel _viewModel({
  UnclaimedPropertySearchResult? savedUnclaimedProperty,
  bool importingSnapshot = false,
  String countyName = 'Riverside County',
  String stateCode = 'CA',
  bool withImagery = true,
  bool parcelsAvailable = true,
  SitusAddress? resolvedSitus,
  Parcel? parcel,
  LayerCatalogRepository? layerCatalog,
  List<GisPortal> portals = const [],
  PortalDiscovery? portalDiscovery,
}) {
  final addresses = _FakeAddressRepository();
  final parcels = _FakeParcelRepository(parcel);
  return GisMapViewModel(
    countyName: countyName,
    stateCode: stateCode,
    countyExtent: _riversideExtent,
    liveAddresses: addresses,
    localAddresses: addresses,
    liveParcels: parcels,
    localParcels: parcels,
    boundaries: _FakeBoundaryRepository(),
    portalDiscovery: portalDiscovery,
    snapshotManager: _FakeSnapshotController(importing: importingSnapshot),
    propertyOwners: _FakePropertyOwnerRepository(),
    unclaimedProperties: _FakeUnclaimedPropertyRepository(
      savedUnclaimedProperty,
    ),
    imageryCatalog: withImagery ? _FakeImageryCatalogRepository() : null,
    overlayFeatures: _FakeOverlayFeatureRepository(),
    situsAddresses: _FakeSitusAddressRepository(resolvedSitus),
    alprCameras: _FakeAlprCameraRepository(),
    layerCatalog: layerCatalog,
    parcelsAvailable: parcelsAvailable,
    portals: portals,
  );
}

/// A catalogue that answers instantly with two drawable layers.
final class _FakeLayerCatalog implements LayerCatalogRepository {
  @override
  Future<List<CatalogService>> listServices(GisPortal portal) async => [
    CatalogService(
      portal: portal,
      name: 'OpenData/Assessor_Parcels',
      type: 'MapServer',
      themes: const ['parcels & assessor'],
    ),
  ];

  @override
  Future<Map<String, Object?>> describe(CatalogService service) async => {
    'layers': [
      {'id': 0, 'name': 'Layer'},
    ],
  };

  @override
  void forget(GisPortal portal) {}
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

/// An overlay source that never returns anything.
///
/// The catalogue is off by default and these tests never switch a layer on,
/// so the map should draw without ever reaching this.
final class _FakeOverlayFeatureRepository implements OverlayFeatureRepository {
  @override
  Future<List<OverlayFeature>> queryViewport(
    Uri layerQuery,
    GeoBounds bounds, {
    int limit = 1200,
  }) async => const [];
}

/// Records shares instead of presenting the platform share sheet.
final class _FakeSharing implements ContentSharing {
  final List<String> shared = [];
  final List<Rect> origins = [];
  bool fails = false;

  @override
  Future<void> shareText(String text, Rect origin) async {
    if (fails) throw StateError('share unavailable');
    shared.add(text);
    origins.add(origin);
  }

  @override
  Future<void> shareCsv(String contents, String fileName, Rect origin) async {
    if (fails) throw StateError('share unavailable');
    shared.add(contents);
    origins.add(origin);
  }
}
