"""Stage 3 — collect every REST root, and remember who pointed at it.

Two sources beyond stage 1's hostname guesses:

* **Item URLs.** A county's ArcGIS Online items link straight at its
  on-premises server, so every registered item is a free, already-correct
  address. This is what finds `maps.sbcounty.gov` and
  `public.gis.lacounty.gov`, which no hostname pattern generates.
* **Derived hosted roots.** An organisation's hosted services always live at
  `services{n}.arcgis.com/<orgId>`; the shard number is the only unknown and
  there are ten. Probing all ten beats hoping an item search returns before
  its timeout, which is how Sonoma and Los Angeles went missing on the first
  pass.

Which organisation cited a root is recorded, not just the root. Stage 5 needs
it: a root cited only by CalEMA is CalEMA's wherever it is hosted, and one
cited only by a `City of ...` is not the county's however county-ish its
hostname looks.

Runtime: about fifteen minutes.
"""
from collections import Counter

import arcgis
from discover_orgs import ITEM_TYPES

HOSTED_HOSTS = ([f'https://services{n}.arcgis.com' for n in ('',) + tuple(range(1, 10))] +
                ['https://tiles.arcgis.com/tiles'])


def county_orgs():
    return [org for org in arcgis.read_work('orgs.json')
            if (org.get('coverage') or 0) >= 0.5
            and (org.get('publicItems') or 0) >= 5]


def cited_roots(org):
    """Every REST root this organisation's public items point at."""
    counts = Counter()
    for start in (1, 101, 201, 301):
        payload = arcgis.arcgis_search(
            f'orgid:{org["orgId"]} AND ({ITEM_TYPES})', start=start)
        results = (payload or {}).get('results', [])
        for item in results:
            root = arcgis.rest_root_of(item.get('url'))
            if root and 'arcgisonline.com' not in root.lower():
                counts[root] += 1
        if len(results) < 100:
            break
    return org, counts


def confirm(task):
    county_id, root, citations = task
    payload, cors = arcgis.fetch(f'{root}?f=json', limit=2_000_000)
    if not isinstance(payload, dict) or 'currentVersion' not in payload:
        return None
    return {'countyId': county_id, 'root': root, 'via': 'agol-item-url',
            'currentVersion': payload.get('currentVersion'),
            'folders': payload.get('folders') or [],
            'services': payload.get('services') or [], 'cors': cors,
            'citedBy': citations}


def derived_hosted(task):
    org, host = task
    root = f'{host}/{org["orgId"]}/arcgis/rest/services'
    payload, cors = arcgis.fetch(f'{root}?f=json', limit=2_000_000)
    if not isinstance(payload, dict) or 'currentVersion' not in payload:
        return None
    if not (payload.get('services') or payload.get('folders')):
        return None
    return {'countyId': org['countyId'], 'root': root,
            'via': 'org-hosted-root',
            'currentVersion': payload.get('currentVersion'),
            'folders': payload.get('folders') or [],
            'services': payload.get('services') or [], 'cors': cors,
            'citedBy': [{'orgId': org['orgId'],
                         'orgName': org.get('orgName'),
                         'items': org.get('publicItems')}]}


def main():
    orgs = county_orgs()
    arcgis.progress(f'harvesting item URLs for {len(orgs)} organisations')
    harvest = arcgis.in_parallel(cited_roots, orgs, workers=6)

    citations = {}
    for org, counts in harvest:
        for root, count in counts.items():
            key = (org['countyId'], root.rstrip('/').lower())
            citations.setdefault(key, []).append(
                {'orgId': org['orgId'], 'orgName': org.get('orgName'),
                 'items': count})

    roots = {}
    for entry in arcgis.read_work('hosts.json', default=[]):
        roots[(entry['countyId'], entry['root'].rstrip('/').lower())] = entry

    tasks = [(county_id, root, cites)
             for (county_id, root), cites in citations.items()
             if (county_id, root) not in roots]
    arcgis.progress(f'confirming {len(tasks)} cited roots')
    for entry in arcgis.in_parallel(confirm, tasks, workers=16):
        if entry:
            roots[(entry['countyId'], entry['root'].rstrip('/').lower())] = entry

    arcgis.progress(f'deriving hosted roots for {len(orgs)} organisations')
    derived = arcgis.in_parallel(
        derived_hosted, [(org, host) for org in orgs for host in HOSTED_HOSTS],
        workers=16)
    for entry in derived:
        if entry:
            roots.setdefault(
                (entry['countyId'], entry['root'].rstrip('/').lower()), entry)

    for key, entry in roots.items():
        entry.setdefault('citedBy', citations.get(key, []))

    # ArcGIS answers on both /arcgis/ and /ArcGIS/; keep one spelling.
    deduped = {}
    for (county_id, lowered), entry in roots.items():
        current = deduped.get((county_id, lowered))
        if current is None or entry['root'].islower():
            deduped[(county_id, lowered)] = entry

    arcgis.write_work('roots.json', list(deduped.values()))
    arcgis.progress(
        f'{len(deduped)} roots across '
        f'{len({county for county, _ in deduped})} counties')


if __name__ == '__main__':
    main()
