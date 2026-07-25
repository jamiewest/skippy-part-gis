import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/data/services/property_owner_cache_store.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Live address access backed by the county ArcGIS service.
final class LiveAddressRepository implements AddressRepository {
  /// Creates a live repository using [service].
  const LiveAddressRepository(this.service);

  /// The county service.
  final ArcGisService service;

  @override
  Future<List<Address>> queryViewport(GeoBounds bounds, {int limit = 2000}) {
    return service.fetchAddressesInBounds(bounds, limit: limit);
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) {
    return service.searchAddresses(query, limit: limit);
  }
}

/// Offline address access backed by the active SQLite snapshot.
final class LocalAddressRepository implements AddressRepository {
  /// Creates a local repository using [store].
  const LocalAddressRepository(this.store);

  /// The local GIS store.
  final LocalGisStore store;

  @override
  Future<List<Address>> queryViewport(GeoBounds bounds, {int limit = 2000}) {
    return store.addressesInBounds(bounds, limit: limit);
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) {
    return store.searchAddresses(query, limit: limit);
  }
}

/// Live parcel access backed by the county ArcGIS service.
final class LiveParcelRepository implements ParcelRepository {
  /// Creates a live repository using [service].
  LiveParcelRepository(this.service);

  /// The county service.
  final ArcGisService service;

  List<Parcel> _lastViewport = const [];

  @override
  Future<Parcel?> hitTest(LatLng point) async {
    for (final parcel in _lastViewport.reversed) {
      if (parcel.bounds.contains(point) && parcel.contains(point)) {
        return parcel;
      }
    }
    return null;
  }

  @override
  Future<List<Parcel>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    _lastViewport = await service.fetchParcelsInBounds(bounds, limit: limit);
    return _lastViewport;
  }
}

/// Offline parcel access backed by the active SQLite snapshot.
final class LocalParcelRepository implements ParcelRepository {
  /// Creates a local repository using [store].
  const LocalParcelRepository(this.store);

  /// The local GIS store.
  final LocalGisStore store;

  @override
  Future<Parcel?> hitTest(LatLng point) async {
    final epsilon = 0.00001;
    final candidates = await store.parcelsInBounds(
      GeoBounds(
        west: point.longitude - epsilon,
        south: point.latitude - epsilon,
        east: point.longitude + epsilon,
        north: point.latitude + epsilon,
      ),
      limit: 20,
    );
    for (final parcel in candidates.reversed) {
      if (parcel.contains(point)) {
        return parcel;
      }
    }
    return null;
  }

  @override
  Future<List<Parcel>> queryViewport(GeoBounds bounds, {int limit = 2000}) {
    return store.parcelsInBounds(bounds, limit: limit);
  }
}

/// Boundary access with live refresh and an offline persisted fallback.
final class CountyBoundaryRepository implements BoundaryRepository {
  /// Creates boundary access using [service] and [store].
  CountyBoundaryRepository(this.service, this.store);

  /// The county service.
  final ArcGisService service;

  /// The local fallback store.
  final LocalGisStore store;

  RegionBoundary? _cached;

  @override
  Future<RegionBoundary> getCountyBoundary() async {
    if (_cached case final cached?) {
      return cached;
    }
    try {
      final boundary = await service.fetchCountyBoundary();
      await store.saveBoundary(boundary);
      return _cached = boundary;
    } on Object {
      final boundary = await store.loadBoundary();
      if (boundary == null) {
        rethrow;
      }
      return _cached = boundary;
    }
  }
}

/// Owner access for counties with no public owner-name source.
///
/// San Bernardino redacts every owner name in its published parcel layer
/// under California Government Code 7928.205, so reporting the lookup as
/// unavailable is more honest than reporting no match.
final class UnavailablePropertyOwnerRepository
    implements PropertyOwnerRepository {
  /// Creates an owner repository that always reports being unavailable.
  const UnavailablePropertyOwnerRepository(this.countyName);

  /// County named in the failure message.
  final String countyName;

  @override
  Future<PropertyOwnership?> lookupAddress(Address address) => _unavailable();

  @override
  Future<PropertyOwnership?> lookupParcel(Parcel parcel) => _unavailable();

  @override
  Future<PropertyOwnership?> refreshAddress(Address address) => _unavailable();

  @override
  Future<PropertyOwnership?> refreshParcel(Parcel parcel) => _unavailable();

  Future<Never> _unavailable() {
    return Future<Never>.error(
      StateError('$countyName publishes no public owner names.'),
    );
  }
}

/// Owner access backed by the county site and a persistent SQLite cache.
final class CachedPropertyOwnerRepository implements PropertyOwnerRepository {
  /// Creates cached owner access for the county named by [countyId].
  const CachedPropertyOwnerRepository({
    required this.countyId,
    required this.service,
    required this.cache,
  });

  /// County whose identifier scopes every saved result.
  final String countyId;

  /// The county's live public owner source.
  final PropertyOwnerSource service;

  /// Persistent owner-result cache.
  final PropertyOwnerCacheStore cache;

  @override
  Future<PropertyOwnership?> lookupAddress(Address address) {
    final query = OwnerQuery.fromAddress(address, countyId: countyId);
    return _lookup(query, () => service.lookupByAddress(query));
  }

  @override
  Future<PropertyOwnership?> lookupParcel(Parcel parcel) {
    final query = OwnerQuery.fromParcel(parcel, countyId: countyId);
    return _lookup(query, () => service.lookupByApn(query));
  }

  @override
  Future<PropertyOwnership?> refreshAddress(Address address) {
    final query = OwnerQuery.fromAddress(address, countyId: countyId);
    return _fetch(query, () => service.lookupByAddress(query));
  }

  @override
  Future<PropertyOwnership?> refreshParcel(Parcel parcel) {
    final query = OwnerQuery.fromParcel(parcel, countyId: countyId);
    return _fetch(query, () => service.lookupByApn(query));
  }

  Future<PropertyOwnership?> _lookup(
    OwnerQuery query,
    Future<PropertyOwnership?> Function() fetch,
  ) async {
    final cached = await cache.readFresh(query.cacheKey);
    if (cached != null) {
      return cached.ownership;
    }
    return _fetch(query, fetch);
  }

  /// Checks the county source and keeps any saved answer if it cannot be read.
  ///
  /// A county site being briefly unreachable should not blank an owner the map
  /// already showed, so a prior result is preferred over surfacing the error.
  Future<PropertyOwnership?> _fetch(
    OwnerQuery query,
    Future<PropertyOwnership?> Function() fetch,
  ) async {
    final prior = await cache.readAny(query.cacheKey);
    try {
      final ownership = await fetch();
      await cache.save(query.cacheKey, ownership, sourceUri: service.sourceUri);
      return ownership;
    } on Object {
      if (prior?.ownership case final saved?) {
        return saved;
      }
      rethrow;
    }
  }
}
