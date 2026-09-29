"""Stage — find each incorporated city's public GIS.

The county pipeline's strongest channels, pointed at the 483 incorporated
cities. Hostname guessing is deliberately absent: it found only 21 of the 130
county roots and would mean tens of thousands of DNS probes here. What worked
for counties — self-verifying ArcGIS Online vanity subdomains, item search,
and roots harvested from item URLs — is what runs.

A city organisation is accepted only when its *name* claims the city ("City of
Riverside, CA"), because geography alone cannot tell the City of Riverside
from Riverside County, and a name alone cannot tell it from Riverside,
Missouri. Both checks run; both must pass.

Roots already registered to a county (first-party, partner or statewide) are
skipped rather than re-listed — the eight counties covered by a city's
catalogue, Alameda among them, would otherwise show every city layer twice.

Runtime: about forty minutes, almost all of it ArcGIS Online.
"""
import re
import unicodedata
from collections import Counter

import arcgis
from classify_roots import verify_location
from enumerate_services import enumerate_root

CITY_BOUNDARIES = ('https://services1.arcgis.com/jUJYIo9tSA7EHvfZ/arcgis/'
                   'rest/services/California_Incorporated_City_Boundaries/'
                   'FeatureServer/0/query')

ITEM_TYPES = ('type:"Feature Service" OR type:"Map Service" OR '
              'type:"Image Service" OR type:"Vector Tile Service"')

# Organisations that pass a city name test while not being the city
# government. 'county' is the important one: every "<City> County" org
# contains its namesake city's tokens.
NOT_CITY_GOV = re.compile(
    r'county|college|universit|school|unified|chamber|association|church|'
    r'realtors|conservancy|water ?district|utility district|tribe|rancheria|'
    r'esri |\bcog\b|council of governments', re.I)

# Vanity subdomains the generic patterns miss, each confirmed by probing.
CITY_ALIASES = {
    'los_angeles': ['lahub'],
    'san_jose': ['csj'],
    'chula_vista': ['cvgis'],
    'moreno_valley': ['moval'],
}


def slug_of(name):
    return re.sub(r'[^a-z]+', '_', name.lower()).strip('_')


def city_list():
    """Every incorporated city with its county and WGS84 bounding box.

    Read from CAL FIRE's city boundaries layer — 483 polygons with a COUNTY
    attribute, so no centroid-in-county guessing near county lines. Geometry
    is requested generalised: only the box is kept.
    """
    cached = arcgis.read_work('cities_list.json', default=[])
    if cached:
        return cached
    counties = {county['name'].lower(): county['id']
                for county in arcgis.counties()}
    cities = []
    offset = 0
    while True:
        payload = arcgis.fetch_json(
            f'{CITY_BOUNDARIES}?where=1%3D1&outFields=CITY,COUNTY'
            f'&outSR=4326&maxAllowableOffset=0.005&resultOffset={offset}'
            '&f=json', timeout=120, limit=32_000_000)
        features = (payload or {}).get('features') or []
        if not features:
            break
        for feature in features:
            name = (feature.get('attributes') or {}).get('CITY')
            county = ((feature.get('attributes') or {}).get('COUNTY')
                      or '').lower()
            rings = (feature.get('geometry') or {}).get('rings') or []
            points = [point for ring in rings for point in ring]
            if not name or county not in counties or not points:
                continue
            cities.append({
                'cityId': slug_of(name), 'name': name,
                'countyId': counties[county],
                'bounds': [round(min(p[0] for p in points), 4),
                           round(min(p[1] for p in points), 4),
                           round(max(p[0] for p in points), 4),
                           round(max(p[1] for p in points), 4)]})
        offset += len(features)
        if not (payload or {}).get('exceededTransferLimit'):
            break
    if len(cities) < 400:
        raise SystemExit(f'read {len(cities)} cities from the boundaries '
                         'layer, expected ~483 — refusing a partial list.')
    return arcgis.write_work('cities_list.json', sorted(
        cities, key=lambda city: city['cityId']))


def subdomains(city):
    slug = city['name'].lower().replace(' ', '')
    dashed = city['name'].lower().replace(' ', '-')
    keys = [f'cityof{slug}', f'{slug}ca', f'cityof{slug}ca', slug,
            f'{slug}gis', f'townof{slug}']
    if dashed != slug:
        keys.append(dashed)
    return list(dict.fromkeys(keys + CITY_ALIASES.get(city['cityId'], [])))


