import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:riverside_atlas/data/services/portal_discovery_service.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

/// Dallas County, Texas — a county with no registry entry, which is the case
/// discovery exists for.
final _dallas = UsGeography.byGeoid('48113')!;
final _texas = UsGeography.stateByFips('48')!;

/// One item as ArcGIS Online's search returns it.
Map<String, Object?> _item(
  String url, {
  List<double> extent = const [-96.9, 32.6, -96.5, 32.9],
  String owner = 'someone',
}) => {
  'url': url,
  'owner': owner,
  'extent': [
    [extent[0], extent[1]],
    [extent[2], extent[3]],
  ],
};

const _countyRoot =
    'https://services3.arcgis.com/zqe2kwz79KUqUvxC/arcgis/rest/services';
const _cityRoot =
    'https://services2.arcgis.com/rwnOSbfKSwyTBcwN/arcgis/rest/services';

/// A stand-in ArcGIS Online answering the three channels discovery uses.
///
/// [subdomains] maps a vanity key to an organisation; every other key returns
/// the empty body a wrong guess gets, which is what makes the probe
/// self-verifying. [results] maps a substring of the search query to items.
MockClient _arcGisOnline({
  Map<String, Map<String, String>> subdomains = const {},
  Map<String, List<Map<String, Object?>>> results = const {},
  Map<String, String> organisations = const {},
  Map<int, List<Map<String, Object?>>> places = const {},
  void Function(Uri)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request.url);
    final host = request.url.host;
    if (host == 'tigerweb.geo.census.gov') {
      final layer = int.parse(
        request.url.pathSegments[request.url.pathSegments.length - 2],
      );
      return http.Response(
        jsonEncode({'features': places[layer] ?? const []}),
        200,
      );
    }
    if (host.endsWith('.maps.arcgis.com')) {
      final key = host.split('.').first;
      final organisation = subdomains[key];
      return http.Response(jsonEncode(organisation ?? const {}), 200);
    }
    if (request.url.path.contains('/sharing/rest/portals/')) {
      final id = request.url.pathSegments.last;
      final name = organisations[id];
      return http.Response(
        jsonEncode(name == null ? const {} : {'id': id, 'name': name}),
        200,
      );
    }
    final query = request.url.queryParameters['q'] ?? '';
    for (final entry in results.entries) {
      if (query.contains(entry.key)) {
        return http.Response(jsonEncode({'results': entry.value}), 200);
      }
    }
    return http.Response(jsonEncode(const {'results': []}), 200);
  });
}

