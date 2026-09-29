import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';

void main() {
  group('UsGeography', () {
    test('covers every state, territory, and county', () {
      check(UsGeography.states).length.equals(56);
      check(UsGeography.counties).length.equals(3235);
      check(UsGeography.countiesIn('06')).length.equals(58);
    });

    test('parses a county the app already had baked in', () {
      final riverside = UsGeography.byId('ca_riverside');
      check(riverside).isNotNull();
      check(riverside!.fips).equals('06065');
      check(riverside.name).equals('Riverside County');
      check(riverside.stateFips).equals('06');
      check(riverside.countyFips).equals('065');
      check(riverside.displayName).equals('Riverside County, CA');
      check(riverside.extent.west).isCloseTo(-117.6763, 0.01);
      check(riverside.extent.north).isCloseTo(34.08, 0.01);
    });

    test('tells a county from an independent city of the same name', () {
      // Maryland publishes both, and an identifier that collapsed them would
      // scope one jurisdiction's snapshots onto the other's.
      check(UsGeography.byId('md_baltimore')!.fips).equals('24005');
      check(UsGeography.byId('md_baltimore_city')!.fips).equals('24510');
    });

    test('keeps the published legal type rather than saying County', () {
      check(UsGeography.byGeoid('22071')!.name).equals('Orleans Parish');
      check(UsGeography.byGeoid('02158')!.name).equals('Kusilvak Census Area');
      check(UsGeography.byGeoid('51510')!.name).equals('Alexandria city');
    });

    test('gives every county a unique identifier', () {
      final ids = UsGeography.counties.map((county) => county.id).toSet();
      check(ids).length.equals(UsGeography.counties.length);
    });

    test('states extent excludes the Pacific territories', () {
      // Guam sits across the antimeridian and belongs to nationExtent.
      check(UsGeography.statesExtent.west).isGreaterThan(-180);
      check(UsGeography.statesExtent.east).isLessThan(0);
      check(
        UsGeography.statesExtent.contains(const LatLng(33.98, -117.37)),
      ).isTrue();
    });

    test('every county has a usable centre and a non-empty extent', () {
      for (final county in UsGeography.counties) {
        check(
          because: '${county.id} extent',
          county.extent.east > county.extent.west &&
              county.extent.north > county.extent.south,
        ).isTrue();
      }
    });
  });
}
