import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Stores completed ClaimIt checks separately from replaceable GIS snapshots.
final class UnclaimedPropertyCacheStore implements UnclaimedPropertyRepository {
  /// Creates a cache backed by [database].
  const UnclaimedPropertyCacheStore(this.database);

  /// The application database.
  final AppDatabase database;

  @override
  Future<UnclaimedPropertySearchResult?> findSaved(
    UnclaimedPropertyQuery query,
  ) async {
    final row =
        await (database.select(database.unclaimedPropertyCache)
              ..where((entry) => entry.searchKey.equals(query.cacheKey)))
            .getSingleOrNull();
    if (row == null || !row.expiresAt.isAfter(DateTime.now().toUtc())) {
      return null;
    }
    return UnclaimedPropertySearchResult(
      query: UnclaimedPropertyQuery(
        ownerName: row.ownerName,
        firstName: row.firstName,
        lastName: row.lastName,
        city: row.city,
        zipCode: row.zipCode,
      ),
      found: row.found,
      resultCount: row.resultCount,
      checkedAt: row.checkedAt,
      sourceUri: Uri.parse(row.sourceUrl),
      isSaved: true,
    );
  }

  @override
  Future<void> save(UnclaimedPropertySearchResult result) async {
    await database
        .into(database.unclaimedPropertyCache)
        .insertOnConflictUpdate(
          UnclaimedPropertyCacheCompanion.insert(
            searchKey: result.query.cacheKey,
            ownerName: result.query.ownerName,
            firstName: result.query.firstName,
            lastName: result.query.lastName,
            city: result.query.city,
            zipCode: result.query.zipCode,
            found: result.found,
            resultCount: result.resultCount,
            sourceUrl: result.sourceUri.toString(),
            checkedAt: result.checkedAt,
            expiresAt: result.checkedAt.add(const Duration(days: 7)),
          ),
        );
  }

  @override
  Future<void> remove(UnclaimedPropertyQuery query) async {
    await (database.delete(
      database.unclaimedPropertyCache,
    )..where((entry) => entry.searchKey.equals(query.cacheKey))).go();
  }
}
