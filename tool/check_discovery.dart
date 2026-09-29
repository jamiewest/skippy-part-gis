// Runs the live catalogue search against real counties and prints what it
// finds. Not a test: it talks to ArcGIS Online, so its answers change as
// publishers do. It is how you check that discovery still works, and what a
// county actually gets, without launching the app.
//
//     flutter test tool/check_discovery.dart
//
// It runs under `flutter test` rather than `dart run` because the geography
// table it reads is part of the Flutter package. It lives outside `test/` so
// that `flutter test` never picks it up: the suite must not depend on a
// third party being reachable. Edit [_counties] to check
// somewhere else; the codes are five-digit county FIPS.
// Printing is the point: this is a report a person reads in the terminal.
// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/portal_discovery_service.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// Six counties chosen for what each one breaks:
///
/// * `09110` Capitol Planning Region, CT — no county government at all, so
///   the county channel finds nothing and the municipality channel is the
///   only one that can answer. The sharpest test of the whole feature.
/// * `48113` Dallas, TX — a strong county publisher and several cities.
/// * `39035` Cuyahoga, OH — a server answering on two hostnames.
/// * `04013` Maricopa, AZ — a city that writes itself `Buckeye, Arizona`,
///   which must not be read as a state agency.
/// * `49053` Washington, UT — a name that repeats in thirty-one states.
/// * `06065` Riverside, CA — already in the registry, so this checks that
///   discovery does not list a registered catalogue a second time.
const _counties = ['09110', '48113', '39035', '04013', '49053', '06065'];

/// A city-level viewport inside each county, to exercise the place channel.
const _viewports = <String, GeoBounds>{
  '48113': GeoBounds(west: -96.85, south: 32.74, east: -96.72, north: 32.83),
  '39035': GeoBounds(west: -81.75, south: 41.45, east: -81.62, north: 41.55),
  '04013': GeoBounds(west: -112.12, south: 33.42, east: -111.98, north: 33.52),
  '49053': GeoBounds(west: -113.63, south: 37.06, east: -113.5, north: 37.16),
  '06065': GeoBounds(west: -117.44, south: 33.84, east: -117.31, north: 33.94),
  '09110': GeoBounds(west: -72.75, south: 41.73, east: -72.63, north: 41.82),
};

void main() {
  test(
    'discovery finds live catalogues',
    _report,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _report() async {
  final client = http.Client();
  final discovery = PortalDiscoveryService(client);
  for (final code in _counties) {
    final county = UsGeography.byGeoid(code);
    final state = county == null
        ? null
        : UsGeography.stateByFips(county.stateFips);
    if (county == null || state == null) {
      print('$code — no such county');
      continue;
    }
    final started = DateTime.now();
    final portals = await discovery.discover(county: county, state: state);
    final elapsed = DateTime.now().difference(started);
    print(
      '\n${county.displayName} — ${portals.length} found '
      'in ${elapsed.inMilliseconds}ms',
    );
    for (final portal in portals) {
      print('  ${portal.tier.name.padRight(12)} ${portal.publisher}');
    }
    if (_viewports[code] case final viewport?) {
      final placeStart = DateTime.now();
      final nearby = await discovery.discoverPlaces(
        viewport: viewport,
        county: county,
        state: state,
      );
      final extra = nearby.where((p) => !portals.contains(p)).toList();
      final placeMs = DateTime.now().difference(placeStart).inMilliseconds;
      print(
        '  + ${extra.length} more from the municipalities on screen '
        '(${placeMs}ms):',
      );
      for (final portal in extra) {
        print('    ${portal.tier.name.padRight(12)} ${portal.publisher}');
      }
    }
  }
  client.close();
}
