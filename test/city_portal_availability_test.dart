import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

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

const _cityPortal = GisPortal(
  root: 'https://services.arcgis.com/example/arcgis/rest/services',
  publisher: 'City of Example',
  tier: PortalTier.city,
);

const _city = CityPortals(
  name: 'Example',
  bounds: GeoBounds(west: -117.6, south: 33.85, east: -117.4, north: 33.95),
  portals: [_cityPortal],
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

GisMapViewModel _viewModel() => buildFakeMapViewModel(
  portals: const [_countyPortal, _statewidePortal],
  cities: const [_city],
);

/// Moves the map and lets the viewport debounce fire.
///
/// City availability is recomputed on the debounced path, not on the
/// `updateViewport` call itself, so a test reading [GisMapViewModel.portals]
/// immediately would see the previous set.
Future<void> _moveTo(
  WidgetTester tester,
  GisMapViewModel viewModel,
  GeoBounds bounds,
  double zoom,
) async {
  viewModel.updateViewport(bounds, zoom);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('city catalogues stay hidden until the map is over the city', (
    tester,
  ) async {
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    expect(viewModel.portals, isNot(contains(_cityPortal)));

    await _moveTo(tester, viewModel, _elsewhere, 13);
    expect(viewModel.portals, isNot(contains(_cityPortal)));

    await _moveTo(tester, viewModel, _overCity, 13);
    expect(viewModel.portals, [_countyPortal, _cityPortal, _statewidePortal]);
  });

  testWidgets('a county-wide view offers no city catalogue', (tester) async {
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    await _moveTo(tester, viewModel, _overCity, 8);

    expect(viewModel.portals, isNot(contains(_cityPortal)));
  });

  testWidgets('panning away removes the city again', (tester) async {
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);

    await _moveTo(tester, viewModel, _overCity, 13);
    expect(viewModel.portals, contains(_cityPortal));

    await _moveTo(tester, viewModel, _elsewhere, 13);
    expect(viewModel.portals, isNot(contains(_cityPortal)));
  });

  testWidgets('moving the map never notifies during a build', (tester) async {
    // `onPositionChanged` fires from inside the map's own build, so a
    // synchronous notification here is a markNeedsBuild-during-build crash.
    final viewModel = _viewModel();
    addTearDown(viewModel.dispose);
    var notifiedSynchronously = false;
    viewModel.addListener(() => notifiedSynchronously = true);

    viewModel.updateViewport(_overCity, 13);

    expect(notifiedSynchronously, isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.portals, contains(_cityPortal));
  });
}
