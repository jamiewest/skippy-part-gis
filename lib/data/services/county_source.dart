import 'package:riverside_atlas/data/services/detected_parcel_source.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/gis_portal_registry.g.dart';
import 'package:riverside_atlas/data/services/state_source.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/data/services/imagery_catalog_service.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/data/services/riverside_property_owner_service.dart';
import 'package:riverside_atlas/data/services/san_bernardino_imagery_catalog_service.dart';
import 'package:riverside_atlas/data/services/statewide_situs_service.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Stable identifier for Riverside County, California.
///
/// County identifiers are prefixed with their state because a county name
/// does not identify a county nationally -- thirty-one states have a
/// Washington County. See [UsCounty.id]; the prefix arrived with national
/// coverage and schema 6 renames what was already on disk.
const riversideCountyId = 'ca_riverside';

/// Stable identifier for San Bernardino County, California.
const sanBernardinoCountyId = 'ca_san_bernardino';

/// Translates one county's ArcGIS attribute schema into the shared models.
///
/// Counties publish the same facts under different field names and types, so
/// each county supplies its own mapper rather than a shared field table.
abstract interface class ArcGisFeatureMapper {
  /// The address point described by [feature].
  Address address(Map<String, Object?> feature);

  /// The parcel described by [feature].
  Parcel parcel(Map<String, Object?> feature);
}

/// Reads Riverside County's `OpenData` address and assessor schema.
final class RiversideFeatureMapper implements ArcGisFeatureMapper {
  /// Creates the Riverside mapper.
  const RiversideFeatureMapper();

  @override
  Address address(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    final geometry = arcGisObject(feature['geometry']);
    return Address(
      objectId: arcGisInt(attributes['OBJECTID']),
      sourceId: arcGisInt(attributes['ADDRESS_ID']),
      fullAddress: arcGisString(attributes['ADDRESS']),
      houseNumber: arcGisNullableInt(attributes['HOUSE_NUMBER']),
      streetName: arcGisString(attributes['STREET_NAME']),
      streetType: arcGisString(attributes['STREET_TYPE']),
      unit: arcGisString(attributes['UNIT']),
      city: arcGisString(attributes['CITY']),
      zipCode: arcGisString(attributes['ZIP']),
      apn: arcGisString(attributes['APN']),
      addressType: arcGisString(attributes['ADDRESS_TYPE']),
      numberOfUnits: arcGisInt(attributes['NUMBER_OF_UNITS']),
      position: LatLng(
        arcGisDouble(geometry['y']),
        arcGisDouble(geometry['x']),
      ),
      sourceUpdatedAt: arcGisEpochMillis(attributes['DATE_EDITED']),
    );
  }

  @override
  Parcel parcel(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    return Parcel(
      sourceId: arcGisInt(attributes['OBJECTID']),
      apn: arcGisString(attributes['APN']),
      situsAddress: arcGisString(attributes['SITUS_STREET']),
      city: arcGisString(attributes['CITY']),
      zipCode: arcGisString(attributes['ZIP_CODE']),
      landUse: arcGisString(attributes['CLASS_CODE']),
      acreage: arcGisNullableDouble(attributes['ACREAGE']),
      rings: arcGisRings(arcGisObject(feature['geometry'])['rings']),
    );
  }
}

/// Reads San Bernardino County's site-address and parcel schema.
///
/// Three facts Riverside publishes have no San Bernardino equivalent and are
/// left empty rather than guessed: the parcel situs address, the parcel ZIP
/// code, and the address unit count. `SITEADDID` arrives as text such as
/// `SID-38`, so the numeric object ID identifies an address row instead.
///
/// The missing situs is filled in from the statewide layer when a parcel is
/// selected; see [SitusAddressRepository].
final class SanBernardinoFeatureMapper implements ArcGisFeatureMapper {
  /// Creates the San Bernardino mapper.
  const SanBernardinoFeatureMapper();

  @override
  Address address(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    final geometry = arcGisObject(feature['geometry']);
    final objectId = arcGisInt(attributes['OBJECTID']);
    final unitType = arcGisString(attributes['UNITTYPE']);
    final unitId = arcGisString(attributes['UNITID']);
    return Address(
      objectId: objectId,
      sourceId: objectId,
      fullAddress: arcGisString(attributes['FULLADDR']),
      houseNumber: arcGisNullableInt(attributes['ADDRNUM']),
      streetName: arcGisString(attributes['FULLNAME']),
      streetType: '',
      unit: '$unitType $unitId'.trim(),
      city: arcGisString(attributes['MUNICIPALITY']),
      zipCode: arcGisString(attributes['ROV_ZIPC']),
      apn: arcGisString(attributes['PRCLNUM']),
      addressType: arcGisString(attributes['POINTTYPE']),
      numberOfUnits: 0,
      position: LatLng(
        arcGisDouble(geometry['y']),
        arcGisDouble(geometry['x']),
      ),
      sourceUpdatedAt: arcGisEpochMillis(attributes['LAST_EDITED_DATE']),
    );
  }

