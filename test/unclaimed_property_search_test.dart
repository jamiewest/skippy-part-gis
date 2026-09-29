import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/unclaimed_property_cache_store.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';

void main() {
  group('UnclaimedPropertyQuery', () {
    test('splits assessor-style individual names into last and first', () {
      final query = UnclaimedPropertyQuery.fromOwner(
        ownerName: 'SMITH JOHN A',
        city: 'RIVERSIDE',
        zipCode: '92501',
      );

      expect(query.lastName, 'SMITH');
      expect(query.firstName, 'JOHN');
      expect(query.cacheKey, 'SMITH JOHN A|RIVERSIDE|92501');
    });

    for (final name in ["O'BRIEN & SONS LLC", 'SMITH AND JONES INC']) {
      test('preserves the full business name $name', () {
        final query = UnclaimedPropertyQuery.fromOwner(
          ownerName: name,
          city: '',
          zipCode: '',
        );
        expect(query.lastName, name);
        expect(query.firstName, isEmpty);
      });
    }

    test('uses the first listed individual for joint ownership', () {
      final query = UnclaimedPropertyQuery.fromOwner(
        ownerName: 'SMITH JOHN & JANE',
        city: '',
        zipCode: '',
      );
      expect(query.lastName, 'SMITH');
      expect(query.firstName, 'JOHN');
    });

    test('uses the complete business name as the last-name search', () {
      final query = UnclaimedPropertyQuery.fromOwner(
        ownerName: 'MISSION INN RIVERSIDE',
        city: 'RIVERSIDE',
        zipCode: '92501',
      );

      expect(query.lastName, 'MISSION INN RIVERSIDE');
      expect(query.firstName, isEmpty);
    });
  });

  test('saves and restores a completed result', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = UnclaimedPropertyCacheStore(database);
    final query = UnclaimedPropertyQuery.fromOwner(
      ownerName: 'SMITH JOHN',
      city: 'RIVERSIDE',
      zipCode: '92501',
    );
    final result = UnclaimedPropertySearchResult(
      query: query,
      found: false,
      resultCount: 0,
      checkedAt: DateTime.now().toUtc(),
      sourceUri: Uri.parse('https://claimit.ca.gov/app/claim-search'),
    );

    await store.save(result);
    final restored = await store.findSaved(query);

    expect(restored?.found, isFalse);
    expect(restored?.isSaved, isTrue);
    expect(restored?.query.firstName, 'JOHN');
  });
}
