import 'package:riverside_atlas/data/services/valhalla_routing_service.dart';
import 'package:riverside_atlas/data/services/route_geocoding_service.dart';
import 'package:riverside_atlas/data/services/route_camera_service.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:riverside_atlas/data/services/parcel_layer_inspector.dart';
import 'package:riverside_atlas/data/services/parcel_source_store.dart';
import 'package:riverside_atlas/data/services/detected_parcel_source.dart';
import 'package:riverside_atlas/domain/repositories/county_data_sources.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/repositories/gis_repository_implementations.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/gis_catalog_service.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/data/services/overlay_feature_service.dart';
import 'package:riverside_atlas/data/services/overpass_alpr_service.dart';
import 'package:riverside_atlas/data/services/portal_discovery_service.dart';
import 'package:riverside_atlas/data/services/property_owner_cache_store.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/data/services/unclaimed_property_cache_store.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// The county-scoped half of the application graph.
///
/// The HTTP client and database outlive any one county and are owned by the
/// host container; everything else is county-scoped and rebuilt by
/// [createMapViewModel] when the county changes. That split is why this is
/// still a hand-written factory rather than a set of DI scopes: switching
/// county replaces a dozen repositories at once, which is a lifetime the
/// container has no opinion about.
final class AppDependencies {
  /// Creates the graph over host-owned [client] and [database].
  AppDependencies({
    required this.client,
    required this.database,
    CountySource? county,
    this.routingEndpoint,
    this.routeSnapEndpoint,
    this.geocodingEndpoint,
    this.routeCameraEndpoint,
  }) : initialCounty = county ?? CountySources.riverside;

  /// Creates the graph and the resources it needs, for tests and tools.
  ///
  /// The application resolves [AppDependencies] from the host container
  /// instead, so that the client and database are shared with everything else
  /// registered there.
  factory AppDependencies.create({CountySource? county}) {
    return AppDependencies(
      client: http.Client(),
      database: AppDatabase(),
      county: county,
    );
  }

  final Uri? routingEndpoint;
  final Uri? routeSnapEndpoint;
  final Uri? geocodingEndpoint;
  final Uri? routeCameraEndpoint;

  /// Shared HTTP client.
  final http.Client client;

  /// Local application database.
  final AppDatabase database;

  /// Shared county map-catalogue reader.
  ///
  /// Outlives any one county because its cache is keyed by catalogue root, and
  /// the national catalogues are the same list everywhere — switching county
  /// should not throw away a listing that is still correct.
  late final GisCatalogService catalog = GisCatalogService(client);

  /// Shared live search for catalogues the registry has no entry for.
  ///
  /// Outlives any one county for the same reason [catalog] does: its results
  /// are cached per county, and switching back to a county already searched
  /// should not search it again.
  late final PortalDiscoveryService portalDiscovery = PortalDiscoveryService(
    client,
  );

  late final ParcelLayerInspector parcelInspector = ParcelLayerInspector(
    client,
  );
  late final ParcelSourceStore parcelSources = ParcelSourceStore(database);

  /// Include the mapping, not just the URL: a republished schema can reuse IDs.
  String _dataKey(CountySource county) {
    final source = county.detectedParcels;
    return source == null
        ? county.id
        : '${county.id}:source:${base64Url.encode(utf8.encode(jsonEncode([source.query.toString(), source.fields.fields])))}';
  }

  CountyDataSources dataSourcesFor(CountySource county) {
    final store = LocalGisStore(database, countyId: _dataKey(county));
    final source = county.detectedParcels;
    final service = ArcGisService(
      client,
      county: county,
      onInvalidSource: source == null
          ? null
          : () {
              unawaited(
                parcelSources
                    .markStale(county.id, source.query)
                    .catchError((Object _) {}),
              );
            },
    );
    return CountyDataSources(
      liveAddresses: county.hasParcelCoverage
          ? LiveAddressRepository(service)
          : const EmptyAddressRepository(),
      liveParcels: county.hasParcelCoverage
          ? LiveParcelRepository(service)
          : const EmptyParcelRepository(),
      localAddresses: LocalAddressRepository(store),
      localParcels: LocalParcelRepository(store),
      snapshotManager: SnapshotManager(
        service: service,
        store: store,
        pageSize: source?.maxRecordCount ?? SnapshotManager.defaultPageSize,
      ),
      propertyOwners: _propertyOwners(county),
      situsAddresses:
          county.situsSource?.call(client) ??
          const UnavailableSitusRepository(),
      parcelsAvailable: county.hasParcelCoverage,
      parcelSourceLabel: source?.label,
    );
  }

  /// The county the session starts on.
  final CountySource initialCounty;

  /// Every county this build can read.
  ///
  /// These are the light geography records, not configured sources. Building a
  /// [CountySource] for all 3,235 counties would parse ten thousand URLs
  /// before the first frame, and a session reads one; the picker only needs a
  /// name and a rectangle, and [CountySources.forCounty] builds the rest when
  /// a county is actually chosen.
  List<UsCounty> get counties => UsGeography.counties;

