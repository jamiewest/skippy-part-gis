"""Stage 8 — emit the Dart registry the app compiles in.

`docs/county-gis-inventory.json` is the source of truth; this turns it into
`lib/data/services/gis_portal_registry.g.dart`. Hand-maintaining 150-odd URLs
across 58 counties is how they go stale one at a time without anybody
noticing.

    python3 tool/gis_inventory/generate_dart.py
"""
import json
import os

import arcgis
from statewide import ROOTS as STATEWIDE_ROOTS

TARGET = os.path.join(
    arcgis.REPO, 'lib', 'data', 'services', 'gis_portal_registry.g.dart')

HEADER = '''// GENERATED — do not edit by hand.
//
// Written by tool/gis_inventory/generate_dart.py from
// docs/county-gis-inventory.json. To change what is here, re-run the
// inventory pipeline and regenerate:
//
//     python3 tool/gis_inventory/run.py
//     python3 tool/gis_inventory/generate_dart.py

import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

/// Public map catalogues, keyed by county id.
///
/// A county absent from this map published nothing this build could find,
/// which is not the same as publishing nothing. Those counties still get
/// [nationalPortals], and their state's entry in [statePortals].
const countyPortals = <String, List<GisPortal>>{
'''

FOOTER = '''};

/// Incorporated city catalogues, keyed by county id.
///
/// A city's catalogue applies to the city, not the county, so each carries
/// the bounds that say where it is worth offering. A city absent here
/// published nothing this build could find — or publishes through a root the
/// county tier already lists, which is deliberately not repeated.
const cityPortals = <String, List<CityPortals>>{
{cities}};

/// Catalogues covering the whole country, offered in every county.
///
/// Federal servers whose data does not stop at a state line: the Census
/// Bureau layer every county reads its own boundary from, the USGS National
/// Map, the National Weather Service, FEMA's flood hazard layers, the Forest
/// Service, the Park Service and the EPA.
///
/// This is what stops any county's layer panel opening empty, wherever it is.
const nationalPortals = <GisPortal>[
{national}];

/// State agency catalogues, keyed by two-digit state FIPS code.
///
/// A state agency's data stops at the state line, so offering it anywhere
/// else would attribute coverage the publisher never claimed — the same
/// provenance error [PortalTier] exists to prevent. CAL FIRE's hazard
/// severity zones are a fact about California and are offered in California.
///
/// A state absent here has no agency catalogue in this build. Its counties
/// still get [nationalPortals] and whatever they publish themselves.
const statePortals = <String, List<GisPortal>>{
{states}};
'''


def escape(value):
    return (value or '').replace('\\', r'\\').replace("'", r"\'")


def portal(root, publisher, tier, services, indent):
    pad = ' ' * indent
    return (f'{pad}GisPortal(\n'
            f"{pad}  root: '{escape(root)}',\n"
            f"{pad}  publisher: '{escape(publisher)}',\n"
            f'{pad}  tier: PortalTier.{tier},\n'
            f'{pad}  serviceCount: {services or 0},\n'
            f'{pad}),\n')


_ORG_NAMES = {}


def publisher_for(record, county_name, tier):
    """Who to credit a layer to.

    A citing organisation is not the publisher: City of Alameda's items link at
    half a dozen other organisations' hosted services, and crediting those to
    Alameda would be a false provenance claim. For an ArcGIS Online hosted
    root, the organisation in the path is the publisher and can be asked for
    its own name; for an on-premises server the host is the honest answer.
    """
    if tier == 'countyPortal':
        return f'{county_name} County'
    key = arcgis.hosted_org_key(record['root'])
    if key:
        if key not in _ORG_NAMES:
            payload = arcgis.fetch_json(
                f'https://www.arcgis.com/sharing/rest/portals/{key}?f=json')
            _ORG_NAMES[key] = (payload or {}).get('name')
        if _ORG_NAMES[key]:
            return _ORG_NAMES[key]
    return record['root'].split('/')[2]


