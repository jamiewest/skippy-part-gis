import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:extensions/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/map_assistant_tools.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';

import 'support/fake_map_repositories.dart';

void main() {
  /// The tool named [name], from a workspace over [addresses].
  ({AIFunction tool, MapWorkspace workspace}) build(
    String name, {
    AddressRepository? addresses,
    CensusService? census,
    CountySource? county,
    bool parcelsAvailable = true,
  }) {
    final workspace = MapWorkspace()
      ..attach(
        buildFakeMapViewModel(
          addresses: addresses,
          parcelsAvailable: parcelsAvailable,
        ),
        county ?? CountySources.riverside,
      );
    final tools = buildMapTools(
      workspace: workspace,
      census: census ?? CensusService(MockClient((_) async => _noTracts())),
    );
    return (
      tool: tools.whereType<AIFunction>().firstWhere((t) => t.name == name),
      workspace: workspace,
    );
  }

  Future<Object?> call(
    AIFunction tool, [
    Map<String, Object?> args = const {},
  ]) {
    return tool.invoke(AIFunctionArguments()..addAll(args));
  }

  group('draw_area', () {
    test('draws a circle and reads the addresses inside it', () async {
      final built = build('draw_area', addresses: _ThreeAddresses());

      final result =
          await call(built.tool, {
                'shape': 'circle',
                'centerLatitude': 33.98,
                'centerLongitude': -117.37,
                'radiusMeters': 800,
              })
              as Map<String, Object?>;

      check(result['drew'] as String).contains('circle');
      // Two of the three fixtures sit inside 800 m; the third is a kilometre
      // out, inside the enclosing square but outside the circle.
      check(result['addressesFound']).equals(2);
      check(built.workspace.requireViewModel.areaSelection!.count).equals(2);
    });

    test('leaves the drawn area on the map for the next question', () async {
      final built = build('draw_area', addresses: _ThreeAddresses());

      await call(built.tool, {
        'shape': 'circle',
        'centerLatitude': 33.98,
        'centerLongitude': -117.37,
        'radiusMeters': 800,
      });

      final selection = built.workspace.requireViewModel.areaSelection;
      check(selection).isNotNull();
      check(selection!.shape.description).contains('circle');
    });

    test('says what a shape is missing rather than guessing it', () async {
      final built = build('draw_area');

      check(
        await call(built.tool, {'shape': 'circle'}) as String,
      ).contains('radiusMeters');
      check(
        await call(built.tool, {'shape': 'rectangle', 'west': -117.4})
            as String,
      ).contains('north');
    });

    test('normalises a rectangle drawn from any corner', () async {
      final built = build('draw_area');

      final result =
          await call(built.tool, {
                'shape': 'rectangle',
                'west': -117.30,
                'south': 34.00,
                'east': -117.40,
                'north': 33.90,
              })
              as Map<String, Object?>;
      final bounds = result['bounds']! as Map<String, double>;

      check(bounds['west']!).isLessThan(bounds['east']!);
      check(bounds['south']!).isLessThan(bounds['north']!);
    });
  });

  group('describe_map', () {
    test('names the county and reports that data exists', () async {
      final built = build('describe_map');

      final result = await call(built.tool) as Map<String, Object?>;

      // The viewport is what lets draw_area answer "circle the middle of what
      // I am looking at" without the model inventing a centre.
      check(result['visibleExtent']).isNotNull();
      check(result['county'] as String).contains('Riverside');
      check(result['countyFips']).equals('06065');
      check(result['hasParcelAndAddressData']).equals(true);
      check(result['coverageNote']).isNull();
      final capabilities = result['mapCapabilities'] as Map;
      final cameras = capabilities['openStreetMap'] as Map;
      check(cameras['queryTool']).equals('query_map_cameras');
      check(cameras['enabled']).equals(false);
    });

    test('says a county has no parcel or address layer at all', () async {
      // Without this the model would read an empty address list as "nobody
      // lives here" rather than "this build cannot look".
      final built = build(
        'describe_map',
        county: CountySources.byFips('48201'),
        parcelsAvailable: false,
      );

      final result = await call(built.tool) as Map<String, Object?>;

      check(result['hasParcelAndAddressData']).equals(false);
      check(result['coverageNote'] as String).contains('No public layer');
    });
  });

  test(
    'registers camera and catalog tools with the shared provider toolset',
    () async {
      for (final name in [
        'get_map_capabilities',
        'query_map_cameras',
        'list_map_layers',
        'describe_map_layer',
        'set_map_layer_visibility',
      ]) {
        final built = build(name);
        check(built.tool.name).equals(name);
        built.workspace.requireViewModel.dispose();
        built.workspace.dispose();
      }
    },
  );

  group('list_area_addresses', () {
    test('asks for an area before answering about one', () async {
      final built = build('list_area_addresses');

      check(await call(built.tool) as String).contains('draw_area');
    });

    test('reports the true count even when the list is trimmed', () async {
      final built = build('list_area_addresses', addresses: _ManyAddresses());
      final draw = buildMapTools(
        workspace: built.workspace,
        census: CensusService(MockClient((_) async => _noTracts())),
      ).whereType<AIFunction>().firstWhere((t) => t.name == 'draw_area');
      await call(draw, {
        'shape': 'rectangle',
        'west': -118.0,
        'south': 33.0,
        'east': -117.0,
        'north': 34.5,
      });

      final result = await call(built.tool) as Map<String, Object?>;

      check(result['addressesFound']).equals(200);
      check(result['listed']).equals(assistantAddressLimit);
      check(
        (result['addresses']! as List).length,
      ).equals(assistantAddressLimit);
    });
  });

  group('get_area_demographics', () {
    test('warns the model that figures cover whole tracts', () async {
      // The caveat has to be in the description the model reads, not only in
      // a comment: this is what stops an answer scaling a tract population
      // down to the circle drawn over it.
      final built = build('get_area_demographics');
      final description = built.tool.description!;

      check(description).contains('WHOLE TRACTS');
      check(description).contains('not the shape itself');
      check(description).contains('medians are given as a range');
    });

    test('asks the census about the drawn shape, not a rectangle', () async {
      // The tool must hand the circle itself to the census service; asking
      // about the enclosing box pulls in corner tracts the circle never
      // touches, which measurably over-reports.
      late http.Request captured;
      final built = build(
        'get_area_demographics',
        addresses: _ThreeAddresses(),
        census: CensusService(
          MockClient((request) async {
            captured = request;
            return _twoTracts();
          }),
        ),
      );
      await _drawCircle(built.workspace);

      await call(built.tool);

      check(captured.bodyFields['geometryType']).equals('esriGeometryPolygon');
      check(captured.bodyFields['geometry']!).startsWith('{"rings":[[');
    });

    test('says a key is missing rather than reporting nothing', () async {
      final built = build(
        'get_area_demographics',
        addresses: _ThreeAddresses(),
        census: CensusService(MockClient((_) async => _twoTracts())),
      );
      await _drawCircle(built.workspace);

      final result = await call(built.tool) as Map<String, Object?>;

      check(result['figuresAvailable']).equals(false);
      check(result['tractsRead']).equals(2);
      check(result['coversWholeTracts']).equals(true);
      check(result['note'] as String).contains('key_signup');
    });
  });
}

