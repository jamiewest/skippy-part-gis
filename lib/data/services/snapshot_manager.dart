import 'dart:math' as math;

import 'package:riverside_atlas/data/services/arcgis_service.dart';
import 'package:riverside_atlas/data/services/local_gis_store.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/snapshot_status.dart';

/// Indicates that a user cancelled a resumable snapshot import.
final class SnapshotCancelledException implements Exception {
  const SnapshotCancelledException();
}

/// Indicates that a download activated fewer features than the county reported.
final class SnapshotIncompleteException implements Exception {
  /// Creates an exception describing a short [storedCount].
  const SnapshotIncompleteException({
    required this.storedCount,
    required this.expectedCount,
  });

  /// Features actually written to the snapshot.
  final int storedCount;

  /// Features the county reported for the region before the download began.
  final int expectedCount;
}

/// Indicates that the requested area holds more features than a snapshot takes.
final class SnapshotAreaTooLargeException implements Exception {
  /// Creates an exception describing an over-sized [featureCount].
  const SnapshotAreaTooLargeException({
    required this.featureCount,
    required this.limit,
  });

  /// Addresses plus parcels the county reports for the requested area.
  final int featureCount;

  /// The largest feature count a single snapshot accepts.
  final int limit;
}

/// Commands and status for the local GIS snapshot lifecycle.
abstract interface class GisSnapshotController {
  /// Whether a snapshot import is active.
  bool get isImporting;

  /// The current complete snapshot status.
  Future<SnapshotStatus> status();

  /// Counts the features a snapshot of [region] would hold.
  Future<int> estimate(GeoBounds region);

  /// Downloads or resumes a snapshot covering [region].
  Future<void> download({
    required GeoBounds region,
    required void Function(SnapshotStatus status) onProgress,
  });

  /// Requests cooperative cancellation.
  void cancel();
}

/// Downloads and atomically activates county GIS snapshots for a region.
///
/// A region is covered by splitting it into tiles and paging each tile, rather
/// than by listing object IDs and fetching them in batches. Two limits forced
/// that shape and both are real:
///
/// * A feature service caps an ID list. Los Angeles County alone publishes more
///   parcels than one enumeration returns, so an ID-first import cannot express
///   "download this whole county".
/// * Deep pagination is expensive server-side. Reading page 100 of a single
///   large query measured over thirty seconds against the statewide layer, so
///   tiles are subdivided until each holds few enough features that no offset
///   ever gets deep.
///
/// Inserts ignore conflicts, so re-running a paused download re-covers ground
/// cheaply instead of tracking which tiles finished.
final class SnapshotManager implements GisSnapshotController {
  /// Creates a manager using the county [service] and local [store].
  ///
  /// [tileFeatureLimit] and [pageSize] are exposed so a test can drive the
  /// subdivision and paging logic without a fixture the size of a real county.
  SnapshotManager({
    required this.service,
    required this.store,
    this.tileFeatureLimit = defaultTileFeatureLimit,
    this.pageSize = defaultPageSize,
  });

  /// The largest number of features a single snapshot accepts.
  ///
  /// Sized so that a small or medium county fits whole while the largest ones
  /// still have to be taken a region at a time. Parcel geometry dominates the
  /// on-disk cost, so this is a storage guard as much as a network one.
  static const maxFeatureCount = 400000;

  /// The most features a tile may hold, by default, before it is subdivided.
  static const defaultTileFeatureLimit = 8000;

  /// Features requested per page, by default.
  static const defaultPageSize = 1000;

  /// How many times a tile may be quartered before it is paged as it stands.
  static const maxSubdivisions = 8;

  /// County ArcGIS access.
  final ArcGisService service;

  /// Local snapshot persistence.
  final LocalGisStore store;

  /// The most features a tile may hold before it is quartered.
  final int tileFeatureLimit;

  /// Features requested per page.
  final int pageSize;

  bool _cancelRequested = false;
  int? _activeImportId;

  /// Whether a download is currently active.
  @override
  bool get isImporting => _activeImportId != null;

