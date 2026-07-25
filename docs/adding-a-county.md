# Upgrading a county

Every California county is already configured. `CaliforniaCounties.all` holds
all 58, and `CountySources.statewide` builds each one against the shared
statewide parcel layer, which gives it parcels, a boundary, a mailable street
address, and address search out of the box.

This document is about the other case: a county that publishes its own services
with more than the statewide fabric carries — a land-use class, an acreage, real
address points, an aerial history, an owner name — and that is therefore worth
reading directly. Riverside and San Bernardino are the two done so far.

The work is the same either way: describe the county's services in one
`CountySource`, write the adapters that read that county's schema, and replace
its statewide entry. No code outside `CountySource` and its adapters should
branch on a county identifier. If you find yourself writing
`if (source.id == ...)`, the fact belongs on `CountySource` instead.

`lib/data/services/county_source.dart` is the single registry.

## 0. Check what the county actually adds

The statewide layer already publishes, for every county, a parcel polygon, an
assessor parcel number, and a situs address split into house number, direction,
street name, street type, unit, city, and ZIP. A county service is worth wiring
up when it adds facts on top of that — not when it merely repeats them in a
different schema.

## 1. GIS layers

Add a `CountySource` entry with the county's address and parcel query
endpoints, the `outFields` each layer needs, and its five-digit `fips`. Reuse
the `id`, `displayName`, `initialCenter`, and `extent` already in
`CaliforniaCounties`; the id in particular scopes offline snapshots and
owner-cache rows, so it must never change once shipped.

Boundaries need no work: every county reads its polygon from the California
State Geoportal's `CA_Counties` layer under `boundaryFilter: "FIPS='<nnn>'"`,
which is the three-digit form, while `countyFilter` uses the five-digit form the
statewide parcel layer keys on.

Write an `ArcGisFeatureMapper` for the county. Counties publish the same facts
under different field names, so the mapper is where `PRCLNUM` becomes `apn`.
Leave a field empty rather than guessing when a county publishes no equivalent,
and say so in the mapper's doc comment.

Replace the county's entry in `CountySources.all`, which selects on the county
id and otherwise falls through to `statewide(county)`.

### Filters, and where they apply

`countyFilter` restricts a shared statewide layer to one county. It is applied
where a result crossing the county line would be wrong — address search and
offline downloads — and deliberately **not** to viewport drawing. The visible
rectangle already bounds a viewport query, and a map panned over a county line
should keep rendering rather than go half blank. A county with its own services
leaves it at the `1=1` default.

### Address points from a parcel layer

A county with no address-point service can answer address queries from its
parcel layer, as the 56 statewide counties do: point `addressQuery` at the same
endpoint, set `addressQueryParameters` to ask for the polygon centroid instead
of the rings, and supply an `addressMapper` that reads the centroid. When
`addressQuery == parcelQuery`, `ArcGisService.sharesAddressLayer` is true and an
offline download fetches each row once and stores it as both.

## 2. Aerial imagery

Supply an `ImageryCatalogFactory`. If the county's `ImageServer` catalog has
the same shape as Riverside's, reuse `ImageryCatalogService`; otherwise write a
catalog service for it. Leave `imageryCatalog` unset when the county has no
aerial history in this build — the workspace hides the imagery control rather
than offering an empty year list.

## 3. Owner names

This is the part that differs most between counties. The plumbing is in place;
what each county needs is a resolver.

Implement `PropertyOwnerSource`
(`lib/data/services/property_owner_source.dart`):

```dart
final class ExampleCountyOwnerService implements PropertyOwnerSource {
  ExampleCountyOwnerService(this._client);

  @override
  Uri get sourceUri => Uri.https('assessor.example.gov', '/search');

  @override
  Future<PropertyOwnership?> lookupByApn(OwnerQuery query) async { ... }

  @override
  Future<PropertyOwnership?> lookupByAddress(OwnerQuery query) async { ... }
}
```

Then set `ownerSource: ExampleCountyOwnerService.new` on the county's
`CountySource`. That is the whole wiring step — `AppDependencies` picks it up
and wraps it in the shared cache. Leave `ownerSource` unset when the county
publishes nothing usable; the app then reports the lookup as unavailable
instead of as a property with no owner on record.

### What the resolver gets

`OwnerQuery` (`lib/domain/models/owner_query.dart`) is the county-neutral
request. It carries the parcel number and the address components the GIS layer
published, already flattened out of `Address` and `Parcel`. Resolvers never
touch the GIS models.

Useful members: `normalizedApn` for searching and comparing, `hasStreetAddress`
to bail out early when a street search is impossible, and `cacheKey`, which the
repository owns — a resolver should not need it.

