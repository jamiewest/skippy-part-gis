import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

import 'support/fake_map_repositories.dart';

const _registered = GisPortal(
  root: 'https://gis.example.gov/arcgis/rest/services',
  publisher: 'Example County',
  tier: PortalTier.countyPortal,
);

const _national = GisPortal(
  root: 'https://tigerweb.geo.census.gov/arcgis/rest/services',
  publisher: 'US Census Bureau',
  tier: PortalTier.national,
);

/// A publisher found live, mapping one city inside the county.
const _cityBounds = GeoBounds(
  west: -117.6,
  south: 33.85,
  east: -117.4,
  north: 33.95,
);

const _discoveredCity = GisPortal(
  root: 'https://services2.arcgis.com/abcdefghij/arcgis/rest/services',
  publisher: 'City of Example',
  tier: PortalTier.city,
  coverage: _cityBounds,
  origin: PortalOrigin.discovered,
);

/// A publisher found live whose items blanket the state.
const _discoveredState = GisPortal(
  root: 'https://services1.arcgis.com/klmnopqrst/arcgis/rest/services',
  publisher: 'Example State Geographic Center',
  tier: PortalTier.statewide,
  coverage: GeoBounds(west: -124, south: 32, east: -114, north: 42),
  origin: PortalOrigin.discovered,
);

const _overCity = GeoBounds(
  west: -117.55,
  south: 33.88,
  east: -117.45,
  north: 33.92,
);

const _elsewhere = GeoBounds(
  west: -116.5,
  south: 34.2,
  east: -116.4,
  north: 34.3,
);

Future<void> _moveTo(
  WidgetTester tester,
  GisMapViewModel viewModel,
  GeoBounds bounds,
) async {
  viewModel.updateViewport(bounds, 13);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  _placeTests();

  testWidgets('a county with no registry entry still finds publishers', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => const [_discoveredCity, _discoveredState],
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.portals, const [_national]);
    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.idle);

    await viewModel.discoverPortals();

    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.found);
    expect(viewModel.portals, contains(_discoveredCity));
    expect(viewModel.portals, contains(_discoveredState));
  });

  testWidgets('local catalogues are offered before wide-area ones', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_registered, _national],
      portalDiscovery: () async => const [_discoveredState, _discoveredCity],
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.portals, const [
      _registered,
      _discoveredCity,
      _discoveredState,
      _national,
    ]);
  });

  testWidgets('a discovered publisher is offered only where it maps', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => const [_discoveredCity, _discoveredState],
    );
    addTearDown(viewModel.dispose);
    await viewModel.discoverPortals();

    await _moveTo(tester, viewModel, _overCity);
    expect(viewModel.portals, contains(_discoveredCity));

    await _moveTo(tester, viewModel, _elsewhere);
    expect(viewModel.portals, isNot(contains(_discoveredCity)));
    // The state publisher covers everywhere in the state, so it stays.
    expect(viewModel.portals, contains(_discoveredState));
  });

  testWidgets('a catalogue already in the registry is not listed twice', (
    tester,
  ) async {
    const duplicate = GisPortal(
      root: 'https://gis.example.gov/arcgis/rest/services',
      publisher: 'gis.example.gov',
      tier: PortalTier.partner,
      origin: PortalOrigin.discovered,
    );
    final viewModel = buildFakeMapViewModel(
      portals: const [_registered],
      portalDiscovery: () async => const [duplicate],
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.portals, const [_registered]);
    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.none);
  });

  testWidgets('a registered server found under another name is not repeated', (
    tester,
  ) async {
    // Riverside is registered as `gis.` and answers as `gis1.` as well, so a
    // search finds it under whichever name it was published under.
    const registeredAlias = GisPortal(
      root: 'https://gis1.example.gov/arcgis/rest/services',
      publisher: 'gis1.example.gov',
      tier: PortalTier.partner,
      origin: PortalOrigin.discovered,
    );
    final viewModel = buildFakeMapViewModel(
      portals: const [_registered],
      portalDiscovery: () async => const [registeredAlias],
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.portals, const [_registered]);
  });

  testWidgets('finding nothing is reported as an answer, not a failure', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => const [],
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.none);
    expect(viewModel.portals, const [_national]);
  });

  testWidgets('a failed search leaves the registry tiers intact', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => throw Exception('offline'),
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.unavailable);
    expect(viewModel.portals, const [_national]);
  });

  testWidgets('a county is searched once however often it is asked', (
    tester,
  ) async {
    var searches = 0;
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async {
        searches++;
        return const [_discoveredCity];
      },
    );
    addTearDown(viewModel.dispose);

    await Future.wait([
      viewModel.discoverPortals(),
      viewModel.discoverPortals(),
    ]);
    await viewModel.discoverPortals();

    expect(searches, 1);
  });

  testWidgets('offline mode does not search for catalogues it cannot draw', (
    tester,
  ) async {
    var searches = 0;
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      snapshotAvailable: true,
      portalDiscovery: () async {
        searches++;
        return const [_discoveredCity];
      },
    );
    addTearDown(viewModel.dispose);
    // Offline mode is refused until a snapshot is on disk, and that is read
    // by initialize, so the switch below would otherwise be a no-op.
    await viewModel.initialize();
    await viewModel.setMode(DataMode.offline);

    await viewModel.discoverPortals();

    expect(searches, 0);
    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.idle);

    await viewModel.setMode(DataMode.live);
    await viewModel.discoverPortals();

    expect(searches, 1);
  });

  testWidgets('a workspace with no search still lists its registry', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(portals: const [_national]);
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();

    expect(viewModel.discoveryAvailable, isFalse);
    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.idle);
    expect(viewModel.portals, const [_national]);
  });
}

