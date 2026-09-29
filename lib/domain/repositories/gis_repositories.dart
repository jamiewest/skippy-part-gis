import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';

/// Read access to address points.
abstract interface class AddressRepository {
  /// Addresses matching a user-entered prefix.
  Future<List<Address>> search(String query, {int limit = 20});

  /// Address points visible inside [bounds].
  Future<List<Address>> queryViewport(GeoBounds bounds, {int limit = 2000});
}

/// Read access to parcel geometry and facts.
abstract interface class ParcelRepository {
  /// Parcels visible inside [bounds].
  Future<List<Parcel>> queryViewport(GeoBounds bounds, {int limit = 2000});

  /// The parcel containing [point], when one is loaded or stored.
  Future<Parcel?> hitTest(LatLng point);
}

/// Read access to automated license-plate readers mapped in OpenStreetMap.
abstract interface class AlprCameraRepository {
  /// Cameras inside [bounds], newest crowdsourced data first.
  Future<List<AlprCamera>> queryViewport(GeoBounds bounds, {int limit = 2000});
}

/// Read access to the Riverside County boundary.
abstract interface class BoundaryRepository {
  /// The current county boundary.
  Future<RegionBoundary> getCountyBoundary();
}

/// On-demand access to public property ownership records.
abstract interface class PropertyOwnerRepository {
  /// Finds the public owner record that exactly matches [address].
  ///
  /// Returns `null` when the source has no unambiguous address match.
  Future<PropertyOwnership?> lookupAddress(Address address);

  /// Finds the public owner record for [parcel].
  Future<PropertyOwnership?> lookupParcel(Parcel parcel);

  /// Discards any saved result and checks [address] again.
  Future<PropertyOwnership?> refreshAddress(Address address);

  /// Discards any saved result and checks [parcel] again.
  Future<PropertyOwnership?> refreshParcel(Parcel parcel);
}

/// Resolves the street address of record for a parcel.
///
/// Several county assessor layers publish a parcel number and no address at
/// all. This turns a location on such a parcel into a mailable address so that
/// an APN can be reported as `1364 W RIALTO AVE, RIALTO, CA 92376`.
abstract interface class SitusAddressRepository {
  /// The published street address at [point], or `null` when none is on record.
  ///
  /// Throws when the source cannot be reached, so that an unreachable service
  /// is distinguishable from a parcel that genuinely has no address.
  Future<SitusAddress?> lookupAt(LatLng point);
}

/// Read access to a public ArcGIS catalogue's service list.
abstract interface class LayerCatalogRepository {
  /// The drawable services [portal] publishes.
  Future<List<CatalogService>> listServices(GisPortal portal);

  /// The service's own metadata, read when a layer is turned on.
  ///
  /// This is where sub-layer ids, geometry types and scale limits come from,
  /// and it is deliberately not read while listing: one request per service
  /// would be hundreds before the panel could open.
  Future<Map<String, Object?>> describe(CatalogService service);

  /// Discards any cached listing for [portal] so it is read again.
  void forget(GisPortal portal);
}

/// Finds the public map catalogues published over a place.
///
/// The generated registry can only hold catalogues somebody enumerated
/// offline, and that inventory has been run for one state. This is the channel
/// that answers the same question anywhere: given a county and its state, which
/// organisations publish ArcGIS services over it, and where are their
/// catalogue roots.
///
/// Discovery is a search, not a lookup, so what it returns is a ranked guess
/// backed by a geographic test — see [PortalOrigin.discovered]. It must never
/// block the map: a county whose discovery fails or returns nothing still has
/// its registry entries and the national tier.
abstract interface class PortalDiscoveryRepository {
  /// Catalogues published over [county], most local first.
  ///
  /// [state] is needed as well as the county because a county name does not
  /// identify a county nationally — thirty-one states have a Washington
  /// County — and the state is both what disambiguates the search and where
  /// the state agency tier comes from.
  Future<List<GisPortal>> discover({
    required UsCounty county,
    required UsState state,
  });

  /// Catalogues published by the municipalities [viewport] covers.
  ///
  /// A separate question from [discover], because a county-name search finds
  /// a city only by accident. Hartford's county equivalent is the Capitol
  /// Planning Region, which no publisher names; asking for the region finds
  /// two university catalogues, and asking for the towns under the viewport
  /// finds the state transport and environment departments and the towns
  /// themselves. Cities in a populous county have the milder version of the
  /// same problem: they are crowded out of a county-wide ranking.
  ///
  /// Called as the map moves, so it must be cheap on repeat and bounded over
  /// a session — see the implementation's budget. [county] supplies the
  /// acceptance gate and [state] disambiguates the place name.
  Future<List<GisPortal>> discoverPlaces({
    required GeoBounds viewport,
    required UsCounty county,
    required UsState state,
  });
}

/// Read access to arbitrary overlay geometry.
abstract interface class OverlayFeatureRepository {
  /// Features from [layerQuery] intersecting [bounds].
  Future<List<OverlayFeature>> queryViewport(
    Uri layerQuery,
    GeoBounds bounds, {
    int limit,
  });
}

/// Read access to dated aerial-imagery layers.
abstract interface class ImageryCatalogRepository {
  /// Lists imagery intersecting [coverage], newest capture first.
  Future<List<ImageryLayer>> list({GeoBounds? coverage});
}

/// Persistent access to completed California unclaimed-property checks.
abstract interface class UnclaimedPropertyRepository {
  /// Returns a still-fresh result for [query], when one was saved.
  Future<UnclaimedPropertySearchResult?> findSaved(
    UnclaimedPropertyQuery query,
  );

  /// Saves a completed result so selecting the property does not recheck it.
  Future<void> save(UnclaimedPropertySearchResult result);

  /// Removes the saved value so the owner can be checked again.
  Future<void> remove(UnclaimedPropertyQuery query);
}
