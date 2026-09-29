"""Turns `.work/geography.json` into `lib/data/services/us_geography.g.dart`.

The table is emitted as one packed string per level rather than 3,235 const
constructor calls. Both forms are compiled in; the packed form parses lazily on
first use, costs the analyzer nothing, and keeps the generated file reviewable.

    python3 tool/us_geography/generate_dart.py
"""

import json
import pathlib
import re
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORK = pathlib.Path(__file__).parent / ".work"
OUT = ROOT / "lib" / "data" / "services" / "us_geography.g.dart"

# Puerto Rico's municipios and the island territories are county equivalents
# with TIGERweb boundaries and, for Puerto Rico, ACS coverage. They are kept.
# What is dropped is anything with no outline, which cannot be framed.


def slug(text):
    """A snake_case identifier for `text`, with accents folded to ASCII."""
    folded = unicodedata.normalize("NFKD", text)
    ascii_only = "".join(c for c in folded if not unicodedata.combining(c))
    lowered = re.sub(r"[^a-z0-9]+", "_", ascii_only.lower())
    return lowered.strip("_")


def county_id(state_abbrev, name):
    """The stable identifier for a county.

    This is an on-disk contract: it scopes offline snapshots, cached owner
    lookups, and saved boundaries. It is written down by the generator rather
    than derived at runtime so that changing the derivation cannot silently
    orphan data already saved under the old form.

    The word `County` is dropped because 2,999 of 3,235 rows carry it and it
    says nothing. Every other legal type is kept, because it is what tells
    Baltimore County from Baltimore city -- both in Maryland, and otherwise
    the same identifier.
    """
    trimmed = re.sub(r"\s+County$", "", name)
    return f"{state_abbrev.lower()}_{slug(trimmed)}"


def escape(text):
    """`text` as the body of a single-quoted Dart string literal.

    County names carry apostrophes -- Prince George's, O'Brien, Lake of the
    Woods -- and a raw one closes the literal. Dollar signs would start an
    interpolation and backslashes an escape; neither appears today, but the
    encoder should not depend on that.
    """
    return text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def main():
    data = json.loads((WORK / "geography.json").read_text())
    states = {s["GEOID"]: s for s in data["states"]}

    state_rows = []
    for state in sorted(data["states"], key=lambda s: s["BASENAME"]):
        state_rows.append(
            "|".join(
                [
                    state["STUSAB"].lower(),
                    state["GEOID"],
                    state["BASENAME"],
                    f"{float(state['INTPTLAT']):.4f},{float(state['INTPTLON']):.4f}",
                    ",".join(str(v) for v in state["bounds"]),
                ]
            )
        )

    county_rows = []
    seen = {}
    for county in sorted(data["counties"], key=lambda c: (c["STATE"], c["NAME"])):
        state = states.get(county["STATE"])
        if state is None:
            # A county whose state is absent cannot be grouped or filtered.
            continue
        identifier = county_id(state["STUSAB"], county["NAME"])
        if identifier in seen:
            raise SystemExit(
                f"identifier collision: {identifier} is both "
                f"{seen[identifier]} and {county['GEOID']}"
            )
        seen[identifier] = county["GEOID"]
        county_rows.append(
            "|".join(
                [
                    identifier,
                    county["GEOID"],
                    county["NAME"],
                    f"{float(county['INTPTLAT']):.4f},{float(county['INTPTLON']):.4f}",
                    ",".join(str(v) for v in county["bounds"]),
                ]
            )
        )

    nation = [
        min(c["bounds"][0] for c in data["counties"]),
        min(c["bounds"][1] for c in data["counties"]),
        max(c["bounds"][2] for c in data["counties"]),
        max(c["bounds"][3] for c in data["counties"]),
    ]
    # The 50 states plus DC, without the Pacific territories, whose longitudes
    # straddle the antimeridian and would otherwise stretch the rectangle
    # across the whole planet.
    contiguous = [
        c
        for c in data["counties"]
        if c["STATE"] in {f"{i:02d}" for i in range(1, 57)}
        and c["bounds"][0] > -180
        and c["bounds"][2] < 0
    ]
    states_extent = [
        min(c["bounds"][0] for c in contiguous),
        min(c["bounds"][1] for c in contiguous),
        max(c["bounds"][2] for c in contiguous),
        max(c["bounds"][3] for c in contiguous),
    ]

    OUT.write_text(TEMPLATE.format(
        # Each row is escaped on its own, then joined with the two-character
        # sequence Dart reads back as a newline. Escaping after the join
        # would double that separator's backslash and split() would never
        # see a line break.
        states="\\n".join(escape(row) for row in state_rows),
        counties="\\n".join(escape(row) for row in county_rows),
        state_count=len(state_rows),
        county_count=len(county_rows),
        nation=", ".join(
            f"{k}: {v}" for k, v in zip(("west", "south", "east", "north"), nation)
        ),
        states_extent=", ".join(
            f"{k}: {v}"
            for k, v in zip(("west", "south", "east", "north"), states_extent)
        ),
    ))
    print(f"wrote {OUT}: {len(state_rows)} states, {len(county_rows)} counties")


