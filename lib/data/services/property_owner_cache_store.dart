import 'package:drift/drift.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';

/// A fresh persisted owner lookup, including a cached no-match result.
final class CachedPropertyOwnerResult {
  /// Creates a persisted lookup result.
  const CachedPropertyOwnerResult({required this.ownership});

  /// The matched owner, or null when the source confirmed no exact match.
  final PropertyOwnership? ownership;
}

/// Persists public owner results separately from replaceable GIS snapshots.
final class PropertyOwnerCacheStore {
  /// Creates a cache backed by [database].
  const PropertyOwnerCacheStore(this.database);

  /// The application database.
  final AppDatabase database;

  /// Reads a result only while its refresh window remains valid.
  Future<CachedPropertyOwnerResult?> readFresh(String propertyKey) async {
    final row = await _read(propertyKey);
    if (row == null || !row.expiresAt.isAfter(DateTime.now().toUtc())) {
      return null;
    }
    return _result(row);
  }

  /// Reads a result even when it is due for a source refresh.
  Future<CachedPropertyOwnerResult?> readAny(String propertyKey) async {
    final row = await _read(propertyKey);
    return row == null ? null : _result(row);
  }

  Future<PropertyOwnerCacheRow?> _read(String propertyKey) {
    return (database.select(database.propertyOwnerCache)
          ..where((entry) => entry.propertyKey.equals(propertyKey)))
        .getSingleOrNull();
  }

  CachedPropertyOwnerResult _result(PropertyOwnerCacheRow row) {
    if (row.status != 'found' || row.ownerName == null) {
      return const CachedPropertyOwnerResult(ownership: null);
    }
    return CachedPropertyOwnerResult(
      ownership: PropertyOwnership(
        ownerName: row.ownerName!,
        parcelId: row.parcelId,
        matchedAddress: row.matchedAddress,
        sourceUri: Uri.parse(row.sourceUrl),
        checkedAt: row.checkedAt,
        isSaved: true,
      ),
    );
  }

  /// Saves a successful or no-match result for [freshFor].
  ///
  /// [sourceUri] records which county source was checked and is used as the
  /// provenance of a no-match row, which carries no record URL of its own.
  Future<void> save(
    String propertyKey,
    PropertyOwnership? ownership, {
    required Uri sourceUri,
    Duration freshFor = const Duration(days: 30),
  }) async {
    final checkedAt = ownership?.checkedAt ?? DateTime.now().toUtc();
    await database
        .into(database.propertyOwnerCache)
        .insertOnConflictUpdate(
          PropertyOwnerCacheCompanion.insert(
            propertyKey: propertyKey,
            ownerName: Value(ownership?.ownerName),
            parcelId: ownership?.parcelId ?? '',
            matchedAddress: ownership?.matchedAddress ?? '',
            sourceUrl: (ownership?.sourceUri ?? sourceUri).toString(),
            status: ownership == null ? 'not_found' : 'found',
            checkedAt: checkedAt,
            expiresAt: checkedAt.add(freshFor),
          ),
        );
  }

  /// Removes a saved result so the next lookup must use the public source.
  Future<void> remove(String propertyKey) async {
    await (database.delete(
      database.propertyOwnerCache,
    )..where((entry) => entry.propertyKey.equals(propertyKey))).go();
  }
}
