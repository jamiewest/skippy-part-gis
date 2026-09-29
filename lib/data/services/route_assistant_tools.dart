import 'package:extensions/ai.dart';
import 'package:extensions/system.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';

List<AITool> buildRouteTools(MapWorkspace workspace) => [
  AIFunctionFactory.create(
    name: 'search_route_places',
    description:
        'Finds route stops by address, place name, or latitude, longitude. '
        'Returns candidates with coordinates. Choose the intended match; ask the '
        'user when ambiguous. Never invent coordinates. Search is biased near the map.',
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
      'required': ['query'],
    },
    callback: (arguments, {CancellationToken? cancellationToken}) async {
      final model = workspace.requireViewModel;
      final routing = model.routing;
      if (routing == null) return _unavailable;
      try {
        final bounds = model.visibleExtent ?? model.countyExtent;
        final stops = await routing.geocoder.search(
          '${arguments['query'] ?? ''}',
          near: LatLng(
            (bounds.north + bounds.south) / 2,
            (bounds.east + bounds.west) / 2,
          ),
        );
        return {
          'source': 'Photon / OpenStreetMap contributors',
          'places': [for (final stop in stops) _stopJson(stop)],
        };
      } catch (e) {
        return {
          'status': 'error',
          'message': e is RoutingException
              ? e.message
              : 'Place search unavailable.',
        };
      }
    },
  ),
  AIFunctionFactory.create(
    name: 'plan_route',
    description:
        'Builds and displays a driving route and turn directions through 2–8 '
        'ordered stops. Resolves actual roads with Valhalla. Camera preferences use '
        'estimated reader-facing footprints and conservative unknown-direction buffers. '
        'Flock is a subset of ALPRs; use all unless the user explicitly wants Flock only. '
        'Checks full route corridors, including detours, independently of visible layers. '
        'Never promises camera-free travel. Does not provide live navigation or traffic.',
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'stops': {
          'type': 'array',
          'minItems': 2,
          'maxItems': 8,
          'items': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string'},
              'latitude': {'type': 'number'},
              'longitude': {'type': 'number'},
            },
            'required': ['label', 'latitude', 'longitude'],
          },
        },
        'preference': {
          'type': 'string',
          'enum': ['fastest', 'lowerExposure', 'avoidMappedCoverage'],
        },
        'cameraFilter': {
          'type': 'string',
          'enum': ['all', 'flock'],
        },
        'maxDetourMinutes': {'type': 'number', 'minimum': 0, 'maximum': 180},
      },
      'required': ['stops'],
    },
    callback: (arguments, {CancellationToken? cancellationToken}) async {
      final map = workspace.requireViewModel;
      final routing = map.routing;
      if (routing == null) return _unavailable;
      try {
        final raw = arguments['stops'];
        if (raw is! List || raw.length < 2 || raw.length > 8) {
          throw const RoutingException('Supply 2–8 ordered stops.');
        }
        final stops = <RouteStop>[];
        for (final item in raw) {
          if (item is! Map ||
              item['label'] is! String ||
              (item['label'] as String).trim().isEmpty) {
            throw const RoutingException(
              'Every stop needs a label and valid coordinates.',
            );
          }
          final lat = _number(item['latitude']),
              lon = _number(item['longitude']);
          if (lat == null ||
              lon == null ||
              !lat.isFinite ||
              !lon.isFinite ||
              lat.abs() > 85 ||
              lon.abs() > 180) {
            throw const RoutingException(
              'Every stop needs valid latitude and longitude.',
            );
          }
          stops.add(RouteStop(item['label'] as String, LatLng(lat, lon)));
        }
        final preference = RoutePreference.values
            .where(
              (p) => p.name == (arguments['preference'] ?? 'lowerExposure'),
            )
            .firstOrNull;
        final filter = RouteCameraFilter.values
            .where((p) => p.name == (arguments['cameraFilter'] ?? 'all'))
            .firstOrNull;
        final detour = arguments.containsKey('maxDetourMinutes')
            ? _number(arguments['maxDetourMinutes'])
            : 15.0;
        if (preference == null ||
            filter == null ||
            detour == null ||
            !detour.isFinite ||
            detour < 0 ||
            detour > 180) {
          throw const RoutingException(
            'Invalid route preference, camera filter, or detour limit.',
          );
        }
        map.setAreaSelectMode(false);
        final result = await routing.calculate(
          stops: stops,
          settings: RouteOptions(
            preference: preference,
            cameraFilter: filter,
            maxDetourMinutes: detour,
          ),
        );
        if (!identical(workspace.viewModel, map)) {
          return {
            'status': 'superseded',
            'message': 'The county workspace changed.',
          };
        }
        if (result == null) {
          return {
            'status': 'unavailable',
            'message':
                routing.error ?? 'The request was cancelled or replaced.',
          };
        }
        return routeState(routing);
      } on RoutingException catch (e) {
        return {'status': 'invalid', 'message': e.message};
      }
    },
  ),
  AIFunctionFactory.create(
    name: 'get_route',
    description:
        'Reads the current route, alternatives, coverage limitations and directions. '
        'Use directionsOffset to page through all turn instructions.',
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'directionsOffset': {'type': 'integer', 'minimum': 0},
      },
    },
    callback: (arguments, {CancellationToken? cancellationToken}) async {
      final model = workspace.requireViewModel.routing;
      if (model == null) return _unavailable;
      final offset = arguments['directionsOffset'] ?? 0;
      if (offset is! int || offset < 0) {
        return {
          'status': 'invalid',
          'message': 'Use a nonnegative directionsOffset.',
        };
      }
      return routeState(model, offset: offset);
    },
  ),
  AIFunctionFactory.create(
    name: 'select_route',
    description:
        'Selects and displays an existing route alternative by its zero-based index.',
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'index': {'type': 'integer', 'minimum': 0},
      },
      'required': ['index'],
    },
    callback: (arguments, {CancellationToken? cancellationToken}) async {
      final model = workspace.requireViewModel.routing;
      if (model == null) return _unavailable;
      final index = arguments['index'];
      if (index is! int ||
          index < 0 ||
          index >= (model.plan?.routes.length ?? 0)) {
        return {
          'status': 'invalid',
          'message': 'Use an index returned by get_route.',
        };
      }
      model.select(index);
      return routeState(model);
    },
  ),
  AIFunctionFactory.create(
    name: 'clear_route',
    description:
        'Clears route stops, directions, overlays and pending route calculations.',
    callback: (arguments, {CancellationToken? cancellationToken}) async {
      workspace.requireViewModel.routing?.clear();
      return {'status': 'cleared'};
    },
  ),
];

