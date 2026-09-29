import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'package:riverside_atlas/domain/repositories/county_data_sources.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/overlay_feature_service.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_select_overlay.dart';
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
import 'package:riverside_atlas/ui/features/map/view_models/active_overlay.dart';
import 'package:stream_transform/stream_transform.dart';

/// Runs a live catalogue search over the county the workspace is reading.
///
/// Bound to a county when the workspace is built, so the view model can ask
/// "what else publishes here" without carrying the geography needed to answer
/// it. Null when this build cannot search — the workspace then shows only the
/// catalogues compiled into the registry.
typedef PortalDiscovery = Future<List<GisPortal>> Function();

/// Runs a live catalogue search over the municipalities under the viewport.
///
/// Separate from [PortalDiscovery] because it asks a different question and
/// is asked repeatedly as the map moves, rather than once per county.
typedef PortalPlaceDiscovery =
    Future<List<GisPortal>> Function(GeoBounds viewport);

/// Progress of the live search for catalogues published over this county.
enum PortalDiscoveryStatus {
  /// Not started. Discovery is lazy; the map draws first.
  idle,

  /// Searching ArcGIS Online right now.
  searching,

  /// Finished, having added at least one catalogue.
  found,

  /// Finished, having found nothing that passed the geographic test.
  ///
  /// A real answer, not a failure: plenty of rural counties publish nothing,
  /// and saying so is better than an empty panel that looks broken.
  none,

  /// Could not be run or could not be reached.
  unavailable,
}

/// The user-selected source for map and search results.
enum DataMode {
  /// Read current data from the county's live services.
  live,

  /// Read the last complete local snapshot.
  offline,
}

/// The lowest zoom that loads OpenStreetMap license-plate readers.
///
/// Readers are far sparser than addresses or parcels, so this sits well below
/// the property-level gates while still keeping Overpass requests small.
const alprCamerasMinimumZoom = 12.0;

/// How many address rows one drawn rectangle reads.
///
/// The cap belongs to the source rather than to the list: a rectangle over a
/// city centre holds more points than any one request will return, and a
/// selection that hits this is reported as capped rather than presented as the
/// whole rectangle.
const areaSelectionLimit = 2000;

/// Progress of an on-demand public property-owner lookup.
enum OwnerLookupStatus { idle, loading, found, notFound, unavailable }

/// Progress of a California unclaimed-property exact-match check.
enum UnclaimedPropertyLookupStatus {
  idle,
  loadingSaved,
  ready,
  found,
  notFound,
  unavailable,
}

enum ParcelSourceStatus { configured, searching, detected, notFound, failed }

typedef ParcelSourceResolver =
    Stream<CountyDataSources> Function(
      void Function(int checked, int total) progress,
    );

/// State and commands for one county's map workspace.
final class GisMapViewModel extends ChangeNotifier {
  /// Creates a map view model with live and local repository implementations.
  GisMapViewModel({
    required this.countyName,
    required this.countyExtent,
    required AddressRepository liveAddresses,
    required AddressRepository localAddresses,
    required ParcelRepository liveParcels,
    required ParcelRepository localParcels,
    required this.boundaries,
    required GisSnapshotController snapshotManager,
    required PropertyOwnerRepository propertyOwners,
    required this.unclaimedProperties,
    required SitusAddressRepository situsAddresses,
    required this.alprCameras,
    required this.overlayFeatures,
    this.routing,
    this.imageryCatalog,
    this.layerCatalog,
    this.portalDiscovery,
    this.portalPlaceDiscovery,
    bool parcelsAvailable = true,
    this.stateCode = 'CA',
    this.resolveParcelSource,
    this.selectParcelSource,
    this.resetParcelSource,
    List<GisPortal> portals = const [],
    List<CityPortals> cities = const [],
  }) : _sources = CountyDataSources(
         liveAddresses: liveAddresses,
         localAddresses: localAddresses,
         liveParcels: liveParcels,
         localParcels: localParcels,
         snapshotManager: snapshotManager,
         propertyOwners: propertyOwners,
         situsAddresses: situsAddresses,
         parcelsAvailable: parcelsAvailable,
       ),
       _portals = List.unmodifiable(portals),
       _cities = List.unmodifiable(cities) {
    _viewportSubscription = _viewportChanges.stream
        .debounce(const Duration(milliseconds: 250))
        .listen(_loadViewport);
    _searchSubscription = _searchChanges.stream
        .debounce(const Duration(milliseconds: 280))
        .listen(_runSearch);
  }

  /// Display name of the county being read, such as `Riverside County, CA`.
  final String countyName;

  /// Owns route planning independently of county parcel and viewport queries.
  final RouteViewModel? routing;

  /// Whether any public layer publishes parcels and addresses here.
  ///
  /// False for most counties in the country: no state fabric covers them
  /// and they publish no service of their own. The workspace hides the
  /// parcel, address and download controls and says so, rather than leaving
  /// switches that can only ever draw nothing. The boundary, the layer
  /// catalogue and every overlay tier still work.
  bool get parcelsAvailable => _sources.parcelsAvailable;
  CountyDataSources _sources;
  final String stateCode;
  final ParcelSourceResolver? resolveParcelSource;
  final Future<CountyDataSources> Function(CatalogService)? selectParcelSource;
  final Future<CountyDataSources> Function()? resetParcelSource;
  ParcelSourceStatus parcelSourceStatus = ParcelSourceStatus.configured;
  String? get parcelSourceLabel => _sources.parcelSourceLabel;
  int _parcelSourceGeneration = 0;
  bool _parcelSourceStarted = false;
  int _parcelChecked = 0, _parcelTotal = 0;
  bool _choosingParcelSource = false;

  Future<void> discoverParcelSource() async {
    if (_disposed ||
        _mode != DataMode.live ||
        _parcelSourceStarted ||
        resolveParcelSource == null) {
      return;
    }
    _parcelSourceStarted = true;
    final generation = ++_parcelSourceGeneration;
    parcelSourceStatus = ParcelSourceStatus.searching;
    notifyListeners();
    try {
      await for (final sources in resolveParcelSource!((checked, total) {
        if (_disposed || generation != _parcelSourceGeneration) return;
        _parcelChecked = checked;
        _parcelTotal = total;
        notifyListeners();
      })) {
        if (_disposed || generation != _parcelSourceGeneration) return;
        await adoptDataSources(sources);
      }
      if (_disposed || generation != _parcelSourceGeneration) return;
      parcelSourceStatus = parcelSourceLabel != null
          ? ParcelSourceStatus.detected
          : parcelsAvailable
          ? ParcelSourceStatus.configured
          : ParcelSourceStatus.notFound;
    } on Object {
      if (_disposed || generation != _parcelSourceGeneration) return;
      parcelSourceStatus = parcelsAvailable
          ? ParcelSourceStatus.detected
          : ParcelSourceStatus.failed;
    }
    notifyListeners();
  }

