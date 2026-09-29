import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/census_area.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// Two tracts as TIGERweb answers for them.
final _tractResponse = jsonEncode({
  'features': [
    {
      'attributes': {
        'GEOID': '06065031100',
        'NAME': 'Census Tract 311',
        'INTPTLAT': '+33.9800000',
        'INTPTLON': '-117.3700000',
      },
    },
    {
      'attributes': {
        'GEOID': '06065030700',
        'NAME': 'Census Tract 307',
        'INTPTLAT': '+33.9900000',
        'INTPTLON': '-117.3800000',
      },
    },
  ],
});

const _area = RectangleArea(
  GeoBounds(west: -117.40, south: 33.95, east: -117.35, north: 34.00),
);

void main() {
  test('reads the tracts a rectangle touches without any key', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_tractResponse, 200);
    });

    final tracts = await CensusService(client).tractsIn(_area);

    check(captured.url.path).endsWith('/Tracts_Blocks/MapServer/0/query');
    check(captured.bodyFields['geometryType']).equals('esriGeometryEnvelope');
    check(tracts).length.equals(2);
    check(tracts.first.geoid).equals('06065031100');
    check(tracts.first.name).equals('Census Tract 311');
    check(tracts.first.countyFips).equals('06065');
    check(tracts.first.center.latitude).isCloseTo(33.98, 0.001);
  });

  test('asks the server about the circle, not the box around it', () async {
    // The enclosing square of a circle is a third larger and reaches into
    // corner tracts the circle never enters. Sending the outline is what
    // makes "within half a mile" mean what it says.
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_tractResponse, 200);
    });

    await CensusService(client).tractsIn(
      const CircleArea(center: LatLng(33.98, -117.37), radiusMeters: 800),
    );

    check(captured.bodyFields['geometryType']).equals('esriGeometryPolygon');
    final geometry = captured.bodyFields['geometry']!;
    check(geometry).startsWith('{"rings":[[');
    // The ring must close, or the server reads it as a line.
    final ring =
        (jsonDecode(geometry) as Map<String, Object?>)['rings']! as List;
    final points = (ring.first as List).cast<List<Object?>>();
    check(points).length.equals(73);
    check(points.first).deepEquals(points.last);
  });

  test('names the tracts but refuses the figures with no key', () async {
    var dataRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.census.gov') {
        dataRequests++;
      }
      return http.Response(_tractResponse, 200);
    });
    final service = CensusService(client);

    final profile = await service.profile(await service.tractsIn(_area));

    check(service.hasApiKey).isFalse();
    // The geography is public; the measures are not. Saying which tracts
    // these are is a real answer, and inventing numbers would not be.
    check(profile.tractCount).equals(2);
    check(profile.hasValues).isFalse();
    check(profile.message!).contains('key_signup');
    check(dataRequests).equals(0);
  });

  test('reads published measures for every tract when a key is set', () async {
    late Uri dataUrl;
    final client = MockClient((request) async {
      if (request.url.host != 'api.census.gov') {
        return http.Response(_tractResponse, 200);
      }
      dataUrl = request.url;
      return http.Response(
        jsonEncode([
          ['B01003_001E', 'B19013_001E', 'state', 'county', 'tract'],
          ['4200', '71000', '06', '065', '031100'],
          ['3100', '58000', '06', '065', '030700'],
        ]),
        200,
      );
    });
    final service = CensusService(client, apiKey: 'test-key');

    final profile = await service.profile(await service.tractsIn(_area));

    check(dataUrl.queryParameters['key']).equals('test-key');
    // One request per county, not one per tract: the ACS geography predicate
    // names a state and county and then lists the tracts inside it.
    check(dataUrl.queryParameters['in']).equals('state:06 county:065');
    check(dataUrl.queryParameters['for']).equals('tract:031100,030700');
    check(profile.hasValues).isTrue();
    check(profile.tracts.first.values['B01003_001E']).equals(4200);
  });

  test('sums counts and refuses to sum medians', () async {
    final client = _keyedClient();
    final service = CensusService(client, apiKey: 'test-key');

    final profile = await service.profile(await service.tractsIn(_area));
    final population = censusVariables.firstWhere(
      (variable) => variable.code == 'B01003_001E',
    );
    final income = censusVariables.firstWhere(
      (variable) => variable.code == 'B19013_001E',
    );

    check(profile.total(population)).equals(7300);
    // Adding two median incomes produces a figure describing nobody, so the
    // profile reports the span across tracts instead.
    check(profile.total(income)).isNull();
    check(profile.range(income)!.low).equals(58000);
    check(profile.range(income)!.high).equals(71000);
  });

  test('drops the suppression sentinel rather than reading it', () async {
    // The ACS writes -666666666 where it suppressed a value. Read as a
    // number it becomes a median income of minus six hundred million.
    final client = MockClient((request) async {
      if (request.url.host != 'api.census.gov') {
        return http.Response(_tractResponse, 200);
      }
      return http.Response(
        jsonEncode([
          ['B19013_001E', 'state', 'county', 'tract'],
          ['-666666666', '06', '065', '031100'],
          ['58000', '06', '065', '030700'],
        ]),
        200,
      );
    });
    final service = CensusService(client, apiKey: 'test-key');

    final profile = await service.profile(await service.tractsIn(_area));
    final income = censusVariables.firstWhere(
      (variable) => variable.code == 'B19013_001E',
    );

    check(profile.tracts.first.values['B19013_001E']).isNull();
    check(profile.range(income)!.low).equals(58000);
    check(profile.range(income)!.high).equals(58000);
  });

  test('treats the missing-key redirect as a refusal, not as data', () async {
    // An unkeyed or rejected request answers 302 towards an HTML page headed
    // "Missing Key". A client that only decoded the body would see nothing
    // and report an area with no people in it.
    final client = MockClient((request) async {
      if (request.url.host != 'api.census.gov') {
        return http.Response(_tractResponse, 200);
      }
      return http.Response('<html>Missing Key</html>', 302);
    });
    final service = CensusService(client, apiKey: 'wrong-key');

    await check(
      service.profile(await service.tractsIn(_area)),
    ).throws<CensusException>();
  });

  test('says so when no tract covers the area at all', () async {
    final client = MockClient(
      (request) async => http.Response(jsonEncode({'features': []}), 200),
    );
    final service = CensusService(client);

    final profile = await service.profile(await service.tractsIn(_area));

    check(profile.tractCount).equals(0);
    check(profile.message!).contains('No census tract');
  });
}

/// A client answering both services, with two tracts carrying two measures.
MockClient _keyedClient() {
  return MockClient((request) async {
    if (request.url.host != 'api.census.gov') {
      return http.Response(_tractResponse, 200);
    }
    return http.Response(
      jsonEncode([
        ['B01003_001E', 'B19013_001E', 'state', 'county', 'tract'],
        ['4200', '71000', '06', '065', '031100'],
        ['3100', '58000', '06', '065', '030700'],
      ]),
      200,
    );
  });
}