const _unavailable = {
  'status': 'unavailable',
  'message': 'Routing is not configured in this workspace.',
};
double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
Map<String, Object?> _stopJson(RouteStop stop) => {
  'label': stop.label,
  'latitude': stop.position.latitude,
  'longitude': stop.position.longitude,
};

Map<String, Object?> routeState(RouteViewModel model, {int offset = 0}) {
  final plan = model.plan;
  if (plan == null) {
    return {'status': model.busy ? 'loading' : 'empty', 'message': model.error};
  }
  final selected = model.selected!;
  final steps = selected.path.maneuvers;
  final selectedSatisfies =
      model.options.preference == RoutePreference.fastest ||
      (plan.cameraQueryComplete &&
          (model.options.preference != RoutePreference.avoidMappedCoverage ||
              selected.hits.isEmpty));
  return {
    'status': model.editing
        ? 'editing'
        : selectedSatisfies
        ? 'ready'
        : 'constraints_not_met',
    'cameraCheckPending': model.editing,
    'editMessage': model.editMessage,
    'shapingPoints': [
      for (final point in model.shapingPoints)
        {
          'id': point.id,
          'legIndex': point.legIndex,
          'street': point.snap.label,
          'latitude': point.snap.position.latitude,
          'longitude': point.snap.position.longitude,
        },
    ],
    'detourBaseline': model.shapingPoints.isEmpty
        ? 'fastest'
        : 'fastest_through_chosen_streets',
    'source': 'Valhalla / © OpenStreetMap contributors (ODbL)',
    'stops': [
      for (final stop in model.stops.whereType<RouteStop>()) _stopJson(stop),
    ],
    'selectedIndex': model.selectedIndex,
    'cameraFilter': model.options.cameraFilter.name,
    'preference': model.options.preference.name,
    'maxDetourMinutes': model.options.maxDetourMinutes,
    'cameraQueryComplete': plan.cameraQueryComplete,
    'cameraCheckedAt': plan.cameraCheckedAt.toIso8601String(),
    'notices': plan.notices,
    'routes': [
      for (var i = 0; i < plan.routes.length; i++)
        {
          'index': i,
          'meters': plan.routes[i].path.meters,
          'seconds': plan.routes[i].path.seconds,
          'extraSeconds': plan.routes[i].path.seconds - plan.baselineSeconds,
          'estimatedCameraAreas': plan.cameraQueryComplete
              ? plan.routes[i].directionalCount
              : null,
          'unknownDirectionReaders': plan.cameraQueryComplete
              ? plan.routes[i].unknownCount
              : null,
        },
    ],
    'directions': [
      for (final step in steps.skip(offset).take(60))
        {
          'instruction': step.instruction,
          'meters': step.meters,
          'latitude': step.point.latitude,
          'longitude': step.point.longitude,
        },
    ],
    if (offset + 60 < steps.length) 'nextDirectionsOffset': offset + 60,
    'totalDirections': steps.length,
  };
}