  /// Builds a workspace reading [county].
  ///
  /// The caller owns the returned model and must dispose it; switching
  /// counties replaces it rather than mutating it, because the repositories
  /// underneath are all county-scoped.
  GisMapViewModel createMapViewModel(CountySource county) {
    final store = LocalGisStore(database, countyId: county.id);
    final service = ArcGisService(client, county: county);
    final initial = dataSourcesFor(county);
    var revision = 0;
    Stream<CountyDataSources> resolve(void Function(int, int) progress) async* {
      final token = ++revision;
      final cached = await parcelSources.load(county.id);
      if (token != revision) return;
      if (cached != null) {
        yield dataSourcesFor(county.withDetectedParcels(cached));
        if (cached.origin == 'manual' || !cached.expired) return;
      }
      if (county.hasParcelCoverage ||
          county.place == null ||
          county.state == null) {
        return;
      }
      final candidates = await portalDiscovery.findParcelServiceCandidates(
        county: county.place!,
        state: county.state!,
        catalog: catalog,
        registered: county.portals,
      );
      if (token != revision) return;
      final verified = <DetectedParcelSource>[];
      var next = 0;
      var completed = 0;
      progress(0, candidates.length);
      Future<void> worker() async {
        while (next < candidates.length && token == revision) {
          final candidate = candidates[next++];
          final result = await parcelInspector.inspectService(
            candidate.uri,
            county,
            publisher: candidate.portal.publisher,
          );
          verified.addAll(result.layers);
          if (token == revision) progress(++completed, candidates.length);
        }
      }

      await Future.wait(List.generate(4, (_) => worker()));
      if (token != revision) return;
      final winner = parcelInspector.rank(verified).firstOrNull;
      if (winner != null) {
        final saved = await parcelSources.save(county.id, winner);
        if (token == revision) {
          yield dataSourcesFor(county.withDetectedParcels(saved));
        }
      }
    }

    return GisMapViewModel(
      routing: RouteViewModel(
        planner: RoutePlanner(
          routing: ValhallaRoutingService(
            client,
            endpoint: routingEndpoint,
            snapEndpoint: routeSnapEndpoint,
          ),
          cameras: OverpassRouteCameraService(
            client,
            endpoint: routeCameraEndpoint,
          ),
        ),
        geocoder: PhotonRouteGeocoder(client, endpoint: geocodingEndpoint),
      ),
      countyName: county.displayName,
      countyExtent: county.extent,
      stateCode: county.state?.displayAbbreviation ?? '',
      liveAddresses: initial.liveAddresses,
      localAddresses: initial.localAddresses,
      liveParcels: initial.liveParcels,
      localParcels: initial.localParcels,
      boundaries: CountyBoundaryRepository(service, store),
      snapshotManager: initial.snapshotManager,
      propertyOwners: initial.propertyOwners,
      resolveParcelSource: resolve,
      selectParcelSource: (candidate) async {
        ++revision;
        final result = await parcelInspector.inspectService(
          candidate.uri,
          county,
          publisher: candidate.portal.publisher,
          origin: 'manual',
        );
        final winner = parcelInspector.rank(result.layers).firstOrNull;
        if (winner == null) {
          throw StateError(
            result.rejections.firstOrNull ?? 'No parcel layer found',
          );
        }
        final saved = await parcelSources.save(county.id, winner);
        return dataSourcesFor(county.withDetectedParcels(saved));
      },
      resetParcelSource: () async {
        ++revision;
        await parcelSources.forget(county.id);
        return initial;
      },
      unclaimedProperties: UnclaimedPropertyCacheStore(database),
      imageryCatalog: county.imageryCatalog?.call(client),
      layerCatalog: catalog,
      overlayFeatures: OverlayFeatureService(client),
      portals: county.portals,
      cities: county.cities,
      portalDiscovery: _discoveryFor(county),
      portalPlaceDiscovery: _placeDiscoveryFor(county),
      situsAddresses: initial.situsAddresses,
      alprCameras: OverpassAlprService(client),
      parcelsAvailable: initial.parcelsAvailable,
    );
  }

  /// Binds the live catalogue search to [county], when its geography is known.
  ///
  /// Null for a county with no Census record, which cannot happen for a source
  /// built from [UsGeography] but is not worth asserting: the workspace
  /// degrades to the registry tiers rather than failing to open.
  PortalDiscovery? _discoveryFor(CountySource county) {
    final place = county.place;
    final state = county.state;
    if (place == null || state == null) {
      return null;
    }
    return () => portalDiscovery.discover(county: place, state: state);
  }

  /// Binds the municipality search to [county], when its geography is known.
  PortalPlaceDiscovery? _placeDiscoveryFor(CountySource county) {
    final place = county.place;
    final state = county.state;
    if (place == null || state == null) {
      return null;
    }
    return (viewport) => portalDiscovery.discoverPlaces(
      viewport: viewport,
      county: place,
      state: state,
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
  /// Configured HTML owner sources are county sites read directly rather than
  /// APIs, and do not send `Access-Control-Allow-Origin`, so a browser blocks the
  /// request before it is sent. The web build reports owners as unavailable
  /// instead of firing a request that is guaranteed to fail. Routing an owner
  /// source through a same-origin proxy is what would lift this. Detected
  /// ArcGIS owner attributes use the public API and are enabled on the web.
  PropertyOwnerRepository _propertyOwners(CountySource county) {
    final ownerSource = kIsWeb && county.detectedParcels == null
        ? null
        : county.ownerSource;
    if (ownerSource == null) {
      return UnavailablePropertyOwnerRepository(county.displayName);
    }
    return CachedPropertyOwnerRepository(
      countyId: _dataKey(county),
      service: ownerSource(client),
      cache: PropertyOwnerCacheStore(database),
    );
  }
}
