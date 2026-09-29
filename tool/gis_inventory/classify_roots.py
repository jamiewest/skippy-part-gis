"""Stage 5 — decide where each root really is, and whose it really is.

Three questions, in order, because each rejects a different kind of wrong
answer:

1. **Is it in the county?** `gis.orangecountync.gov` serves a perfectly valid
   ArcGIS catalogue for Orange County, *North Carolina*. Only geography can
   tell that apart from the real thing.
2. **Whose is it?** A hosted root belongs to the organisation in its path. A
   root cited only by `City of ...` organisations is a city's, however
   county-ish its hostname — twenty-odd California cities share their county's
   name, so `mobile.alamedaca.gov` and `webmaps.sandiego.gov` both pass any
   name test while being city servers.
3. **Is it a duplicate?** One server commonly answers on two names. Riverside
   serves the same 48 services on `gis.` and `gis1.`; registering both would
   list every layer twice.

Runtime: about ten minutes.
"""
import re

import arcgis

STATEWIDE_HOST = re.compile(
    r'(^|\.)(fema|epa|usgs|noaa|nps|census|dot|cdc|usda|blm|nationalmap|'
    r'arcgisonline|weather)\.gov$|'
    r'(^|\.)(water|dot|cnra|conservation|fire|wildlife|parks|waterboards|'
    r'gis|data|geohub|caltrans-gis|ferix)\.ca\.gov$|'
    r'\.fed\.us$|apps\.fs\.usda\.gov$|geo\.dot\.gov$', re.I)

# Publishers that are demonstrably not the county government. Matching here is
# a positive disqualification; merely failing to say "County" is not, because
# county agencies name themselves by initialism ("OC Public Works").
NOT_COUNTY_GOV = re.compile(
    r'college|universit|stanford|claremont|ucdavis|conservancy|'
    r'council of governments|water ?board|regional park|open space|'
    r'esri |fema|emergency services|forest service|waterkeeper|'
    r'geospatial llc|planning agency|transportation commission|sbo\b|'
    r'\bcog\b|school|hospital|\bcity of\b', re.I)

# County-government hosts sharing no word with the county's name.
COUNTY_HOST_ALIAS = {
    'san_bernardino': ('sbcounty',), 'san_benito': ('cosb',),
    'san_luis_obispo': ('slocounty',), 'san_francisco': ('sfgov', 'sfdpw'),
    'san_mateo': ('smcgov', 'smcmaps'), 'san_joaquin': ('sjcgis', 'sjmap'),
    'el_dorado': ('edcgov',), 'sacramento': ('saccounty',),
    'stanislaus': ('stancounty',), 'santa_clara': ('sccgov',),
    'los_angeles': ('lacounty',), 'contra_costa': ('cccounty',),
    'marin': ('marinpublic',), 'orange': ('ocgis', 'ocpw'),
    'san_diego': ('sangis', 'sdcounty'),
}


def county_tokens(county):
    name = county['name'].lower()
    return [word for word in name.split() if len(word) > 2] or [name]


def names_county(text, county):
    if not text:
        return False
    flat = re.sub(r'[^a-z]', '', text.lower())
    return all(token in flat for token in county_tokens(county))


def is_county_gov_org(org, county):
    label = f"{org.get('orgName') or ''} {org.get('urlKey') or ''}"
    if NOT_COUNTY_GOV.search(label):
        return False
    return names_county(label, county)


def cited_by_county(entry, county):
    return any(not NOT_COUNTY_GOV.search(cite.get('orgName') or '')
               and names_county(cite.get('orgName'), county)
               for cite in entry.get('citedBy') or [])


def cited_only_by_others(entry):
    cites = entry.get('citedBy') or []
    return bool(cites) and all(
        NOT_COUNTY_GOV.search(cite.get('orgName') or '') for cite in cites)


def host_is_county(entry, county):
    host = entry['root'].split('/')[2].split(':')[0].lower()
    if names_county(host, county):
        return True
    flat = re.sub(r'[^a-z]', '', host)
    return any(alias in flat
               for alias in COUNTY_HOST_ALIAS.get(county['id'], ()))


