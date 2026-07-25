# Riverside Atlas

A macOS Flutter prototype for searching and visualizing public county address
points, assessor parcels, and county boundaries. All 58 California counties are
configured; coverage is the whole county in each, incorporated cities and
unincorporated areas alike.

## What works

- Live county-wide address search and viewport-based map queries.
- Address-point and parcel-boundary overlays in every California county.
- A parcel's street address of record, resolved statewide, even where the
  county's own assessor layer publishes no situs.
- Address, property-fact, and cached owner detail panels.
- One-click copy of a selection's APN, location, and owner name, or of the whole
  detail block as `LABEL: value` lines.
- Riverside and San Bernardino aerial-imagery history, ordered newest first.
- An optional OpenStreetMap layer of automated license-plate readers, Flock
  Safety hardware included, in the style of the DeFlock project.
- Saved California unclaimed-property outcomes shown inline with owner details.
- A resumable, in-app SQLite snapshot of the visible map area or of a whole
  county, downloaded by subdividing the region and paging each tile.
- FTS5 address search and RTree spatial indexes.
- Adaptive Material 3 desktop and compact-window layouts.

## Run locally

```shell
flutter pub get
dart run build_runner build
flutter run -d macos
```

Validation:

```shell
flutter analyze
flutter test
flutter build macos
flutter build web
```

## Run on the web

```shell
flutter run -d chrome
```

Every county service the app reads answers cross-origin requests, so live
search, parcels, boundaries, imagery, and the Overpass camera layer all work
from a browser unchanged. Three things differ from the desktop build.

**SQLite is WebAssembly.** `web/sqlite3.wasm` and `web/drift_worker.js` are
checked in because drift fetches them from the site root at run time; a deploy
that omits them cannot open the database at all. Both are upstream release
artifacts and are replaced by re-downloading them, not by building:

```shell
curl -L -o web/sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm
curl -L -o web/drift_worker.js \
  https://github.com/simolus3/drift/releases/latest/download/drift_worker.js
```

Serve the app with `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: credentialless` to get OPFS, which is the
backend the offline snapshot wants. Without those headers drift falls back to
IndexedDB: slower, still persistent, still able to create the FTS5 and RTree
tables. `credentialless` is deliberate — the stricter `require-corp` would
block the basemap and county tiles. The backend that was chosen is logged
under `riverside_atlas.database` on startup, though that log does not reach
the browser console in a release or profile build; `DriftWebOptions.onResult`
in `app_database.dart` is the hook to read it from, and is where a check for
a non-persistent backend would go.

GitHub Pages serves no custom response headers, so the deployed build always
takes the IndexedDB path. Reaching OPFS needs a host that can set those two
headers.

## Deploying

`.github/workflows/deploy-web.yml` builds the web bundle on every push to
`main` and publishes it to GitHub Pages at
<https://jamiewest.github.io/skippy-part-gis/>. The base href in that workflow
is the repository name; renaming the repository means changing it too, or every
asset request resolves against the domain root and 404s.

**Owner lookup is unavailable.** Owner sources are county sites read directly
rather than APIs, and none of them send `Access-Control-Allow-Origin`, so the
browser blocks the request before it leaves. The web build reports owners as
unavailable for every county rather than firing a request that cannot succeed,
which is the same path San Bernardino already takes. Routing an owner source
through a same-origin proxy is the one change that would lift this.

**Google search opens a new tab.** `webview_flutter` has no web
implementation, and an iframe is refused because `www.google.com` sends
`X-Frame-Options: SAMEORIGIN`, so the panel offers a link instead of an
embedded browser. `google_search_view.dart` picks the implementation per
platform.

The OpenStreetMap basemap needs a different tile provider before any real web
deployment. Repeated reloads during development were enough to have
`tile.openstreetmap.org` answer the browser with `503` while the same tiles
still served fine to other clients, so expect the basemap to drop out under
ordinary iteration. Separately, browsers forbid setting `User-Agent`, so the
`userAgentPackageName` that identifies this app to OSM has no effect on the
web. The OSM tile usage policy does not cover deployed applications at volume
on any platform.