  @override
  Parcel parcel(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    return Parcel(
      sourceId: arcGisInt(attributes['OBJECTID']),
      apn: arcGisString(attributes['ParcelNumber']),
      situsAddress: '',
      city: arcGisString(attributes['Jurisdiction']),
      zipCode: '',
      landUse: arcGisString(attributes['AssessDescription']),
      acreage: arcGisNullableDouble(attributes['Acreage']),
      rings: arcGisRings(arcGisObject(feature['geometry'])['rings']),
    );
  }
}

/// Builds the imagery catalog a county publishes.
typedef ImageryCatalogFactory =
    ImageryCatalogRepository Function(http.Client client);

/// Builds the public owner-name source a county publishes.
typedef PropertyOwnerSourceFactory =
    PropertyOwnerSource Function(http.Client client);

/// The parcel and address layers a county is read through.
///
/// This is nullable on [CountySource] because most counties in the United
/// States have neither. There is no national parcel layer, free or otherwise;
/// California works because one state agency republishes a statewide fabric,
/// and a county outside such a state has parcel data only if it publishes its
/// own service. Bundling the layers into one object rather than scattering a
/// dozen nullable fields is what lets the application ask a single question --
/// [CountySource.hasParcelCoverage] -- and say so plainly.
@immutable
final class CountyLayers {
  /// Creates a layer bundle.
  const CountyLayers({
    required this.addressQuery,
    required this.parcelQuery,
    required this.addressFields,
    required this.parcelFields,
    required this.addressSearchField,
    required this.mapper,
    this.addressMapper,
    this.objectIdField = 'OBJECTID',
    this.addressQueryParameters = const {'returnGeometry': 'true'},
    this.uppercaseAddressSearch = true,
    this.countyFilter = '1=1',
    this.searchBounds,
    this.addressNumberField,
    this.supportsPagination = true,
    this.supportsCentroid = true,
  });

  /// Address-point query endpoint.
  final Uri addressQuery;

  /// Parcel-polygon query endpoint.
  final Uri parcelQuery;

  /// `outFields` list for address queries.
  final String addressFields;

  /// `outFields` list for parcel queries.
  final String parcelFields;

  /// Address field searched by prefix and used for result ordering.
  final String addressSearchField;

  /// Attribute translation for this county's parcel schema.
  final ArcGisFeatureMapper mapper;

  /// Attribute translation for this county's address schema.
  ///
  /// Null means the address layer shares [mapper], which is the case whenever
  /// one service answers both queries.
  final ArcGisFeatureMapper? addressMapper;

  /// The object-identifier field both feature layers order pages by.
  ///
  /// Paging without a stable sort lets a row appear on two pages and another
  /// on none, so a download has to name the column it orders by.
  final String objectIdField;

  /// Extra query parameters this county's address layer needs.
  ///
  /// A county publishing address points needs the point geometry. A county read
  /// through a statewide parcel layer needs the polygon centroid instead.
  final Map<String, String> addressQueryParameters;

  /// Whether an address prefix search must upper-case the field first.
  ///
  /// Wrapping a column in `UPPER()` stops the server using its index, which
  /// turns a sub-second statewide prefix search into a scan. Only counties
  /// whose address text is not already upper-case should pay that cost.
  final bool uppercaseAddressSearch;

  /// `where` clause restricting a shared statewide layer to this county.
  ///
  /// Applied where a result crossing the county line would be wrong — address
  /// search and offline downloads — but deliberately not to viewport drawing.
  /// The visible rectangle already bounds a viewport query, and a map panned
  /// over a county line should keep rendering rather than go half blank.
  final String countyFilter;
  final GeoBounds? searchBounds;
  final String? addressNumberField;
  final bool supportsPagination;
  final bool supportsCentroid;

  /// The mapper that reads this county's address responses.
  ArcGisFeatureMapper get effectiveAddressMapper => addressMapper ?? mapper;

