"""Run the county GIS inventory pipeline.

    python3 tool/gis_inventory/run.py            # every stage, ~90 minutes
    python3 tool/gis_inventory/run.py emit       # one stage
    python3 tool/gis_inventory/run.py classify emit

Stages are ordered and each reads the previous one's output from `.work/`, so
a later stage can be re-run on its own after an interruption.
"""
import sys
import time

import arcgis

STAGES = [
    ('hosts', 'discover_hosts', 'guess county hostnames (~30 min)'),
    ('orgs', 'discover_orgs', 'find ArcGIS Online organisations (~5 min)'),
    ('harvest', 'harvest_roots', 'collect REST roots and citations (~15 min)'),
    ('enumerate', 'enumerate_services', 'count services per root (~20 min)'),
    ('classify', 'classify_roots', 'locate, attribute, de-duplicate (~10 min)'),
    ('statewide', 'statewide', 'California State Geoportal (~5 min)'),
    ('cities', 'discover_cities', 'incorporated city catalogues (~40 min)'),
    ('emit', 'emit', 'write docs/county-gis-inventory.{json,md}'),
]


def main(argv):
    names = [name for name, _, _ in STAGES]
    wanted = argv[1:] or names
    unknown = [name for name in wanted if name not in names]
    if unknown:
        raise SystemExit(f'unknown stage(s): {", ".join(unknown)}\n'
                         f'available: {", ".join(names)}')

    for name, module, description in STAGES:
        if name not in wanted:
            continue
        arcgis.progress(f'\n=== {name}: {description}')
        started = time.monotonic()
        __import__(module).main()
        arcgis.progress(f'=== {name} done in '
                        f'{time.monotonic() - started:.0f}s')


if __name__ == '__main__':
    main(sys.argv)