TEMPLATE = '''// GENERATED -- do not edit by hand.
//
// Written by tool/us_geography/generate_dart.py from Census TIGERweb. To
// change what is here, re-run:
//
//     python3 tool/us_geography/fetch_geography.py
//     python3 tool/us_geography/generate_dart.py

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';

/// Every state, territory, and county the application knows about.
///
/// The identifiers, opening points, and framing rectangles come from the
/// Census Bureau's TIGERweb `State_County` service, read once at build time
/// and written down here. Starting the app, listing counties, and framing the
/// map therefore never wait on a network call; the outlines themselves are
/// still fetched live.
///
/// The tables are packed strings parsed on first use rather than {county_count}
/// const constructor calls, which the analyzer and the compiler both handle
/// far better at this size.
abstract final class UsGeography {{
  /// Every state, the District of Columbia, and the five inhabited
  /// territories, alphabetically.
  static List<UsState> get states => _states ??= _parseStates();

  /// Every county and county equivalent, by state then name.
  ///
  /// 3,235 rows covering counties, Louisiana parishes, Alaska boroughs and
  /// census areas, Connecticut planning regions, Puerto Rico municipios, and
  /// the independent cities of Virginia, Maryland, Missouri, and Nevada.
  static List<UsCounty> get counties => _counties ??= _parseCounties();

  /// The county whose stable identifier is [id], or null when none is.
  static UsCounty? byId(String id) => _countyIndex[id];

  /// The county whose five-digit FIPS code is [geoid], or null when none is.
  static UsCounty? byGeoid(String geoid) => _countyGeoidIndex[geoid];

  /// The state whose two-letter abbreviation is [abbreviation], lower-cased.
  static UsState? stateByAbbreviation(String abbreviation) =>
      _stateIndex[abbreviation.toLowerCase()];

  /// The state whose two-digit FIPS code is [fips], or null when none is.
  static UsState? stateByFips(String fips) => _stateFipsIndex[fips];

  /// Every county in the state whose two-digit FIPS code is [stateFips].
  static List<UsCounty> countiesIn(String stateFips) =>
      _byState[stateFips] ?? const [];

  /// The rectangle enclosing the 50 states and the District of Columbia.
  ///
  /// Pacific territories are excluded; [nationExtent] includes them.
  /// These data extents do not restrict map navigation.
  static const statesExtent = GeoBounds({states_extent});

  /// The rectangle enclosing every row in [counties], territories included.
  static const nationExtent = GeoBounds({nation});

  static List<UsState>? _states;
  static List<UsCounty>? _counties;

  static final Map<String, UsCounty> _countyIndex = {{
    for (final county in counties) county.id: county,
  }};

  static final Map<String, UsCounty> _countyGeoidIndex = {{
    for (final county in counties) county.fips: county,
  }};

  static final Map<String, UsState> _stateIndex = {{
    for (final state in states) state.abbreviation: state,
  }};

  static final Map<String, UsState> _stateFipsIndex = {{
    for (final state in states) state.fips: state,
  }};

  static final Map<String, List<UsCounty>> _byState = () {{
    final grouped = <String, List<UsCounty>>{{}};
    for (final county in counties) {{
      (grouped[county.stateFips] ??= []).add(county);
    }}
    return grouped;
  }}();

  static List<UsState> _parseStates() => List.unmodifiable([
    for (final row in _statesTable.split('\\n')) _parseState(row),
  ]);

  static List<UsCounty> _parseCounties() => List.unmodifiable([
    for (final row in _countiesTable.split('\\n')) _parseCounty(row),
  ]);

  static UsState _parseState(String row) {{
    final parts = row.split('|');
    return UsState(
      abbreviation: parts[0],
      fips: parts[1],
      name: parts[2],
      center: _point(parts[3]),
      extent: _bounds(parts[4]),
    );
  }}

  static UsCounty _parseCounty(String row) {{
    final parts = row.split('|');
    return UsCounty(
      id: parts[0],
      fips: parts[1],
      name: parts[2],
      center: _point(parts[3]),
      extent: _bounds(parts[4]),
    );
  }}

  static LatLng _point(String value) {{
    final parts = value.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }}

  static GeoBounds _bounds(String value) {{
    final parts = value.split(',');
    return GeoBounds(
      west: double.parse(parts[0]),
      south: double.parse(parts[1]),
      east: double.parse(parts[2]),
      north: double.parse(parts[3]),
    );
  }}

  /// `abbreviation|fips|name|lat,lon|west,south,east,north`, one per line.
  static const _statesTable =
      '{states}';

  /// `id|fips|name|lat,lon|west,south,east,north`, one per line.
  ///
  /// The centre is the Census internal point, which is guaranteed to fall
  /// inside the county's land area -- unlike a centroid, which for a
  /// horseshoe-shaped county can land outside it entirely.
  static const _countiesTable =
      '{counties}';
}}
'''


if __name__ == "__main__":
    main()
