"""Stage 2 — find each county's ArcGIS Online organisation.

Two channels, because counties name their organisations inconsistently:

* **Vanity subdomains.** `https://<key>.maps.arcgis.com/sharing/rest/portals/
  self` names the organisation owning a subdomain, so guessing is
  self-verifying — a wrong guess returns a null id. This is what recovers
  `sbcounty` → `aA3snZwJfFkVyDuP`, the org id already hard-coded in
  `ImageryCatalogService`.
* **ArcGIS Hub dataset search.** The Online item search ranks by popularity and
  buries a small county under statewide publishers; the Hub index is keyed on
  open-data sites, which is what a county actually runs.

Every candidate is then scored geographically: the share of its public items
whose advertised extent overlaps the county. That is what separates the county
from CDFW, which publishes over every county in the state.

A third channel was tried and abandoned: ArcGIS Online's `bbox` search
parameter does not restrict results — a Fresno-shaped box returns global
weather feeds — so it discovers nothing name search does not.

Runtime: about five minutes.
"""
from collections import Counter

import arcgis

# Subdomain forms the generic patterns miss: initialisms and department names.
ALIASES = {
    'san_bernardino': ['sbcounty', 'sbcountygis'],
    'los_angeles': ['lacounty', 'lacountyisd', 'countyoflosangeles'],
    'san_diego': ['sandiegocounty', 'sdcounty', 'sangis'],
    'orange': ['ocgis', 'countyoforange', 'ocpw', 'ocgov'],
    'santa_clara': ['sccgov', 'santaclaracounty', 'sccplanning'],
    'contra_costa': ['cccounty', 'contracosta', 'ccmap'],
    'san_francisco': ['sfgov', 'sfgis', 'sfplanninggis'],
    'san_mateo': ['smcgov', 'smcmaps', 'sanmateocounty'],
    'san_joaquin': ['sjmap', 'sjgov', 'sjcgis'],
    'san_luis_obispo': ['slocounty', 'slogis'],
    'santa_barbara': ['countyofsb', 'sbcgis', 'santabarbaracounty'],
    'santa_cruz': ['sccounty01', 'santacruzcounty'],
    'ventura': ['vcgis', 'venturacounty', 'vcrma', 'vcitsgis'],
    'kern': ['kerncounty', 'kerngis'], 'fresno': ['cofgisonline'],
    'placer': ['placergis'], 'sacramento': ['saccounty', 'saccountygis'],
    'stanislaus': ['stancounty', 'stancounty-gis'],
    'solano': ['solanocounty'], 'yolo': ['yolocounty'],
    'humboldt': ['humboldtgov'], 'monterey': ['montereyco'],
    'nevada': ['nevcounty'], 'butte': ['buttecounty'],
    'madera': ['maderacounty'], 'kings': ['kingscounty', 'countyofkings'],
    'trinity': ['trinitycountyca'], 'plumas': ['plumascountyca'],
    'colusa': ['colusacountyca'], 'yuba': ['yubacountyca'],
    'amador': ['amadorgov'], 'calaveras': ['calaverasgov', 'calaveras-gis'],
    'del_norte': ['delnortecounty'], 'lake': ['lakecountyca'],
    'san_benito': ['sanbenitocounty', 'cosb'], 'siskiyou': ['siskiyoucounty'],
    'sutter': ['suttercounty'], 'glenn': ['countyofglenn'],
    'imperial': ['imperialcounty', 'icpds'], 'inyo': ['inyocounty'],
    'mono': ['monocountyca'], 'alpine': ['alpinecountyca'],
    'modoc': ['modoccounty', 'modocca'], 'lassen': ['lassencountyca'],
    'shasta': ['shastacountyca'], 'tehama': ['tehamacounty'],
    'tuolumne': ['tuolumnecountyca'], 'mariposa': ['mariposacountyca'],
    'merced': ['countyofmerced', 'mercedcounty'], 'napa': ['countyofnapa'],
    'marin': ['marinmap', 'countyofmarin'],
    'sonoma': ['sonomacounty', 'countyofsonoma'],
    'mendocino': ['mendocinocounty', 'mendocino-county'],
    'riverside': ['rivco', 'countyofriverside'],
    'el_dorado': ['eldoradocounty', 'edcgov'], 'tulare': ['tularecounty'],
    'sierra': ['sierracountyca'], 'alameda': ['acgov', 'alamedacounty'],
}