Note the asymmetry: a parcel selection carries only its parcel number, because
`Parcel` models situs as a single string and `OwnerQuery.fromParcel` does not
try to split it. That is a limit of this app, not of the data — Riverside's
parcel layer separately publishes `STREET_NUMBER`, `STREET_PREDIRECTION`,
`STREET_NAME`, `STREET_TYPE`, `UNIT_NUMBER`, and `ZIP_CODE`, none of which this
app requests, while San Bernardino's publishes no situs at all. A county whose
parcels carry no usable parcel number would leave a resolver nothing to search
on from a parcel click. If you hit that, widen `Parcel` and read the county's
split situs fields in its `ArcGisFeatureMapper` — not in the resolver.

### What to reuse

There is deliberately **no** base class to extend. Riverside searches, then
reads a second detail page; the next county may answer in one request, or gate
its search behind a form. A shared shape guessed from one sample would be worse
than none. Reuse comes from helpers you call:

- `situsMatchesQuery(situs, query)` — confirms a returned row really is the
  requested property. County search endpoints match loosely and will happily
  answer a house number on the wrong street.
- `selectOwnerCandidate(candidates, preferredApn:)` — narrows a result list to
  one unambiguous row, or `null`. Naming the wrong owner is worse than naming
  none.
- `OwnerCandidate` — a search row before its owner detail is read. `recordKey`
  is opaque and county-specific.
- `digitsOnly`, `normalizeForMatching`, `matchTokens`, `decodeHtmlEntities` in
  `lib/core/text_matching.dart`.

`riverside_property_owner_service.dart` is the worked example.

### The situs fallback comes free

Do not write an APN-to-address resolver. `SitusAddressRepository`, implemented
by `StatewideSitusService`, already fills in the street address of any parcel
whose county publishes none, for every county. It looks the address up
**spatially**, from a point inside the parcel, because assessor numbers are
formatted per county — San Bernardino's own layer writes `0128-061-48` where the
statewide fabric writes `012806148` — and a string match would fail exactly where
the fallback is most needed.

### `null` versus throwing

The two are not interchangeable and the map renders them differently.

- Return `null` when the source answered and had no unambiguous match. The
  result is cached, so the property is not rechecked on every selection.
- Throw when the source could not be reached, parsed, or refused the request.
  The repository then falls back to any previously saved answer rather than
  blanking an owner the map already showed.

### Caching

`CachedPropertyOwnerRepository` handles freshness, negative caching, and
offline fallback for every county. Results are keyed
`us:ca:<county-id>:apn:<digits>`, falling back to
`us:ca:<county-id>:<subject>:<feature-id>` when the county publishes no parcel
number. Because the key is parcel-based, clicking an address and then its
parcel reuses one saved lookup.

**This format is an on-disk contract.** Changing it silently orphans every row
in an installed database. `test/owner_query_test.dart` pins the exact strings.

## 4. Legal and licensing

Record what the county actually permits in the README. Owner names are public
record in some counties and redacted in others.

Check the parcel layer before assuming a resolver is needed: a county may
publish owner names straight into its GIS, in which case the mapper reads them
and no `ownerSource` is required. San Bernardino has an `OwnerName` field, but
every one of its 839,806 rows holds the literal string
`Protected Per CA Gov Code 7928.205` rather than a name, so a resolver is the
only route there. Verify by counting rows that do not carry the redaction
string, not by eyeballing a sample.

Note redistribution terms before shipping snapshots.

## 5. Performance

Two rules, both measured against the statewide layer and both easy to violate
by accident:

- **Never ask a spatially filtered query for a few rows.** The same envelope
  query took 12 seconds at `resultRecordCount=100` and 0.4 seconds at 200; a
  point lookup took 42 seconds at 1 and 0.3 seconds at 250, returning the
  identical feature. `ArcGisService.fastPathRecordCount` is the floor, and
  spatial queries below it request the floor and discard the surplus. Keep any
  new spatial query above it.
- **Do not wrap a search column in `UPPER()` unless the data needs it.** It
  stops the server using the column's index. `uppercaseAddressSearch` exists so
  that a county whose address text is already upper-case does not pay for it.

## 6. Verify

```shell
flutter analyze
flutter test
```

Add a `CountySource` test asserting the county's field lists match what its
mapper reads, and a resolver test driving `MockClient` with a captured payload
from the county's real response.

Replacing the county in `CountySources.all` is all the county picker needs; the
workspace picks the list up from `AppDependencies.counties`. Run the app and
switch to the county to confirm its boundary, imagery years, and framing are
the ones you configured.