## Counties

The workspace reads one county at a time. Pick one from the searchable picker
under the app name on desktop, or from the COUNTY section of the tools sheet on
compact windows; type any part of a name to filter the list of 58. Switching
rebuilds every county-scoped repository and frames the new county's extent, so
it is blocked while a snapshot download is running — pause or finish the
download first.

Panning is bounded by the state rather than by the selected county, because
parcels come from a statewide layer and a map that stopped at the county line
would refuse to draw data it can load. When the map is panned over a different
county, a **Switch to …** chip appears over the map; taking it moves the
workspace, and ignoring it leaves the map where it is.

`lib/data/services/california_counties.dart` holds each county's identifier,
FIPS code, centre, and extent. `lib/data/services/county_source.dart` turns
those into the endpoints, `outFields`, and attribute mapping the app reads, and
`AppDependencies.createMapViewModel` builds a workspace from one. Local
snapshots and the saved boundary are scoped by county id, so a Riverside
download is never served as San Bernardino data.

County identifiers are an on-disk contract. `riverside` and `san_bernardino`
predate the statewide registry and are kept verbatim; renaming any id orphans
every snapshot row and cached owner result saved under the old one.

### What each county gets

| | Riverside | San Bernardino | The other 56 |
| --- | --- | --- | --- |
| Parcels | county assessor | county parcel service | statewide fabric |
| Address points | county address layer | county site addresses | parcel centroids |
| Boundary | state layer | state layer | state layer |
| Street address for a parcel | county situs | statewide fabric | statewide fabric |
| Land use and acreage | yes | acreage only | no |
| Aerial history | yes | yes | no |
| Owner names | yes | redacted countywide | no |

Land use, acreage, and the county address-type code are left empty for a
statewide-sourced parcel rather than guessed; the statewide layer publishes
none of them, and `Shape__Area` is a projected geometry measurement, not an
assessed figure.

San Bernardino runs every Riverside feature except property owners. Its parcel
layer redacts every owner name countywide under California Government Code
7928.205, so owner lookups — and the unclaimed-property check that keys off an
owner name — report as unavailable rather than returning a wrong or empty
match.

## Matching an APN to a street address

The point of the statewide layer is that each row carries an assessor parcel
number *and* the components of a mailable address, so a parcel can be reported
as `1364 W RIALTO AVE, RIALTO, CA 92376`.

Where a county's own assessor layer publishes no situs — San Bernardino
publishes none at all — selecting a parcel resolves its address from the
statewide layer and shows it with a `STREET SOURCE` row naming where it came
from. The lookup is **spatial, not by parcel number**: assessor numbers are
formatted per county, so San Bernardino's own layer writes `0128-061-48` where
the statewide fabric writes `012806148`, and a string match would fail exactly
where it is most needed. A point inside the parcel has no such ambiguity.

A parcel with no address on record reports that rather than inventing one. The
statewide layer writes the literal `, ,  ` into its own `FullStreetAddress`
column for those rows, so that column is deliberately never read.

## Offline snapshots

A snapshot covers either the visible map area or a whole county. Both are
downloaded the same way: the region is quartered until each tile holds few
enough features to page shallowly, then each tile is paged. Inserts ignore
conflicts, so a paused download resumes by re-covering ground rather than by
tracking which tiles finished.

That shape is forced by two real limits. A feature service caps how many object
IDs one query returns, so the app's previous list-then-fetch import could not
express "download this whole county" for Los Angeles. And deep pagination is
expensive: reading page 100 of a single large query measured over thirty
seconds against the statewide layer, while the same rows read as small tiles
come back in well under a second each.

A region holding more than 400,000 features is refused with its count. Small
and medium counties fit whole; Los Angeles, San Diego, and Orange have to be
taken an area at a time.

A download that ends up short of the count the county reported does not
activate. Paging stops on a short page, which is indistinguishable from a page
the service truncated, so a download can end early without failing — and the
whole point of an offline snapshot is that what is missing from it is known.
The shortfall is reported with both numbers and the downloaded rows are kept to
resume from. The comparison allows a small tolerance, because the count is taken
before the first page and the county keeps editing in between.