  Future<void> adoptDataSources(CountyDataSources sources) async {
    if (_disposed) return;
    // A background refresh must not cancel a download or replace its scope.
    if (snapshotManager.isImporting) return;
    _sources = sources;
    _viewportGeneration++;
    _searchGeneration++;
    _areaSelectionGeneration++;
    _addresses = const [];
    _parcels = const [];
    _searchResults = const [];
    _areaSelection = null;
    _isLoadingMap = false;
    _isSearching = false;
    clearSelection();
    parcelSourceStatus = sources.parcelSourceLabel == null
        ? ParcelSourceStatus.configured
        : ParcelSourceStatus.detected;
    final current = _sources;
    final status = await snapshotManager.status();
    if (_disposed || !identical(current, _sources)) return;
    _snapshotStatus = status;
    if (_mode == DataMode.offline && !status.isAvailable) _mode = DataMode.live;
    notifyListeners();
    _refreshLastViewport();
  }

  Future<String> useAsParcelSource(CatalogService service) async {
    if (selectParcelSource == null || _mode != DataMode.live) {
      return 'Parcel selection is available in live mode';
    }
    if (_choosingParcelSource || snapshotManager.isImporting) {
      return 'Finish the current source change or snapshot download first';
    }
    _choosingParcelSource = true;
    final generation = ++_parcelSourceGeneration;
    try {
      final sources = await selectParcelSource!(service);
      if (_disposed || generation != _parcelSourceGeneration) {
        return 'Source selection cancelled';
      }
      await adoptDataSources(sources);
      return 'Using ${sources.parcelSourceLabel}';
    } on Object catch (error) {
      if (!_disposed && generation == _parcelSourceGeneration) {
        parcelSourceStatus = parcelsAvailable
            ? (parcelSourceLabel == null
                  ? ParcelSourceStatus.configured
                  : ParcelSourceStatus.detected)
            : ParcelSourceStatus.failed;
        notifyListeners();
      }
      return error is StateError ? error.message : '$error';
    } finally {
      _choosingParcelSource = false;
    }
  }

  Future<void> forgetParcelSource() async {
    if (resetParcelSource == null ||
        _choosingParcelSource ||
        snapshotManager.isImporting) {
      return;
    }
    ++_parcelSourceGeneration;
    _parcelSourceStarted = true; // Forget lasts for this workspace session.
    await adoptDataSources(await resetParcelSource!());
  }

  /// The rectangle enclosing the county being read.
  final GeoBounds countyExtent;

  /// Live county address access.
  AddressRepository get liveAddresses => _sources.liveAddresses;

  /// Local snapshot address access.
  AddressRepository get localAddresses => _sources.localAddresses;

  /// Live county parcel access.
  ParcelRepository get liveParcels => _sources.liveParcels;

  /// Local snapshot parcel access.
  ParcelRepository get localParcels => _sources.localParcels;

  /// County boundary access.
  final BoundaryRepository boundaries;

  /// Snapshot lifecycle commands.
  GisSnapshotController get snapshotManager => _sources.snapshotManager;

  /// On-demand public property owner access.
  PropertyOwnerRepository get propertyOwners => _sources.propertyOwners;

  /// Saved results from California's official unclaimed-property search.
  final UnclaimedPropertyRepository unclaimedProperties;

  /// County historical imagery catalog access, when the county publishes one.
  ///
  /// Only two counties in this build have an aerial history wired up. The rest
  /// hide the imagery control rather than offer an empty year list.
  final ImageryCatalogRepository? imageryCatalog;

  /// Statewide street-address resolution for parcels with no situs on record.
  SitusAddressRepository get situsAddresses => _sources.situsAddresses;

  /// Crowdsourced OpenStreetMap license-plate reader access.
  final AlprCameraRepository alprCameras;

  /// Geometry access for county overlay layers.
  final OverlayFeatureRepository overlayFeatures;

  /// County map-catalogue access, when this build can list catalogues.
  final LayerCatalogRepository? layerCatalog;

  /// Live search for catalogues this build has no registry entry for.
  ///
  /// This is what makes the layer panel work outside the one state whose
  /// offline inventory has been run. Null disables it; the registry tiers
  /// still list.
  final PortalDiscovery? portalDiscovery;

  /// Live search for the catalogues the municipalities on screen publish.
  ///
  /// Null disables it. This is what makes a city's own layers appear as the
  /// map reaches the city, rather than only when the city happens to rank
  /// highly in a county-wide search.
  final PortalPlaceDiscovery? portalPlaceDiscovery;

  final List<GisPortal> _portals;

  /// Catalogues found live, keyed by [GisPortal.aliasKey].
  ///
  /// A map rather than a list because two searches write here — the county's
  /// and the viewport's — and they find overlapping sets. Keyed on the alias
  /// so one server found under two names is one entry, and insertion-ordered
  /// so the county's answer keeps the ranking it was given.
  final Map<String, GisPortal> _discovered = {};
  GeoBounds? _lastPlaceSearch;
  bool _searchingPlaces = false;
  PortalDiscoveryStatus _discoveryStatus = PortalDiscoveryStatus.idle;
  final List<CityPortals> _cities;
  Set<String> _visibleCityNames = const {};
  final Map<String, List<CatalogService>> _catalogue = {};
  final Map<String, String> _portalMessages = {};
  final Set<String> _loadingPortals = {};
  final List<ActiveOverlay> _activeOverlays = [];

  final StreamController<_ViewportRequest> _viewportChanges =
      StreamController<_ViewportRequest>();
  final StreamController<String> _searchChanges = StreamController<String>();
  late final StreamSubscription<_ViewportRequest> _viewportSubscription;
  late final StreamSubscription<String> _searchSubscription;

  DataMode _mode = DataMode.live;
  bool _addressesVisible = false;
  bool _parcelsVisible = false;
  bool _boundaryVisible = true;
  bool _alprCamerasVisible = false;
  bool _areaSelectMode = false;
  AreaTool _areaTool = AreaTool.rectangle;
  bool _isInitializing = true;
  bool _isLoadingMap = false;
  bool _isSearching = false;
  bool _isLoadingImagery = true;
  String? _errorMessage;
  String? _mapMessage;
  RegionBoundary? _boundary;
  List<Address> _addresses = const [];
  List<Parcel> _parcels = const [];
  List<Address> _searchResults = const [];
  List<AlprCamera> _alprCameraList = const [];
  String? _alprMessage;
  List<ImageryLayer> _imageryLayers = const [];
  ImageryLayer? _selectedImagery;
  String? _imageryMessage;
  Address? _selectedAddress;
  Parcel? _selectedParcel;
  SitusAddress? _resolvedSitus;
  PropertyOwnership? _propertyOwnership;
  OwnerLookupStatus _ownerLookupStatus = OwnerLookupStatus.idle;
  UnclaimedPropertyQuery? _unclaimedPropertyQuery;
  UnclaimedPropertySearchResult? _unclaimedPropertyResult;
  UnclaimedPropertyLookupStatus _unclaimedPropertyLookupStatus =
      UnclaimedPropertyLookupStatus.idle;
  SnapshotStatus _snapshotStatus = SnapshotStatus.empty;
  _ViewportRequest? _lastViewport;
  AreaSelection? _areaSelection;

