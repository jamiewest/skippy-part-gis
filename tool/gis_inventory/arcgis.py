"""Shared plumbing for the county GIS inventory pipeline.

Everything here is deliberately dependency-free: `urllib` and the standard
library only, so the pipeline runs on a stock Python 3 without a virtualenv.
"""
import json
import math
import os
import re
import ssl
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.work')
DOCS = os.path.join(REPO, 'docs')
COUNTIES_DART = os.path.join(
    REPO, 'lib', 'data', 'services', 'us_geography.g.dart')

USER_AGENT = 'Mozilla/5.0 riverside-atlas-inventory'

# County ArcGIS servers are routinely deployed with an expired or
# hostname-mismatched certificate. Refusing them would drop real public data
# for a reason that has nothing to do with the data, so verification is off
# and nothing here sends credentials.
_CONTEXT = ssl.create_default_context()
_CONTEXT.check_hostname = False
_CONTEXT.verify_mode = ssl.CERT_NONE


def work_path(name):
    """Path to an intermediate file, creating the work directory if needed."""
    os.makedirs(WORK, exist_ok=True)
    return os.path.join(WORK, name)


def read_work(name, default=None):
    try:
        with open(work_path(name)) as handle:
            return json.load(handle)
    except FileNotFoundError:
        if default is None:
            raise SystemExit(
                f'{name} is missing — run the earlier stage first '
                f'(see tool/gis_inventory/README.md).')
        return default


def write_work(name, payload):
    with open(work_path(name), 'w') as handle:
        json.dump(payload, handle, indent=1)
    return payload


def fetch(url, timeout=30, origin='https://example.org', limit=4_000_000):
    """GET `url` as JSON, returning `(payload, allowOriginHeader)`.

    Returns `(None, None)` for anything that fails, because a probe that
    cannot distinguish "no server" from "server had a bad day" would rather
    under-report than invent a root. Sending `Origin` is what makes the CORS
    header in the response meaningful.
    """
    request = urllib.request.Request(url, headers={
        'Accept': 'application/json',
        'Origin': origin,
        'User-Agent': USER_AGENT,
    })
    try:
        with urllib.request.urlopen(
                request, timeout=timeout, context=_CONTEXT) as response:
            body = response.read(limit).decode('utf-8', 'replace')
            cors = response.headers.get('Access-Control-Allow-Origin')
    except Exception:
        return None, None
    try:
        return json.loads(body), cors
    except ValueError:
        return None, None


def fetch_json(url, **kwargs):
    """`fetch` when only the payload matters."""
    return fetch(url, **kwargs)[0]


def arcgis_search(query, start=1, num=100):
    """One page of the ArcGIS Online item search."""
    return fetch_json(
        'https://www.arcgis.com/sharing/rest/search?' + urllib.parse.urlencode(
            {'q': query, 'num': num, 'start': start, 'f': 'json'}))


def in_parallel(function, items, workers=12):
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(function, items))


def counties():
    """Every California county, read from the app's own geography table.

    `us_geography.g.dart` is the app's national list of identifiers, FIPS
    codes and extents. This pipeline is California-scoped -- its host guessing,
    its organisation search and its "is it in the county?" test are all tuned
    for one state -- so it takes the California rows and leaves the rest alone.
    Reading them from the app rather than restating them here is what stops the
    two drifting.
    """
    source = open(COUNTIES_DART, encoding='utf-8').read()
    rows = []
    # The table is one packed string: `id|fips|name|lat,lon|w,s,e,n` per row,
    # rows separated by the two-character sequence Dart reads as a newline.
    for row in re.split(r'\\n', source):
        parts = row.split('|')
        if len(parts) != 5 or not parts[1].startswith('06'):
            continue
        identifier = parts[0].split("'")[-1]
        if not identifier.startswith('ca_'):
            continue
        box = [float(v) for v in parts[4].split(',')[:4]]
        rows.append({
            'id': identifier,
            'name': re.sub(r'\s+County$', '', parts[2]),
            'fips': parts[1],
            'west': box[0], 'south': box[1], 'east': box[2], 'north': box[3],
        })
    if len(rows) != 58:
        raise SystemExit(
            f'parsed {len(rows)} California counties from us_geography.g.dart, '
            'expected 58 - the file format changed.')
    return rows


def counties_by_id():
    return {county['id']: county for county in counties()}


def overlaps(box, county):
    """Whether a `[west, south, east, north]` box meets the county's."""
    if box is None:
        return None
    west, south, east, north = box
    return not (east < county['west'] or west > county['east'] or
                north < county['south'] or south > county['north'])


def item_extent(extent):
    """An ArcGIS Online item's `[[w, s], [e, n]]` as a flat box."""
    if not (isinstance(extent, list) and len(extent) == 2):
        return None
    try:
        (west, south), (east, north) = extent
    except (ValueError, TypeError):
        return None
    values = (west, south, east, north)
    if not all(isinstance(value, (int, float)) for value in values):
        return None
    return [west, south, east, north]


def service_extent(extent, wkid):
    """A service `fullExtent` as WGS84, or None if it cannot be converted.

    Only the two projections that need no projection library are handled.
    Everything else is answered by asking the server itself — see
    `reprojected_layer_extent`.
    """
    if not isinstance(extent, dict):
        return None
    values = (extent.get('xmin'), extent.get('ymin'),
              extent.get('xmax'), extent.get('ymax'))
    if not all(isinstance(value, (int, float)) for value in values):
        return None
    xmin, ymin, xmax, ymax = values
    if wkid in (4326, 4269, 4152):
        return [xmin, ymin, xmax, ymax]
    if wkid in (3857, 102100, 102113):
        scale = 180 / 20037508.342789244
        return [xmin * scale, _mercator_latitude(ymin),
                xmax * scale, _mercator_latitude(ymax)]
    return None


def _mercator_latitude(y):
    return math.degrees(2 * math.atan(math.exp(y / 6378137.0)) - math.pi / 2)


def reprojected_layer_extent(layer_url):
    """Ask a layer for its extent in WGS84.

    Most county servers publish in California State Plane, which this pipeline
    deliberately cannot reproject. It does not need to: an ArcGIS layer will
    reproject on request, so the server answers the containment question
    itself.
    """
    payload = fetch_json(
        f'{layer_url}/query?where=1%3D1&returnExtentOnly=true'
        '&outSR=4326&f=json')
    extent = (payload or {}).get('extent') or {}
    values = (extent.get('xmin'), extent.get('ymin'),
              extent.get('xmax'), extent.get('ymax'))
    if not all(isinstance(value, (int, float)) for value in values):
        return None
    return list(values)


def rest_root_of(url):
    """The `.../rest/services` root a service URL belongs to."""
    if not isinstance(url, str):
        return None
    lowered = url.lower()
    marker = '/rest/services'
    if marker not in lowered:
        return None
    return url[:lowered.index(marker) + len(marker)]


def hosted_org_key(root):
    """The organisation id an ArcGIS Online hosted root belongs to.

    A hosted root belongs to the org named in its path whoever links to it —
    without this, Esri's own demographics org gets filed under El Dorado
    County merely because El Dorado's items reference it.
    """
    parts = root.split('/')
    if len(parts) <= 3 or not parts[2].lower().endswith('arcgis.com'):
        return None
    if parts[3].lower() == 'tiles':
        return parts[4].lower() if len(parts) > 4 else None
    return parts[3].lower()


def progress(message):
    print(message, file=sys.stderr, flush=True)