void main() {
  _placeTests();

  test('finds a county publisher by its vanity subdomain', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        subdomains: {
          'dallascountygis': {
            'id': 'zqe2kwz79KUqUvxC',
            'name': 'Dallas County GIS Information Technology',
          },
        },
        results: {
          'orgid:zqe2kwz79KUqUvxC': [
            _item('$_countyRoot/Parcels/FeatureServer/0'),
            _item('$_countyRoot/Zoning/FeatureServer/0'),
            _item('$_countyRoot/Flood/MapServer'),
          ],
        },
      ),
    );

    final portals = await service.discover(county: _dallas, state: _texas);

    expect(portals, hasLength(1));
    expect(portals.single.root, _countyRoot);
    expect(
      portals.single.publisher,
      'Dallas County GIS Information Technology',
    );
    expect(portals.single.tier, PortalTier.countyPortal);
    expect(portals.single.origin, PortalOrigin.discovered);
  });

  test('names a publisher from its own organisation record', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        organisations: const {
          'rwnOSbfKSwyTBcwN': 'City of Dallas GIS Services',
        },
        results: {
          'Dallas County': [
            _item('$_cityRoot/Zoning/FeatureServer/0'),
            _item('$_cityRoot/Streets/FeatureServer/0'),
            _item('$_cityRoot/Aerials/ImageServer'),
          ],
        },
      ),
    );

    final portals = await service.discover(county: _dallas, state: _texas);

    expect(portals.single.publisher, 'City of Dallas GIS Services');
    expect(portals.single.tier, PortalTier.city);
  });

  test('rejects a publisher whose work is somewhere else', () async {
    // "Washington County" matches in thirty-one states; this is the Alabama
    // one answering a Texas search. Nothing but the extents tells them apart.
    final service = PortalDiscoveryService(
      _arcGisOnline(
        results: {
          'Dallas County': [
            for (var index = 0; index < 8; index++)
              _item(
                'https://gis.elsewhere.gov/arcgis/rest/services/L$index'
                '/MapServer',
                extent: const [-86.9, 32.1, -86.5, 32.4],
              ),
          ],
        },
      ),
    );

    expect(await service.discover(county: _dallas, state: _texas), isEmpty);
  });

  test('a world extent is not a claim to cover this county', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        results: {
          'Dallas County': [
            for (var index = 0; index < 6; index++)
              _item(
                'https://services1.arcgis.com/global/arcgis/rest/services/'
                'L$index/FeatureServer/0',
                extent: const [-180, -90, 180, 90],
              ),
          ],
        },
      ),
    );

    expect(await service.discover(county: _dallas, state: _texas), isEmpty);
  });

  test('collapses a host alias, preferring the .gov name', () async {
    const gov = 'https://gis.dallascounty.gov/server/rest/services';
    const us = 'https://gis.dallascounty.us/server/rest/services';
    final service = PortalDiscoveryService(
      _arcGisOnline(
        results: {
          'Dallas County': [
            for (var index = 0; index < 4; index++)
              _item('$us/L$index/MapServer'),
            for (var index = 0; index < 4; index++)
              _item('$gov/L$index/MapServer'),
          ],
        },
      ),
    );

    final portals = await service.discover(county: _dallas, state: _texas);

    expect(portals.map((portal) => portal.root), [gov]);
  });

  test('one server spelled two ways is one catalogue', () async {
    // ArcGIS Online publishes the same hosted root as both `/arcgis/rest/
    // services` and `/ArcGIS/rest/services`. Counting them apart would list
    // the catalogue twice and ask its organisation for a name twice.
    const lower =
        'https://services3.arcgis.com/zqe2kwz79KUqUvxC/arcgis/rest/services';
    const upper =
        'https://services3.arcgis.com/zqe2kwz79KUqUvxC/ArcGIS/rest/services';
    final service = PortalDiscoveryService(
      _arcGisOnline(
        organisations: const {'zqe2kwz79KUqUvxC': 'Dallas County'},
        results: {
          'Dallas County': [
            _item('$lower/A/FeatureServer/0'),
            _item('$upper/B/FeatureServer/0'),
            _item('$upper/C/FeatureServer/0'),
          ],
        },
      ),
    );

    final portals = await service.discover(county: _dallas, state: _texas);

    expect(portals, hasLength(1));
    expect(portals.single.root, lower);
  });

  test('never offers a proxied or tile-cache root', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        results: {
          'Dallas County': [
            for (var index = 0; index < 5; index++)
              _item(
                'https://utility.arcgis.com/usrsvcs/servers/abc/rest/services'
                '/L$index/MapServer',
              ),
            for (var index = 0; index < 5; index++)
              _item(
                'https://tiles.arcgis.com/tiles/abc/arcgis/rest/services'
                '/L$index/VectorTileServer',
              ),
          ],
        },
      ),
    );

    expect(await service.discover(county: _dallas, state: _texas), isEmpty);
  });

  test('carries the publisher coverage the items advertise', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        organisations: const {
          'rwnOSbfKSwyTBcwN': 'City of Dallas GIS Services',
        },
        results: {
          'Dallas County': [
            _item(
              '$_cityRoot/A/FeatureServer/0',
              extent: const [-96.9, 32.6, -96.7, 32.8],
            ),
            _item(
              '$_cityRoot/B/FeatureServer/0',
              extent: const [-96.8, 32.7, -96.6, 32.9],
            ),
            _item(
              '$_cityRoot/C/FeatureServer/0',
              extent: const [-96.85, 32.65, -96.75, 32.75],
            ),
          ],
        },
      ),
    );

    final coverage = (await service.discover(
      county: _dallas,
      state: _texas,
    )).single.coverage;

    expect(coverage, isNotNull);
    expect(coverage!.west, closeTo(-96.9, 1e-9));
    expect(coverage.east, closeTo(-96.6, 1e-9));
  });

  test(
    'an unreachable ArcGIS Online is an empty answer, not a throw',
    () async {
      final service = PortalDiscoveryService(
        MockClient((_) async => http.Response('gateway timeout', 504)),
      );

      expect(await service.discover(county: _dallas, state: _texas), isEmpty);
    },
  );

  test('reads a county once and remembers the answer', () async {
    final asked = <Uri>[];
    final service = PortalDiscoveryService(_arcGisOnline(onRequest: asked.add));

    await service.discover(county: _dallas, state: _texas);
    final first = asked.length;
    await service.discover(county: _dallas, state: _texas);

    expect(asked, hasLength(first));
    expect(first, greaterThan(0));
  });

  test('a city that names its state is not a state agency', () async {
    // `Buckeye, Arizona` is how a city writes itself. Reading that as a state
    // agency would offer one city's layers over every county in the state.
    const root =
        'https://services1.arcgis.com/sixrqw8b8BHDvWq2/arcgis/rest/services';
    final service = PortalDiscoveryService(
      _arcGisOnline(
        organisations: const {'sixrqw8b8BHDvWq2': 'Buckeye, Texas'},
        results: {
          'Dallas County': [
            for (var index = 0; index < 4; index++)
              _item('$root/L$index/FeatureServer/0'),
          ],
        },
      ),
    );

    final portal = (await service.discover(
      county: _dallas,
      state: _texas,
    )).single;

    expect(portal.tier, PortalTier.partner);
    expect(portal.isWideArea, isFalse);
  });

  test('a state agency that names its state is one', () async {
    const root =
        'https://services1.arcgis.com/99lidPhWCzftIe9K/arcgis/rest/services';
    final service = PortalDiscoveryService(
      _arcGisOnline(
        organisations: const {
          '99lidPhWCzftIe9K': 'Texas Department of Transportation',
        },
        results: {
          'Dallas County': [
            for (var index = 0; index < 4; index++)
              _item('$root/L$index/FeatureServer/0'),
          ],
        },
      ),
    );

    final portal = (await service.discover(
      county: _dallas,
      state: _texas,
    )).single;

    expect(portal.tier, PortalTier.statewide);
  });

  test(
    'attributes an unrecognised publisher to nobody in particular',
    () async {
      const root = 'https://maps.nctcog.org/arcgis/rest/services';
      final service = PortalDiscoveryService(
        _arcGisOnline(
          results: {
            'Dallas County': [
              for (var index = 0; index < 5; index++)
                _item('$root/L$index/MapServer'),
            ],
          },
        ),
      );

      final portal = (await service.discover(
        county: _dallas,
        state: _texas,
      )).single;

      expect(portal.tier, PortalTier.partner);
      expect(portal.publisher, 'maps.nctcog.org');
    },
  );
}

