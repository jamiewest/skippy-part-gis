import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/situs_address.dart';
import 'package:riverside_atlas/domain/models/snapshot_status.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:stream_transform/stream_transform.dart';

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

/// State and commands for one county's map workspace.
final class GisMapViewModel extends ChangeNotifier {
  /// Creates a map view model with live and local repository implementations.
  GisMapViewModel({
    required this.countyName,
    required this.countyExtent,
    required this.liveAddresses,
    required this.localAddresses,
    required this.liveParcels,
    required this.localParcels,
    required this.boundaries,
    required this.snapshotManager,
    required this.propertyOwners,
    required this.unclaimedProperties,
    required this.situsAddresses,
    required this.alprCameras,
    this.imageryCatalog,
  }) {
    _viewportSubscription = _viewportChanges.stream
        .debounce(const Duration(milliseconds: 250))
        .listen(_loadViewport);
    _searchSubscription = _searchChanges.stream
        .debounce(const Duration(milliseconds: 280))
        .listen(_runSearch);
  }

  /// Display name of the county being read, such as `Riverside County`.
  final String countyName;

  /// The rectangle enclosing the county being read.
  final GeoBounds countyExtent;

  /// Live county address access.
  final AddressRepository liveAddresses;

  /// Local snapshot address access.
  final AddressRepository localAddresses;

  /// Live county parcel access.
  final ParcelRepository liveParcels;

  /// Local snapshot parcel access.
  final ParcelRepository localParcels;

  /// County boundary access.
  final BoundaryRepository boundaries;

  /// Snapshot lifecycle commands.
  final GisSnapshotController snapshotManager;

  /// On-demand public property owner access.
  final PropertyOwnerRepository propertyOwners;

  /// Saved results from California's official unclaimed-property search.
  final UnclaimedPropertyRepository unclaimedProperties;

  /// County historical imagery catalog access, when the county publishes one.
  ///
  /// Only two counties in this build have an aerial history wired up. The rest
  /// hide the imagery control rather than offer an empty year list.
  final ImageryCatalogRepository? imageryCatalog;

  /// Statewide street-address resolution for parcels with no situs on record.
  final SitusAddressRepository situsAddresses;

  /// Crowdsourced OpenStreetMap license-plate reader access.
  final AlprCameraRepository alprCameras;

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
  int _viewportGeneration = 0;
  int _searchGeneration = 0;
  int _ownerLookupGeneration = 0;
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
    try {
      final results = await Future.wait<Object>([
        boundaries.getCountyBoundary(),
        snapshotManager.status(),
      ]);
      _boundary = results[0] as RegionBoundary;
      _snapshotStatus = results[1] as SnapshotStatus;
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
    if (!alprCamerasAvailable) {
      _alprCamerasVisible = false;
      _alprCameraList = const [];
      _alprMessage = null;
    }
    notifyListeners();
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
    notifyListeners();

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
    _ownerLookupGeneration++;
    _unclaimedPropertyGeneration++;
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

String _formatCount(int value) {
  final digits = '$value';
  return digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
}
