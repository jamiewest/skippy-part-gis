# What the counties publish

Every California county was probed for public ArcGIS REST catalogues on
2026-07-30. This document records what was found, how it was found, and where
the search is known to be incomplete. The machine-readable result is
[county-gis-inventory.json](county-gis-inventory.json); the plan for putting it
on the map is [overlay-catalog-strategy.md](overlay-catalog-strategy.md).

## The headline

| | Counties |
| --- | ---: |
| Publish their own ArcGIS catalogue (**first-party**) | 46 |
| Covered only by another publisher (**partner-only**) | 8 |
| Nothing found (**none-found**) | 4 |

Across the 46 first-party counties: **130 REST roots** carrying **24,691
services**. Riverside and San Bernardino — the two counties this app already
configures by hand — are 1,581 and 1,274 services respectively, of which the
app currently reads four.

The city probe (2026-08-24) adds a tier below the counties: of the 483
incorporated cities, **128 publish a catalogue this search could attribute to
them** — 244 roots carrying about 17,000 services, City of Riverside's 767
among them. A city entry carries the city's bounding box, because a city
catalogue is only offered while the map is over the city. Cities whose
servers were already filed in a county's partner tier — San Diego, San
Francisco — are deliberately absent rather than listed twice. See
`tool/gis_inventory/README.md` for how city attribution is decided.

Fifteen further roots were dropped as **aliases**: one server answering on two
names. Riverside serves the same 48 services on `gis.` and `gis1.`, Shasta on
`gis.co.shasta.ca.us` and `gis.shastacounty.gov`, Ventura on `gis.` and
`maps.ventura.org`. Registering both would list every layer twice.

`none-found` means this probe found nothing, not that nothing exists. Madera,
Mono, Solano and Trinity are the four; each is a candidate for ten minutes of
manual checking rather than evidence of absence.