  /// Current local snapshot status.
  @override
  Future<SnapshotStatus> status() => store.status();

  /// Counts the addresses plus parcels a snapshot of [region] would hold.
  @override
  Future<int> estimate(GeoBounds region) => _countFeatures(region);

  /// Downloads or resumes a snapshot and reports bounded progress.
  ///
  /// A completed download activates a snapshot holding [region] alone, so
  /// choosing a new area replaces the previous offline coverage. A paused
  /// download resumes in place, even when the map has moved since.
  @override
  Future<void> download({
    required GeoBounds region,
    required void Function(SnapshotStatus status) onProgress,
  }) async {
    if (isImporting) {
      return;
    }
    _cancelRequested = false;
    final snapshotId = await store.beginOrResumeSnapshot();
    _activeImportId = snapshotId;
    try {
      _report(
        onProgress,
        phase: 'Measuring the area',
        completed: 0,
        total: 0,
        addressCount: 0,
        parcelCount: 0,
      );
      final total = await _countFeatures(region);
      if (total > maxFeatureCount) {
        throw SnapshotAreaTooLargeException(
          featureCount: total,
          limit: maxFeatureCount,
        );
      }

      final tiles = <GeoBounds>[];
      await _collectTiles(region, 0, tiles);

      var addressCount = 0;
      var parcelCount = 0;
      void progress(String phase) {
        _report(
          onProgress,
          phase: phase,
          // A shared layer stores one downloaded row as both an address point
          // and a parcel. [total] counts those rows once, so progress has to
          // count them once too, or it reaches 100% at the halfway mark.
          completed: service.sharesAddressLayer
              ? parcelCount
              : addressCount + parcelCount,
          total: total,
          addressCount: addressCount,
          parcelCount: parcelCount,
        );
      }

      for (var index = 0; index < tiles.length; index++) {
        final tile = tiles[index];
        final phase = 'Downloading area ${index + 1} of ${tiles.length}';
        progress(phase);
        if (service.sharesAddressLayer) {
          await _pageCombined(snapshotId, tile, (addresses, parcels) {
            addressCount += addresses;
            parcelCount += parcels;
            progress(phase);
          });
        } else {
          await _pageAddresses(snapshotId, tile, (count) {
            addressCount += count;
            progress(phase);
          });
          await _pageParcels(snapshotId, tile, (count) {
            parcelCount += count;
            progress(phase);
          });
        }
      }

      final storedAddresses = await store.existingAddressObjectIds(snapshotId);
      final storedParcels = await store.existingParcelIds(snapshotId);
      _verifyCoverage(
        stored: service.sharesAddressLayer
            ? storedParcels.length
            : storedAddresses.length + storedParcels.length,
        expected: total,
      );
      await store.activate(
        snapshotId,
        addressCount: storedAddresses.length,
        parcelCount: storedParcels.length,
      );
    } finally {
      _activeImportId = null;
    }
  }

  /// Refuses to activate a snapshot that covers less than it was told to.
  ///
  /// Paging stops on a short page, which is indistinguishable from a page the
  /// service truncated, so a download can end early without failing. The whole
  /// point of an offline snapshot is that what is missing from it is known, so
  /// a shortfall leaves the rows in place to resume from and reports itself
  /// rather than activating.
  ///
  /// The comparison is not exact. The count is taken before the first page and
  /// the county keeps editing in between, so a handful of rows legitimately
  /// appear or vanish mid-download.
  void _verifyCoverage({required int stored, required int expected}) {
    if (expected == 0) {
      return;
    }
    final tolerance = math.max(5, (expected * 0.005).ceil());
    if (stored + tolerance < expected) {
      throw SnapshotIncompleteException(
        storedCount: stored,
        expectedCount: expected,
      );
    }
  }

  /// Requests cooperative cancellation after the active network batch.
  @override
  void cancel() {
    _cancelRequested = true;
  }

