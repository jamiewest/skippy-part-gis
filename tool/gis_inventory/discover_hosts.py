"""Stage 1 — find county ArcGIS servers by guessing their hostnames.

Guessing is cheap because it is self-verifying: a name either resolves and
answers `?f=json` with a `currentVersion`, or it does not. It is also the
weakest channel — `maps.sbcounty.gov` carries an initialism no pattern here
generates, and `gis.orangecountync.gov` answers for the wrong Orange County.
Stage 5 rejects the false positives; stages 2 and 3 cover the misses.

Runtime: about ten minutes for the DNS sweep, twenty for the HTTP probe.
"""
import socket

import arcgis

PREFIXES = ['gis', 'maps', 'map', 'gisportal', 'geo', 'arcgis', 'mapping',
            'gisweb', 'services', 'gis1', 'egis', 'portal', 'gisdata']

PATHS = ['/arcgis/rest/services', '/server/rest/services',
         '/arcgis_mapping/rest/services', '/gis/rest/services',
         '/img/rest/services', '/rest/services', '/host/rest/services',
         '/public/rest/services', '/image/rest/services',
         '/arcgiswad/rest/services', '/geoserver/rest/services']


def domains(name):
    slug = name.lower().replace(' ', '')
    dashed = name.lower().replace(' ', '-')
    return [f'{slug}.ca.gov', f'{slug}county.ca.gov', f'{slug}countyca.gov',
            f'co.{slug}.ca.us', f'{slug}.ca.us', f'countyof{slug}.us',
            f'{slug}county.us', f'{slug}county.org', f'{slug}.org',
            f'{dashed}.ca.gov', f'{slug}ca.gov']


def candidate_hosts():
    seen = set()
    for county in arcgis.counties():
        for domain in domains(county['name']):
            for prefix in PREFIXES:
                host = f'{prefix}.{domain}'
                if host not in seen:
                    seen.add(host)
                    yield county['id'], host


def resolves(candidate):
    county_id, host = candidate
    try:
        socket.getaddrinfo(host, 443, proto=socket.IPPROTO_TCP)
        return county_id, host
    except OSError:
        return None


def probe(candidate):
    county_id, host, path = candidate
    root = f'https://{host}{path}'
    payload, cors = arcgis.fetch(f'{root}?f=json', timeout=12, limit=200_000)
    if not isinstance(payload, dict) or 'currentVersion' not in payload:
        return None
    arcgis.progress(f'  {county_id:18} {root}')
    return {'countyId': county_id, 'root': root, 'via': 'hostname-guess',
            'currentVersion': payload.get('currentVersion'),
            'folders': payload.get('folders') or [],
            'services': payload.get('services') or [], 'cors': cors}


def main():
    candidates = list(candidate_hosts())
    arcgis.progress(f'resolving {len(candidates)} hostnames')
    live = [row for row in arcgis.in_parallel(resolves, candidates, workers=64)
            if row]
    arcgis.progress(f'{len(live)} hosts resolve; probing REST paths')

    tasks = [(county_id, host, path)
             for county_id, host in live for path in PATHS]
    found = [row for row in arcgis.in_parallel(probe, tasks, workers=48) if row]
    arcgis.write_work('hosts.json', found)
    arcgis.progress(
        f'{len(found)} REST roots across '
        f'{len({row["countyId"] for row in found})} counties')


if __name__ == '__main__':
    main()