def city_publisher(record, city_name):
    """`City of Corona`, not `CoBMAP City of Berkeley` or `Riverside, CA`.

    The organisation's own name is kept in the inventory JSON; the chip label
    the app shows is normalised, because a third of these orgs brand
    themselves with initialisms and suffixes that mean nothing in a layer
    panel. `Town of` survives — eighteen California cities are towns and say
    so.
    """
    original = (record.get('publisher') or '').lower()
    prefix = 'Town of' if 'town of' in original else 'City of'
    return f'{prefix} {city_name}'


def cities_block(inventory):
    lines = []
    groups = portals = 0
    for county_id, row in sorted(inventory['counties'].items()):
        cities = row.get('cities') or []
        if not cities:
            continue
        lines.append(f"  '{county_id}': [\n")
        for city in cities:
            groups += 1
            west, south, east, north = city['bounds']
            lines.append(
                f'    CityPortals(\n'
                f"      name: '{escape(city['name'])}',\n"
                f'      bounds: GeoBounds(\n'
                f'        west: {west},\n'
                f'        south: {south},\n'
                f'        east: {east},\n'
                f'        north: {north},\n'
                f'      ),\n'
                f'      portals: [\n')
            for record in city['portals']:
                portals += 1
                lines.append(portal(
                    record['root'], city_publisher(record, city['name']),
                    'city', record.get('serviceCount'), indent=8))
            lines.append('      ],\n    ),\n')
        lines.append('  ],\n')
    return ''.join(lines), groups, portals


def main():
    source = os.path.join(arcgis.DOCS, 'county-gis-inventory.json')
    inventory = json.load(open(source))

    lines = [HEADER]
    counties = 0
    portals = 0
    for county_id, row in sorted(inventory['counties'].items()):
        entries = [(record, 'countyPortal') for record in row['portals']]
        if not entries:
            entries = [(record, 'partner') for record in row['partners']
                       if (record.get('serviceCount') or 0) > 0]
        if not entries:
            continue
        counties += 1
        lines.append(f"  '{county_id}': [\n")
        for record, tier in entries:
            portals += 1
            lines.append(portal(
                record['root'],
                publisher_for(record, row['name'], tier),
                tier, record.get('serviceCount'), indent=4))
        lines.append('  ],\n')

    # The captured inventory records what each wide-area root is; `statewide.py`
    # records where it applies. Reading the scope from the root list rather
    # than the capture keeps one source of truth for it and means a re-scoped
    # root does not need the network stages re-run.
    scopes = {root: scope for root, _, scope in STATEWIDE_ROOTS}
    national = ''.join(
        portal(record['root'], record['publisher'], 'national',
               record.get('serviceCount'), indent=2)
        for record in inventory.get('statewide', {}).get('roots', [])
        if scopes.get(record['root'], 'national') == 'national')
    by_state = {}
    for record in inventory.get('statewide', {}).get('roots', []):
        scope = scopes.get(record['root'], 'national')
        if scope == 'national':
            continue
        by_state.setdefault(scope, []).append(record)
    states = ''
    for fips, records in sorted(by_state.items()):
        states += f"  '{fips}': [\n"
        states += ''.join(
            portal(record['root'], record['publisher'], 'statewide',
                   record.get('serviceCount'), indent=4)
            for record in records)
        states += '  ],\n'
    cities, city_groups, city_portals = cities_block(inventory)

    lines.append(FOOTER.replace('{cities}', cities)
                 .replace('{national}', national)
                 .replace('{states}', states))
    with open(TARGET, 'w') as handle:
        handle.write(''.join(lines))
    arcgis.progress(
        f'{portals} portals across {counties} counties, plus '
        f'{city_portals} portals across {city_groups} cities and '
        f'{national.count("GisPortal(")} national and '
        f'{states.count("GisPortal(")} state → '
        f'{os.path.relpath(TARGET, arcgis.REPO)}')


if __name__ == '__main__':
    main()