# Publishers whose data blankets every county. Counting them as a county's own
# would make all 58 look well served by CDFW.
STATEWIDE_ORGS = {
    'Uq9r85Potqm3MfRV',  # CDFW / BIOS
    'jUJYIo9tSA7EHvfZ',  # CAL FIRE
    'iwxhJVOFEKDxO7gk',  # Board of Equalization
    '5aaQCuq3e4GRvkFG',  # State Lands Commission
    'RHVPKKiFTONKtxq3',  # Esri live feeds
    'P3ePLMYs2RVChkJx',  # Esri
}

ITEM_TYPES = ('type:"Feature Service" OR type:"Map Service" OR '
              'type:"Image Service" OR type:"Vector Tile Service"')


def subdomains(name):
    slug = name.lower().replace(' ', '')
    dashed = name.lower().replace(' ', '-')
    return [f'{slug}county', f'countyof{slug}', f'{dashed}-county',
            f'{slug}countyca', f'{slug}', f'{slug}countygis', f'{slug}gis']


def portal_self(candidate):
    county_id, key = candidate
    payload = arcgis.fetch_json(
        f'https://{key}.maps.arcgis.com/sharing/rest/portals/self?f=json',
        timeout=20)
    if not payload or not payload.get('id'):
        return None
    return {'countyId': county_id, 'orgId': payload['id'],
            'urlKey': payload.get('urlKey') or key,
            'orgName': payload.get('name'), 'via': 'org-subdomain'}


def hub_candidates(county_id, name):
    counts = Counter()
    for page in (1, 2):
        payload = arcgis.fetch_json(
            'https://hub.arcgis.com/api/v3/datasets?' +
            f'q={name.replace(" ", "+")}+County&page%5Bsize%5D=100'
            f'&page%5Bnumber%5D={page}', timeout=35)
        rows = (payload or {}).get('data', [])
        for row in rows:
            org = (row.get('attributes') or {}).get('orgId')
            if org and org not in STATEWIDE_ORGS:
                counts[org] += 1
        if len(rows) < 100:
            break
    return [org for org, _ in counts.most_common(6)]


def describe(org_id):
    payload = arcgis.fetch_json(
        f'https://www.arcgis.com/sharing/rest/portals/{org_id}?f=json')
    return ((payload or {}).get('name'), (payload or {}).get('urlKey'))


def verify(org, county):
    """Score an organisation by how much of its data sits in the county."""
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


def main():
    counties = arcgis.counties()
    by_id = {county['id']: county for county in counties}

    candidates = []
    for county in counties:
        keys = dict.fromkeys(subdomains(county['name']) +
                             ALIASES.get(county['id'], []))
        candidates += [(county['id'], key) for key in keys]
    arcgis.progress(f'probing {len(candidates)} org subdomains')
    orgs = {}
    for org in arcgis.in_parallel(portal_self, candidates, workers=24):
        if org:
            orgs.setdefault((org['countyId'], org['orgId']), org)

    arcgis.progress('searching ArcGIS Hub for counties still unresolved')
    resolved = {county_id for county_id, _ in orgs}
    missing = [county for county in counties if county['id'] not in resolved]
    for county in missing:
        for org_id in hub_candidates(county['id'], county['name']):
            name, url_key = describe(org_id)
            orgs.setdefault((county['id'], org_id), {
                'countyId': county['id'], 'orgId': org_id, 'orgName': name,
                'urlKey': url_key, 'via': 'hub-search'})

    arcgis.progress(f'verifying {len(orgs)} candidate organisations')
    verified = arcgis.in_parallel(
        lambda org: verify(org, by_id[org['countyId']]), list(orgs.values()),
        workers=8)
    verified.sort(key=lambda org: (org['countyId'], -(org['coverage'] or 0)))
    arcgis.write_work('orgs.json', verified)

    kept = [org for org in verified
            if (org['coverage'] or 0) >= 0.5 and (org['publicItems'] or 0) >= 5]
    arcgis.progress(
        f'{len(kept)} organisations pass the coverage check across '
        f'{len({org["countyId"] for org in kept})} counties')


if __name__ == '__main__':
    main()