def _ascii(text):
    # "City of San José" must match San Jose; NFKD strips the accent
    # rather than deleting the letter it sits on.
    decomposed = unicodedata.normalize('NFKD', text.lower())
    return re.sub(r'[^a-z]', '', decomposed)


def names_city(text, city):
    if not text:
        return False
    flat = _ascii(text)
    tokens = [_ascii(word) for word in city['name'].lower().split()
              if len(word) > 2] or [_ascii(city['name'])]
    return all(token in flat for token in tokens)


def is_city_gov(org, city):
    label = f"{org.get('orgName') or ''} {org.get('urlKey') or ''}"
    return not NOT_CITY_GOV.search(label) and names_city(label, city)


def portal_self(candidate):
    city_id, key = candidate
    payload = arcgis.fetch_json(
        f'https://{key}.maps.arcgis.com/sharing/rest/portals/self?f=json',
        timeout=20)
    if not payload or not payload.get('id'):
        return None
    return {'cityId': city_id, 'orgId': payload['id'],
            'urlKey': payload.get('urlKey') or key,
            'orgName': payload.get('name'), 'via': 'org-subdomain'}


def search_candidates(city):
    """Org ids of ArcGIS Online items published under the city's name."""
    counts = Counter()
    for prefix in ('City of', 'Town of'):
        payload = arcgis.arcgis_search(
            f'"{prefix} {city["name"]}" AND ({ITEM_TYPES})', num=50)
        for item in (payload or {}).get('results') or []:
            if item.get('orgId'):
                counts[item['orgId']] += 1
    return [org for org, _ in counts.most_common(4)]


def describe(org_id):
    payload = arcgis.fetch_json(
        f'https://www.arcgis.com/sharing/rest/portals/{org_id}?f=json')
    return ((payload or {}).get('name'), (payload or {}).get('urlKey'))


def verify(org, county):
    """Score an organisation by how much of its data sits in the county.

    The *county* box, not the city's: city data legitimately covers spheres
    of influence and utility service areas beyond the limits, and the check
    only exists to reject same-named cities in other states.
    """
    payload = arcgis.arcgis_search(f'orgid:{org["orgId"]} AND ({ITEM_TYPES})')
    results = (payload or {}).get('results', [])
    checked = inside = 0
    hosts = Counter()
    for item in results:
        verdict = arcgis.overlaps(arcgis.item_extent(item.get('extent')),
                                  county)
        if verdict is not None:
            checked += 1
            inside += 1 if verdict else 0
        root = arcgis.rest_root_of(item.get('url'))
        if root:
            hosts[root] += 1
    org['publicItems'] = (payload or {}).get('total')
    org['extentChecked'] = checked
    org['coverage'] = round(inside / checked, 2) if checked else None
    org['serviceHosts'] = hosts.most_common(8)
    return org


def confirm_root(task):
    root, via = task
    # Items routinely cite a server's old cleartext address years after it
    # gained TLS. Prefer the https root whenever it answers.
    if root.lower().startswith('http://'):
        upgraded = confirm_root((f'https://{root[len("http://"):]}', via))
        if upgraded:
            return upgraded
    payload, cors = arcgis.fetch(f'{root}?f=json', limit=2_000_000)
    if not isinstance(payload, dict) or 'currentVersion' not in payload:
        return None
    return {'root': root, 'via': via, 'cors': cors,
            'currentVersion': payload.get('currentVersion'),
            'folders': payload.get('folders') or [],
            'services': payload.get('services') or []}


def registered_roots():
    """Roots the county and statewide tiers already carry, lowercased."""
    taken = set()
    for entry in arcgis.read_work('roots.json'):
        if entry.get('tier') not in ('rejected-wrong-place',):
            taken.add(entry['root'].lower())
    for entry in arcgis.read_work('statewide.json').get('roots', []):
        taken.add(entry['root'].lower())
    return taken


def collapse_aliases(portals):
    shapes = {}
    for portal in portals:
        shape = (portal['serviceCount'],
                 tuple(sorted(portal.get('folders') or [])),
                 tuple(sorted((portal.get('serviceTypes') or {}).items())))
        shapes.setdefault(shape, []).append(portal)
    kept = []
    for group in shapes.values():
        group.sort(key=lambda p: (0 if p['root'].startswith('https') else 1,
                                  0 if '.gov' in p['root'].split('/')[2]
                                  else 1, len(p['root'])))
        kept.append(group[0])
    return kept


