"""Stage 7 — write the registry and the per-county table into `docs/`.

`county-gis-inventory.json` is what the Dart generator reads; the table is
regenerated into `county-gis-inventory.md` between its markers so the prose
around it survives.
"""
import datetime
import json
from collections import Counter

import arcgis

BUCKETS = {'county-portal': 'portals', 'partner': 'partners',
           'statewide': 'statewide', 'rejected-wrong-place': 'rejected',
           'unattributed': 'partners', 'alias': 'aliases'}

TABLE_START = '<!-- county-table -->'
TABLE_END = '<!-- /county-table -->'


def build(roots, statewide, cities):
    counties = arcgis.counties()
    registry = {county['id']: {
        'countyId': county['id'], 'name': county['name'],
        'fips': county['fips'], 'portals': [], 'partners': [], 'cities': [],
        'statewide': [], 'rejected': [], 'aliases': []} for county in counties}

    for city in cities:
        registry[city['countyId']]['cities'].append({
            'cityId': city['cityId'], 'name': city['name'],
            'bounds': city['bounds'],
            'portals': [{key: portal.get(key) for key in (
                'root', 'publisher', 'via', 'geoVerdict', 'cors',
                'serviceCount', 'serviceTypes', 'themes')}
                for portal in city['portals']]})

    for entry in roots:
        record = {key: entry.get(key) for key in (
            'root', 'via', 'geoVerdict', 'cors', 'currentVersion', 'folders',
            'serviceCount', 'serviceTypes', 'themes', 'aliasOf')}
        record['citedBy'] = [cite.get('orgName')
                             for cite in entry.get('citedBy') or []]
        registry[entry['countyId']][BUCKETS[entry['tier']]].append(record)

    for row in registry.values():
        row['portals'].sort(key=lambda r: -(r['serviceCount'] or 0))
        row['partners'].sort(key=lambda r: -(r['serviceCount'] or 0))
        row['countyServiceCount'] = sum(r['serviceCount'] or 0
                                        for r in row['portals'])
        themes = Counter()
        for portal in row['portals']:
            themes.update(portal['themes'] or {})
        row['themes'] = dict(themes.most_common())
        row['coverage'] = ('first-party' if row['portals'] else
                           'partner-only' if row['partners'] else 'none-found')
    return registry


def table(registry):
    lines = ['| County | Coverage | Services | Primary root | Other roots '
             '| Cities | Top themes |',
             '| --- | --- | ---: | --- | ---: | ---: | --- |']
    for row in sorted(registry.values(), key=lambda r: r['name']):
        portals = row['portals']
        fallback = row['partners'][0]['root'] if row['partners'] else None
        primary = portals[0]['root'] if portals else fallback
        primary = f'`{primary}`' if primary else '—'
        others = max(len(portals) - 1, 0) or ''
        themes = ', '.join(list(row['themes'])[:3]) or '—'
        lines.append(f"| {row['name']} | {row['coverage']} | "
                     f"{row['countyServiceCount'] or ''} | {primary} | "
                     f"{others} | {len(row['cities']) or ''} | {themes} |")
    return '\n'.join(lines)


def main():
    roots = arcgis.read_work('roots.json')
    # No default: a missing statewide.json would emit a registry with no
    # statewide tier, and `generate_dart.py` would then compile an empty
    # `statewidePortals` — silently removing flood, fire and highway layers
    # from all 58 counties. `.work/` is git-ignored, so that is exactly the
    # state a fresh clone starts in. Fail rather than degrade.
    statewide = arcgis.read_work('statewide.json')
    # Same reasoning as statewide: emitting without cities.json would
    # silently drop every city catalogue from the registry.
    cities = arcgis.read_work('cities.json')
    registry = build(roots, statewide, cities)

    payload = {
        'generated': datetime.date.today().isoformat(),
        'note': 'Discovered by probing public ArcGIS REST catalogues; see '
                'docs/county-gis-inventory.md for method and limits.',
        'counties': registry,
    }
    if not statewide.get('roots'):
        raise SystemExit(
            'statewide.json holds no roots — run the statewide stage first. '
            'Emitting without it would silently drop the flood, fire and '
            'highway layers from all 58 counties.')
    payload['statewide'] = {
        'note': 'Applies to every county. Discovered from the California '
                'State Geoportal DCAT feed at https://gis.data.ca.gov '
                'plus the state ArcGIS Server this app already reads '
                'county boundaries from.',
        'catalogue': statewide.get('catalogue'),
        'datasetsListed': (statewide.get('feed') or {}).get('datasets'),
        'roots': [{key: entry.get(key) for key in (
            'root', 'publisher', 'cors', 'currentVersion', 'folders',
            'serviceCount', 'serviceTypes', 'themes')}
            for entry in statewide['roots']],
    }

    target = f'{arcgis.DOCS}/county-gis-inventory.json'
    with open(target, 'w') as handle:
        json.dump(payload, handle, indent=1)

    report = f'{arcgis.DOCS}/county-gis-inventory.md'
    try:
        prose = open(report).read()
    except FileNotFoundError:
        prose = None
    if prose and TABLE_START in prose and TABLE_END in prose:
        head, rest = prose.split(TABLE_START, 1)
        _, tail = rest.split(TABLE_END, 1)
        with open(report, 'w') as handle:
            handle.write(f'{head}{TABLE_START}\n{table(registry)}\n'
                         f'{TABLE_END}{tail}')
        arcgis.progress('county table refreshed in county-gis-inventory.md')
    else:
        arcgis.progress('no <!-- county-table --> markers; JSON only')

    tiers = Counter(row['coverage'] for row in registry.values())
    services = sum(row['countyServiceCount'] for row in registry.values())
    portals = sum(len(row['portals']) for row in registry.values())
    city_count = sum(len(row['cities']) for row in registry.values())
    arcgis.progress(f'{dict(tiers)}; {portals} roots, {services} services, '
                    f'{city_count} cities with a catalogue')


if __name__ == '__main__':
    main()
