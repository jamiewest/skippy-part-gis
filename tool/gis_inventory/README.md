# County GIS inventory pipeline

Regenerates [`docs/county-gis-inventory.json`](../../docs/county-gis-inventory.json)
and the per-county table in
[`docs/county-gis-inventory.md`](../../docs/county-gis-inventory.md) by probing
every California county's public ArcGIS services.

Standard library only — no virtualenv, no dependencies.

```shell
python3 tool/gis_inventory/run.py
```

About 90 minutes, almost all of it waiting on other people's servers. Stages
are independent and resumable:

```shell
python3 tool/gis_inventory/run.py classify emit
```

Intermediates land in `.work/`, which is git-ignored. Delete it to start clean.

## Why this exists

The app discovers services at runtime; it cannot discover *which servers
exist*. That is the one durable fact, and it is what this produces. County
portals move, get renamed and get retired, so the registry needs regenerating
occasionally rather than never.

## Stages

| Stage | Does | Writes |
| --- | --- | --- |
| `hosts` | Resolves ~8,500 guessed hostnames, probes 11 REST paths on each | `.work/hosts.json` |
| `orgs` | Vanity-subdomain and Hub search for county organisations, scored by geographic coverage | `.work/orgs.json` |
| `harvest` | REST roots from item URLs and derived hosted shards, keeping who cited what | `.work/roots.json` |
| `enumerate` | Walks folders, counts services by type and theme | `.work/roots.json` |
| `classify` | Locates each root, assigns a tier, collapses aliases | `.work/roots.json` |
| `statewide` | California State Geoportal, state and federal agency roots | `.work/statewide.json` |
| `cities` | Incorporated city organisations, roots and services | `.work/cities.json` |
| `emit` | Registry JSON and the markdown table | `docs/` |

The county list — ids, FIPS codes, extents — is parsed out of
`lib/data/services/california_counties.dart` rather than duplicated, so the two
cannot drift.

## The three questions `classify` answers

Each rejects a different kind of wrong answer, and all three are needed:

- **Is it in the county?** `gis.orangecountync.gov` serves a valid ArcGIS
  catalogue for Orange County, *North Carolina*. Only geography separates that
  from the real thing. Most county servers publish in California State Plane,
  which this pipeline deliberately cannot reproject — it asks the server
  instead, via `query?returnExtentOnly=true&outSR=4326`.
- **Whose is it?** A hosted `services*.arcgis.com/<orgId>` root belongs to the
  org in its path whoever links to it. A root cited only by `City of ...`
  organisations is a city's, however county-ish the hostname —
  `mobile.alamedaca.gov` and `webmaps.sandiego.gov` are both city servers that
  pass any name test.
- **Is it a duplicate?** Riverside serves the same 48 services on `gis.` and
  `gis1.countyofriverside.us`. Registering both would list every layer twice.

## Editing the heuristics

Three places hold judgement calls, and all three will need updating as
counties change:

- `discover_orgs.ALIASES` — subdomain forms the generic patterns miss
  (`sbcounty`, `edcgov`, `cofgisonline`).
- `classify_roots.NOT_COUNTY_GOV` — publishers that are positively *not* the
  county. Matching here disqualifies; merely failing to say "County" does not,
  because county agencies name themselves by initialism ("OC Public Works").
- `classify_roots.COUNTY_HOST_ALIAS` — county hosts sharing no word with the
  county's name.

`themes.py` is the keyword classifier, shared with the app's catalogue
grouping. It is a heuristic for sorting a long list and is wrong at the edges;
never use it to decide what a layer *is*.

## The city tier

`cities` points the county pipeline's strongest channels at the 483
incorporated cities, read with their county and bounding box from CAL FIRE's
city-boundaries layer. Hostname guessing is deliberately skipped — it found 21
of 130 county roots and would cost tens of thousands of probes here. A city
organisation must pass two tests that reject different wrong answers: its
*name* must claim the city (else the county's own org, at coverage 1.0, claims
every city in it), and its items must sit in the city's county (else
`cityofglendale` — Glendale, Arizona — passes the name test). Roots already
registered to a county or statewide tier are skipped rather than re-listed;
that is why San Diego and San Francisco, whose city servers were already
demoted into their counties' partner tiers, have no city entry.

`discover_cities.CITY_ALIASES` holds the vanity subdomains the generic
patterns miss, like the counties' list above it.

## What was tried and abandoned

ArcGIS Online's `bbox` search parameter does not restrict results — a
Fresno-shaped box returns global weather feeds — so searching by geography
finds nothing that searching by name does not. The idea keeps looking
attractive; it does not work.