/// Draws a circle on [workspace] through the tool, as the model would.
Future<void> _drawCircle(MapWorkspace workspace) async {
  final draw = buildMapTools(
    workspace: workspace,
    census: CensusService(MockClient((_) async => _noTracts())),
  ).whereType<AIFunction>().firstWhere((tool) => tool.name == 'draw_area');
  await draw.invoke(
    AIFunctionArguments()..addAll({
      'shape': 'circle',
      'centerLatitude': 33.98,
      'centerLongitude': -117.37,
      'radiusMeters': 800,
    }),
  );
}

http.Response _noTracts() =>
    http.Response(jsonEncode({'features': <Object>[]}), 200);

http.Response _twoTracts() => http.Response(
  jsonEncode({
    'features': [
      for (final id in ['06065031100', '06065030700'])
        {
          'attributes': {
            'GEOID': id,
            'NAME': 'Census Tract $id',
            'INTPTLAT': '+33.9800000',
            'INTPTLON': '-117.3700000',
          },
        },
    ],
  }),
  200,
);

/// Two addresses within 800 m of the test centre and one a kilometre out.
final class _ThreeAddresses implements AddressRepository {
  @override
  Future<List<Address>> queryViewport(GeoBounds bounds, {int limit = 2000}) {
    const distance = Distance();
    const centre = LatLng(33.98, -117.37);
    return Future.value([
      _address(1, distance.offset(centre, 200, 0)),
      _address(2, distance.offset(centre, 700, 90)),
      _address(3, distance.offset(centre, 1000, 45)),
    ]);
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) =>
      Future.value(const []);
}

/// Two hundred addresses, all inside any rectangle the tests draw.
final class _ManyAddresses implements AddressRepository {
  @override
  Future<List<Address>> queryViewport(GeoBounds bounds, {int limit = 2000}) {
    return Future.value([
      for (var index = 0; index < 200; index++)
        _address(index, LatLng(33.9 + index * 0.001, -117.4)),
    ]);
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) =>
      Future.value(const []);
}

Address _address(int id, LatLng position) => Address(
  objectId: id,
  sourceId: id,
  fullAddress: '$id TEST ST',
  houseNumber: id,
  streetName: 'TEST',
  streetType: 'ST',
  unit: '',
  city: 'RIVERSIDE',
  zipCode: '92501',
  apn: '',
  addressType: '',
  numberOfUnits: 0,
  position: position,
);
