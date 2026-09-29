import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Web-only options for opening the database.
///
/// On the web there is no bundled SQLite. Drift loads `sqlite3.wasm` and
/// `drift_worker.js` at runtime from the site root, which is why both are
/// checked into `web/` rather than declared as Flutter assets.
///
/// Which storage backend drift ends up with depends on the headers the page
/// is served with. With `Cross-Origin-Opener-Policy: same-origin` and
/// `Cross-Origin-Embedder-Policy: credentialless` it reaches OPFS; without
/// them it falls back to IndexedDB. Both survive a reload and both support
/// the FTS5 and RTree tables this schema creates, so the fallback costs
/// speed rather than features. The choice is logged because it is otherwise
/// invisible, and because an `inMemory` result means snapshots will not
/// outlive the tab.
final DriftWebOptions _webOptions = DriftWebOptions(
  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
  driftWorker: Uri.parse('drift_worker.js'),
  onResult: (result) {
    developer.log(
      'sqlite storage: ${result.chosenImplementation.name}; '
      'missing browser features: ${result.missingFeatures}',
      name: 'riverside_atlas.database',
    );
  },
);

/// Import metadata for each local GIS snapshot.
@DataClassName('SnapshotRow')
class Snapshots extends Table {
  /// Local snapshot identifier.
  IntColumn get id => integer().autoIncrement()();

  /// Import lifecycle status.
  TextColumn get status => text()();

  /// Import start time.
  DateTimeColumn get startedAt => dateTime()();

  /// Successful activation time.
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Number of imported addresses.
  IntColumn get addressCount => integer().withDefault(const Constant(0))();

  /// Number of imported parcels.
  IntColumn get parcelCount => integer().withDefault(const Constant(0))();

  /// Identifier of the county the snapshot was downloaded from.
  ///
  /// Snapshots predating multi-county support are all Riverside.
  TextColumn get county => text().withDefault(const Constant('riverside'))();
}

/// Normalized address rows associated with a snapshot.
@DataClassName('AddressRow')
class Addresses extends Table {
  /// Local row identifier used by FTS and RTree indexes.
  IntColumn get id => integer().autoIncrement()();

  /// Owning snapshot.
  IntColumn get snapshotId => integer().references(Snapshots, #id)();

  /// Riverside County address identifier.
  IntColumn get sourceId => integer()();

  /// ArcGIS object identifier used to resume batch downloads.
  IntColumn get sourceObjectId => integer().withDefault(const Constant(0))();

  /// Primary street address.
  TextColumn get fullAddress => text()();

  /// Numeric house component.
  IntColumn get houseNumber => integer().nullable()();

  /// Street name component.
  TextColumn get streetName => text()();

  /// Street type component.
  TextColumn get streetType => text()();

  /// Unit component.
  TextColumn get unit => text()();

  /// Situs city.
  TextColumn get city => text()();

  /// ZIP code.
  TextColumn get zipCode => text()();

  /// Assessor parcel number.
  TextColumn get apn => text()();

  /// Raw county address type code.
  TextColumn get addressType => text()();

  /// Number of units at this point.
  IntColumn get numberOfUnits => integer()();

  /// WGS84 latitude.
  RealColumn get latitude => real()();

  /// WGS84 longitude.
  RealColumn get longitude => real()();

  /// County edit time.
  DateTimeColumn get sourceUpdatedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {snapshotId, sourceId},
    {snapshotId, sourceObjectId},
  ];
}

/// Parcel facts and geometry associated with a snapshot.
@DataClassName('ParcelRow')
class Parcels extends Table {
  /// Local row identifier used by the RTree index.
  IntColumn get id => integer().autoIncrement()();

  /// Owning snapshot.
  IntColumn get snapshotId => integer().references(Snapshots, #id)();

  /// Riverside County object identifier.
  IntColumn get sourceId => integer()();

  /// Assessor parcel number.
  TextColumn get apn => text()();

  /// Situs street address.
  TextColumn get situsAddress => text()();

  /// Situs city.
  TextColumn get city => text()();

  /// ZIP code.
  TextColumn get zipCode => text()();

  /// Assessor class or land-use description.
  TextColumn get landUse => text()();

  /// Assessed acreage.
  RealColumn get acreage => real().nullable()();

  /// JSON-encoded WGS84 polygon rings.
  TextColumn get geometryJson => text()();

  /// Western geometry bound.
  RealColumn get minLongitude => real()();

  /// Eastern geometry bound.
  RealColumn get maxLongitude => real()();

  /// Southern geometry bound.
  RealColumn get minLatitude => real()();

  /// Northern geometry bound.
  RealColumn get maxLatitude => real()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {snapshotId, sourceId},
  ];
}

/// Small persisted application settings.
@DataClassName('SettingRow')
class Settings extends Table {
  /// Setting name.
  TextColumn get key => text()();

  /// Setting value.
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Persisted results from public property-owner lookups.
@DataClassName('PropertyOwnerCacheRow')
class PropertyOwnerCache extends Table {
  /// Stable jurisdiction and property identifier, normally the APN.
  TextColumn get propertyKey => text()();

  /// Published current owner, or null for a confirmed no-match result.
  TextColumn get ownerName => text().nullable()();

  /// Parcel identifier returned by the property-tax source.
  TextColumn get parcelId => text()();

  /// Situs address used to validate the source result.
  TextColumn get matchedAddress => text()();

  /// Public page that supplied the record.
  TextColumn get sourceUrl => text()();

  /// Whether the lookup found an owner or confirmed no exact match.
  TextColumn get status => text()();

  /// Time the public source was checked.
  DateTimeColumn get checkedAt => dateTime()();

