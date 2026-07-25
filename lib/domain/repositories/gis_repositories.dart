import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';

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
