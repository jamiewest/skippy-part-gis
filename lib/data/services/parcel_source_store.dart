import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/detected_parcel_source.dart';

/// Per-county source settings; manual choices survive background discovery.
final class ParcelSourceStore {
  const ParcelSourceStore(this.database);
  final AppDatabase database;
  Future<DetectedParcelSource?> load(String countyId) async {
    final row = await (database.select(
      database.settings,
    )..where((s) => s.key.equals('parcel_source:$countyId'))).getSingleOrNull();
    if (row == null) return null;
    try {
      return DetectedParcelSource.fromJson(
        (jsonDecode(row.value) as Map).cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  Future<DetectedParcelSource> save(
    String countyId,
    DetectedParcelSource source,
  ) => database.transaction(() async {
    final old = await load(countyId);
    if (old?.origin == 'manual' && source.origin != 'manual') return old!;
    await database
        .into(database.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'parcel_source:$countyId',
            value: jsonEncode(source.toJson()),
          ),
        );
    return source;
  });
  Future<void> forget(String countyId) async {
    await (database.delete(
      database.settings,
    )..where((s) => s.key.equals('parcel_source:$countyId'))).go();
  }

  Future<void> markStale(String countyId, Uri query) =>
      database.transaction(() async {
        final source = await load(countyId);
        if (source == null || source.query != query) return;
        final json = source.toJson()
          ..['detectedAt'] = DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ).toIso8601String();
        await (database.update(database.settings)
              ..where((s) => s.key.equals('parcel_source:$countyId')))
            .write(SettingsCompanion(value: Value(jsonEncode(json))));
      });
}
