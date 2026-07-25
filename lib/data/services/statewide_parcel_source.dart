/// The one statewide layer that gives every California county parcel data.
///
/// CAL FIRE republishes a public, anonymously queryable view of a 13.1-million
/// row statewide parcel fabric. Every one of the 58 county FIPS codes is
/// present, and each row carries an assessor parcel number alongside the
/// components of a mailable street address. That single fact is what lets this
/// application cover counties whose own GIS publishes nothing, and what lets an
/// APN be turned into `1364 W RIALTO AVE, RIALTO, CA 92376`.
///
/// The service host is an organization-specific ArcGIS hosted-view hostname and
/// is not stable the way a county's own domain is. ArcGIS Online item
/// `2061fbc963464c5198ec064100802624` is the durable handle: resolve it through
/// `arcgis.com/sharing/rest/content/items/<id>` to recover the URL if the
/// hostname ever moves.
///
/// The data is licensed third-party content — `PARCEL_DMP_ID` is Digital Map
/// Products lineage — republished by the state under a query-only capability
/// with no extract endpoint. Treat downloaded copies accordingly.
library;

import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';

/// Query endpoint for the statewide parcel layer.
final statewideParcelQuery = Uri.parse(
  'https://bz1uwWPKUInZBK94.svcs5.arcgis.com/bz1uwWPKUInZBK94/arcgis/rest/'
  'services/CA_Statewide_Parcels_Public_view/FeatureServer/0/query',
);

/// `outFields` needed to draw and describe a statewide parcel.
///
/// The layer publishes no land-use class and no acreage, so neither is
/// requested; see [StatewideParcelMapper] for what stays empty because of it.
const statewideParcelFields =
    'OBJECTID,PARCEL_APN,FIPS_CODE,COUNTYNAME,SITE_ADDR,SITE_CITY,SITE_ZIP';

/// `outFields` needed to describe a statewide parcel as an address point.
const statewideAddressFields =
    'OBJECTID,PARCEL_APN,SITE_ADDR,SITE_CITY,SITE_ZIP,SITE_HOUSE_NUMBER,'
    'SITE_DIRECTION,SITE_STREET_NAME,SITE_MODE';

/// The field an address prefix search matches against.
const statewideAddressSearchField = 'SITE_ADDR';

/// `outFields` needed to resolve a parcel's street address of record.
const statewideSitusFields =
    'PARCEL_APN,COUNTYNAME,SITE_ADDR,SITE_CITY,SITE_ZIP';

/// Extra query parameters the statewide layer needs to answer as address points.
///
/// The layer holds polygons, not points, so an address position comes from the
/// server-computed centroid. Asking for the centroid instead of the rings also
/// makes a search response a fraction of the size.
const statewideAddressQueryParameters = <String, String>{
  'returnGeometry': 'false',
  'returnCentroid': 'true',
};

/// Reads the statewide parcel schema as parcels.
///
/// Two facts a county's own assessor layer normally publishes have no statewide
/// equivalent and are left empty rather than guessed: the land-use or class
/// code, and the assessed acreage. `Shape__Area` is a projected geometry
/// measurement, not an assessed figure, so it is not converted into one.
final class StatewideParcelMapper implements ArcGisFeatureMapper {
  /// Creates the statewide parcel mapper.
  const StatewideParcelMapper();

  @override
  Address address(Map<String, Object?> feature) =>
      const StatewideAddressMapper().address(feature);

  @override
  Parcel parcel(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    return Parcel(
      sourceId: arcGisInt(attributes['OBJECTID']),
      apn: arcGisString(attributes['PARCEL_APN']),
      situsAddress: arcGisString(attributes['SITE_ADDR']),
      city: arcGisString(attributes['SITE_CITY']),
      zipCode: arcGisString(attributes['SITE_ZIP']),
      landUse: '',
      acreage: null,
      rings: arcGisRings(arcGisObject(feature['geometry'])['rings']),
    );
  }
}

/// Reads the statewide parcel schema as address points.
///
/// `SITE_ADDR` is already the complete street line with any unit designator
/// inside it, so it is used verbatim as the full address and [Address.unit] is
/// left empty; appending the unit again would render `535 PIERCE ST APT 3115
/// Unit APT 3115`. The parsed house number, street name, and street type are
/// still read so that detail panels keep their structure.
///
/// Two fields have no statewide equivalent and stay empty: the county address
/// type code and the unit count at the point. A parcel is also not an address
/// point — a parcel with no situs on record yields an empty address rather than
/// a fabricated one, and `FullStreetAddress` is deliberately not read because
/// the layer writes the literal `, ,  ` into it for those rows.
final class StatewideAddressMapper implements ArcGisFeatureMapper {
  /// Creates the statewide address mapper.
  const StatewideAddressMapper();

  @override
  Address address(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    final objectId = arcGisInt(attributes['OBJECTID']);
    return Address(
      objectId: objectId,
      sourceId: objectId,
      fullAddress: arcGisString(attributes['SITE_ADDR']),
      houseNumber: arcGisNullableInt(attributes['SITE_HOUSE_NUMBER']),
      streetName: [
        arcGisString(attributes['SITE_DIRECTION']),
        arcGisString(attributes['SITE_STREET_NAME']),
      ].where((part) => part.isNotEmpty).join(' '),
      streetType: arcGisString(attributes['SITE_MODE']),
      unit: '',
      city: arcGisString(attributes['SITE_CITY']),
      zipCode: arcGisString(attributes['SITE_ZIP']),
      apn: arcGisString(attributes['PARCEL_APN']),
      addressType: '',
      numberOfUnits: 0,
      position: statewideCentroid(feature),
    );
  }

  @override
  Parcel parcel(Map<String, Object?> feature) =>
      const StatewideParcelMapper().parcel(feature);
}

/// The position of [feature], preferring the server-computed centroid.
///
/// A statewide address row is a polygon queried with `returnCentroid`, so its
/// position arrives beside the attributes rather than in `geometry`. Falling
/// back to `geometry` keeps the mapper usable against a stored snapshot row,
/// which is written back as a point.
LatLng statewideCentroid(Map<String, Object?> feature) {
  final centroid = arcGisObject(feature['centroid']);
  final source = centroid.isEmpty
      ? arcGisObject(feature['geometry'])
      : centroid;
  return LatLng(arcGisDouble(source['y']), arcGisDouble(source['x']));
}

/// Reads a situs address from a statewide feature, or `null` when none exists.
///
/// Rows with no address on record carry empty components, and the layer's own
/// `FullStreetAddress` renders those as the literal `, ,  `. Gating on the
/// street line rather than on that field is what keeps `, ,` off the screen.
SitusAddress? statewideSitus(Map<String, Object?> feature) {
  final attributes = arcGisObject(feature['attributes']);
  final streetAddress = arcGisString(attributes['SITE_ADDR']);
  if (streetAddress.isEmpty) {
    return null;
  }
  return SitusAddress(
    apn: arcGisString(attributes['PARCEL_APN']),
    countyName: arcGisString(attributes['COUNTYNAME']),
    streetAddress: streetAddress,
    city: arcGisString(attributes['SITE_CITY']),
    zipCode: arcGisString(attributes['SITE_ZIP']),
  );
}
