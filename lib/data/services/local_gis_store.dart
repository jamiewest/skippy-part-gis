import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/domain/models/snapshot_status.dart';

/// Persistence and indexed read operations for local GIS snapshots.
final class LocalGisStore {
  /// Creates a local store backed by [database].
  ///
  /// Every snapshot and setting is scoped to [countyId] so downloads from
  /// one county are never served as another county's data.
  const LocalGisStore(this.database, {this.countyId = riversideCountyId});

  /// The underlying Drift database.
  final AppDatabase database;

  /// Identifier of the county this store reads and writes.
  final String countyId;

  /// Settings key holding this county's saved boundary polygon.
  String get _boundaryKey => 'county_boundary:$countyId';

  /// Settings key holding this county's active snapshot identifier.
  String get _activeSnapshotKey => 'active_snapshot_id:$countyId';

  /// Persists [boundary] for offline map startup.
  ///
  /// The key deliberately differs from the retired city-scoped key so an
  /// upgraded install cannot fall back to the old City of Riverside polygon.
  Future<void> saveBoundary(RegionBoundary boundary) async {
    final value = jsonEncode({
      'name': boundary.name,
      'fips': boundary.fips,
      'rings': boundary.rings
          .map(
            (ring) => ring
                .map((point) => [point.longitude, point.latitude])
                .toList(growable: false),
          )
          .toList(growable: false),
    });
    await database
        .into(database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: _boundaryKey, value: value),
        );
  }

  /// The last boundary saved during a successful online request.
  Future<RegionBoundary?> loadBoundary() async {
    final setting = await (database.select(
      database.settings,
    )..where((row) => row.key.equals(_boundaryKey))).getSingleOrNull();
    if (setting == null) {
      return null;
    }
    final value = jsonDecode(setting.value);
    if (value is! Map<String, Object?>) {
      return null;
    }
    final rawRings = value['rings'];
    if (rawRings is! List<Object?>) {
      return null;
    }
    final rings = rawRings
        .whereType<List<Object?>>()
        .map(
          (ring) => ring
              .whereType<List<Object?>>()
              .map(
                (pair) => LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                ),
              )
              .toList(growable: false),
        )
        .toList(growable: false);
    return RegionBoundary(
      name: value['name']?.toString() ?? '',
      fips: value['fips']?.toString() ?? '',
      rings: rings,
    );
  }

  /// The active snapshot status, or an empty status before first download.
  Future<SnapshotStatus> status() async {
    final activeId = await _activeSnapshotId();
    if (activeId == null) {
      return SnapshotStatus.empty;
    }
    final snapshot = await (database.select(
      database.snapshots,
    )..where((row) => row.id.equals(activeId))).getSingleOrNull();
    if (snapshot == null) {
      return SnapshotStatus.empty;
    }
    return SnapshotStatus(
      isAvailable: true,
      isImporting: false,
      addressCount: snapshot.addressCount,
      parcelCount: snapshot.parcelCount,
      progress: 1,
      updatedAt: snapshot.completedAt,
    );
  }

  /// Creates or resumes the latest incomplete snapshot for this county.
  Future<int> beginOrResumeSnapshot() async {
    final incomplete =
        await (database.select(database.snapshots)
              ..where((row) => row.status.isNotIn(const ['complete']))
              ..where((row) => row.county.equals(countyId))
              ..orderBy([(row) => OrderingTerm.desc(row.id)])
              ..limit(1))
            .getSingleOrNull();
    if (incomplete != null) {
      await (database.update(database.snapshots)
            ..where((row) => row.id.equals(incomplete.id)))
          .write(const SnapshotsCompanion(status: Value('importing')));
      return incomplete.id;
    }
    return database
        .into(database.snapshots)
        .insert(
          SnapshotsCompanion.insert(
            status: 'importing',
            startedAt: DateTime.now().toUtc(),
            county: Value(countyId),
          ),
        );
  }

  /// Source IDs already stored for [snapshotId].
  Future<Set<int>> existingAddressObjectIds(int snapshotId) async {
    final rows =
        await (database.selectOnly(database.addresses)
              ..addColumns([database.addresses.sourceObjectId])
              ..where(database.addresses.snapshotId.equals(snapshotId)))
            .get();
    return rows
        .map((row) => row.read(database.addresses.sourceObjectId))
        .whereType<int>()
        .toSet();
  }

  /// Source IDs already stored for [snapshotId].
  Future<Set<int>> existingParcelIds(int snapshotId) async {
    final rows =
        await (database.selectOnly(database.parcels)
              ..addColumns([database.parcels.sourceId])
              ..where(database.parcels.snapshotId.equals(snapshotId)))
            .get();
    return rows
        .map((row) => row.read(database.parcels.sourceId))
        .whereType<int>()
        .toSet();
  }

  /// Inserts an address batch into [snapshotId].
  Future<void> insertAddresses(int snapshotId, List<Address> values) async {
    await database.batch((batch) {
      batch.insertAll(
        database.addresses,
        values
            .map(
              (address) => AddressesCompanion.insert(
                snapshotId: snapshotId,
                sourceId: address.sourceId,
                sourceObjectId: Value(address.objectId),
                fullAddress: address.fullAddress,
                houseNumber: Value(address.houseNumber),
                streetName: address.streetName,
                streetType: address.streetType,
                unit: address.unit,
                city: address.city,
                zipCode: address.zipCode,
                apn: address.apn,
                addressType: address.addressType,
                numberOfUnits: address.numberOfUnits,
                latitude: address.position.latitude,
                longitude: address.position.longitude,
                sourceUpdatedAt: Value(address.sourceUpdatedAt),
              ),
            )
            .toList(growable: false),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Inserts a parcel batch into [snapshotId].
  Future<void> insertParcels(int snapshotId, List<Parcel> values) async {
    await database.batch((batch) {
      batch.insertAll(
        database.parcels,
        values
            .map(
              (parcel) => ParcelsCompanion.insert(
                snapshotId: snapshotId,
                sourceId: parcel.sourceId,
                apn: parcel.apn,
                situsAddress: parcel.situsAddress,
                city: parcel.city,
                zipCode: parcel.zipCode,
                landUse: parcel.landUse,
                acreage: Value(parcel.acreage),
                geometryJson: jsonEncode(
                  parcel.rings
                      .map(
                        (ring) => ring
                            .map((point) => [point.longitude, point.latitude])
                            .toList(growable: false),
                      )
                      .toList(growable: false),
                ),
                minLongitude: parcel.bounds.west,
                maxLongitude: parcel.bounds.east,
                minLatitude: parcel.bounds.south,
                maxLatitude: parcel.bounds.north,
              ),
            )
            .toList(growable: false),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Marks [snapshotId] cancelled while retaining its resumable rows.
  Future<void> markCancelled(int snapshotId) async {
    await (database.update(database.snapshots)
          ..where((row) => row.id.equals(snapshotId)))
        .write(const SnapshotsCompanion(status: Value('cancelled')));
  }

  /// Atomically makes [snapshotId] active and retains one prior snapshot.
  Future<void> activate(
    int snapshotId, {
    required int addressCount,
    required int parcelCount,
  }) async {
    await database.transaction(() async {
      await (database.update(
        database.snapshots,
      )..where((row) => row.id.equals(snapshotId))).write(
        SnapshotsCompanion(
          status: const Value('complete'),
          completedAt: Value(DateTime.now().toUtc()),
          addressCount: Value(addressCount),
          parcelCount: Value(parcelCount),
        ),
      );
      await database
          .into(database.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: _activeSnapshotKey,
              value: '$snapshotId',
            ),
          );
      await _deleteOldSnapshots(keeping: {snapshotId});
    });
  }

  /// Searches the active snapshot using FTS5 prefix matching.
  Future<List<Address>> searchAddresses(String query, {int limit = 20}) async {
    final activeId = await _activeSnapshotId();
    final ftsQuery = _ftsPrefix(query);
    if (activeId == null || ftsQuery.isEmpty) {
      return const [];
    }
    final rows = await database
        .customSelect(
          '''
      SELECT addresses.*
      FROM address_fts
      JOIN addresses ON addresses.id = address_fts.rowid
      WHERE address_fts MATCH ? AND addresses.snapshot_id = ?
      ORDER BY bm25(address_fts)
      LIMIT ?
      ''',
          variables: [
            Variable.withString(ftsQuery),
            Variable.withInt(activeId),
            Variable.withInt(limit),
          ],
          readsFrom: {database.addresses},
        )
        .get();
    return rows
        .map((row) => _address(database.addresses.map(row.data)))
        .toList(growable: false);
  }

  /// Address rows spatially intersecting [bounds].
  Future<List<Address>> addressesInBounds(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    final activeId = await _activeSnapshotId();
    if (activeId == null) {
      return const [];
    }
    final rows = await database
        .customSelect(
          '''
      SELECT addresses.*
      FROM address_rtree
      JOIN addresses ON addresses.id = address_rtree.id
      WHERE address_rtree.min_lon <= ?
        AND address_rtree.max_lon >= ?
        AND address_rtree.min_lat <= ?
        AND address_rtree.max_lat >= ?
        AND addresses.snapshot_id = ?
      LIMIT ?
      ''',
          variables: [
            Variable.withReal(bounds.east),
            Variable.withReal(bounds.west),
            Variable.withReal(bounds.north),
            Variable.withReal(bounds.south),
            Variable.withInt(activeId),
            Variable.withInt(limit),
          ],
          readsFrom: {database.addresses},
        )
        .get();
    return rows
        .map((row) => _address(database.addresses.map(row.data)))
        .toList(growable: false);
  }

  /// Parcel rows spatially intersecting [bounds].
  Future<List<Parcel>> parcelsInBounds(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    final activeId = await _activeSnapshotId();
    if (activeId == null) {
      return const [];
    }
    final rows = await database
        .customSelect(
          '''
      SELECT parcels.*
      FROM parcel_rtree
      JOIN parcels ON parcels.id = parcel_rtree.id
      WHERE parcel_rtree.min_lon <= ?
        AND parcel_rtree.max_lon >= ?
        AND parcel_rtree.min_lat <= ?
        AND parcel_rtree.max_lat >= ?
        AND parcels.snapshot_id = ?
      LIMIT ?
      ''',
          variables: [
            Variable.withReal(bounds.east),
            Variable.withReal(bounds.west),
            Variable.withReal(bounds.north),
            Variable.withReal(bounds.south),
            Variable.withInt(activeId),
            Variable.withInt(limit),
          ],
          readsFrom: {database.parcels},
        )
        .get();
    return rows
        .map((row) => _parcel(database.parcels.map(row.data)))
        .toList(growable: false);
  }

  Future<int?> _activeSnapshotId() async {
    final setting = await (database.select(
      database.settings,
    )..where((row) => row.key.equals(_activeSnapshotKey))).getSingleOrNull();
    return setting == null ? null : int.tryParse(setting.value);
  }

  Future<void> _deleteOldSnapshots({required Set<int> keeping}) async {
    final complete =
        await (database.select(database.snapshots)
              ..where((row) => row.status.equals('complete'))
              ..where((row) => row.county.equals(countyId))
              ..orderBy([(row) => OrderingTerm.desc(row.id)]))
            .get();
    final keepIds = {...keeping, ...complete.take(2).map((row) => row.id)};
    for (final snapshot in complete.where((row) => !keepIds.contains(row.id))) {
      await (database.delete(
        database.addresses,
      )..where((row) => row.snapshotId.equals(snapshot.id))).go();
      await (database.delete(
        database.parcels,
      )..where((row) => row.snapshotId.equals(snapshot.id))).go();
      await (database.delete(
        database.snapshots,
      )..where((row) => row.id.equals(snapshot.id))).go();
    }
  }

  Address _address(AddressRow row) {
    return Address(
      objectId: row.sourceObjectId,
      sourceId: row.sourceId,
      fullAddress: row.fullAddress,
      houseNumber: row.houseNumber,
      streetName: row.streetName,
      streetType: row.streetType,
      unit: row.unit,
      city: row.city,
      zipCode: row.zipCode,
      apn: row.apn,
      addressType: row.addressType,
      numberOfUnits: row.numberOfUnits,
      position: LatLng(row.latitude, row.longitude),
      sourceUpdatedAt: row.sourceUpdatedAt,
    );
  }

  Parcel _parcel(ParcelRow row) {
    final geometry = jsonDecode(row.geometryJson);
    final rings = (geometry as List<Object?>)
        .whereType<List<Object?>>()
        .map(
          (ring) => ring
              .whereType<List<Object?>>()
              .map(
                (pair) => LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                ),
              )
              .toList(growable: false),
        )
        .toList(growable: false);
    return Parcel(
      sourceId: row.sourceId,
      apn: row.apn,
      situsAddress: row.situsAddress,
      city: row.city,
      zipCode: row.zipCode,
      landUse: row.landUse,
      acreage: row.acreage,
      rings: rings,
    );
  }

  String _ftsPrefix(String query) {
    final tokens = query
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    return tokens.map((token) => '"$token"*').join(' ');
  }
}
