import 'package:checks/checks.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/data/database/app_database.dart';

/// Schema 6 rewrites every county-scoped row onto a state-prefixed identifier.
///
/// This runs the migration rather than reading it. It is a one-shot rewrite of
/// three tables including a primary key, on databases holding downloads a user
/// waited on; if it is wrong there is no second attempt, and the failure is
/// silent — the rows stay, scoped to identifiers nothing looks up again.
void main() {
  /// A schema-5 database holding one row of each county-scoped kind.
  Future<AppDatabase> legacyDatabase() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    // `forTesting` opens at the current schema, which is what the app would
    // have created; the rows below are written in the shape schema 5 left.
    await database
        .into(database.snapshots)
        .insert(
          SnapshotsCompanion.insert(
            status: 'complete',
            startedAt: DateTime.utc(2026),
            county: const Value('riverside'),
          ),
        );
    await database
        .into(database.snapshots)
        .insert(
          SnapshotsCompanion.insert(
            status: 'complete',
            startedAt: DateTime.utc(2026),
            county: const Value('calaveras'),
          ),
        );
    await database
        .into(database.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'active_snapshot_id:riverside',
            value: '1',
          ),
        );
    await database
        .into(database.settings)
        .insert(
          SettingsCompanion.insert(
            key: 'county_boundary:san_bernardino',
            value: '{}',
          ),
        );
    await database
        .into(database.propertyOwnerCache)
        .insert(
          PropertyOwnerCacheCompanion.insert(
            propertyKey: 'us:ca:riverside:apn:213191035',
            parcelId: '213191035',
            matchedAddress: '3641 6TH ST',
            sourceUrl: 'https://example.test',
            status: 'found',
            checkedAt: DateTime.utc(2026),
            expiresAt: DateTime.utc(2027),
            ownerName: const Value('EXAMPLE OWNER'),
          ),
        );
    return database;
  }

  Future<void> migrate(AppDatabase database) async {
    await database.customStatement('PRAGMA user_version = 5');
    await database.migration.onUpgrade(
      database.createMigrator(),
      5,
      database.schemaVersion,
    );
  }

  test('prefixes every snapshot county with its state', () async {
    final database = await legacyDatabase();
    addTearDown(database.close);

    await migrate(database);

    final counties = await database
        .customSelect('SELECT county FROM snapshots ORDER BY county')
        .map((row) => row.read<String>('county'))
        .get();
    // `calaveras` begins with the same two letters as the prefix and must
    // still be prefixed; only a literal `ca_` is already done.
    check(counties).deepEquals(['ca_calaveras', 'ca_riverside']);
  });

  test('keeps a downloaded snapshot and a saved boundary findable', () async {
    final database = await legacyDatabase();
    addTearDown(database.close);

    await migrate(database);

    final keys = await database
        .customSelect('SELECT key FROM settings ORDER BY key')
        .map((row) => row.read<String>('key'))
        .get();
    check(keys).deepEquals([
      'active_snapshot_id:ca_riverside',
      'county_boundary:ca_san_bernardino',
    ]);
  });

  test('moves cached owner names onto the new key format', () async {
    final database = await legacyDatabase();
    addTearDown(database.close);

    await migrate(database);

    final rows = await database
        .customSelect(
          'SELECT property_key, owner_name FROM property_owner_cache',
        )
        .get();
    check(rows).length.equals(1);
    check(
      rows.single.read<String>('property_key'),
    ).equals('us:ca_riverside:apn:213191035');
    check(rows.single.read<String>('owner_name')).equals('EXAMPLE OWNER');
  });

  test('leaves an already-migrated database alone', () async {
    // The upgrade only runs once, but a rerun must not double the prefix.
    final database = await legacyDatabase();
    addTearDown(database.close);

    await migrate(database);
    await migrate(database);

    final counties = await database
        .customSelect('SELECT county FROM snapshots ORDER BY county')
        .map((row) => row.read<String>('county'))
        .get();
    check(counties).deepEquals(['ca_calaveras', 'ca_riverside']);
  });
}