/// One municipality as TIGERweb returns it.
Map<String, Object?> _place(
  String geoid,
  String basename, {
  List<double> box = const [-96.75, 32.75, -96.70, 32.80],
  String state = '48',
}) => {
  'attributes': {'GEOID': geoid, 'BASENAME': basename, 'STATE': state},
  'geometry': {
    'rings': [
      [
        [box[0], box[1]],
        [box[2], box[1]],
        [box[2], box[3]],
        [box[0], box[3]],
        [box[0], box[1]],
      ],
    ],
  },
};

const _viewport = GeoBounds(
  west: -96.78,
  south: 32.73,
  east: -96.68,
  north: 32.82,
);

const _townRoot =
    'https://services5.arcgis.com/HmZrfXtpyBP9VLYQ/arcgis/rest/services';

void _placeTests() {
  test('finds the town under the viewport', () async {
    final service = PortalDiscoveryService(
      _arcGisOnline(
        places: {
          4: [_place('4805864', 'Balch Springs')],
          1: const [],
        },
        organisations: const {'HmZrfXtpyBP9VLYQ': 'City of Balch Springs'},
        results: {
          'Balch Springs': [
            for (var index = 0; index < 5; index++)
              _item('$_townRoot/L$index/FeatureServer/0'),
          ],
        },
      ),
    );

    final portals = await service.discoverPlaces(
      viewport: _viewport,
      county: _dallas,
      state: _texas,
    );

    expect(portals.single.publisher, 'City of Balch Springs');
    expect(portals.single.tier, PortalTier.city);
    expect(portals.single.origin, PortalOrigin.discovered);
  });

  test('asks the Census only for governments, not statistical areas', () async {
    // Texas county subdivisions are census county divisions: drawn for
    // tabulation, administered by nobody. Searching for one spends budget
    // to find noise, so the filter belongs in the request.
    final asked = <Uri>[];
    final service = PortalDiscoveryService(_arcGisOnline(onRequest: asked.add));

    await service.discoverPlaces(
      viewport: _viewport,
      county: _dallas,
      state: _texas,
    );

    final census = asked.where((uri) => uri.host == 'tigerweb.geo.census.gov');
    expect(census, hasLength(2));
    for (final uri in census) {
      expect(uri.queryParameters['where'], "FUNCSTAT IN ('A','B','C')");
    }
  });

  test('a city and its coextensive town are searched once', () async {
    // Hartford city is an incorporated place and Hartford town is a county
    // subdivision covering the same ground. They are one government.
    final asked = <String>[];
    final service = PortalDiscoveryService(
      _arcGisOnline(
        places: {
          4: [_place('0937000', 'Hartford')],
          1: [_place('0911037070', 'Hartford')],
        },
        onRequest: (uri) {
          final query = uri.queryParameters['q'];
          if (query != null) {
            asked.add(query);
          }
        },
      ),
    );

    await service.discoverPlaces(
      viewport: _viewport,
      county: _dallas,
      state: _texas,
    );

    expect(asked.where((q) => q.contains('"Hartford"')), hasLength(1));
  });

  test('a municipality already searched is not searched again', () async {
    final asked = <String>[];
    final service = PortalDiscoveryService(
      _arcGisOnline(
        places: {
          4: [_place('4805864', 'Balch Springs')],
          1: const [],
        },
        onRequest: (uri) {
          final query = uri.queryParameters['q'];
          if (query != null && query.contains('Balch Springs')) {
            asked.add(query);
          }
        },
      ),
    );

    await service.discoverPlaces(
      viewport: _viewport,
      county: _dallas,
      state: _texas,
    );
    await service.discoverPlaces(
      viewport: _viewport,
      county: _dallas,
      state: _texas,
    );

    expect(asked, hasLength(1));
  });

  test(
    'a session stops searching municipalities once the budget is out',
    () async {
      // Panning across a township county puts a new set of towns on screen
      // every gesture. Without a session budget that is unbounded searching.
      var round = 0;
      final searched = <String>{};
      final service = PortalDiscoveryService(
        _arcGisOnline(
          places: {
            4: [
              for (var index = 0; index < 3; index++)
                _place('${round}0$index', 'Town $round$index'),
            ],
            1: const [],
          },
          onRequest: (uri) {
            final query = uri.queryParameters['q'] ?? '';
            final match = RegExp(r'"(Town \d+)"').firstMatch(query);
            if (match != null) {
              searched.add(match.group(1)!);
            }
          },
        ),
      );

      for (round = 0; round < 10; round++) {
        await service.discoverPlaces(
          viewport: _viewport,
          county: _dallas,
          state: _texas,
        );
      }

      expect(searched.length, lessThanOrEqualTo(12));
      expect(searched, isNotEmpty);
    },
  );

  test("never offers Esri's own global content", () async {
    const livingAtlas =
        'https://services9.arcgis.com/jIL9msH9OI208GCb/arcgis/rest/services';
    final service = PortalDiscoveryService(
      _arcGisOnline(
        places: {
          4: [_place('4805864', 'Balch Springs')],
          1: const [],
        },
        results: {
          'Balch Springs': [
            for (var index = 0; index < 8; index++)
              _item('$livingAtlas/L$index/FeatureServer/0'),
          ],
        },
      ),
    );

    expect(
      await service.discoverPlaces(
        viewport: _viewport,
        county: _dallas,
        state: _texas,
      ),
      isEmpty,
    );
  });
}
