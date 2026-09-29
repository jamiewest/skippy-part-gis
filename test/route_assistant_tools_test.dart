import 'package:extensions/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/route_assistant_tools.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/domain/services/route_planner.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';
import 'support/fake_map_repositories.dart';
import 'support/fake_route_editing.dart';
import 'support/fake_routing.dart';

void main() {
  late MapWorkspace workspace;
  late RouteViewModel routing;
  late List<AIFunction> tools;
  Future<Map> call(String name, [Map<String, Object?> args = const {}]) async =>
      await tools
              .firstWhere((t) => t.name == name)
              .invoke(AIFunctionArguments()..addAll(args))
          as Map;
  setUp(() {
    routing = RouteViewModel(
      planner: RoutePlanner(
        routing: FakeRouting([
          [testRoute(), testDetour()],
        ]),
        cameras: FakeRouteCameras([
          RouteCameraSnapshot(cameras: [testCamera()], complete: true),
        ]),
      ),
      geocoder: FakeRouteGeocoder(),
    );
    workspace = MapWorkspace()
      ..attach(
        buildFakeMapViewModel(routing: routing),
        CountySources.riverside,
      );
    tools = buildRouteTools(workspace).whereType<AIFunction>().toList();
  });
  tearDown(() {
    workspace.requireViewModel.dispose();
    workspace.dispose();
  });
  Map<String, Object?> arguments() => {
    'stops': [
      for (final stop in testStops)
        {
          'label': stop.label,
          'latitude': stop.position.latitude,
          'longitude': stop.position.longitude,
        },
    ],
    'preference': 'avoidMappedCoverage',
  };
  test(
    'assistant draws the same route as the manual builder and reports limits',
    () async {
      expect(
        (await call('search_route_places', {'query': 'Start'}))['places'],
        hasLength(2),
      );
      final result = await call('plan_route', arguments());
      expect(result['status'], 'ready');
      expect(routing.panelOpen, isTrue);
      expect(routing.selected!.path.seconds, 200);
      expect(
        result['notices'].toString(),
        contains('not an exhaustive search'),
      );
      expect(result['directions'], isNotEmpty);
      expect(routing.plan!.routes.every((r) => r.hits.isEmpty), isTrue);
      final selected = await call('select_route', {'index': 0});
      expect(selected['status'], 'ready');
      expect(routing.selectedConstraintsSatisfied, isTrue);
      await call('clear_route');
      expect((await call('get_route'))['status'], 'empty');
    },
  );
  test(
    'invalid coordinates and filter values are rejected without routing',
    () async {
      expect(
        (await call('plan_route', {
          ...arguments(),
          'cameraFilter': 'invented',
        }))['status'],
        'invalid',
      );
      expect(
        (await call('plan_route', {
          ...arguments(),
          'maxDetourMinutes': 'NaN',
        }))['status'],
        'invalid',
      );
      expect(routing.plan, isNull);
      expect((await call('select_route', {'index': -1}))['status'], 'invalid');
    },
  );
  test('tools resolve the current workspace after a county switch', () async {
    final old = workspace.requireViewModel;
    workspace.attach(buildFakeMapViewModel(), CountySources.riverside);
    old.dispose();
    expect((await call('plan_route', arguments()))['status'], 'unavailable');
  });
  test(
    'assistant reports pending checks and committed chosen streets',
    () async {
      final old = workspace.requireViewModel;
      routing = RouteViewModel(
        planner: RoutePlanner(
          routing: FakeEditableRouting(),
          cameras: FakeRouteCameras([
            RouteCameraSnapshot(cameras: [], complete: true),
          ]),
        ),
        geocoder: FakeRouteGeocoder(),
      );
      workspace.attach(
        buildFakeMapViewModel(routing: routing),
        CountySources.riverside,
      );
      old.dispose();
      await call('plan_route', {...arguments(), 'preference': 'fastest'});
      routing.beginRouteDrag(0.5);
      routing.updateRouteDrag(routePoint(0, 200), 50);
      final pending = await call('get_route');
      expect(pending['status'], 'editing');
      expect(pending['cameraCheckPending'], isTrue);
      await routing.finishRouteDrag();
      final committed = await call('get_route');
      expect(committed['status'], 'ready');
      expect(committed['cameraCheckPending'], isFalse);
      expect(committed['shapingPoints'], hasLength(1));
      expect(committed['detourBaseline'], 'fastest_through_chosen_streets');
    },
  );
}