  int _viewportGeneration = 0;
  int _searchGeneration = 0;
  int _ownerLookupGeneration = 0;
  int _areaSelectionGeneration = 0;
  int _unclaimedPropertyGeneration = 0;
  bool _disposed = false;

  /// The active live or offline mode.
  DataMode get mode => _mode;

  /// Whether address points are visible.
  bool get addressesVisible => _addressesVisible;

  /// Whether parcel boundaries are visible.
  bool get parcelsVisible => _parcelsVisible;

  /// Whether the county boundary is visible.
  bool get boundaryVisible => _boundaryVisible;

  /// Whether OpenStreetMap license-plate readers are visible.
  bool get alprCamerasVisible => _alprCamerasVisible;

  /// Whether a drag on the map draws a rectangle instead of panning.
  bool get areaSelectMode => _areaSelectMode;

  /// The rectangle last drawn on the map, and the addresses inside it.
  AreaSelection? get areaSelection => _areaSelection;

  /// Whether the license-plate reader layer can be turned on right now.
  ///
  /// The layer reads OpenStreetMap live and is not part of the offline
  /// snapshot, so offline mode has nothing to show.
  bool get alprCamerasAvailable => _mode == DataMode.live;

  /// Whether startup data is loading.
  bool get isInitializing => _isInitializing;

  /// Whether visible map features are loading.
  bool get isLoadingMap => _isLoadingMap;

  /// Whether an address search is active.
  bool get isSearching => _isSearching;

  /// Whether the historical imagery catalog is loading.
  bool get isLoadingImagery => _isLoadingImagery;

  /// A recoverable error for the current task.
  String? get errorMessage => _errorMessage;

  /// A short map guidance message.
  String? get mapMessage => _mapMessage;

  /// The active county boundary.
  RegionBoundary? get boundary => _boundary;

  /// Address points in the current viewport.
  List<Address> get addresses => _addresses;

  /// Parcels in the current viewport.
  List<Parcel> get parcels => _parcels;

  /// Current address search suggestions.
  List<Address> get searchResults => _searchResults;

  /// License-plate readers in the current viewport.
  List<AlprCamera> get alprCameraList => _alprCameraList;

  /// A recoverable OpenStreetMap message.
  String? get alprMessage => _alprMessage;

  /// County aerial captures, newest year first.
  List<ImageryLayer> get imageryLayers => _imageryLayers;

  /// The imagery currently rendered below feature overlays.
  ///
  /// Null means the street map background, which is the startup default.
  ImageryLayer? get selectedImagery => _selectedImagery;

  /// A recoverable catalog message.
  String? get imageryMessage => _imageryMessage;

  /// Whether this county has an aerial-imagery history in this build.
  bool get imageryAvailable => imageryCatalog != null;

  /// Why parcels and addresses are unavailable, or null when they are not.
  String? get coverageMessage =>
      parcelSourceStatus == ParcelSourceStatus.searching && !parcelsAvailable
      ? (_parcelTotal == 0
            ? 'Looking for a parcel layer…'
            : 'Looking for a parcel layer… ($_parcelChecked of $_parcelTotal checked)')
      : parcelSourceStatus == ParcelSourceStatus.failed && !parcelsAvailable
      ? 'Parcel discovery is unavailable. Browse published layers to select a source.'
      : parcelsAvailable
      ? null
      : 'No public layer this build knows of publishes parcels or '
            'addresses for $countyName. Its boundary and map layers still '
            'work.';

  /// The street address resolved for a parcel that publishes none.
  ///
  /// Null whenever the selected parcel already carries a situs address, no
  /// address is on record for it, or the lookup has not answered yet.
  SitusAddress? get resolvedSitus => _resolvedSitus;

  /// The selected address.
  Address? get selectedAddress => _selectedAddress;

  /// The selected parcel.
  Parcel? get selectedParcel => _selectedParcel;

  /// The current public property ownership match.
  PropertyOwnership? get propertyOwnership => _propertyOwnership;

  /// Progress of the selected address's owner lookup.
  OwnerLookupStatus get ownerLookupStatus => _ownerLookupStatus;

  /// Search terms derived from the selected property's public owner.
  UnclaimedPropertyQuery? get unclaimedPropertyQuery => _unclaimedPropertyQuery;

  /// The current saved or newly completed California search result.
  UnclaimedPropertySearchResult? get unclaimedPropertyResult =>
      _unclaimedPropertyResult;

  /// Progress of the selected owner's California search.
  UnclaimedPropertyLookupStatus get unclaimedPropertyLookupStatus =>
      _unclaimedPropertyLookupStatus;

  /// Local snapshot availability and progress.
  SnapshotStatus get snapshotStatus => _snapshotStatus;

