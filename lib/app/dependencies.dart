import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/repositories/gis_repository_implementations.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/data/services/overpass_alpr_service.dart';
import 'package:riverside_atlas/data/services/property_owner_cache_store.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/data/services/statewide_situs_service.dart';
import 'package:riverside_atlas/data/services/unclaimed_property_cache_store.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// Manually wired application services and repositories.
///
/// The HTTP client and database outlive any one county; everything else is
/// county-scoped and rebuilt by [createMapViewModel] when the county changes.
final class AppDependencies {
  AppDependencies._({
    required this.client,
    required this.database,
    required this.initialCounty,
  });

  /// Creates the production dependency graph starting on [county].
  ///
  /// Defaults to Riverside County. The workspace can switch to any entry in
  /// [counties] afterwards.
  factory AppDependencies.create({CountySource? county}) {
    return AppDependencies._(
      client: http.Client(),
      database: AppDatabase(),
      initialCounty: county ?? CountySources.riverside,
    );
  }

  /// Shared HTTP client.
  final http.Client client;

  /// Local application database.
  final AppDatabase database;

  /// The county the session starts on.
  final CountySource initialCounty;

  /// Every county this build can read.
  List<CountySource> get counties => CountySources.all;

  /// Builds a workspace reading [county].
  ///
  /// The caller owns the returned model and must dispose it; switching
  /// counties replaces it rather than mutating it, because the repositories
  /// underneath are all county-scoped.
  GisMapViewModel createMapViewModel(CountySource county) {
    final store = LocalGisStore(database, countyId: county.id);
    final service = ArcGisService(client, county: county);
    return GisMapViewModel(
      countyName: county.displayName,
      countyExtent: county.extent,
      liveAddresses: LiveAddressRepository(service),
      localAddresses: LocalAddressRepository(store),
      liveParcels: LiveParcelRepository(service),
      localParcels: LocalParcelRepository(store),
      boundaries: CountyBoundaryRepository(service, store),
      snapshotManager: SnapshotManager(service: service, store: store),
      propertyOwners: _propertyOwners(county),
      unclaimedProperties: UnclaimedPropertyCacheStore(database),
      imageryCatalog: county.imageryCatalog?.call(client),
      situsAddresses: StatewideSitusService(client),
      alprCameras: OverpassAlprService(client),
    );
  }

  /// Releases network and database resources.
  ///
  /// View models are owned by their caller and disposed separately.
  Future<void> close() async {
    client.close();
    await database.close();
  }

  /// Owner access for [county], or a stub when it publishes no owner names.
  ///
  /// Adding a county's owner lookup is a matter of giving its [CountySource] an
  /// `ownerSource`; no wiring here names a county.
  ///
  /// Every owner source is a county site read directly rather than an API, and
  /// none of them send `Access-Control-Allow-Origin`, so a browser blocks the
  /// request before it is sent. The web build reports owners as unavailable
  /// instead of firing a request that is guaranteed to fail. Routing an owner
  /// source through a same-origin proxy is what would lift this.
  PropertyOwnerRepository _propertyOwners(CountySource county) {
    final ownerSource = kIsWeb ? null : county.ownerSource;
    if (ownerSource == null) {
      return UnavailablePropertyOwnerRepository(county.displayName);
    }
    return CachedPropertyOwnerRepository(
      countyId: county.id,
      service: ownerSource(client),
      cache: PropertyOwnerCacheStore(database),
    );
  }
}