  /// Whether one service answers both the address and the parcel query.
  bool get sharesAddressLayer => addressQuery == parcelQuery;
}

/// Everything that differs between two county deployments.
///
/// Every county in the United States has an identity, a boundary, and the
/// national and state overlay tiers. What varies is whether anything publishes
/// its parcels and addresses, which is what [layers] carries.
@immutable
final class CountySource {
  /// Creates a county configuration.
  const CountySource({
    required this.id,
    required this.displayName,
    required this.fips,
    required this.initialCenter,
    required this.extent,
    required this.boundaryFilter,
    this.layers,
    this.boundaryQuery,
    this.boundaryNameField = 'NAME',
    this.boundaryFipsField = 'GEOID',
    this.imageryCatalog,
    this.ownerSource,
    this.situsSource,
    this.detectedParcels,
  });

  final DetectedParcelSource? detectedParcels;

  /// An isolated runtime copy; the compiled county registry stays unchanged.
  CountySource withDetectedParcels(DetectedParcelSource source) => CountySource(
    id: id,
    displayName: displayName,
    fips: fips,
    initialCenter: initialCenter,
    extent: extent,
    boundaryFilter: boundaryFilter,
    boundaryQuery: boundaryQuery,
    boundaryNameField: boundaryNameField,
    boundaryFipsField: boundaryFipsField,
    imageryCatalog: imageryCatalog,
    situsSource: situsSource,
    layers: source.toCountyLayers(),
    detectedParcels: source,
    ownerSource: source.fields.ownerField == null
        ? null
        : (client) => DetectedOwnerSource(client, source),
  );

  /// Stable identifier used to scope local snapshots and settings.
  ///
  /// Prefixed with the state, such as `ca_riverside`. See [UsCounty.id].
  final String id;

  /// Human-readable county name, such as `Riverside County, CA`.
  final String displayName;

  /// Five-digit state-plus-county FIPS code, such as `06065`.
  final String fips;

  /// Where the map opens for this county.
  final LatLng initialCenter;

  /// The rectangle the map frames when the workspace switches to this county.
  final GeoBounds extent;

  /// `where` clause that isolates this county in the boundary layer.
  final String boundaryFilter;

  /// The parcel and address layers, when any public source covers this county.
  ///
  /// Null means no source this build knows of publishes parcels or addresses
  /// here. The workspace reports that rather than drawing an empty map: see
  /// [hasParcelCoverage].
  final CountyLayers? layers;

  /// County-boundary query endpoint.
  ///
  /// Defaults to the national Census layer, which publishes all 3,235 county
  /// outlines under one schema. A county overrides it only if it has a better
  /// outline of its own.
  final Uri? boundaryQuery;

  /// Boundary-layer field holding the area name.
  final String boundaryNameField;

  /// Boundary-layer field holding the county FIPS code.
  final String boundaryFipsField;

  /// Creates this county's aerial-imagery catalog, when one is published.
  ///
  /// Null means no build-in catalog exists for this county; the workspace hides
  /// the imagery control rather than showing an empty year list.
  final ImageryCatalogFactory? imageryCatalog;

  /// Creates this county's public owner-name source, when one is published.
  ///
  /// Null means this build has no way to name an owner in this county, either
  /// because the county publishes none or because no resolver is written yet.
  /// The application reports the lookup as unavailable rather than as a
  /// property with no owner on record.
  final PropertyOwnerSourceFactory? ownerSource;

  /// Creates the resolver that turns a map point into a street address.
  ///
  /// Null means no source can answer that here, so a parcel with no situs in
  /// its own attributes is reported without one rather than with a blank line.
  final SitusSourceFactory? situsSource;

  /// The boundary layer this county's outline is read from.
  Uri get effectiveBoundaryQuery =>
      boundaryQuery ?? CountySources.usCountiesQuery;

  /// Two-digit state FIPS code, such as `06`.
  String get stateFips => fips.substring(0, 2);

  /// Whether any public layer publishes parcels and addresses here.
  ///
  /// False for most of the country. The workspace disables parcel and address
  /// drawing, search, and offline download, and says why, rather than showing
  /// controls that can only ever return nothing.
  bool get hasParcelCoverage => layers != null;

  /// Whether a public source can name this county's property owners.
  bool get hasOwnerNames => ownerSource != null;