  /// Loads boundary and snapshot metadata.
  Future<void> initialize() async {
    final initialSources = _sources;
    // initialize is called from the screen's initState; notify after mounting.
    unawaited(Future<void>.microtask(discoverParcelSource));
    try {
      final results = await Future.wait<Object>([
        boundaries.getCountyBoundary(),
        snapshotManager.status(),
      ]);
      _boundary = results[0] as RegionBoundary;
      if (identical(initialSources, _sources)) {
        _snapshotStatus = results[1] as SnapshotStatus;
      }
      if (imageryCatalog case final catalog?) {
        try {
          _imageryLayers = await catalog.list(coverage: _boundary!.bounds);
          _imageryMessage = _imageryLayers.isEmpty
              ? 'No imagery covers $countyName right now.'
              : null;
        } on Object {
          _imageryMessage = 'Historical imagery catalog is unavailable.';
        }
      }
    } on Object {
      _errorMessage =
          '$countyName GIS is unavailable. Check your connection and retry.';
    } finally {
      _isLoadingImagery = false;
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Selects a dated aerial layer, or the street map when [itemId] is null.
  void selectImagery(String? itemId) {
    _selectedImagery = null;
    if (itemId != null) {
      for (final layer in _imageryLayers) {
        if (layer.id == itemId) {
          _selectedImagery = layer;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Schedules visible feature queries for [bounds] at [zoom].
  void updateViewport(GeoBounds bounds, double zoom) {
    final request = _ViewportRequest(bounds: bounds, zoom: zoom);
    _lastViewport = request;
    _viewportChanges.add(request);
  }

  /// The most catalogues a county's panel holds from live search.
  ///
  /// Both searches write to one set, so the bound belongs here rather than
  /// on either of them. Past this the chip row is a list nobody reads.
  static const _maximumDiscovered = 24;

  /// Below this zoom no city catalogue is offered: a county-wide view
  /// intersects every city in the county, and the chip row would drown the
  /// county's own tier under dozens of cities.
  static const _cityCatalogZoom = 10.0;

  /// Recomputes which cities the viewport is over.
  ///
  /// Returns whether the set changed. Deliberately does not notify: this runs
  /// from the debounced viewport listener, which notifies once for the whole
  /// update. Notifying from [updateViewport] instead would fire during the
  /// map's own build — `onPositionChanged` is called from it — which the
  /// framework rejects as a build-during-build.
  bool _refreshVisibleCities(_ViewportRequest request) {
    final visible = <String>{
      if (request.zoom >= _cityCatalogZoom)
        for (final city in _cities)
          if (city.bounds.intersects(request.bounds)) city.name,
    };
    if (setEquals(visible, _visibleCityNames)) {
      return false;
    }
    _visibleCityNames = visible;
    return true;
  }

  /// Schedules address suggestions for [query].
  void search(String query) {
    if (query.trim().length < 2) {
      _searchResults = const [];
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _searchChanges.add(query);
  }

  /// Clears search results without changing the selected feature.
  void clearSearch() {
    _searchResults = const [];
    _isSearching = false;
    notifyListeners();
  }

  /// Selects [address] and clears a parcel selection.
  void selectAddress(Address address) {
    _selectedAddress = address;
    _selectedParcel = null;
    _searchResults = const [];
    _propertyOwnership = null;
    _resolvedSitus = null;
    _ownerLookupStatus = OwnerLookupStatus.loading;
    _resetUnclaimedPropertyLookup();
    notifyListeners();
    final generation = ++_ownerLookupGeneration;
    unawaited(_lookupOwner(propertyOwners.lookupAddress(address), generation));
  }

  /// Discards the saved value and checks the selected property again.
  void retryOwnerLookup() {
    final address = _selectedAddress;
    final parcel = _selectedParcel;
    if (address == null && parcel == null) {
      return;
    }
    _propertyOwnership = null;
    _ownerLookupStatus = OwnerLookupStatus.loading;
    _resetUnclaimedPropertyLookup();
    notifyListeners();
    final generation = ++_ownerLookupGeneration;
    final lookup = address != null
        ? propertyOwners.refreshAddress(address)
        : propertyOwners.refreshParcel(parcel!);
    unawaited(_lookupOwner(lookup, generation));
  }

  /// Selects a parcel at [point] when the parcel layer is enabled.
  Future<void> selectParcelAt(LatLng point) async {
    if (!_parcelsVisible) {
      return;
    }
    final generation = ++_ownerLookupGeneration;
    final repository = switch (_mode) {
      DataMode.live => liveParcels,
      DataMode.offline => localParcels,
    };
    final parcel = await repository.hitTest(point);
    if (parcel != null && generation == _ownerLookupGeneration) {
      _selectedParcel = parcel;
      _selectedAddress = null;
      _propertyOwnership = null;
      _resolvedSitus = null;
      _ownerLookupStatus = OwnerLookupStatus.loading;
      _resetUnclaimedPropertyLookup();
      notifyListeners();
      unawaited(_lookupOwner(propertyOwners.lookupParcel(parcel), generation));
      unawaited(_resolveSitus(parcel, point, generation));
    }
  }

  /// Fills in the street address of a parcel whose county publishes none.
  ///
  /// The lookup uses the point the user clicked rather than the parcel's
  /// centre, because a centre computed from a bounding box can land outside an
  /// L-shaped parcel, and rather than the parcel number, because assessor
  /// number formatting differs between a county's own layer and the statewide
  /// one. A failure here is silent: it costs a supplementary line, not the
  /// selection.
  Future<void> _resolveSitus(
    Parcel parcel,
    LatLng point,
    int generation,
  ) async {
    if (parcel.situsAddress.isNotEmpty || _mode == DataMode.offline) {
      return;
    }
    try {
      final situs = await situsAddresses.lookupAt(point);
      if (generation != _ownerLookupGeneration) {
        return;
      }
      _resolvedSitus = situs;
      notifyListeners();
    } on Object {
      // Leave the parcel showing what its own county published.
    }
  }

  /// The rectangle the map is currently showing, once it has reported one.
  ///
  /// Null until the first viewport arrives. The assistant needs this to
  /// answer "circle the middle of what I am looking at" without inventing a
  /// centre, which is why it is exposed rather than kept private.
  GeoBounds? get visibleExtent => _lastViewport?.bounds;

  /// The shape the area tool draws.
  AreaTool get areaTool => _areaTool;

  /// Chooses the shape the area tool draws.
  ///
  /// A rectangle is what a drag naturally makes; a circle is what a question
  /// about surroundings means. Kept on the model rather than in the overlay
  /// so the choice survives the tool being disarmed and re-armed, and so the
  /// assistant can draw either without going through the pointer.
  void setAreaTool(AreaTool value) {
    if (_areaTool == value) {
      return;
    }
    _areaTool = value;
    notifyListeners();
  }

  /// Arms or disarms the area tool.
  ///
  /// While it is armed a drag on the map draws a shape instead of panning
  /// the map, so the tool disarms itself as soon as one has been drawn: a
  /// mode that stays on is a map that has stopped panning for no visible
  /// reason.
  void setAreaSelectMode(bool value) {
    if (_areaSelectMode == value) {
      return;
    }
    _areaSelectMode = value;
    notifyListeners();
  }

  /// Reads every published address point inside [shape].
  ///
  /// The area is read from the address source directly rather than from what
  /// the map has drawn, so the answer does not depend on the address layer
  /// being switched on or on the area being fully in view.
  Future<void> selectArea(AreaShape shape) async {
    _areaSelectMode = false;
    final generation = ++_areaSelectionGeneration;
    final pending = AreaSelection(
      shape: shape,
      status: AreaSelectionStatus.loading,
    );
    _areaSelection = pending;
    notifyListeners();
    final repository = switch (_mode) {
      DataMode.live => liveAddresses,
      DataMode.offline => localAddresses,
    };
    try {
      final found = await repository.queryViewport(
        shape.bounds,
        limit: areaSelectionLimit,
      );
      if (generation != _areaSelectionGeneration) {
        return;
      }
      // A source queries by envelope, and an offline snapshot stores whole
      // tiles, so both can answer with points outside the shape. For a circle
      // the envelope is the enclosing square, so this is what makes the
      // answer a circle's rather than the square's.
      final inside = [
        for (final address in found)
          if (shape.contains(address.position)) address,
      ]..sort(_byStreetOrder);
      _areaSelection = pending.copyWith(
        status: AreaSelectionStatus.ready,
        addresses: inside,
        truncated: found.length >= areaSelectionLimit,
      );
    } on Object {
      if (generation != _areaSelectionGeneration) {
        return;
      }
      _areaSelection = pending.copyWith(
        status: AreaSelectionStatus.failed,
        message: _mode == DataMode.live
            ? 'The addresses here could not be read. Retry, or download a '
                  'snapshot and work offline.'
            : 'The local snapshot could not be read.',
      );
    } finally {
      if (generation == _areaSelectionGeneration) {
        notifyListeners();
      }
    }
  }

  /// Reads the last drawn area again.
  void retryAreaSelection() {
    if (_areaSelection case final selection?) {
      unawaited(selectArea(selection.shape));
    }
  }

  /// Discards the drawn rectangle and its address list.
  void clearAreaSelection() {
    _areaSelectionGeneration++;
    _areaSelection = null;
    notifyListeners();
  }

  /// The overlay feature the user last tapped, if any.
  OverlayIdentification? get identifiedOverlay => _identifiedOverlay;
  OverlayIdentification? _identifiedOverlay;

  /// Identifies the topmost active overlay feature under [point].
  ///
  /// Returns whether one was found, so the caller can fall back to selecting
  /// a parcel. Overlays win the tap because they are what the user just
  /// switched on, and they are searched newest first — the last overlay
  /// enabled is the one drawn on top.
  ///
  /// [tolerance] is a degree radius around the tap, sized by the caller from
  /// the current zoom: a point feature is a single coordinate and could
  /// otherwise never be hit.
  bool identifyOverlayAt(LatLng point, {required double tolerance}) {
    for (final overlay in _activeOverlays.reversed) {
      if (overlay.isImagery) {
        continue;
      }
      for (final feature in overlay.features) {
        if (!feature.hitTest(point, tolerance: tolerance)) {
          continue;
        }
        _identifiedOverlay = OverlayIdentification(
          title: overlay.service.title,
          color: overlay.color,
          feature: feature,
        );
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Dismisses the identified overlay feature.
  void clearIdentifiedOverlay() {
    if (_identifiedOverlay == null) {
      return;
    }
    _identifiedOverlay = null;
    notifyListeners();
  }

  /// Clears the current address or parcel detail.
  void clearSelection() {
    _selectedAddress = null;
    _selectedParcel = null;
    _propertyOwnership = null;
    _resolvedSitus = null;
    _ownerLookupStatus = OwnerLookupStatus.idle;
    _resetUnclaimedPropertyLookup();
    _ownerLookupGeneration++;
    notifyListeners();
  }

  /// Changes the current data source.
  Future<void> setMode(DataMode mode) async {
    if (mode == DataMode.offline && !_snapshotStatus.isAvailable) {
      _errorMessage = 'Download a snapshot before using offline mode.';
      notifyListeners();
      return;
    }
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    _errorMessage = null;
    _addresses = const [];
    _parcels = const [];
    // The drawn list came from the other source and is no longer what this
    // one would answer, so it is dropped rather than left to look current.
    _areaSelectionGeneration++;
    _areaSelection = null;
    if (!alprCamerasAvailable) {
      _alprCamerasVisible = false;
      _alprCameraList = const [];
      _alprMessage = null;
    }
    notifyListeners();
    // Coming back online is the first chance to answer a question offline
    // mode declined to ask. Not awaited: the mode switch is what the user
    // pressed, and the catalogue list can fill in behind it.
    unawaited(discoverPortals());
    unawaited(discoverParcelSource());
    if (_lastViewport case final viewport?) {
      await _loadViewport(viewport);
    }
  }

  /// Shows or hides address points.
  void setAddressesVisible(bool value) {
    _addressesVisible = value;
    if (!value) {
      _addresses = const [];
    }
    _refreshLastViewport();
  }

  /// Shows or hides parcel boundaries.
  void setParcelsVisible(bool value) {
    _parcelsVisible = value;
    if (!value) {
      _parcels = const [];
      _selectedParcel = null;
    }
    _refreshLastViewport();
  }

  /// Shows or hides OpenStreetMap license-plate readers.
  void setAlprCamerasVisible(bool value) {
    _alprCamerasVisible = value;
    if (!value) {
      _alprCameraList = const [];
      _alprMessage = null;
    }
    _refreshLastViewport();
  }

  /// Shows or hides the county boundary.
  void setBoundaryVisible(bool value) {
    _boundaryVisible = value;
    notifyListeners();
  }

  /// Downloads or resumes an offline snapshot of the whole county.
  ///
  /// Large counties hold more features than one snapshot accepts and are
  /// refused with a count, which is the honest answer: the alternative is a
  /// silently partial copy that reads as complete offline.
  Future<void> downloadCountySnapshot() => _download(countyExtent);

  /// Downloads or resumes an offline snapshot of the current map area.
  Future<void> downloadSnapshot() async {
    final viewport = _lastViewport;
    if (viewport == null) {
      _errorMessage = 'Move the map to the area you want available offline.';
      notifyListeners();
      return;
    }
    await _download(viewport.bounds);
  }

  Future<void> _download(GeoBounds region) async {
    // A county with no parcel or address layer has nothing to snapshot, and
    // the download path would otherwise reach a service with no endpoint to
    // page. The control is hidden as well; this is the guard behind it.
    final coverage = coverageMessage;
    if (coverage != null) {
      _errorMessage = coverage;
      notifyListeners();
      return;
    }
    if (snapshotManager.isImporting) {
      return;
    }
    _errorMessage = null;
    try {
      await snapshotManager.download(
        region: region,
        onProgress: (status) {
          _snapshotStatus = status;
          notifyListeners();
        },
      );
      _snapshotStatus = await snapshotManager.status();
    } on SnapshotCancelledException {
      _snapshotStatus = (await snapshotManager.status()).copyWith(
        phase: 'Download paused. Update to resume.',
      );
    } on SnapshotIncompleteException catch (error) {
      _snapshotStatus = (await snapshotManager.status()).copyWith(
        phase: 'Update incomplete. Try again to resume.',
      );
      _errorMessage =
          'The download covered ${_formatCount(error.storedCount)} of '
          '${_formatCount(error.expectedCount)} features, so the offline copy '
          'was not activated. Try again to finish it.';
    } on SnapshotAreaTooLargeException catch (error) {
      _snapshotStatus = await snapshotManager.status();
      _errorMessage =
          'This area holds ${_formatCount(error.featureCount)} features. '
          'Zoom in to snapshot ${_formatCount(error.limit)} or fewer.';
    } on Object {
      _snapshotStatus = (await snapshotManager.status()).copyWith(
        phase: 'Update paused. Try again to resume.',
      );
      _errorMessage = 'The snapshot update stopped before activation.';
    }
    notifyListeners();
  }

  /// Pauses the snapshot after the current network batch.
  void cancelSnapshot() {
    snapshotManager.cancel();
    _snapshotStatus = _snapshotStatus.copyWith(phase: 'Pausing download…');
    notifyListeners();
  }

  /// Clears the current error message.
  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadViewport(_ViewportRequest request) async {
    final generation = ++_viewportGeneration;
    _isLoadingMap = true;
    _mapMessage = null;
    _refreshVisibleCities(request);
    notifyListeners();
    // Not awaited: what publishes here is a question about the panel, and
    // the map must never wait on it.
    unawaited(_discoverPlaces(request));

    try {
      final addressRepository = switch (_mode) {
        DataMode.live => liveAddresses,
        DataMode.offline => localAddresses,
      };
      final parcelRepository = switch (_mode) {
        DataMode.live => liveParcels,
        DataMode.offline => localParcels,
      };
      final futures = <Future<Object>>[
        if (_addressesVisible && request.zoom >= 15)
          addressRepository.queryViewport(request.bounds)
        else
          Future.value(<Address>[]),
        if (_parcelsVisible && request.zoom >= 14)
          parcelRepository.queryViewport(request.bounds)
        else
          Future.value(<Parcel>[]),
        _alprCamerasFor(request, generation),
      ];
      final results = await Future.wait(futures);
      if (generation != _viewportGeneration) {
        return;
      }
      _addresses = results[0] as List<Address>;
      _parcels = results[1] as List<Parcel>;
      _alprCameraList = results[2] as List<AlprCamera>;
      unawaited(_reloadOverlays(request));
      if ((_addressesVisible && request.zoom < 15) ||
          (_parcelsVisible && request.zoom < 14)) {
        _mapMessage = 'Zoom in to explore property-level data';
      } else if (_addresses.length >= 2000 || _parcels.length >= 2000) {
        _mapMessage = 'More than 2,000 features here. Zoom in for detail.';
      }
      _errorMessage = null;
    } on Object {
      if (generation == _viewportGeneration) {
        _errorMessage = _mode == DataMode.live
            ? 'Map data could not be loaded. Retry or use an offline snapshot.'
            : 'The local snapshot could not be read.';
      }
    } finally {
      if (generation == _viewportGeneration) {
        _isLoadingMap = false;
        notifyListeners();
      }
    }
  }

  /// Resolves the license-plate readers to draw for [request].
  ///
  /// OpenStreetMap is a third-party service, so its failures are reported
  /// through [alprMessage] and never take the county layers down with them.
  Future<List<AlprCamera>> _alprCamerasFor(
    _ViewportRequest request,
    int generation,
  ) async {
    if (!_alprCamerasVisible || !alprCamerasAvailable) {
      _setAlprMessage(null, generation);
      return const [];
    }
    if (request.zoom < alprCamerasMinimumZoom) {
      _setAlprMessage('Zoom in to load license-plate readers.', generation);
      return const [];
    }
    try {
      final cameras = await alprCameras.queryViewport(request.bounds);
      _setAlprMessage(null, generation);
      return cameras;
    } on Object {
      _setAlprMessage(
        'OpenStreetMap camera data is unavailable right now.',
        generation,
      );
      return const [];
    }
  }

  void _setAlprMessage(String? message, int generation) {
    if (generation == _viewportGeneration) {
      _alprMessage = message;
    }
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    try {
      final repository = switch (_mode) {
        DataMode.live => liveAddresses,
        DataMode.offline => localAddresses,
      };
      final results = await repository.search(query);
      if (generation == _searchGeneration) {
        _searchResults = results;
        _errorMessage = null;
      }
    } on Object {
      if (generation == _searchGeneration) {
        _searchResults = const [];
        _errorMessage = 'Address search is unavailable right now.';
      }
    } finally {
      if (generation == _searchGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> _lookupOwner(
    Future<PropertyOwnership?> lookup,
    int generation,
  ) async {
    try {
      final result = await lookup;
      if (generation != _ownerLookupGeneration) {
        return;
      }
      _propertyOwnership = result;
      _ownerLookupStatus = result == null
          ? OwnerLookupStatus.notFound
          : OwnerLookupStatus.found;
      if (result == null) {
        _resetUnclaimedPropertyLookup();
      } else {
        _prepareUnclaimedPropertyLookup(result, generation);
      }
    } on Object {
      if (generation != _ownerLookupGeneration) {
        return;
      }
      _propertyOwnership = null;
      _ownerLookupStatus = OwnerLookupStatus.unavailable;
      _resetUnclaimedPropertyLookup();
    }
    notifyListeners();
  }

  void _prepareUnclaimedPropertyLookup(
    PropertyOwnership ownership,
    int ownerGeneration,
  ) {
    final city = _selectedAddress?.city ?? _selectedParcel?.city ?? '';
    final zipCode = _selectedAddress?.zipCode ?? _selectedParcel?.zipCode ?? '';
    final query = UnclaimedPropertyQuery.fromOwner(
      ownerName: ownership.ownerName,
      city: city,
      zipCode: zipCode,
    );
    _unclaimedPropertyQuery = query;
    _unclaimedPropertyResult = null;
    _unclaimedPropertyLookupStatus = UnclaimedPropertyLookupStatus.loadingSaved;
    final generation = ++_unclaimedPropertyGeneration;
    unawaited(
      _loadSavedUnclaimedPropertyResult(query, ownerGeneration, generation),
    );
  }

  Future<void> _loadSavedUnclaimedPropertyResult(
    UnclaimedPropertyQuery query,
    int ownerGeneration,
    int generation,
  ) async {
    try {
      final saved = await unclaimedProperties.findSaved(query);
      if (generation != _unclaimedPropertyGeneration ||
          ownerGeneration != _ownerLookupGeneration) {
        return;
      }
      _unclaimedPropertyResult = saved;
      _unclaimedPropertyLookupStatus = switch (saved?.found) {
        true => UnclaimedPropertyLookupStatus.found,
        false => UnclaimedPropertyLookupStatus.notFound,
        null => UnclaimedPropertyLookupStatus.ready,
      };
    } on Object {
      if (generation != _unclaimedPropertyGeneration ||
          ownerGeneration != _ownerLookupGeneration) {
        return;
      }
      _unclaimedPropertyResult = null;
      _unclaimedPropertyLookupStatus =
          UnclaimedPropertyLookupStatus.unavailable;
    }
    notifyListeners();
  }

  void _resetUnclaimedPropertyLookup() {
    _unclaimedPropertyQuery = null;
    _unclaimedPropertyResult = null;
    _unclaimedPropertyLookupStatus = UnclaimedPropertyLookupStatus.idle;
    _unclaimedPropertyGeneration++;
  }

  void _refreshLastViewport() {
    notifyListeners();
    if (_lastViewport case final viewport?) {
      _viewportChanges.add(viewport);
    }
  }

  // --- County map catalogue ------------------------------------------------

  /// Every catalogue offered where the map is right now.
  ///
  /// Narrowest coverage first, and by coverage rather than by where the
  /// entry came from: local catalogues — registered, then the cities the
  /// viewport is over, then whatever the live search found — before state
  /// agencies, before federal ones. A state agency found live is still
  /// narrower than the National Weather Service, and somebody looking for a
  /// city's zoning map should not scroll past either to reach it.
  ///
  /// City and discovered portals come and go as the map moves. A registered
  /// city is gated on its own boundary; a discovered publisher on the extents
  /// its items advertise. Both answer the same question — is this publisher
  /// worth offering here — and both are why panning into a city makes its
  /// catalogue appear.
  List<GisPortal> get portals {
    final viewport = _lastViewport?.bounds;
    final seen = <String>{};
    final local = <GisPortal>[];
    final state = <GisPortal>[];
    final national = <GisPortal>[];
    void offer(GisPortal portal) {
      if (viewport != null && !portal.coversViewport(viewport)) {
        return;
      }
      if (!seen.add(portal.root.toLowerCase())) {
        return;
      }
      switch (portal.tier) {
        case PortalTier.statewide:
          state.add(portal);
        case PortalTier.national:
          national.add(portal);
        case PortalTier.countyPortal:
        case PortalTier.city:
        case PortalTier.partner:
          local.add(portal);
      }
    }

    for (final portal in _portals) {
      offer(portal);
    }
    for (final city in _cities) {
      if (_visibleCityNames.contains(city.name)) {
        city.portals.forEach(offer);
      }
    }
    _discovered.values.forEach(offer);
    return List.unmodifiable([...local, ...state, ...national]);
  }

  /// Progress of the live search for catalogues published over this county.
  PortalDiscoveryStatus get discoveryStatus => _discoveryStatus;

  /// Catalogues the live search added, in the order it ranked them.
  List<GisPortal> get discoveredPortals =>
      List.unmodifiable(_discovered.values);

  /// Whether this build can search for catalogues it has no registry entry for.
  bool get discoveryAvailable => portalDiscovery != null;

  /// Searches for catalogues published over this county, once per session.
  ///
  /// Deliberately not called from [initialize]: it is dozens of requests to
  /// ArcGIS Online, several of them guesses that are meant to fail, and none
  /// of them are needed before the map draws. The layer panel is what wants
  /// the answer, so opening it is what asks for it.
  ///
  /// Never throws and never leaves the workspace worse than it found it. A
  /// county whose search fails still has its registry tiers.
  Future<void> discoverPortals() async {
    final discovery = portalDiscovery;
    // Offline mode has no overlays to draw, so searching for more of them is
    // network traffic for a panel that is disabled. The status stays idle, so
    // switching back to live still searches.
    if (discovery == null ||
        !overlaysAvailable ||
        _discoveryStatus != PortalDiscoveryStatus.idle) {
      return;
    }
    _discoveryStatus = PortalDiscoveryStatus.searching;
    notifyListeners();
    try {
      final found = await discovery();
      _discoveryStatus = _remember(found) == 0
          ? PortalDiscoveryStatus.none
          : PortalDiscoveryStatus.found;
    } on Object {
      _discoveryStatus = PortalDiscoveryStatus.unavailable;
    } finally {
      notifyListeners();
    }
  }

  /// Searches for catalogues the municipalities under [viewport] publish.
  ///
  /// Runs off the debounced viewport, so it must be cheap when nothing has
  /// changed. Three guards make it so: it is skipped below the zoom at which
  /// a municipality is what the user is looking at, skipped while the last
  /// search is still running, and skipped when the map has only zoomed
  /// further into ground already searched. Everything past those is the
  /// service's own per-municipality cache and session budget.
  ///
  /// Silent: this does not move [discoveryStatus], which reports whether the
  /// *county* has been searched. The panel's counts come from [portals] and
  /// update on their own when something is found.
  Future<void> _discoverPlaces(_ViewportRequest request) async {
    final discovery = portalPlaceDiscovery;
    if (discovery == null ||
        !overlaysAvailable ||
        _searchingPlaces ||
        request.zoom < _cityCatalogZoom ||
        (_lastPlaceSearch?.encloses(request.bounds) ?? false)) {
      return;
    }
    _searchingPlaces = true;
    try {
      final found = await discovery(request.bounds);
      _lastPlaceSearch = request.bounds;
      if (_remember(found) > 0) {
        notifyListeners();
      }
    } on Object {
      // A municipality search that fails changes nothing the user can see.
      // The county tiers and everything already found stay exactly as they
      // were, which is the whole point of keeping this off the map's path.
    } finally {
      _searchingPlaces = false;
    }
  }

  /// Adds whatever in [found] is new, and answers how many that was.
  ///
  /// Matched on [GisPortal.aliasKey] rather than on the root, because a
  /// search finds a server under whichever name it was published under.
  /// Riverside is registered as `gis.countyofriverside.us` and answers as
  /// `gis1.` too; listing both would put every Riverside layer in the panel
  /// twice. Where the registry already has an entry, the registry wins — it
  /// was read and verified, and this was matched minutes ago.
  int _remember(List<GisPortal> found) {
    final known = {
      for (final portal in _portals) portal.aliasKey,
      for (final city in _cities)
        for (final portal in city.portals) portal.aliasKey,
    };
    var added = 0;
    for (final portal in found) {
      if (_discovered.length >= _maximumDiscovered) {
        break;
      }
      if (known.contains(portal.aliasKey) ||
          _discovered.containsKey(portal.aliasKey)) {
        continue;
      }
      _discovered[portal.aliasKey] = portal;
      added++;
    }
    return added;
  }

  /// Services listed from [portal], empty until [openPortal] has read it.
  List<CatalogService> servicesIn(GisPortal portal) =>
      _catalogue[portal.root] ?? const [];

  /// Whether [portal] is being read right now.
  bool isLoadingPortal(GisPortal portal) =>
      _loadingPortals.contains(portal.root);

  /// Why [portal] could not be listed, when it could not.
  String? portalMessage(GisPortal portal) => _portalMessages[portal.root];

  /// Overlays currently switched on, drawn in list order.
  List<ActiveOverlay> get activeOverlays => List.unmodifiable(_activeOverlays);

  /// Whether county overlays can be read right now.
  ///
  /// Overlays are read from the county's live services and are deliberately
  /// not part of an offline snapshot — the redistribution terms differ per
  /// publisher. Offline mode therefore has nothing to draw, exactly as the
  /// license-plate reader layer does.
  bool get overlaysAvailable => _mode == DataMode.live;

  /// Whether [service] is switched on.
  bool isOverlayActive(CatalogService service) =>
      _activeOverlays.any((overlay) => overlay.id == service.id);

  /// Reads [portal]'s service list, once per session.
  ///
  /// Catalogues are read when the user opens one rather than on a county
  /// switch: Riverside publishes 54 folders across seven roots, and walking
  /// them all up front would be a hundred requests before the map draws.
  Future<void> openPortal(GisPortal portal) async {
    final catalog = layerCatalog;
    if (catalog == null ||
        _catalogue.containsKey(portal.root) ||
        _loadingPortals.contains(portal.root)) {
      return;
    }
    _loadingPortals.add(portal.root);
    _portalMessages.remove(portal.root);
    notifyListeners();
    try {
      _catalogue[portal.root] = await catalog.listServices(portal);
      if (_catalogue[portal.root]!.isEmpty) {
        _portalMessages[portal.root] =
            'This catalogue publishes no map layers.';
      }
    } on Object {
      _portalMessages[portal.root] =
          'The ${portal.host} catalogue could not be read.';
    } finally {
      _loadingPortals.remove(portal.root);
      notifyListeners();
    }
  }

  /// Switches [service] on or off.
  ///
  /// Switching one on in offline mode does nothing; [overlaysAvailable] is
  /// what the picker disables itself on.
  void toggleOverlay(CatalogService service) {
    if (!overlaysAvailable && !isOverlayActive(service)) {
      return;
    }
    final existing = _activeOverlays.indexWhere(
      (overlay) => overlay.id == service.id,
    );
    if (existing >= 0) {
      final removed = _activeOverlays.removeAt(existing);
      if (_identifiedOverlay?.title == removed.service.title) {
        _identifiedOverlay = null;
      }
      notifyListeners();
      return;
    }
    final overlay = ActiveOverlay(
      service: service,
      color: _overlayPalette[_activeOverlays.length % _overlayPalette.length],
    );
    _activeOverlays.add(overlay);
    notifyListeners();
    unawaited(_prepareOverlay(overlay));
  }

  /// Sets how strongly [overlay] draws.
  void setOverlayOpacity(ActiveOverlay overlay, double value) {
    overlay.opacity = value.clamp(0.05, 1);
    notifyListeners();
  }

  /// Moves an overlay in the draw order.
  void reorderOverlay(int from, int to) {
    if (from < 0 || from >= _activeOverlays.length) {
      return;
    }
    final overlay = _activeOverlays.removeAt(from);
    _activeOverlays.insert(to.clamp(0, _activeOverlays.length), overlay);
    notifyListeners();
  }

  /// Turns every overlay off.
  void clearOverlays() {
    if (_activeOverlays.isEmpty) {
      return;
    }
    _activeOverlays.clear();
    _identifiedOverlay = null;
    notifyListeners();
  }

  /// Resolves which endpoints an overlay draws from, then loads it.
  ///
  /// A server-rendered overlay needs nothing resolved. A queried one needs its
  /// sub-layer ids, which only the service's own metadata carries — this is
  /// the one request per service the catalogue listing deliberately skips.
  Future<void> _prepareOverlay(ActiveOverlay overlay) async {
    final catalog = layerCatalog;
    if (overlay.isImagery || catalog == null) {
      overlay.status = OverlayStatus.ready;
      notifyListeners();
      return;
    }
    try {
      final metadata = await catalog.describe(overlay.service);
      final layers = metadata['layers'];
      final ids = <int>[
        if (layers is List<Object?>)
          for (final layer in layers)
            if (layer is Map<String, Object?>)
              if (layer['id'] case final num id)
                if (layer['subLayerIds'] == null) id.toInt(),
      ];
      overlay.featureQueries = [
        for (final id in ids.take(_maxQueriedSubLayers))
          Uri.parse('${overlay.service.uri}/$id/query'),
      ];
      overlay.droppedSubLayers = ids.length - overlay.featureQueries.length;
      if (overlay.featureQueries.isEmpty) {
        overlay.status = OverlayStatus.failed;
        overlay.message = 'This service publishes no queryable layers.';
        notifyListeners();
        return;
      }
    } on Object {
      overlay.status = OverlayStatus.failed;
      overlay.message = 'The layer description could not be read.';
      notifyListeners();
      return;
    }
    if (!_activeOverlays.contains(overlay)) {
      return;
    }
    await _loadOverlay(overlay, _lastViewport);
  }

  /// Reads features for [overlay] over the current viewport.
  ///
  /// Guarded by [_viewportGeneration] for the same reason the address and
  /// parcel loads are: panning leaves several queries per overlay in flight,
  /// and without this the last to *return* wins, which is not necessarily the
  /// one for the viewport now on screen.
  Future<void> _loadOverlay(
    ActiveOverlay overlay,
    _ViewportRequest? request,
  ) async {
    if (overlay.isImagery || request == null) {
      return;
    }
    final generation = _viewportGeneration;
    overlay.status = OverlayStatus.loading;
    notifyListeners();
    try {
      final batches = await Future.wait([
        for (final query in overlay.featureQueries)
          overlayFeatures.queryViewport(query, request.bounds),
      ]);
      if (!_activeOverlays.contains(overlay) ||
          generation != _viewportGeneration) {
        return;
      }
      overlay.features = [for (final batch in batches) ...batch];
      overlay.status = overlay.features.isEmpty
          ? OverlayStatus.empty
          : OverlayStatus.ready;
      overlay.message = switch (overlay.features.length) {
        0 => 'Nothing in view. This layer may not draw at this zoom.',
        final count when count >= OverlayFeatureService.featureLimit =>
          'Showing the first $count features here. Zoom in for the rest.',
        _ => null,
      };
    } on Object catch (error) {
      if (!_activeOverlays.contains(overlay) ||
          generation != _viewportGeneration) {
        return;
      }
      overlay.status = OverlayStatus.failed;
      overlay.message = error is ArcGisException
          ? error.message
          : 'This layer could not be read.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> _reloadOverlays(_ViewportRequest request) async {
    if (!overlaysAvailable) {
      return;
    }
    await Future.wait([
      for (final overlay in List.of(_activeOverlays))
        if (!overlay.isImagery && overlay.featureQueries.isNotEmpty)
          _loadOverlay(overlay, request),
    ]);
  }

  /// Drops notifications once disposed.
  ///
  /// Switching counties disposes this model while viewport, search, and
  /// imagery requests may still be in flight; their continuations would
  /// otherwise notify a disposed listener list.
  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    routing?.dispose();
    _parcelSourceGeneration++;
    _viewportGeneration++;
    _searchGeneration++;
    _ownerLookupGeneration++;
    _unclaimedPropertyGeneration++;
    _areaSelectionGeneration++;
    _viewportSubscription.cancel();
    _searchSubscription.cancel();
    _viewportChanges.close();
    _searchChanges.close();
    super.dispose();
  }
}

@immutable
final class _ViewportRequest {
  const _ViewportRequest({required this.bounds, required this.zoom});

  final GeoBounds bounds;
  final double zoom;
}

/// How many sub-layers of one service an overlay will query.
///
/// A county map service can carry sixty layers; drawing all of them from one
/// switch would fire sixty viewport queries and bury the map.
const _maxQueriedSubLayers = 6;

/// Colours assigned to queried overlays in turn.
///
/// An arbitrary county layer has no meaningful colour — the app does not know
/// what `AIRPORT_INFLUENCE_AREAS` is — so overlays are told apart rather than
/// described. Server-rendered overlays ignore this and arrive with the
/// publisher's own cartography.
const _overlayPalette = <Color>[
  Color(0xFF00897B),
  Color(0xFF8E24AA),
  Color(0xFFEF6C00),
  Color(0xFF3949AB),
  Color(0xFFC2185B),
  Color(0xFF558B2F),
];

String _formatCount(int value) {
  final digits = '$value';
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
}

/// Orders addresses the way a street list reads: by city, street, then number.
///
/// The published `fullAddress` sorts `1000 MAIN ST` above `200 MAIN ST`, which
/// is wrong in a list somebody is meant to work down.
int _byStreetOrder(Address first, Address second) {
  final city = first.city.compareTo(second.city);
  if (city != 0) {
    return city;
  }
  final street = first.streetName.compareTo(second.streetName);
  if (street != 0) {
    return street;
  }
  final number = (first.houseNumber ?? 0).compareTo(second.houseNumber ?? 0);
  if (number != 0) {
    return number;
  }
  return first.fullAddress.compareTo(second.fullAddress);
}
