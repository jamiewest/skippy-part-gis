import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/core/text_matching.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/data/services/riverside_property_owner_service.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';

void main() {
  group('situsMatchesQuery', () {
    test('accepts a situs carrying every published component', () {
      expect(
        situsMatchesQuery('3641 6TH ST RIVERSIDE CA 92501', _query),
        isTrue,
      );
    });

    test('rejects the same house number on another street', () {
      expect(
        situsMatchesQuery('3641 7TH ST RIVERSIDE CA 92501', _query),
        isFalse,
      );
    });

    test('rejects the same address in another city', () {
      expect(situsMatchesQuery('3641 6TH ST CORONA CA 92501', _query), isFalse);
    });

    test('ignores components the county left blank', () {
      const sparse = OwnerQuery(
        countyId: 'riverside',
        subject: OwnerQuerySubject.address,
        sourceId: 16055,
        apn: '213191035',
        houseNumber: 3641,
        streetName: '6TH',
      );

      expect(situsMatchesQuery('3641 6TH ST CORONA CA 92880', sparse), isTrue);
    });

    test('rejects a query with no house number to confirm', () {
      const parcelQuery = OwnerQuery(
        countyId: 'riverside',
        subject: OwnerQuerySubject.parcel,
        sourceId: 1819,
        apn: '213191035',
      );

      expect(
        situsMatchesQuery('3641 6TH ST RIVERSIDE CA 92501', parcelQuery),
        isFalse,
      );
    });
  });

  group('selectOwnerCandidate', () {
    test('accepts a lone row and collapses repeats of it', () {
      const row = OwnerCandidate(
        parcelId: '213191035',
        recordKey: '213191035',
        situs: '3641 6TH ST',
      );

      expect(selectOwnerCandidate([row, row], preferredApn: ''), isNotNull);
    });

    test('resolves several rows by an exact parcel number', () {
      final selected = selectOwnerCandidate(
        _twoRows,
        preferredApn: '213-191-035',
      );

      expect(selected?.parcelId, '213191035');
    });

    test('reports no match rather than guessing between rows', () {
      expect(selectOwnerCandidate(_twoRows, preferredApn: ''), isNull);
      expect(selectOwnerCandidate(_twoRows, preferredApn: '999999999'), isNull);
    });
  });

  group('county registry', () {
    test('publishes an owner source only where a resolver exists', () {
      expect(CountySources.riverside.ownerSource, isNotNull);
      expect(CountySources.sanBernardino.ownerSource, isNull);
    });

    test('builds the resolver written for the county', () {
      final client = MockClient((_) async => http.Response('', 200));
      addTearDown(client.close);

      expect(
        CountySources.riverside.ownerSource!(client),
        isA<RiversidePropertyOwnerService>(),
      );
    });
  });

  group('text matching', () {
    test('reduces county parcel-number punctuation to digits', () {
      expect(digitsOnly('213-191-035'), '213191035');
    });

    test('restores entities county pages emit in owner names', () {
      expect(decodeHtmlEntities('A &amp; B &#x54;RUST'), 'A & B TRUST');
    });
  });
}

const _query = OwnerQuery(
  countyId: 'riverside',
  subject: OwnerQuerySubject.address,
  sourceId: 16055,
  apn: '213191035',
  houseNumber: 3641,
  streetName: '6TH',
  streetType: 'ST',
  city: 'RIVERSIDE',
  zipCode: '92501',
);

const _twoRows = [
  OwnerCandidate(parcelId: '213191035', recordKey: '1', situs: '3641 6TH ST'),
  OwnerCandidate(parcelId: '213191036', recordKey: '2', situs: '3643 6TH ST'),
];