def sample_services(entry):
    services = list(entry.get('services') or [])
    for folder in (entry.get('folders') or [])[:6]:
        if services:
            break
        payload = arcgis.fetch_json(f"{entry['root']}/{folder}?f=json",
                                    limit=2_000_000)
        services += (payload or {}).get('services') or []
    return services


def verify_location(entry, county):
    """Confirm the root serves data inside the county."""
    for service in sample_services(entry)[:4]:
        url = f"{entry['root']}/{service.get('name')}/{service.get('type')}"
        payload = arcgis.fetch_json(f'{url}?f=json', limit=2_000_000)
        if not isinstance(payload, dict):
            continue
        extent = payload.get('fullExtent') or payload.get('extent') or {}
        reference = extent.get('spatialReference') or {}
        wkid = reference.get('latestWkid') or reference.get('wkid')
        box = arcgis.service_extent(extent, wkid)
        if box is None and service.get('type') in ('MapServer',
                                                   'FeatureServer'):
            for layer in (payload.get('layers') or [])[:2]:
                box = arcgis.reprojected_layer_extent(
                    f"{url}/{layer.get('id')}")
                if box:
                    break
        if box is None:
            continue
        entry['sampleExtent'] = [round(value, 3) for value in box]
        return 'in-county' if arcgis.overlaps(box, county) else 'elsewhere'
    return 'unverified'


def canonical_rank(entry):
    host = entry['root'].split('/')[2].lower()
    return (0 if host.endswith('.gov') else 1, len(entry['root']))


def main():
    counties = arcgis.counties_by_id()
    roots = arcgis.read_work('roots.json')
    orgs = arcgis.read_work('orgs.json')
    gov_orgs = {(org['countyId'], org['orgId'].lower()) for org in orgs
                if (org.get('coverage') or 0) >= 0.5
                and (org.get('publicItems') or 0) >= 5
                and is_county_gov_org(org, counties[org['countyId']])}

    pending = [entry for entry in roots if 'geoVerdict' not in entry]
    arcgis.progress(f'locating {len(pending)} roots')
    arcgis.in_parallel(
        lambda entry: entry.update(
            geoVerdict=verify_location(entry, counties[entry['countyId']])),
        pending, workers=12)

    for entry in roots:
        county = counties[entry['countyId']]
        host = entry['root'].split('/')[2].split(':')[0].lower()
        key = arcgis.hosted_org_key(entry['root'])
        if entry['geoVerdict'] == 'elsewhere':
            entry['tier'] = 'rejected-wrong-place'
        elif STATEWIDE_HOST.search(host):
            entry['tier'] = 'statewide'
        elif key is not None:
            entry['tier'] = ('county-portal'
                             if (entry['countyId'], key) in gov_orgs
                             else 'partner')
        elif cited_by_county(entry, county):
            entry['tier'] = 'county-portal'
        elif cited_only_by_others(entry):
            entry['tier'] = 'partner'
        elif host_is_county(entry, county):
            entry['tier'] = 'county-portal'
        else:
            entry['tier'] = 'unattributed'

    shapes = {}
    for entry in roots:
        if entry['tier'] not in ('county-portal', 'partner'):
            continue
        if entry.get('serviceCount') is None:
            continue
        shape = (entry['countyId'], entry['serviceCount'],
                 tuple(sorted(entry.get('folders') or [])),
                 tuple(sorted((entry.get('serviceTypes') or {}).items())))
        shapes.setdefault(shape, []).append(entry)

    aliases = 0
    for group in shapes.values():
        if len(group) < 2:
            continue
        group.sort(key=canonical_rank)
        for duplicate in group[1:]:
            duplicate['tier'] = 'alias'
            duplicate['aliasOf'] = group[0]['root']
            aliases += 1

    arcgis.write_work('roots.json', roots)
    portals = [entry for entry in roots if entry['tier'] == 'county-portal']
    arcgis.progress(
        f'{len(portals)} county-portal roots, {aliases} aliases collapsed, '
        f'{len({entry["countyId"] for entry in portals})} counties covered')


if __name__ == '__main__':
    main()