def main():
    counties = arcgis.counties_by_id()
    cities = city_list()
    by_id = {city['cityId']: city for city in cities}
    arcgis.progress(f'{len(cities)} incorporated cities')

    candidates = [(city['cityId'], key)
                  for city in cities for key in subdomains(city)]
    arcgis.progress(f'probing {len(candidates)} org subdomains')
    orgs = {}
    for org in arcgis.in_parallel(portal_self, candidates, workers=24):
        if org and is_city_gov(org, by_id[org['cityId']]):
            orgs.setdefault((org['cityId'], org['orgId']), org)

    def passes(org):
        return ((org['coverage'] or 0) >= 0.5
                and (org['publicItems'] or 0) >= 5)

    def verify_all(pending):
        return arcgis.in_parallel(
            lambda org: verify(org,
                               counties[by_id[org['cityId']]['countyId']]),
            pending, workers=8)

    arcgis.progress(f'verifying {len(orgs)} candidate organisations')
    verified = verify_all(list(orgs.values()))

    # Cities whose subdomain candidates all failed are searched too, not just
    # cities with no candidate: `cityofglendale` resolves to Glendale,
    # Arizona, and treating that hit as "resolved" would cost the real
    # Glendale its only remaining channel.
    covered = {org['cityId'] for org in verified if passes(org)}
    missing = [city for city in cities if city['cityId'] not in covered]
    arcgis.progress(f'item search for {len(missing)} cities still unresolved')

    def from_search(city):
        found = []
        for org_id in search_candidates(city):
            if (city['cityId'], org_id) in orgs:
                continue
            name, url_key = describe(org_id)
            org = {'cityId': city['cityId'], 'orgId': org_id,
                   'orgName': name, 'urlKey': url_key, 'via': 'item-search'}
            if is_city_gov(org, city):
                found.append(org)
        return found

    searched = []
    for found in arcgis.in_parallel(from_search, missing, workers=8):
        for org in found:
            if (org['cityId'], org['orgId']) not in orgs:
                orgs[(org['cityId'], org['orgId'])] = org
                searched.append(org)
    arcgis.progress(f'verifying {len(searched)} searched organisations')
    verified += verify_all(searched)

    arcgis.write_work('cities_orgs.json', verified)
    kept = [org for org in verified if passes(org)]
    arcgis.progress(f'{len(kept)} organisations pass the coverage check')

    taken = registered_roots()
    tasks = {}
    for org in kept:
        for root, cites in org['serviceHosts']:
            if root.lower() in taken or cites < 1:
                continue
            hosted = arcgis.hosted_org_key(root)
            if hosted is not None and hosted != org['orgId'].lower():
                continue
            tasks.setdefault(root.lower(), (root, org))
    arcgis.progress(f'confirming {len(tasks)} roots')
    confirmed = arcgis.in_parallel(
        lambda task: (confirm_root((task[0], task[1]['via'])), task[1]),
        list(tasks.values()), workers=12)
    confirmed = [(entry, org) for entry, org in confirmed if entry]

    arcgis.progress(f'enumerating and locating {len(confirmed)} roots')

    def flesh_out(pair):
        entry, org = pair
        enumerate_root(entry)
        county = counties[by_id[org['cityId']]['countyId']]
        if arcgis.hosted_org_key(entry['root']):
            entry['geoVerdict'] = 'org-verified'
        else:
            entry['geoVerdict'] = verify_location(entry, county)
        return entry

    arcgis.in_parallel(flesh_out, confirmed, workers=8)

    by_city = {}
    for entry, org in confirmed:
        if not entry.get('serviceCount'):
            continue
        if entry['geoVerdict'] == 'elsewhere':
            continue
        # Checked again because the https upgrade can land on a root that
        # was registered under its https name all along — San Rafael cites
        # MarinMap's server by its old cleartext address.
        if entry['root'].lower() in taken:
            continue
        entry.pop('services', None)
        entry.pop('serviceNames', None)
        entry['publisher'] = org['orgName']
        by_city.setdefault(org['cityId'], []).append(entry)

    rows = []
    for city in cities:
        portals = collapse_aliases(by_city.get(city['cityId'], []))
        if not portals:
            continue
        portals.sort(key=lambda p: -(p['serviceCount'] or 0))
        rows.append({**city, 'portals': portals})
    arcgis.write_work('cities.json', rows)
    services = sum(portal['serviceCount']
                   for row in rows for portal in row['portals'])
    arcgis.progress(
        f'{len(rows)} cities with a catalogue, '
        f'{sum(len(row["portals"]) for row in rows)} roots, '
        f'{services} services')


if __name__ == '__main__':
    main()