  /// Time after which the public source should be checked again.
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {propertyKey};
}

/// Persisted exact-match results from California's unclaimed-property search.
@DataClassName('UnclaimedPropertyCacheRow')
class UnclaimedPropertyCache extends Table {
  /// Normalized owner and location lookup key.
  TextColumn get searchKey => text()();

  /// Owner text supplied by the Riverside County source.
  TextColumn get ownerName => text()();

  /// First name submitted to the official search page.
  TextColumn get firstName => text()();

  /// Last name or business name submitted to the official search page.
  TextColumn get lastName => text()();

  /// Optional city submitted to narrow the result.
  TextColumn get city => text()();

  /// Optional ZIP code submitted to narrow the result.
  TextColumn get zipCode => text()();

  /// Whether the state reported at least one exact match.
  BoolColumn get found => boolean()();

  /// Number of records returned by the state search.
  IntColumn get resultCount => integer()();

  /// Official page used for the search.
  TextColumn get sourceUrl => text()();

  /// Time the state source was checked.
  DateTimeColumn get checkedAt => dateTime()();

  /// Time after which a fresh state search should be offered.
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {searchKey};
}

/// The background-isolate SQLite database for local GIS snapshots.
@DriftDatabase(
  tables: [
    Snapshots,
    Addresses,
    Parcels,
    Settings,
    PropertyOwnerCache,
    UnclaimedPropertyCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the application database in a background isolate.
  ///
  /// The web build has no isolate; drift runs SQLite compiled to WebAssembly
  /// in a worker instead. See [_webOptions].
  AppDatabase()
    : super(driftDatabase(name: 'riverside_atlas', web: _webOptions));

  /// Opens a database using [executor], primarily for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSpatialIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(addresses, addresses.sourceObjectId);
      }
      if (from < 3) {
        await migrator.createTable(propertyOwnerCache);
      }
      if (from < 4) {
        await migrator.createTable(unclaimedPropertyCache);
      }
      if (from < 5) {
        await migrator.addColumn(snapshots, snapshots.county);
        await _scopeSettingsToRiverside();
      }
      if (from < 6) {
        await _prefixCaliforniaCountyIds();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createSpatialIndexes();
    },
  );

  /// Moves county-blind settings onto their Riverside-scoped keys.
  ///
  /// Existing installs keep their downloaded snapshot and saved boundary
  /// instead of silently re-reading them as another county's data.
  Future<void> _scopeSettingsToRiverside() async {
    await customStatement('''
      UPDATE settings SET key = 'active_snapshot_id:riverside'
      WHERE key = 'active_snapshot_id'
    ''');
    await customStatement('''
      UPDATE settings SET key = 'county_boundary:riverside'
      WHERE key = 'county_boundary'
    ''');
  }

  /// Moves county-scoped rows onto their state-prefixed identifiers.
  ///
  /// County identifiers gained a state prefix when the application went
  /// national, because a county name does not identify a county across fifty
  /// states. Everything already on disk was written by a California-only
  /// build, so every existing identifier is a California one and takes the
  /// `ca_` prefix. Without this, an install's downloaded snapshots, saved
  /// boundaries and cached owner names would all be orphaned -- present in the
  /// database, scoped to identifiers nothing looks up any more.
  Future<void> _prefixCaliforniaCountyIds() async {
    await customStatement('''
      UPDATE snapshots SET county = 'ca_' || county
      WHERE county NOT LIKE 'ca\\_%' ESCAPE '\\'
    ''');
    await customStatement('''
      UPDATE settings
      SET key = 'active_snapshot_id:ca_'
        || substr(key, length('active_snapshot_id:') + 1)
      WHERE key LIKE 'active_snapshot_id:%'
        AND key NOT LIKE 'active_snapshot_id:ca\\_%' ESCAPE '\\'
    ''');
    await customStatement('''
      UPDATE settings
      SET key = 'county_boundary:ca_'
        || substr(key, length('county_boundary:') + 1)
      WHERE key LIKE 'county_boundary:%'
        AND key NOT LIKE 'county_boundary:ca\\_%' ESCAPE '\\'
    ''');
    // Owner cache keys dropped their separate state segment at the same time:
    // `us:ca:riverside:...` becomes `us:ca_riverside:...`.
    await customStatement(r'''
      UPDATE property_owner_cache
      SET property_key = 'us:ca_' || substr(property_key, length('us:ca:') + 1)
      WHERE property_key LIKE 'us:ca:%'
    ''');
  }

  Future<void> _createSpatialIndexes() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS address_fts
      USING fts5(full_address, city, zip_code)
    ''');
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS address_rtree
      USING rtree(id, min_lon, max_lon, min_lat, max_lat)
    ''');
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS parcel_rtree
      USING rtree(id, min_lon, max_lon, min_lat, max_lat)
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS addresses_search_insert
      AFTER INSERT ON addresses BEGIN
        INSERT INTO address_fts(rowid, full_address, city, zip_code)
        VALUES (new.id, new.full_address, new.city, new.zip_code);
        INSERT INTO address_rtree(
          id, min_lon, max_lon, min_lat, max_lat
        ) VALUES (
          new.id, new.longitude, new.longitude, new.latitude, new.latitude
        );
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS addresses_search_delete
      AFTER DELETE ON addresses BEGIN
        DELETE FROM address_fts WHERE rowid = old.id;
        DELETE FROM address_rtree WHERE id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS parcels_spatial_insert
      AFTER INSERT ON parcels BEGIN
        INSERT INTO parcel_rtree(
          id, min_lon, max_lon, min_lat, max_lat
        ) VALUES (
          new.id,
          new.min_longitude,
          new.max_longitude,
          new.min_latitude,
          new.max_latitude
        );
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS parcels_spatial_delete
      AFTER DELETE ON parcels BEGIN
        DELETE FROM parcel_rtree WHERE id = old.id;
      END
    ''');
  }
}