  /// Public map catalogues offered for this county, richest first.
  ///
  /// The county's own portals come first, then its state's agencies, then the
  /// federal ones — narrowest coverage first, because that is the order in
  /// which a layer is likely to be what the user came for.
  ///
  /// The state tier is filtered by [stateFips] rather than offered
  /// everywhere. CAL FIRE's hazard layers are a fact about California; listing
  /// them in a Texas county would attribute coverage its publisher never
  /// claimed, which is the provenance error [PortalTier] exists to prevent.
  ///
  /// Looked up in generated tables rather than by branching: adding a
  /// county's catalogues is a matter of re-running the inventory.
  ///
  /// See `docs/county-gis-inventory.md` for where these came from and
  /// `docs/overlay-catalog-strategy.md` for how they are meant to be used.
  List<GisPortal> get portals => [
    ...?countyPortals[id],
    ...?statePortals[stateFips],
    ...nationalPortals,
  ];

  /// This county's Census geography record.
  ///
  /// Every [CountySource] is built from one, including the two configured by
  /// hand, so the name and rectangle a live catalogue search needs are always
  /// recoverable from the FIPS code without carrying a second copy of them.
  UsCounty? get place => UsGeography.byGeoid(fips);

  /// The state this county is in.
  UsState? get state => UsGeography.stateByFips(stateFips);

  /// Incorporated cities in this county that publish their own catalogue.
  ///
  /// Offered only while the map is over the city — the view model filters by
  /// each city's bounds — because Los Angeles County holds 88 cities and a
  /// panel listing all of them at once would bury the county's own tier.
  List<CityPortals> get cities => cityPortals[id] ?? const [];

  /// Whether this county is read through a shared statewide parcel layer.
  bool get isStatewideSourced =>
      layers != null &&
      layers!.parcelQuery == StateSources.forFips(stateFips)?.parcels?.query;
}

/// The counties this build can read.
///
/// Every county and county equivalent in the United States is here, because
/// [UsGeography] lists them all and every one of them has a boundary and the
/// national overlay tier. What differs is how much more each one gets:
///
/// - Riverside and San Bernardino are configured against their own county
///   services, which publish richer parcel and address attributes than any
///   shared fabric does.
/// - Every other California county is built against the statewide parcel
///   layer in [StateSources], which gives it parcels, a mailable situs
///   address, and address search.
/// - Every county in every other state gets its boundary, its catalogues, and
///   the national tiers. It gets no parcels, because nothing this build knows
///   of publishes them, and the workspace says so.
///
/// Sources are built on demand and cached. Building all 3,235 eagerly would
/// parse ten thousand URLs before the first frame, and a session reads one.
abstract final class CountySources {
  /// The Census Bureau's national county-boundary layer.
  ///
  /// This is the one layer publishing every county outline in the country
  /// under a single schema, which is what lets any county draw its boundary
  /// with no per-county configuration. It replaces the California State
  /// Geoportal's `CA_Counties` layer, which could only ever answer for one
  /// state, and it keys on the five-digit `GEOID` rather than a three-digit
  /// county code that repeats in all fifty states.
  static final usCountiesQuery = Uri.parse(
    'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/'
    'State_County/MapServer/1/query',
  );

  /// Riverside County's public `OpenData` services.
  static final riverside = CountySource(
    id: riversideCountyId,
    displayName: _riverside.displayName,
    fips: _riverside.fips,
    // Hand-picked rather than taken from the Census internal point, which for
    // Riverside lands sixty miles east in the Mojave. The county is framed by
    // its extent on a switch; this is only where a session opens.
    initialCenter: const LatLng(33.9806, -117.3755),
    extent: _riverside.extent,
    boundaryFilter: "GEOID='06065'",
    layers: CountyLayers(
      addressQuery: Uri.parse(
        'https://gis.countyofriverside.us/arcgis_mapping/rest/services/'
        'OpenData/ADDRESS/FeatureServer/8/query',
      ),
      parcelQuery: Uri.parse(
        'https://gis.countyofriverside.us/arcgis_mapping/rest/services/'
        'OpenData/Assessor/MapServer/50/query',
      ),
      addressFields:
          'OBJECTID,ADDRESS_ID,ADDRESS,HOUSE_NUMBER,STREET_NAME,STREET_TYPE,'
          'UNIT,CITY,ZIP,APN,ADDRESS_TYPE,NUMBER_OF_UNITS,DATE_EDITED',
      parcelFields:
          'OBJECTID,APN,SITUS_STREET,CITY,ZIP_CODE,CLASS_CODE,ACREAGE',
      addressSearchField: 'ADDRESS',
      mapper: const RiversideFeatureMapper(),
    ),
    imageryCatalog: ImageryCatalogService.new,
    ownerSource: RiversidePropertyOwnerService.new,
    situsSource: StatewideSitusService.new,
  );