## Performance notes

Two settings account for most of the map's responsiveness against a
13-million-row layer, and both are counter-intuitive enough to be worth stating.

**Never ask a spatially filtered query for a few rows.** A hosted feature layer
answers a small `resultRecordCount` off a slow path. Measured repeatedly against
the statewide layer, the same envelope query took 12 seconds at a limit of 100
and 0.4 seconds at 200; a point lookup took 42 seconds at a limit of 1 and 0.3
seconds at 250, returning the identical feature. `ArcGisService` therefore asks
for at least 250 rows on any spatial query and discards the surplus.

**Generalize viewport geometry server-side.** Parcel outlines are surveyed to a
precision no screen can show, so viewport queries pass `maxAllowableOffset` set
to roughly one pixel of the current view. Offline snapshots deliberately do not,
because stored geometry is redrawn at every later zoom.

Attribute queries are not affected by either; a county-scoped address prefix
search over 13 million rows answers in under a second, which is why the search
field never wraps its column in `UPPER()` — doing so would stop the server using
its index.

## Data sources

Statewide:

- `CA_Statewide_Parcels_Public_view` on CAL FIRE's ArcGIS Online organization —
  13.1 million parcels across all 58 county FIPS codes, each with an assessor
  parcel number and situs address components. Query-only, anonymous. The
  hosted-view hostname is organization-specific; ArcGIS Online item
  `2061fbc963464c5198ec064100802624` is the durable handle to it.
- The California State Geoportal's `Boundaries/CA_Counties` layer for all 58
  county polygons, filtered per county by FIPS.

Riverside County:

- `OpenData/ADDRESS` FeatureServer layer 8.
- `OpenData/Assessor` MapServer layer 50.
- ArcGIS aerial `ImageServer` catalog.
- Treasurer–Tax Collector public property search.

San Bernardino County:

- `AddressDataManagement/SBC_Site_Addresses` FeatureServer layer 0 on
  `maps.sbcounty.gov`.
- `Parcels_for_San_Bernardino_County` FeatureServer layer 0 on the county's
  Esri-hosted `services.arcgis.com` organization.
- One aerial `ImageServer` per capture year at `maps.sbcounty.gov/img`.

Shared:

- OpenStreetMap raster tiles for the online basemap.
- OpenStreetMap `man_made=surveillance` + `surveillance:type=ALPR` features
  through the public Overpass API.

License-plate readers are crowdsourced OpenStreetMap data under the ODbL, not
county data. The layer is live-only, is not written into offline snapshots, and
loads at zoom 12 and closer so that panning stays inside the shared Overpass
instance's rate limits. Coverage is only as complete as volunteer mapping, so
an empty area means nobody has surveyed it rather than that no cameras exist.

The statewide parcel layer is licensed third-party content republished by the
state — `PARCEL_DMP_ID` is Digital Map Products lineage — and is exposed with a
query capability and no extract endpoint. Confirm redistribution terms before
publishing anything downloaded through it; the offline snapshot is scoped to a
region or a single county for that reason, and there is deliberately no
"download all of California".

The application is read-only. County GIS data is approximate and intended for
reference use; parcel geometry is not a legal survey boundary.

The app no longer opens California's ClaimIt site. When a locally cached
unclaimed-property check exists for the selected owner, its outcome and result
count are written straight into the property details as an `UNCLAIMED` row;
when none exists the row is omitted. There is no in-app lookup because the
state's search API is gated behind Cloudflare Turnstile verification.

## Structure

- `lib/domain`: immutable models and repository contracts.
- `lib/data`: ArcGIS access, Drift/SQLite persistence, and repositories.
- `lib/ui`: Material 3 views and `ChangeNotifier` view models.
- `lib/app`: dependency wiring and centralized themes.
- `lib/core`: utilities shared across layers.

Counties are configured, not special-cased. `lib/data/services/county_source.dart`
is the registry, and `docs/adding-a-county.md` is the checklist for giving a
county its own services instead of the statewide default.
