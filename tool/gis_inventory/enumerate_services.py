"""Stage 4 — walk each root's folders and count what is in them.

Stops at the service list rather than opening every service. A folder listing
already carries the name and type, which is what a catalogue shows and what
the theme classifier reads; per-service metadata is what the app fetches
lazily when a layer is actually turned on.

Runtime: about twenty minutes.
"""
from collections import Counter

import arcgis
from themes import themes_of


def _folder(root, folder):
    # One retry: several of these servers flake individually, and a missed
    # folder silently under-counts a root — or, for a root whose services
    # all live in folders, zeroes it out entirely.
    for _ in range(2):
        payload = arcgis.fetch_json(f'{root}/{folder}?f=json',
                                    limit=2_000_000)
        if payload is not None:
            return payload
    return None


def enumerate_root(entry):
    root = entry['root']
    services = list(entry.get('services') or [])
    folders = entry.get('folders') or []
    listings = arcgis.in_parallel(
        lambda folder: _folder(root, folder), folders, workers=6)
    for payload in listings:
        services += (payload or {}).get('services') or []

    themes = Counter()
    for service in services:
        for theme in themes_of(service.get('name')):
            themes[theme] += 1
    entry['serviceCount'] = len(services)
    entry['serviceTypes'] = dict(
        Counter(service.get('type') for service in services))
    entry['themes'] = dict(themes.most_common())
    # Kept so the theme classifier can be corrected and the counts recomputed
    # without re-crawling every county.
    entry['serviceNames'] = [service.get('name') for service in services]
    return entry


def main():
    roots = arcgis.read_work('roots.json')
    pending = [entry for entry in roots if entry.get('serviceCount') is None]
    arcgis.progress(f'enumerating {len(pending)} of {len(roots)} roots')
    arcgis.in_parallel(enumerate_root, pending, workers=8)
    arcgis.write_work('roots.json', roots)
    total = sum(entry.get('serviceCount') or 0 for entry in roots)
    arcgis.progress(f'{total} services across {len(roots)} roots')


if __name__ == '__main__':
    main()