On top of that, the California State Geoportal adds **6,446 services across 13
roots that apply to every county**, which is what closes the gap for the 12
counties with no portal of their own. See
[the statewide tier](#the-statewide-tier-gisdatacagov).

## How the search worked

Four channels, because no single one is complete:

1. **Hostname guessing.** 8,476 candidate names (`gis.`/`maps.`/`gisportal.`
   × `<county>.ca.gov`, `co.<county>.ca.us`, `countyof<county>.us`, …) were
   DNS-resolved; the 625 that resolved were probed on eleven REST paths.
   21 roots. This channel alone misses `maps.sbcounty.gov`, because the
   hostname carries an initialism the pattern cannot generate.
2. **Organisation subdomains.** `https://<key>.maps.arcgis.com/sharing/rest/
   portals/self` names the organisation owning a vanity subdomain, so guessing
   is self-verifying — a wrong guess returns a null id. This is what recovered
   `sbcounty` → `aA3snZwJfFkVyDuP`, matching the org id already hard-coded in
   `ImageryCatalogService`.
3. **Item URLs.** A county's ArcGIS Online items link straight at its
   on-premises server, so every registered item is a free, already-correct
   address. This is the channel that found `maps.sbcounty.gov`,
   `public.gis.lacounty.gov`, `gis.countyofmerced.com` and most of the rest.
4. **ArcGIS Hub dataset search.** The Online item search ranks by popularity
   and buries small counties under statewide publishers; the Hub index is keyed
   on open-data sites instead. This is what surfaced Fresno, Monterey, San
   Joaquin, San Mateo, Santa Barbara, Stanislaus and Calaveras.

### How wrong answers were rejected

A hostname guess produces false positives indistinguishable from real hits:
`gis.orangecountync.gov` serves a perfectly valid ArcGIS catalogue for Orange
County, **North Carolina**. Name matching cannot tell those apart, so every
root was checked geographically — a sample of its services' extents must
overlap the California county's bounding box.

Most county servers publish in California State Plane, which the probe cannot
reproject on its own. It does not have to: `query?returnExtentOnly=true&
outSR=4326` makes the server answer in WGS84. That rejected Orange County NC,
Outagamie County, San Juan County WA, and a Spanish agricultural surveyor that
had claimed the `CONAPA` subdomain.

Ownership is decided separately from geography. A hosted
`services*.arcgis.com/<orgId>` root belongs to the organisation in its path,
whoever links to it — otherwise Esri's own demographics org gets filed as El
Dorado County merely because El Dorado's items reference it.

## Three tiers, kept apart

- **county-portal** — published by the county government. The only tier a
  layer picker may label with the county's name.
- **partner** — a real publisher covering the county but not the county: a
  council of governments, a park district, a university, a neighbouring county.
  Colusa's best coverage today is CalEMA's and Glenn County's.
- **statewide** — Caltrans, DWR, FEMA, USGS, NPS, NOAA, CDC, CAL FIRE and the
  state geoportal. These blanket every county and are worth offering
  everywhere.

Conflating them would have the app assert that UC Davis research data is
Contra Costa County's, which is a provenance claim the app has no business
making.

The tier a hostname suggests is not the tier it gets. Twenty-odd California
cities share their county's name, so `mobile.alamedaca.gov` and
`webmaps.sandiego.gov` both pass any name test while being **city** servers.
What separates them is who cites them: every organisation linking to those two
is a `City of ...`, which is a positive disqualification rather than a mere
failure to say "County". Both were demoted to partner, which is why Alameda is
partner-only and why San Diego's largest root is not its primary one —
`services1.arcgis.com/1vIhDJwtG5eNmiqX`, the County of San Diego GIS Portal,
is smaller than the city's server and is nonetheless the right answer.

## The statewide tier: gis.data.ca.gov

The California State Geoportal is one Hub site indexing **3,990 datasets**
from every state agency. It publishes a DCAT-US feed
(`/api/feed/dcat-us/1.1.json`), so the whole catalogue is one 21 MB request
rather than a crawl — no discovery guesswork at all.

Its datasets resolve to a long tail of agency servers, of which thirteen carry
enough to be worth registering. **6,446 services**, all CORS-permissive:

| Services | Root | Publisher |
| ---: | --- | --- |
| 2,483 | `services2.arcgis.com/Uq9r85Potqm3MfRV` | Dept. of Fish and Wildlife |
| 1,246 | `services1.arcgis.com/jUJYIo9tSA7EHvfZ` | CAL FIRE |
| 999 | `services.arcgis.com/BLN4oKB0N1YSgvY8` | Governor's Office of Emergency Services |
| 733 | `gispublic.waterboards.ca.gov/portalserver` | Water Boards |
| 232 | `caltrans-gis.dot.ca.gov/arcgis` | Caltrans |
| 180 | `gis.conservation.ca.gov/server` | Dept. of Conservation |
| 145 | `gis.water.ca.gov/arcgis` | Dept. of Water Resources |
| 144 | `services3.arcgis.com/bWPjFyq029ChCGur` | Energy Commission |
| 117 | `services7.arcgis.com/iwxhJVOFEKDxO7gk` | Board of Equalization |
| 86 | `gis.fema.gov/arcgis` | FEMA |
| 37 | `gis.wildlife.ca.gov/images` | Dept. of Fish and Wildlife |
| 23 | `services.gis.ca.gov/arcgis` | State Geoportal |
| 21 | `hazards.fema.gov/arcgis` | FEMA |

By theme: flood & water 506, basemap & reference 314, fire & hazard 274,
boundaries & districts 228, transportation 173.

Two things make this tier disproportionately valuable:

- **It covers all 58 counties from 13 registry entries.** The 12 counties with
  no first-party portal stop being empty. Flood zones, fire hazard severity,
  groundwater basins and state highways arrive everywhere at once.
- **The app already reads it.** `CountySources.californiaCountiesQuery` points
  at `services.gis.ca.gov/.../CA_Counties`, which sits in that server's
  `Boundaries` folder next to `CA_PoliticalBoundaries`. The statewide tier is
  not a new dependency, it is the one the app already has, enumerated.

`tags=boundaries` alone returns 73 datasets — city and county boundary line
changes and Board of Equalization tax rate areas from the BOE, groundwater
basins, hydrologic regions and Delta zones from DWR, incorporated cities,
unincorporated communities.

The catalogue is dominated by one publisher: 1,836 of the 3,990 datasets are
CDFW species and habitat layers. Useful, but it means a naive
"most datasets first" ranking shows a user looking for flood zones a list of
bird ranges. Rank by theme, not by count.

## What is actually in there

Service types across the first-party roots:

| Type | Count | What it is good for |
| --- | ---: | --- |
| FeatureServer | 20,660 | vector overlays queryable by viewport |
| MapServer | 3,216 | server-rendered image overlays; some also queryable |
| ImageServer | 334 | aerial and raster imagery |
| GPServer | 148 | geoprocessing tasks — not map layers |
| GeocodeServer | 110 | county address geocoding, in 27 counties |
| VectorTileServer | 92 | styled vector basemaps |
| SceneServer | 84 | 3D — no use in a 2D map |

Themes, by keyword over service names (a service can match several):

| Theme | Services | Counties |
| --- | ---: | ---: |
| boundaries & districts | 3,418 | 45 |
| basemap & reference | 2,305 | 44 |
| flood & water | 1,439 | 40 |
| transportation | 1,339 | 42 |
| fire & hazard | 1,295 | 42 |
| parcels & assessor | 1,013 | 43 |
| utilities & infrastructure | 728 | 41 |
| environment & habitat | 708 | 38 |
| aerial imagery | 515 | 32 |
| public safety | 494 | 38 |
| recreation & parks | 473 | 35 |
| permits & code | 436 | 36 |
| addressing | 352 | 37 |
| zoning & land use | 259 | 38 |

So the two facts this app currently reads per county — parcels and addresses —
are roughly 6% of what the counties publish. Zoning, flood zones, fire hazard
severity, aerial history and school districts are available in about 40
counties each.

The theme counts are a keyword heuristic and were wrong in one way worth
naming: `zone` on its own matched `FLOOD_ZONES`, `HAZARD_ZONE` and much of the
hydrology, which filed them all under land use and inflated zoning from 259
services to 802. Zoning now has to be named. Expect the same class of error
elsewhere in this table — it is for grouping a long list, not for deciding
what a layer is.

The counts are honest about noise. San Bernardino's hosted org carries
`HomelessContactForm`, `Teen311_App_Survey` and forty other Survey123 form
back-ends alongside its parcels. A catalogue that dumps the raw list is not
usable; see the strategy document's ranking rules.

## Facts that constrain how a layer can be drawn

Captured per service, because a title alone does not tell you whether a layer
can be rendered at all:

- **Nothing is blocked by CORS.** All 130 first-party roots return a permissive
  header — 52 send `*`, 78 reflect the requesting origin. Measured server-side
  with a synthetic `Origin` header rather than from a browser: a reflected
  origin does permit a `fetch`, and image tiles loaded as `<img>` never needed
  CORS at all, but the web build should confirm it once. This was the single
  biggest risk to the whole idea and it does not look like one.
- **Query is not universal.** Riverside publishes 104 query-capable services
  and 2 without; San Bernardino publishes 65 with and **67 without**. Half of
  San Bernardino's map services can only be drawn as server-rendered images.
- **Caches are mostly in the wrong projection.** Riverside has no fused cache
  at all — every layer is a dynamic `/export`. San Bernardino has 24 caches, of
  which 20 are tiled in EPSG:6424 and 2 in EPSG:2229 — California State Plane,
  not Web Mercator. Only 2 can be consumed as a direct `{z}/{y}/{x}` template;
  the rest must go through `/export`.
- **`maxRecordCount` is small.** 2,000 and 1,000 dominate both counties. A
  viewport query has to page or accept truncation, and must respect the
  `fastPathRecordCount` floor in `ArcGisService` — a spatially filtered query
  asking for a handful of rows takes tens of seconds.
- **Scale limits are common.** 163 of Riverside's 778 layers carry a
  `minScale`/`maxScale`, so a layer that is on can still legitimately draw
  nothing at the current zoom. The UI has to say so rather than look broken.

## Per-county results

`Services` counts first-party services only. `Primary root` is the largest;
`Other roots` is how many more that county has. Partner-only rows show the
partner's root, which is not the county's own.

<!-- county-table -->
| County | Coverage | Services | Primary root | Other roots | Cities | Top themes |
| --- | --- | ---: | --- | ---: | ---: | --- |
| Alameda | partner-only |  | `https://services3.arcgis.com/i2dkYWmb4wHvYPda/ArcGIS/rest/services` |  | 5 | — |
| Alpine | first-party | 118 | `https://services1.arcgis.com/9z9tEfqo0TExR9C8/arcgis/rest/services` | 1 |  | fire & hazard, parcels & assessor, transportation |
| Amador | first-party | 54 | `https://services8.arcgis.com/uzb563eo87NppqyM/arcgis/rest/services` |  |  | basemap & reference, fire & hazard, boundaries & districts |
| Butte | first-party | 142 | `https://gisportal.buttecounty.ca.gov/arcgis/rest/services` |  |  | boundaries & districts, transportation, flood & water |
| Calaveras | first-party | 273 | `https://gisportal.calaverascounty.gov/server/rest/services` | 2 |  | boundaries & districts, basemap & reference, flood & water |
| Colusa | partner-only |  | `https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services` |  |  | — |
| Contra Costa | first-party | 67 | `https://gis.cccounty.us/arcgis/rest/services` |  | 3 | boundaries & districts, transportation, fire & hazard |
| Del Norte | partner-only |  | `https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services` |  |  | — |
| El Dorado | first-party | 383 | `https://services.arcgis.com/UHg8l1wC48WQyDSO/arcgis/rest/services` | 1 |  | boundaries & districts, flood & water, transportation |
| Fresno | first-party | 582 | `https://services3.arcgis.com/ibgDyuD2DLBge82s/arcgis/rest/services` | 3 | 4 | boundaries & districts, basemap & reference, flood & water |
| Glenn | first-party | 66 | `https://services3.arcgis.com/GUHJKBhKMcD5JjTe/arcgis/rest/services` | 1 |  | basemap & reference, boundaries & districts, flood & water |
| Humboldt | first-party | 222 | `https://gis.co.humboldt.ca.us/arcgis/rest/services` |  |  | parcels & assessor, aerial imagery, basemap & reference |
| Imperial | first-party | 204 | `https://services7.arcgis.com/RomaVqqozKczDNgd/arcgis/rest/services` | 2 |  | boundaries & districts, basemap & reference, fire & hazard |
| Inyo | first-party | 418 | `https://gis.inyo.gov/server/rest/services` | 2 |  | boundaries & districts, fire & hazard, flood & water |
| Kern | first-party | 42 | `https://maps.co.kern.ca.us/arcgis/rest/services` |  | 3 | aerial imagery, utilities & infrastructure, basemap & reference |
| Kings | partner-only |  | `https://services1.arcgis.com/sTaVXkn06Nqew9yU/arcgis/rest/services` |  | 3 | — |
| Lake | first-party | 156 | `https://gis.lakecountyca.gov/server/rest/services` |  | 1 | boundaries & districts, fire & hazard, flood & water |
| Lassen | first-party | 4 | `https://services7.arcgis.com/RUPP32QG1q5ljV4l/arcgis/rest/services` |  |  | boundaries & districts |
| Los Angeles | first-party | 5155 | `https://services.arcgis.com/RmCCgQtiZLDCtblq/arcgis/rest/services` | 8 | 20 | boundaries & districts, basemap & reference, fire & hazard |
| Madera | none-found |  | — |  |  | — |
| Marin | first-party | 694 | `https://services6.arcgis.com/T8eS7sop5hLmgRRH/arcgis/rest/services` | 2 | 2 | boundaries & districts, basemap & reference, flood & water |
| Mariposa | first-party | 357 | `https://services2.arcgis.com/wEula7SYiezXcdRv/arcgis/rest/services` | 1 |  | transportation, basemap & reference, boundaries & districts |
| Mendocino | first-party | 42 | `https://services5.arcgis.com/8y4r60VTvWj2wnDH/arcgis/rest/services` |  |  | boundaries & districts, basemap & reference, fire & hazard |
| Merced | first-party | 1055 | `https://services6.arcgis.com/LYh3hRvKq5ASgAVM/arcgis/rest/services` | 3 |  | boundaries & districts, flood & water, basemap & reference |
| Modoc | first-party | 6 | `https://services6.arcgis.com/MIuDOWgDqUpHjCEg/arcgis/rest/services` | 1 |  | boundaries & districts, public safety |
| Mono | none-found |  | — |  |  | — |
| Monterey | first-party | 1094 | `https://maps.co.monterey.ca.us/server/rest/services` | 1 | 2 | boundaries & districts, fire & hazard, flood & water |
| Napa | first-party | 710 | `https://services1.arcgis.com/Ko5rxt00spOfjMqj/arcgis/rest/services` | 4 |  | basemap & reference, boundaries & districts, transportation |
| Nevada | first-party | 244 | `https://services1.arcgis.com/UvqJJ6GFv4u5BZQj/arcgis/rest/services` | 3 | 1 | boundaries & districts, transportation, basemap & reference |
| Orange | first-party | 839 | `https://ocgis.com/arcpub/rest/services` | 1 | 10 | environment & habitat, utilities & infrastructure, transportation |
| Placer | partner-only |  | `https://services.sacog.org/hosting/rest/services` |  | 1 | — |
| Plumas | partner-only |  | `https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services` |  |  | — |
| Riverside | first-party | 1581 | `https://services1.arcgis.com/pWmBUdSlVpXStHU6/arcgis/rest/services` | 5 | 15 | basemap & reference, flood & water, boundaries & districts |
| Sacramento | first-party | 268 | `https://services1.arcgis.com/5NARefyPVtAeuJPU/arcgis/rest/services` | 2 | 5 | boundaries & districts, flood & water, basemap & reference |
| San Benito | first-party | 482 | `https://services2.arcgis.com/NjMFCzThTMQy3AJa/arcgis/rest/services` | 2 |  | boundaries & districts, flood & water, basemap & reference |
| San Bernardino | first-party | 1274 | `https://services.arcgis.com/aA3snZwJfFkVyDuP/arcgis/rest/services` | 4 | 9 | boundaries & districts, basemap & reference, parcels & assessor |
| San Diego | first-party | 215 | `https://services1.arcgis.com/1vIhDJwtG5eNmiqX/arcgis/rest/services` | 1 | 10 | fire & hazard, basemap & reference, boundaries & districts |
| San Francisco | first-party | 2221 | `https://services.arcgis.com/Zs2aNLFN00jrS4gG/arcgis/rest/services` | 4 |  | boundaries & districts, basemap & reference, transportation |
| San Joaquin | first-party | 489 | `https://services2.arcgis.com/GQhSReJEO6f7tsvy/arcgis/rest/services` | 1 | 1 | flood & water, boundaries & districts, transportation |
| San Luis Obispo | first-party | 130 | `https://services6.arcgis.com/M6e56DqzbdJf20YO/arcgis/rest/services` | 1 | 2 | basemap & reference, boundaries & districts, flood & water |
| San Mateo | first-party | 1177 | `https://services.arcgis.com/yq3FgOI44hYHAFVZ/arcgis/rest/services` | 4 | 4 | boundaries & districts, basemap & reference, flood & water |
| Santa Barbara | first-party | 410 | `https://services.arcgis.com/KkJhFbLnXVqahKz2/arcgis/rest/services` | 1 | 1 | flood & water, boundaries & districts, transportation |
| Santa Clara | first-party | 411 | `https://services.arcgis.com/NkcnS0qk4w2wasOJ/arcgis/rest/services` | 5 | 7 | boundaries & districts, basemap & reference, parcels & assessor |
| Santa Cruz | first-party | 199 | `https://services5.arcgis.com/RjgxPpXv8MHiv19f/arcgis/rest/services` | 2 |  | basemap & reference, flood & water, utilities & infrastructure |
| Shasta | first-party | 320 | `https://services2.arcgis.com/22p1CUjMjjRWlw6O/arcgis/rest/services` | 2 | 3 | boundaries & districts, basemap & reference, parcels & assessor |
| Sierra | first-party | 37 | `https://services6.arcgis.com/MtSzpOZ2FMytnchL/arcgis/rest/services` |  |  | boundaries & districts, basemap & reference, utilities & infrastructure |
| Siskiyou | first-party | 138 | `https://services3.arcgis.com/JmPiYilyU1x5zuxM/arcgis/rest/services` | 1 | 1 | boundaries & districts, basemap & reference, fire & hazard |
| Solano | none-found |  | — |  | 1 | — |
| Sonoma | first-party | 756 | `https://services1.arcgis.com/P5Mv5GY5S66M8Z1Q/arcgis/rest/services` | 1 | 2 | fire & hazard, parcels & assessor, boundaries & districts |
| Stanislaus | first-party | 133 | `https://services.arcgis.com/EeYBJFxLdUojipYa/arcgis/rest/services` | 3 | 1 | boundaries & districts, transportation, parcels & assessor |
| Sutter | first-party | 266 | `https://gis.suttercounty.org/server/rest/services` | 2 |  | boundaries & districts, basemap & reference, parcels & assessor |
| Tehama | partner-only |  | `https://services2.arcgis.com/3iNbxbY9zhyxPvde/arcgis/rest/services` |  |  | — |
| Trinity | none-found |  | — |  |  | — |
| Tulare | first-party | 323 | `https://services2.arcgis.com/bYBANhmQGwSSLC0l/arcgis/rest/services` | 3 | 5 | boundaries & districts, flood & water, transportation |
| Tuolumne | first-party | 254 | `https://services3.arcgis.com/afQpMaliVrwHS7Ud/arcgis/rest/services` | 1 |  | boundaries & districts, transportation, basemap & reference |
| Ventura | first-party | 645 | `https://gis.ventura.org/arcgis/rest/services` | 3 | 3 | basemap & reference, boundaries & districts, flood & water |
| Yolo | partner-only |  | `https://services9.arcgis.com/mt4kvYhNXSa5AqLG/arcgis/rest/services` |  | 3 | — |
| Yuba | first-party | 35 | `https://gis.yuba.org/arcgis/rest/services` |  |  | parcels & assessor, addressing, boundaries & districts |
<!-- /county-table -->

## Known limits

- **Point-in-time.** Every number here is from 2026-07-30. Counties add and
  retire services continuously; this file is a starting registry, not a source
  of truth. The app should discover services at runtime and treat the roots as
  the only durable fact.
- **Four counties returned nothing.** Madera, Mono, Solano and Trinity. Absence
  of evidence only.
- **Service counts include noise.** Survey back-ends, test services and
  duplicate `/arcgis/` vs `/ArcGIS/` spellings were deduplicated but internal
  duplication was not.
- **Layer-level detail was only crawled for two counties.** Riverside (778
  layers) and San Bernardino (150) were walked service-by-service; everywhere
  else stops at the service list. That is deliberate — per-service metadata is
  what the app fetches lazily when a layer is turned on.
- **Licensing was not assessed.** Everything here is publicly readable. That is
  not the same as redistributable, which matters the moment overlays enter
  offline snapshots. See the strategy document.