  /// Counts what a snapshot of [region] holds, without double-counting.
  ///
  /// When one layer answers both queries its rows arrive once and are stored
  /// as both an address point and a parcel, so they are counted once too.
  Future<int> _countFeatures(GeoBounds region) async {
    final parcels = await service.countParcels(region);
    if (service.sharesAddressLayer) {
      return parcels;
    }
    return parcels + await service.countAddresses(region);
  }

  /// Splits [region] until every tile is small enough to page shallowly.
  Future<void> _collectTiles(
    GeoBounds region,
    int depth,
    List<GeoBounds> into,
  ) async {
    await _checkCancellation(_activeImportId);
    if (depth >= maxSubdivisions) {
      into.add(region);
      return;
    }
    final count = await _countFeatures(region);
    if (count == 0) {
      return;
    }
    if (count <= tileFeatureLimit) {
      into.add(region);
      return;
    }
    final midLongitude = (region.west + region.east) / 2;
    final midLatitude = (region.south + region.north) / 2;
    final quadrants = [
      GeoBounds(
        west: region.west,
        south: region.south,
        east: midLongitude,
        north: midLatitude,
      ),
      GeoBounds(
        west: midLongitude,
        south: region.south,
        east: region.east,
        north: midLatitude,
      ),
      GeoBounds(
        west: region.west,
        south: midLatitude,
        east: midLongitude,
        north: region.north,
      ),
      GeoBounds(
        west: midLongitude,
        south: midLatitude,
        east: region.east,
        north: region.north,
      ),
    ];
    for (final quadrant in quadrants) {
      await _collectTiles(quadrant, depth + 1, into);
    }
  }

  Future<void> _pageCombined(
    int snapshotId,
    GeoBounds tile,
    void Function(int addresses, int parcels) onBatch,
  ) async {
    for (var offset = 0; ; offset += pageSize) {
      await _checkCancellation(snapshotId);
      final page = await service.fetchCombinedPage(
        tile,
        offset: offset,
        limit: pageSize,
      );
      if (page.parcels.isEmpty) {
        return;
      }
      await store.insertAddresses(snapshotId, page.addresses);
      await store.insertParcels(snapshotId, page.parcels);
      onBatch(page.addresses.length, page.parcels.length);
      if (page.parcels.length < pageSize) {
        return;
      }
    }
  }

  Future<void> _pageAddresses(
    int snapshotId,
    GeoBounds tile,
    void Function(int count) onBatch,
  ) async {
    for (var offset = 0; ; offset += pageSize) {
      await _checkCancellation(snapshotId);
      final values = await service.fetchAddressPage(
        tile,
        offset: offset,
        limit: pageSize,
      );
      if (values.isEmpty) {
        return;
      }
      await store.insertAddresses(snapshotId, values);
      onBatch(values.length);
      if (values.length < pageSize) {
        return;
      }
    }
  }

  Future<void> _pageParcels(
    int snapshotId,
    GeoBounds tile,
    void Function(int count) onBatch,
  ) async {
    for (var offset = 0; ; offset += pageSize) {
      await _checkCancellation(snapshotId);
      final values = await service.fetchParcelPage(
        tile,
        offset: offset,
        limit: pageSize,
      );
      if (values.isEmpty) {
        return;
      }
      await store.insertParcels(snapshotId, values);
      onBatch(values.length);
      if (values.length < pageSize) {
        return;
      }
    }
  }

  Future<void> _checkCancellation(int? snapshotId) async {
    if (!_cancelRequested) {
      return;
    }
    if (snapshotId != null) {
      await store.markCancelled(snapshotId);
    }
    throw const SnapshotCancelledException();
  }

  void _report(
    void Function(SnapshotStatus status) onProgress, {
    required String phase,
    required int completed,
    required int total,
    required int addressCount,
    required int parcelCount,
  }) {
    onProgress(
      SnapshotStatus(
        isAvailable: false,
        isImporting: true,
        addressCount: addressCount,
        parcelCount: parcelCount,
        progress: total == 0 ? 0 : (completed / total).clamp(0, 1),
        phase: phase,
      ),
    );
  }
}