  /// San Bernardino County's public services.
  ///
  /// Address points come from the county's own server while parcels come
  /// from its Esri-hosted feature service, so the two live on different
  /// hosts. Owner names in the parcel layer are redacted countywide under
  /// California Government Code 7928.205 and are not read here.
  static final sanBernardino = CountySource(
    id: sanBernardinoCountyId,
    displayName: _sanBernardino.displayName,
    fips: _sanBernardino.fips,
    initialCenter: const LatLng(34.1083, -117.2898),
    extent: _sanBernardino.extent,
    boundaryFilter: "GEOID='06071'",
    layers: CountyLayers(
      addressQuery: Uri.parse(
        'https://maps.sbcounty.gov/gis/rest/services/AddressDataManagement/'
        'SBC_Site_Addresses/FeatureServer/0/query',
      ),
      parcelQuery: Uri.parse(
        'https://services.arcgis.com/aA3snZwJfFkVyDuP/arcgis/rest/services/'
        'Parcels_for_San_Bernardino_County/FeatureServer/0/query',
      ),
      addressFields:
          'OBJECTID,ADDRNUM,UNITTYPE,UNITID,FULLNAME,FULLADDR,MUNICIPALITY,'
          'POINTTYPE,ROV_ZIPC,PRCLNUM,LAST_EDITED_DATE',
      parcelFields:
          'OBJECTID,ParcelNumber,Jurisdiction,AssessDescription,Acreage',
      addressSearchField: 'FULLADDR',
      mapper: const SanBernardinoFeatureMapper(),
    ),
    imageryCatalog: SanBernardinoImageryCatalogService.new,
    situsSource: StatewideSitusService.new,
  );

  /// The county matching [id], or `null` when no such county exists.
  static CountySource? byId(String id) {
    final cached = _cache[id];
    if (cached != null) {
      return cached;
    }
    final county = UsGeography.byId(id);
    return county == null ? null : forCounty(county);
  }

  /// The county matching the five-digit FIPS code [fips].
  static CountySource? byFips(String fips) {
    final county = UsGeography.byGeoid(fips);
    return county == null ? null : forCounty(county);
  }

  /// The source reading [county], built once and reused.
  static CountySource forCounty(UsCounty county) =>
      _cache[county.id] ??= _build(county);

  /// The configured county whose extent contains [point], if any.
  ///
  /// County extents are rectangles, so several can contain one point along a
  /// ragged border; the smallest is the better guess. This is a hint used to
  /// offer a county switch, not an authoritative containment test.
  static CountySource? nearest(LatLng point) {
    UsCounty? best;
    var bestArea = double.infinity;
    for (final county in UsGeography.counties) {
      if (!county.extent.contains(point)) {
        continue;
      }
      final area =
          (county.extent.east - county.extent.west) *
          (county.extent.north - county.extent.south);
      if (area < bestArea) {
        bestArea = area;
        best = county;
      }
    }
    return best == null ? null : forCounty(best);
  }

  /// Builds the source for [county] from whatever covers it.
  static CountySource _build(UsCounty county) {
    switch (county.id) {
      case riversideCountyId:
        return riverside;
      case sanBernardinoCountyId:
        return sanBernardino;
    }
    final state = StateSources.forFips(county.stateFips);
    final parcels = state?.parcels;
    return CountySource(
      id: county.id,
      displayName: county.displayName,
      fips: county.fips,
      initialCenter: county.center,
      extent: county.extent,
      boundaryFilter: "GEOID='${county.fips}'",
      situsSource: parcels?.situsSource,
      layers: parcels == null
          ? null
          : CountyLayers(
              addressQuery: parcels.query,
              parcelQuery: parcels.query,
              addressFields: parcels.addressFields,
              parcelFields: parcels.parcelFields,
              addressSearchField: parcels.addressSearchField,
              addressQueryParameters: parcels.addressQueryParameters,
              uppercaseAddressSearch: parcels.uppercaseAddressSearch,
              countyFilter: parcels.countyFilter(county.fips),
              mapper: parcels.parcelMapper,
              addressMapper: parcels.addressMapper,
            ),
    );
  }

  static final Map<String, CountySource> _cache = {};

  static final _riverside = UsGeography.byId(riversideCountyId)!;
  static final _sanBernardino = UsGeography.byId(sanBernardinoCountyId)!;
}
