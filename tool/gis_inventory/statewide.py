"""Stage 6 — the California State Geoportal, which applies to every county.

`gis.data.ca.gov` publishes a DCAT-US feed listing every dataset with its
service distributions, so the whole 3,990-dataset catalogue arrives in one
request and needs no discovery at all. The feed's value is the long tail of
agency hosts it names; the short list below is the subset carrying enough to
be worth a registry entry, each confirmed and enumerated like a county root.

Runtime: about five minutes, of which most is one 21 MB download.
"""
import json
from collections import Counter

import arcgis
from enumerate_services import enumerate_root
from themes import themes_of

DCAT = 'https://gis.data.ca.gov/api/feed/dcat-us/1.1.json'

# Publisher and scope per root. The publisher is so a layer can be attributed
# to the agency that made it rather than to whichever county the map happens
# to be showing. The scope is so it is only offered where it applies: a
# CAL FIRE hazard layer is not a fact about Texas, and listing it in a Texas
# county would be the same provenance error the publisher label exists to
# prevent. 'national' covers every county; a two-digit FIPS code covers one
# state.
ROOTS = [
    ('https://services.gis.ca.gov/arcgis/rest/services',
     'California State Geoportal', '06'),
    ('https://services2.arcgis.com/Uq9r85Potqm3MfRV/arcgis/rest/services',
     'California Department of Fish and Wildlife', '06'),
    ('https://services7.arcgis.com/iwxhJVOFEKDxO7gk/arcgis/rest/services',
     'California State Board of Equalization', '06'),
    ('https://gispublic.waterboards.ca.gov/portalserver/rest/services',
     'California Water Boards', '06'),
    ('https://gis.conservation.ca.gov/server/rest/services',
     'California Department of Conservation', '06'),
    ('https://caltrans-gis.dot.ca.gov/arcgis/rest/services', 'Caltrans', '06'),
    ('https://gis.water.ca.gov/arcgis/rest/services',
     'California Department of Water Resources', '06'),
    ('https://services1.arcgis.com/jUJYIo9tSA7EHvfZ/arcgis/rest/services',
     'CAL FIRE', '06'),
    ('https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services',
     "California Governor's Office of Emergency Services", '06'),
    ('https://hazards.fema.gov/arcgis/rest/services', 'FEMA', 'national'),
    ('https://gis.fema.gov/arcgis/rest/services', 'FEMA', 'national'),
    ('https://gis.wildlife.ca.gov/images/rest/services',
     'California Department of Fish and Wildlife', '06'),
    ('https://services3.arcgis.com/bWPjFyq029ChCGur/arcgis/rest/services',
     'California Energy Commission', '06'),
    # Federal servers whose coverage blankets the state, same tier as the
    # state agencies above. Each was probed live before being listed here;
    # the stage re-confirms them on every run and drops what has moved.
    ('https://tigerweb.geo.census.gov/arcgis/rest/services',
     'US Census Bureau', 'national'),
    ('https://carto.nationalmap.gov/arcgis/rest/services',
     'USGS National Map', 'national'),
    ('https://hydro.nationalmap.gov/arcgis/rest/services',
     'USGS National Map', 'national'),
    ('https://elevation.nationalmap.gov/arcgis/rest/services',
     'USGS National Map', 'national'),
    ('https://mapservices.weather.noaa.gov/eventdriven/rest/services',
     'National Weather Service', 'national'),
    ('https://mapservices.weather.noaa.gov/static/rest/services',
     'National Weather Service', 'national'),
    ('https://gis.blm.gov/caarcgis/rest/services',
     'Bureau of Land Management California', '06'),
    ('https://apps.fs.usda.gov/arcx/rest/services', 'US Forest Service', 'national'),
    ('https://mapservices.nps.gov/arcgis/rest/services',
     'National Park Service', 'national'),
    ('https://geopub.epa.gov/arcgis/rest/services',
     'US Environmental Protection Agency', 'national'),
]


def first(value):
    if isinstance(value, list):
        return value[0] if value else None
    return value


def summarise_feed():
    """Publisher and theme counts from the DCAT feed, for the written report.

    Returns None when the feed is unreachable; it is descriptive colour, not
    something a later stage depends on.
    """
    payload = arcgis.fetch_json(DCAT, timeout=180, limit=64_000_000)
    datasets = (payload or {}).get('dataset')
    if not datasets:
        arcgis.progress('DCAT feed unavailable; skipping catalogue summary')
        return None
    publishers = Counter(
        first((row.get('publisher') or {}).get('name')) for row in datasets)
    themes = Counter()
    for row in datasets:
        for theme in themes_of(first(row.get('title'))):
            themes[theme] += 1
    return {'datasets': len(datasets),
            'publishers': publishers.most_common(12),
            'titleThemes': themes.most_common()}


def confirm(task):
    root, publisher, scope = task
    payload = cors = None
    # One retry: these servers flake individually and transiently, and a
    # root dropped here silently vanishes from all 58 counties.
    for _ in range(2):
        payload, cors = arcgis.fetch(f'{root}?f=json', limit=2_000_000)
        if isinstance(payload, dict) and 'currentVersion' in payload:
            break
    if not isinstance(payload, dict) or 'currentVersion' not in payload:
        arcgis.progress(f'  unreachable: {root}')
        return None
    return {'root': root, 'publisher': publisher, 'tier': 'statewide',
            'scope': scope,
            'currentVersion': payload.get('currentVersion'),
            'folders': payload.get('folders') or [],
            'services': payload.get('services') or [], 'cors': cors}


def carried_forward(root, publisher, scope):
    """The previous inventory's record for a root that is down right now.

    Statewide servers 503 for an afternoon and come back; deleting one on a
    failed probe would remove its layers from all 58 counties over a bad
    hour. The stale count is kept and marked, and the next successful run
    replaces it.
    """
    try:
        previous = json.load(open(f'{arcgis.DOCS}/county-gis-inventory.json'))
    except (FileNotFoundError, ValueError):
        return None
    for entry in (previous.get('statewide') or {}).get('roots', []):
        if entry.get('root') == root and entry.get('serviceCount'):
            arcgis.progress(f'  carried forward from last inventory: {root}')
            return {**entry, 'publisher': publisher, 'tier': 'statewide',
                    'scope': scope, 'carriedForward': True}
    return None


def main():
    arcgis.progress(f'confirming {len(ROOTS)} statewide roots')
    found = []
    for task, entry in zip(ROOTS, arcgis.in_parallel(confirm, ROOTS,
                                                     workers=8)):
        entry = entry or carried_forward(*task)
        if entry:
            found.append(entry)
    live = [entry for entry in found if not entry.get('carriedForward')]
    arcgis.progress(f'enumerating {len(live)} roots')
    arcgis.in_parallel(enumerate_root, live, workers=6)
    found = [entry for entry in found if entry.get('serviceCount')]
    found.sort(key=lambda entry: -entry['serviceCount'])
    for entry in found:
        entry.pop('services', None)

    arcgis.write_work('statewide.json',
                      {'catalogue': 'https://gis.data.ca.gov',
                       'feed': summarise_feed(), 'roots': found})
    total = sum(entry['serviceCount'] for entry in found)
    arcgis.progress(f'{len(found)} statewide roots, {total} services')


if __name__ == '__main__':
    main()