/// A publisher found by searching for the municipality on screen.
const _discoveredTown = GisPortal(
  root: 'https://services5.arcgis.com/zzzzzzzzzz/arcgis/rest/services',
  publisher: 'Town of Example',
  tier: PortalTier.city,
  coverage: _cityBounds,
  origin: PortalOrigin.discovered,
);

void _placeTests() {
  testWidgets('the municipality search adds to the county search', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => const [_discoveredState],
      portalPlaceDiscovery: (_) async => const [_discoveredTown],
    );
    addTearDown(viewModel.dispose);

    await viewModel.discoverPortals();
    expect(viewModel.discoveredPortals, const [_discoveredState]);

    await _moveTo(tester, viewModel, _overCity);

    expect(viewModel.discoveredPortals, const [
      _discoveredState,
      _discoveredTown,
    ]);
    expect(viewModel.portals, contains(_discoveredTown));
  });

  testWidgets('a county-wide view searches for no municipality', (
    tester,
  ) async {
    var searches = 0;
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalPlaceDiscovery: (_) async {
        searches++;
        return const [_discoveredTown];
      },
    );
    addTearDown(viewModel.dispose);

    viewModel.updateViewport(_overCity, 8);
    await tester.pump(const Duration(milliseconds: 300));

    expect(searches, 0);
  });

  testWidgets('zooming further into searched ground searches nothing new', (
    tester,
  ) async {
    var searches = 0;
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalPlaceDiscovery: (_) async {
        searches++;
        return const [];
      },
    );
    addTearDown(viewModel.dispose);

    await _moveTo(tester, viewModel, _overCity);
    expect(searches, 1);

    // Inside the rectangle already searched.
    await _moveTo(
      tester,
      viewModel,
      const GeoBounds(west: -117.53, south: 33.89, east: -117.47, north: 33.91),
    );
    expect(searches, 1);

    // Somewhere else entirely.
    await _moveTo(tester, viewModel, _elsewhere);
    expect(searches, 2);
  });

  testWidgets('a failed municipality search leaves everything as it was', (
    tester,
  ) async {
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalDiscovery: () async => const [_discoveredState],
      portalPlaceDiscovery: (_) async => throw Exception('offline'),
    );
    addTearDown(viewModel.dispose);
    await viewModel.discoverPortals();

    await _moveTo(tester, viewModel, _overCity);

    expect(viewModel.discoveryStatus, PortalDiscoveryStatus.found);
    expect(viewModel.discoveredPortals, const [_discoveredState]);
  });

  testWidgets('the panel never grows past its cap however much is found', (
    tester,
  ) async {
    var round = 0;
    final viewModel = buildFakeMapViewModel(
      portals: const [_national],
      portalPlaceDiscovery: (_) async => [
        for (var index = 0; index < 10; index++)
          GisPortal(
            root:
                'https://services1.arcgis.com/org$round$index'
                '/arcgis/rest/services',
            publisher: 'Publisher $round$index',
            tier: PortalTier.partner,
            origin: PortalOrigin.discovered,
          ),
      ],
    );
    addTearDown(viewModel.dispose);

    for (round = 0; round < 6; round++) {
      await _moveTo(
        tester,
        viewModel,
        GeoBounds(
          west: -117.6 + round,
          south: 33.85,
          east: -117.4 + round,
          north: 33.95,
        ),
      );
    }

    expect(viewModel.discoveredPortals.length, lessThanOrEqualTo(24));
    expect(viewModel.discoveredPortals, isNotEmpty);
  });
}
