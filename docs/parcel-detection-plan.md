# Runtime parcel-source detection

Implemented revision of the proposed “Detect parcel layers by schema + sample” plan.

## Review decisions

- Keep compiled county sources unchanged. Runtime source copies supply a replaceable repository bundle, including local repositories, so switching a parcel layer cannot reuse another layer's object IDs.
- Treat names as a shortlist only. Before the 25-service cap, prioritize broad parcel names and government hosts. The first live run demonstrated that sorting by publisher tier alone lets hosted address layers and subsets crowd out Maricopa's countywide service.
- Inspect polygon layers with Query capability, a real OID, an APN, and a situs address (full or composed). Check 250 sample rows, require 30% populated APNs and 20% plausible addresses, and choose full-address candidates by plausible fill rate.
- Count intersecting parcels inside the county envelope and apply a verified county-name/FIPS filter where present. Require at least 1,000 rows. Rank penalized coverage counts, then pagination, centroid support, host and URL. Near-tie bands are anchored to their highest score; pairwise “within 5%” comparators are not transitive.
- Apply the county envelope to detected-source address and owner searches even without a county field. Downloads already use spatial bounds. This avoids unrestricted statewide searches, although a bounding rectangle is not an exact county boundary and can include neighboring parcels near borders.
- Honor pagination and centroid capabilities. Unsupported offset pagination uses sorted object-ID slices, fails closed on an explicitly truncated ID response, and snapshot pages respect the published maximum record count. Polygon address positions use the server centroid or the polygon envelope's midpoint; these are representative positions, not independently surveyed address points.
- Partition snapshots and owner caches by county, source URL and field mapping. Existing configured sources retain their original cache keys.
- Persist versioned settings without a database migration. A manual choice beats automatic refresh. Cached sources load first; automatic entries older than 30 days refresh in the background. HTTP 4xx and invalid-field/query failures mark the matching cached entry stale for the next resolution. Forget suppresses automatic rediscovery for the current workspace session.
- Guard adoption with generation tokens, and defer source adoption while a snapshot is importing. Manual source changes are serialized. Clear outstanding viewport, search, area, property and owner selection state when adopting.
- Keep source provenance visible in the layer controls and assistant tools. Catalog service menus offer “Use as parcel source”; the source controls offer Forget. Manual selection still requires verification and the 1,000-row minimum.
- Show manual inspection results in a dialog above the catalog sheet. The proposed root snackbar was obscured by the modal sheet in the desktop walkthrough. Owner subtitles use the actual publisher and only claim a cached result when it was restored from storage.
- Preserve letters in normalized APNs, escape SQL values, and reject ambiguous or truncated owner responses. Pass state abbreviations through address displays, clipboard output, CSV exports and marker labels without adding state columns to stored address models.

## Implementation

- `parcel_schema.dart`: immutable serializable semantic mappings; name/alias vocabulary and sample plausibility.
- `parcel_layer_inspector.dart`: request semaphore (four requests), 20-second request timeouts, per-layer rejection reasons, sample verification and deterministic ranking.
- `portal_discovery_service.dart`: county/state and discovered-organization item searches plus registered/discovered county and state catalog roots; geographic item gate, URL deduplication and shortlist cap.
- `detected_parcel_source.dart`: persisted source metadata, generic parcel/address mapper and public ArcGIS owner lookup.
- `parcel_source_store.dart`: settings persistence, manual precedence, staleness and forgetting.
- `CountyDataSources`, dependencies and map view model: cached/background resolution, progress, atomic runtime adoption and manual selection.
- Map controls, catalog menus and assistant tools: runtime coverage and provenance.

## Verification

Run deterministic coverage with `flutter test` and `flutter analyze`.

`test/fixtures/parcel_detection` contains live-captured Maricopa service/layer metadata and a 250-row attribute sample, plus King and Hennepin layer metadata. Other schema vocabulary tests use explicit representative fields; they are not presented as captured service fixtures.

The opt-in live diagnostic is:

```sh
flutter test tool/check_parcel_detection.dart
flutter test tool/check_parcel_detection.dart --dart-define=PARCEL_COUNTIES=04013
```

It prints candidates, rejection reasons, the selected source/count/mapping, three mapped parcels and one owner lookup for Maricopa, Harris, King, Hennepin, Wake and Cuyahoga. An unavailable county is reported rather than treated as proof that the detector failed; the live check does not assert universal coverage.

## Remaining heuristic limits

A 250-row sample can miss sparse situs data, and the 1,000-row minimum excludes very small counties or intentionally narrow manual sources. County-envelope counts can include neighboring jurisdictions when the publisher has no usable county field. A source can also be a large subset without naming that fact; the largest verified candidate is evidence of coverage, not proof of a complete county fabric. Parcel-derived addresses represent one published situs per parcel, not every unit or entrance.

ArcGIS capability behavior follows the official [layer metadata](https://developers.arcgis.com/rest/services-reference/enterprise/layer-feature-service/) and [query documentation](https://developers.arcgis.com/rest/services-reference/enterprise/query-feature-service-layer/).

## Results on 2026-09-26

- `flutter test`: 328 tests passed, including 27 detection-specific cases, a runtime-adoption widget test and a catalog-rejection dialog test.
- `flutter analyze`: no issues.
- macOS desktop walkthrough completed: Maricopa searched and adopted automatically, enabled both parcel controls, rendered Avondale parcels, resolved address and parcel owner details, and returned 26 records in a drawn neighborhood rectangle. Reopening Maricopa restored the cached source immediately; Riverside retained its configured layers.
- The catalog's `Subdivisions_view` service was rejected with a visible explanation: its `T_SUBDIVISIONS` layer needs a parcel-number field and situs address. The existing parcel source remained active.
- The desktop walkthrough exposed two remaining display defaults: Riverside owner attribution and California in drawn-area rows. Both were corrected and regression-tested, along with the visible manual-rejection result.
- Live automatic selection: Maricopa county Parcel layer 1 (1,760,474 intersecting records); King public parcel/address layer (574,682); Hennepin regional parcel layer (447,044); Wake parcel layer (438,730).
- Harris's principal services timed out during inspection; Cuyahoga returned no qualifying schema/sample combination. These counties remain uncovered rather than claiming an unverified source.
- Live checks exposed and drove fixes for shortlist crowding and missing Minnesota street-type/postal-community component names. King was rerun after the shortlist correction and selected the countywide public layer.

The final Maricopa smoke check also resolved `702 S 114TH LN, AVONDALE, AZ 85323` to APN `10101019`, returned the published owner `NGUYEN AN K/NHAN`, and read 164 addresses from a small surrounding envelope.

## Owner provenance verification on 2026-09-27

A fresh direct query to `gis.maricopa.gov/arcgis/rest/services/IndividualService/Parcel/MapServer/1/query` for APN `10101019` returned `702 S 114TH LN`, `AVONDALE`, ZIP `85323`, and `OwnerName: NGUYEN AN K/NHAN`. A read-only inspection of the running app's SQLite cache found exactly one matching owner row, scoped to `us:az_maricopa`, that layer's query URL and field mapping. Its stored source URL was the same Maricopa layer; no Riverside cache row matched this APN. Detected sources read the published GIS owner attribute directly, without an assessor-site scraper. The earlier Riverside attribution was a hardcoded UI subtitle, not the source of the owner result.
