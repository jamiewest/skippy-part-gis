import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/california_counties.dart';
import 'package:riverside_atlas/data/services/imagery_catalog_service.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/data/services/riverside_property_owner_service.dart';
import 'package:riverside_atlas/data/services/san_bernardino_imagery_catalog_service.dart';
import 'package:riverside_atlas/data/services/statewide_parcel_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Stable identifier for Riverside County.
const riversideCountyId = 'riverside';

/// Stable identifier for San Bernardino County.
const sanBernardinoCountyId = 'san_bernardino';

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

/// Everything that differs between two county ArcGIS deployments.
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
    required this.addressQuery,
    required this.parcelQuery,
    required this.boundaryQuery,
    required this.addressFields,
    required this.parcelFields,
    required this.addressSearchField,
    required this.mapper,
    this.addressMapper,
    this.boundaryNameField = 'County',
    this.boundaryFipsField = 'FIPS',
    this.objectIdField = 'OBJECTID',
    this.addressQueryParameters = const {'returnGeometry': 'true'},
    this.uppercaseAddressSearch = true,
    this.countyFilter = '1=1',
    this.imageryCatalog,
    this.ownerSource,
  });

  /// Stable identifier used to scope local snapshots and settings.
  final String id;

  /// Human-readable county name.
  final String displayName;

  /// Five-digit state-plus-county FIPS code, such as `06065`.
  final String fips;

  /// Where the map opens for this county.
  final LatLng initialCenter;

  /// The rectangle the map frames when the workspace switches to this county.
  final GeoBounds extent;

  /// `where` clause that isolates this county in the boundary layer.
  final String boundaryFilter;

  /// Address-point query endpoint.
  final Uri addressQuery;

  /// Parcel-polygon query endpoint.
  final Uri parcelQuery;

  /// County-boundary query endpoint.
  final Uri boundaryQuery;

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

  /// Boundary-layer field holding the area name.
  final String boundaryNameField;

  /// Boundary-layer field holding the county FIPS code.
  final String boundaryFipsField;

  /// The object-identifier field both feature layers order pages by.
  ///
  /// Paging without a stable sort lets a row appear on two pages and another
  /// on none, so a download has to name the column it orders by.
  final String objectIdField;

  /// Extra query parameters this county's address layer needs.
  ///
  /// A county publishing address points needs the point geometry. A county read
  /// through the statewide parcel layer needs the polygon centroid instead.
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

  /// The mapper that reads this county's address responses.
  ArcGisFeatureMapper get effectiveAddressMapper => addressMapper ?? mapper;

  /// Whether this county is read through the shared statewide parcel layer.
  bool get isStatewideSourced => parcelQuery == statewideParcelQuery;
}

/// The counties this build can read.
///
/// Riverside and San Bernardino are configured against their own county
/// services, which publish richer parcel and address attributes than the
/// statewide fabric does. Every other county is built from
/// [CaliforniaCounties] against the shared statewide parcel layer, so adding a
/// county-specific service later is a matter of replacing one entry rather than
/// adding one.
abstract final class CountySources {
  /// Riverside County's public `OpenData` services.
  static final riverside = CountySource(
    id: riversideCountyId,
    displayName: 'Riverside County',
    fips: '06065',
    initialCenter: _riverside.center,
    extent: _riverside.extent,
    boundaryFilter: "FIPS='065'",
    addressQuery: Uri.parse(
      'https://gis.countyofriverside.us/arcgis_mapping/rest/services/'
      'OpenData/ADDRESS/FeatureServer/8/query',
    ),
    parcelQuery: Uri.parse(
      'https://gis.countyofriverside.us/arcgis_mapping/rest/services/'
      'OpenData/Assessor/MapServer/50/query',
    ),
    boundaryQuery: californiaCountiesQuery,
    addressFields:
        'OBJECTID,ADDRESS_ID,ADDRESS,HOUSE_NUMBER,STREET_NAME,STREET_TYPE,'
        'UNIT,CITY,ZIP,APN,ADDRESS_TYPE,NUMBER_OF_UNITS,DATE_EDITED',
    parcelFields: 'OBJECTID,APN,SITUS_STREET,CITY,ZIP_CODE,CLASS_CODE,ACREAGE',
    addressSearchField: 'ADDRESS',
    mapper: const RiversideFeatureMapper(),
    imageryCatalog: ImageryCatalogService.new,
    ownerSource: RiversidePropertyOwnerService.new,
  );

