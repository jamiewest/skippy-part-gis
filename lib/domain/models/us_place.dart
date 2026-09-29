import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// One state, the District of Columbia, or an inhabited territory.
///
/// States exist in the model because a county name does not identify a county
/// nationally: thirty-one states have a Washington County, and Maryland has
/// both a Baltimore County and an independent Baltimore city. Every lookup
/// that used to key on a county name now keys on a FIPS code, and the state is
/// what makes the picker navigable at 3,235 rows.
@immutable
final class UsState {
  /// Creates a state entry.
  const UsState({
    required this.abbreviation,
    required this.fips,
    required this.name,
    required this.center,
    required this.extent,
  });

  /// The two-letter USPS abbreviation, lower-cased, such as `ca`.
  ///
  /// This prefixes every county identifier in the state, so it is an on-disk
  /// contract for the same reason [UsCounty.id] is.
  final String abbreviation;

  /// Two-digit state FIPS code, such as `06`.
  final String fips;

  /// The state's name, such as `California`.
  final String name;

  /// The Census internal point, guaranteed to fall on the state's land.
  final LatLng center;

  /// The rectangle enclosing the state.
  final GeoBounds extent;

  /// The abbreviation as it is normally written, such as `CA`.
  String get displayAbbreviation => abbreviation.toUpperCase();

  @override
  bool operator ==(Object other) => other is UsState && other.fips == fips;

  @override
  int get hashCode => fips.hashCode;

  @override
  String toString() => 'UsState($displayAbbreviation)';
}

/// One county or county equivalent.
///
/// `County` is the common case but not the only one: this covers Louisiana
/// parishes, Alaska boroughs and census areas, Connecticut planning regions,
/// Puerto Rico municipios, and the independent cities of Virginia, Maryland,
/// Missouri, and Nevada. [name] carries whichever it is, because the Census
/// publishes it and renaming a parish a county would be wrong.
@immutable
final class UsCounty {
  /// Creates a county entry.
  const UsCounty({
    required this.id,
    required this.fips,
    required this.name,
    required this.center,
    required this.extent,
  });

  /// Stable identifier scoping snapshots, cached lookups, and saved settings.
  ///
  /// Written as the state abbreviation and the name, such as `ca_riverside`.
  /// This is an on-disk contract: changing an id orphans every snapshot row
  /// and every cached owner result saved under the old one, so the generator
  /// writes it down rather than deriving it at runtime.
  final String id;

  /// Five-digit state-plus-county FIPS code, such as `06065`.
  ///
  /// The one identifier every federal source agrees on. Census ACS, TIGERweb,
  /// and the national overlay tiers all key on it.
  final String fips;

  /// The full published name, such as `Riverside County` or `Orleans Parish`.
  final String name;

  /// The Census internal point, guaranteed to fall on the county's land.
  ///
  /// For a sprawling desert or island county this can be a long way from
  /// anywhere anyone lives; switching counties frames [extent] instead, so
  /// this only decides where a session opens.
  final LatLng center;

  /// The county's bounding rectangle, used to frame the map on a switch.
  final GeoBounds extent;

  /// Two-digit state FIPS code, such as `06`.
  String get stateFips => fips.substring(0, 2);

  /// Three-digit county FIPS code, such as `065`.
  String get countyFips => fips.substring(2);

  /// The two-letter state abbreviation this county's [id] is prefixed with.
  String get stateAbbreviation => id.substring(0, id.indexOf('_'));

  /// The name shown in the picker, such as `Riverside County, CA`.
  String get displayName => '$name, ${stateAbbreviation.toUpperCase()}';

  @override
  bool operator ==(Object other) => other is UsCounty && other.fips == fips;

  @override
  int get hashCode => fips.hashCode;

  @override
  String toString() => 'UsCounty($id)';
}

/// One municipal government: an incorporated place, or a minor civil division
/// in the states where those govern.
///
/// Unlike [UsState] and [UsCounty] this is not compiled in. There are about
/// 35,000 of them, they are only ever needed for the patch of map on screen,
/// and the Census publishes them live — so they are read from TIGERweb when
/// the map reaches a zoom where a municipality is what the user is looking at.
///
/// The distinction that matters is *governs*, not *is a populated area*. A
/// Texas census county division and a census designated place are drawn on
/// the same maps as a Connecticut town and mean something entirely different:
/// nobody administers them, so nobody publishes their GIS. The Census records
/// which is which in `FUNCSTAT`, and only the governing ones become a
/// [UsPlace].
@immutable
final class UsPlace {
  /// Creates a municipality.
  const UsPlace({
    required this.geoid,
    required this.name,
    required this.stateFips,
    required this.bounds,
  });

  /// The Census identifier, unique across places and subdivisions alike.
  ///
  /// This is what a search result is remembered under, so that panning back
  /// over a town does not search for it a second time.
  final String geoid;

  /// The name without its type suffix, such as `West Hartford`.
  ///
  /// The suffix is dropped because it is not how a government names itself:
  /// the Census writes `West Hartford town`, and the organisation publishing
  /// its data is `Town of West Hartford`.
  final String name;

  /// Two-digit state FIPS code of the state this place is in.
  final String stateFips;

  /// The rectangle enclosing the municipality.
  final GeoBounds bounds;

  @override
  bool operator ==(Object other) => other is UsPlace && other.geoid == geoid;

  @override
  int get hashCode => geoid.hashCode;

  @override
  String toString() => 'UsPlace($name)';
}
