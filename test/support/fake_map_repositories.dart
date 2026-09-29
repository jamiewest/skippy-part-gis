import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'package:riverside_atlas/domain/repositories/county_data_sources.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
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
import 'package:riverside_atlas/domain/models/snapshot_status.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// A workspace whose repositories all answer with nothing.
///
/// For tests about one collaborator — the layer catalogue, say — where every
/// other repository only has to exist and stay quiet.
GisMapViewModel buildFakeMapViewModel({
  RouteViewModel? routing,
  LayerCatalogRepository? layerCatalog,
  OverlayFeatureRepository? overlayFeatures,
  AddressRepository? addresses,
  AlprCameraRepository? alprCameras,
  List<GisPortal> portals = const [],
  List<CityPortals> cities = const [],
  Future<CountyDataSources> Function(CatalogService)? selectParcelSource,
  Future<CountyDataSources> Function()? resetParcelSource,
  ParcelSourceResolver? resolveParcelSource,
  PortalDiscovery? portalDiscovery,
  PortalPlaceDiscovery? portalPlaceDiscovery,
  String countyName = 'Example County',
  bool snapshotAvailable = false,
  bool parcelsAvailable = true,
}) {
  return GisMapViewModel(
    routing: routing,
    countyName: countyName,
    countyExtent: const GeoBounds(
      west: -117.7,
      south: 33.4,
      east: -114.4,
      north: 34.1,
    ),
    liveAddresses: addresses ?? const SilentAddressRepository(),
    localAddresses: addresses ?? const SilentAddressRepository(),
    liveParcels: const SilentParcelRepository(),
    localParcels: const SilentParcelRepository(),
    boundaries: SilentBoundaryRepository(),
    snapshotManager: SilentSnapshotController(available: snapshotAvailable),
    propertyOwners: const SilentPropertyOwnerRepository(),
    unclaimedProperties: const SilentUnclaimedPropertyRepository(),
    situsAddresses: const SilentSitusAddressRepository(),
    alprCameras: alprCameras ?? const SilentAlprCameraRepository(),
    overlayFeatures: overlayFeatures ?? const SilentOverlayFeatureRepository(),
    layerCatalog: layerCatalog,
    parcelsAvailable: parcelsAvailable,
    portals: portals,
    cities: cities,
    portalDiscovery: portalDiscovery,
    resolveParcelSource: resolveParcelSource,
    selectParcelSource: selectParcelSource,
    resetParcelSource: resetParcelSource,
    portalPlaceDiscovery: portalPlaceDiscovery,
  );
}

/// An address source with nothing in it.
final class SilentAddressRepository implements AddressRepository {
  /// Creates the empty source.
  const SilentAddressRepository();

  @override
  Future<List<Address>> search(String query, {int limit = 20}) async =>
      const [];

  @override
  Future<List<Address>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async => const [];
}

/// A parcel source with nothing in it.
final class SilentParcelRepository implements ParcelRepository {
  /// Creates the empty source.
  const SilentParcelRepository();

  @override
  Future<List<Parcel>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async => const [];

  @override
  Future<Parcel?> hitTest(LatLng point) async => null;
}

/// A boundary source publishing an empty outline.
final class SilentBoundaryRepository implements BoundaryRepository {
  @override
  Future<RegionBoundary> getCountyBoundary() async =>
      RegionBoundary(name: 'Example', fips: '000', rings: const []);
}

/// An owner source that never has a record.
final class SilentPropertyOwnerRepository implements PropertyOwnerRepository {
  /// Creates the empty source.
  const SilentPropertyOwnerRepository();

  @override
  Future<PropertyOwnership?> lookupAddress(Address address) async => null;

  @override
  Future<PropertyOwnership?> lookupParcel(Parcel parcel) async => null;

  @override
  Future<PropertyOwnership?> refreshAddress(Address address) async => null;

  @override
  Future<PropertyOwnership?> refreshParcel(Parcel parcel) async => null;
}

/// An unclaimed-property store that never has a saved result.
final class SilentUnclaimedPropertyRepository
    implements UnclaimedPropertyRepository {
  /// Creates the empty store.
  const SilentUnclaimedPropertyRepository();

  @override
  Future<UnclaimedPropertySearchResult?> findSaved(
    UnclaimedPropertyQuery query,
  ) async => null;

  @override
  Future<void> save(UnclaimedPropertySearchResult result) async {}

  @override
  Future<void> remove(UnclaimedPropertyQuery query) async {}
}

/// A situs resolver that never has an address.
final class SilentSitusAddressRepository implements SitusAddressRepository {
  /// Creates the empty resolver.
  const SilentSitusAddressRepository();

  @override
  Future<SitusAddress?> lookupAt(LatLng point) async => null;
}

/// A camera source with nothing in it.
final class SilentAlprCameraRepository implements AlprCameraRepository {
  /// Creates the empty source.
  const SilentAlprCameraRepository();

  @override
  Future<List<AlprCamera>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async => const [];
}

/// An overlay source with nothing in it.
final class SilentOverlayFeatureRepository implements OverlayFeatureRepository {
  /// Creates the empty source.
  const SilentOverlayFeatureRepository();

  @override
  Future<List<OverlayFeature>> queryViewport(
    Uri layerQuery,
    GeoBounds bounds, {
    int limit = 1200,
  }) async => const [];
}

/// An imagery catalogue with no years in it.
final class SilentImageryCatalogRepository implements ImageryCatalogRepository {
  /// Creates the empty catalogue.
  const SilentImageryCatalogRepository();

  @override
  Future<List<ImageryLayer>> list({GeoBounds? coverage}) async => const [];
}

/// A snapshot controller that never imports anything.
final class SilentSnapshotController implements GisSnapshotController {
  /// Creates the inert controller.
  ///
  /// [available] reports a complete snapshot, which is what offline mode
  /// refuses to switch to without.
  const SilentSnapshotController({this.available = false});

  /// Whether a snapshot is reported as ready.
  final bool available;

  @override
  bool get isImporting => false;

  @override
  Future<SnapshotStatus> status() async => available
      ? SnapshotStatus.empty.copyWith(isAvailable: true, addressCount: 1)
      : SnapshotStatus.empty;

  @override
  Future<int> estimate(GeoBounds region) async => 0;

  @override
  Future<void> download({
    required GeoBounds region,
    required void Function(SnapshotStatus status) onProgress,
  }) async {}

  @override
  void cancel() {}
}