  /// San Bernardino County's public services.
  ///
  /// Address points come from the county's own server while parcels come
  /// from its Esri-hosted feature service, so the two live on different
  /// hosts. Owner names in the parcel layer are redacted countywide under
  /// California Government Code 7928.205 and are not read here.
  static final sanBernardino = CountySource(
    id: sanBernardinoCountyId,
    displayName: 'San Bernardino County',
    fips: '06071',
    initialCenter: _sanBernardino.center,
    extent: _sanBernardino.extent,
    boundaryFilter: "FIPS='071'",
    addressQuery: Uri.parse(
      'https://maps.sbcounty.gov/gis/rest/services/AddressDataManagement/'
      'SBC_Site_Addresses/FeatureServer/0/query',
    ),
    parcelQuery: Uri.parse(
      'https://services.arcgis.com/aA3snZwJfFkVyDuP/arcgis/rest/services/'
      'Parcels_for_San_Bernardino_County/FeatureServer/0/query',
    ),
    boundaryQuery: californiaCountiesQuery,
    addressFields:
        'OBJECTID,ADDRNUM,UNITTYPE,UNITID,FULLNAME,FULLADDR,MUNICIPALITY,'
        'POINTTYPE,ROV_ZIPC,PRCLNUM,LAST_EDITED_DATE',
    parcelFields:
        'OBJECTID,ParcelNumber,Jurisdiction,AssessDescription,Acreage',
    addressSearchField: 'FULLADDR',
    mapper: const SanBernardinoFeatureMapper(),
    imageryCatalog: SanBernardinoImageryCatalogService.new,
  );

  /// Every configured county, alphabetically by display name.
  static final all = List<CountySource>.unmodifiable([
    for (final county in CaliforniaCounties.all)
      switch (county.id) {
        riversideCountyId => riverside,
        sanBernardinoCountyId => sanBernardino,
        _ => statewide(county),
      },
  ]);

  /// The county matching [id], or `null` when nothing is configured for it.
  static CountySource? byId(String id) {
    for (final source in all) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  /// The configured county whose extent contains [point], if any.
  ///
  /// County extents are rectangles, so several can contain one point along a
  /// ragged border; the smallest is the better guess. This is a hint used to
  /// offer a county switch, not an authoritative containment test.
  static CountySource? nearest(LatLng point) {
    CountySource? best;
    var bestArea = double.infinity;
    for (final source in all) {
      if (!source.extent.contains(point)) {
        continue;
      }
      final area =
          (source.extent.east - source.extent.west) *
          (source.extent.north - source.extent.south);
      if (area < bestArea) {
        bestArea = area;
        best = source;
      }
    }
    return best;
  }

  /// Builds a county read entirely through the statewide parcel layer.
  ///
  /// These counties get parcels, boundaries, a mailable situs address, and
  /// address search. They get no aerial-imagery history and no owner names,
  /// because neither exists statewide; both are per-county work.
  static CountySource statewide(CaliforniaCounty county) {
    return CountySource(
      id: county.id,
      displayName: county.displayName,
      fips: county.fips,
      initialCenter: county.center,
      extent: county.extent,
      boundaryFilter: "FIPS='${county.countyFips}'",
      addressQuery: statewideParcelQuery,
      parcelQuery: statewideParcelQuery,
      boundaryQuery: californiaCountiesQuery,
      addressFields: statewideAddressFields,
      parcelFields: statewideParcelFields,
      addressSearchField: statewideAddressSearchField,
      addressQueryParameters: statewideAddressQueryParameters,
      uppercaseAddressSearch: false,
      countyFilter: "FIPS_CODE='${county.fips}'",
      mapper: const StatewideParcelMapper(),
      addressMapper: const StatewideAddressMapper(),
    );
  }

  /// The California State Geoportal's county-boundary layer.
  ///
  /// This is the one layer that publishes all 58 county polygons under a single
  /// schema, so every county reads its outline from it under a FIPS filter.
  static final californiaCountiesQuery = Uri.parse(
    'https://services.gis.ca.gov/arcgis/rest/services/Boundaries/CA_Counties/'
    'FeatureServer/0/query',
  );

  static final _riverside = CaliforniaCounties.byId(riversideCountyId)!;
  static final _sanBernardino = CaliforniaCounties.byId(sanBernardinoCountyId)!;
}
