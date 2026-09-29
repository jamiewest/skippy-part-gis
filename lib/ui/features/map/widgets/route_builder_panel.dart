import 'package:riverside_atlas/ui/features/map/widgets/route_map_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/route_plan.dart';
import 'package:riverside_atlas/ui/features/map/view_models/route_view_model.dart';

/// Responsive map overlay. Picking a point temporarily collapses the panel.
class RouteBuilderOverlay extends StatelessWidget {
  const RouteBuilderOverlay({
    super.key,
    required this.model,
    required this.near,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
  });
  final RouteViewModel model;
  final LatLng Function() near;
  final VoidCallback onOpen;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final panelRect = routePanelRect(constraints.biggest, padding);
        return Stack(
          children: [
            if (!model.panelOpen)
              Positioned(
                right: padding.right + 18,
                bottom: padding.bottom + 68,
                child: FloatingActionButton.small(
                  heroTag: null,
                  key: const Key('open-route-builder'),
                  tooltip: 'Build a route',
                  onPressed: () {
                    onOpen();
                    model.showPanel(!model.panelOpen);
                  },
                  child: const Icon(Icons.route),
                ),
              ),
            if (model.editMessage != null ||
                (!model.panelOpen && model.error != null))
              Positioned(
                left: padding.left + 12,
                right: padding.right + 76,
                top: padding.top + 12,
                child: IgnorePointer(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(model.editMessage ?? model.error!),
                    ),
                  ),
                ),
              ),
            if (model.pickingStop != null)
              Positioned(
                top: padding.top + 12,
                left: 12,
                right: 76,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tap the map for stop ${model.pickingStop! + 1}',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel picking',
                          onPressed: () => model.showPanel(true),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (model.panelOpen)
              Positioned.fromRect(
                rect: panelRect,
                child: RouteBuilderPanel(model: model, near: near),
              ),
          ],
        );
      },
    ),
  );
}

class RouteBuilderPanel extends StatelessWidget {
  const RouteBuilderPanel({super.key, required this.model, required this.near});
  final RouteViewModel model;
  final LatLng Function() near;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('route-builder-panel'),
    elevation: 8,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              const Icon(Icons.route),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Route builder',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Clear route',
                onPressed: model.clear,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: 'Close route builder',
                onPressed: () => model.showPanel(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < model.stops.length; i++)
                  _StopRow(
                    key: ValueKey('stop-$i-${model.stops[i]?.label}'),
                    model: model,
                    index: i,
                    near: near,
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: model.stops.length < 8 ? model.addStop : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add stop'),
                    ),
                    TextButton.icon(
                      onPressed: model.reverseStops,
                      icon: const Icon(Icons.swap_vert),
                      label: const Text('Reverse'),
                    ),
                  ],
                ),
                DropdownButtonFormField<RoutePreference>(
                  key: ValueKey(model.options.preference),
                  initialValue: model.options.preference,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Route preference',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RoutePreference.fastest,
                      child: Text('Fastest'),
                    ),
                    DropdownMenuItem(
                      value: RoutePreference.lowerExposure,
                      child: Text('Lower camera exposure'),
                    ),
                    DropdownMenuItem(
                      value: RoutePreference.avoidMappedCoverage,
                      child: Text('Avoid mapped coverage'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      model.setOptions(
                        RouteOptions(
                          preference: v,
                          cameraFilter: model.options.cameraFilter,
                          maxDetourMinutes: model.options.maxDetourMinutes,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RouteCameraFilter>(
                  key: ValueKey(model.options.cameraFilter),
                  initialValue: model.options.cameraFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Readers'),
                  items: const [
                    DropdownMenuItem(
                      value: RouteCameraFilter.all,
                      child: Text('All ALPRs, including Flock'),
                    ),
                    DropdownMenuItem(
                      value: RouteCameraFilter.flock,
                      child: Text('Known Flock readers only'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      model.setOptions(
                        RouteOptions(
                          preference: model.options.preference,
                          cameraFilter: v,
                          maxDetourMinutes: model.options.maxDetourMinutes,
                        ),
                      );
                    }
                  },
                ),
                if (model.options.preference != RoutePreference.fastest) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Maximum detour: ${model.options.maxDetourMinutes.round()} minutes',
                  ),
                  Slider(
                    value: model.options.maxDetourMinutes.clamp(0, 180),
                    min: 0,
                    max: 180,
                    divisions: 36,
                    label: '${model.options.maxDetourMinutes.round()} min',
                    onChanged: (v) => model.setOptions(
                      RouteOptions(
                        preference: model.options.preference,
                        cameraFilter: model.options.cameraFilter,
                        maxDetourMinutes: v,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('calculate-route'),
                  onPressed: model.busy
                      ? model.cancel
                      : model.ready
                      ? () => model.calculate()
                      : null,
                  icon: Icon(model.busy ? Icons.stop : Icons.directions),
                  label: Text(model.busy ? 'Cancel routing' : 'Build route'),
                ),
                if (model.busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  ),
                if (model.error case final error?)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (model.shapingPoints.isNotEmpty || model.canUndo) ...[
                  const Text(
                    'Chosen streets',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final point in model.shapingPoints)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(point.snap.label),
                      subtitle: Text(
                        'Between stops ${point.legIndex + 1} and ${point.legIndex + 2}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove chosen street',
                        icon: const Icon(Icons.close),
                        onPressed: model.busy || model.dragging
                            ? null
                            : () => model.removeShapingPoint(point.id),
                      ),
                    ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: model.canUndo ? model.undoRouteEdit : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                      ),
                      TextButton(
                        onPressed:
                            model.busy ||
                                model.dragging ||
                                model.shapingPoints.isEmpty
                            ? null
                            : model.resetRouteEdits,
                        child: const Text('Reset route edits'),
                      ),
                    ],
                  ),
                ],
                if (model.plan case final plan?) ...[
                  if (!model.selectedConstraintsSatisfied ||
                      !plan.cameraQueryComplete)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Requested camera avoidance has not been established.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  for (var i = 0; i < plan.routes.length; i++)
                    Card(
                      color: i == model.selectedIndex
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        dense: true,
                        selected: i == model.selectedIndex,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        title: Text(
                          'Route ${i + 1} · ${_duration(plan.routes[i].path.seconds)} · ${_distance(plan.routes[i].path.meters)}',
                        ),
                        subtitle: Text(
                          plan.cameraQueryComplete
                              ? '${plan.routes[i].directionalCount} estimated camera areas · ${plan.routes[i].unknownCount} unknown directions\n'
                                    '+${((plan.routes[i].path.seconds - plan.baselineSeconds) / 60).clamp(0, double.infinity).toStringAsFixed(0)} min vs fastest${model.shapingPoints.isEmpty ? '' : ' through your chosen streets'}'
                              : 'Camera coverage unverified',
                        ),
                        onTap: model.busy || model.dragging
                            ? null
                            : () => model.select(i),
                      ),
                    ),
                  Wrap(
                    children: [
                      TextButton.icon(
                        onPressed: model.fit,
                        icon: const Icon(Icons.zoom_out_map),
                        label: const Text('Fit route'),
                      ),
                      TextButton.icon(
                        onPressed: model.editing ? null : () => _copy(context),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy directions'),
                      ),
                    ],
                  ),
                  const Text(
                    'Drag the selected route onto another street.\nBlue: selected · Gray: alternatives\nRed: estimated exposure · Orange: unknown direction\nPurple dotted: preview, cameras unchecked',
                  ),
                  ExpansionTile(
                    title: const Text('Coverage and method'),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      for (final notice in plan.notices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(notice),
                        ),
                      Text('Checked ${plan.cameraCheckedAt.toLocal()}'),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'Directions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final maneuver
                      in model.selected?.path.maneuvers ?? <RouteManeuver>[])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.turn_right),
                      title: Text(maneuver.instruction),
                      subtitle: Text(_distance(maneuver.meters)),
                      onTap: () => model.focusManeuver(maneuver.point),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Routes: Valhalla · Places: Photon\n© OpenStreetMap contributors (ODbL)\n'
                  'Online route planning; estimated coverage, not a guarantee. '
                  'Locations are sent to the configured routing and search services.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _copy(BuildContext context) async {
    final route = model.selected;
    if (route == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: [
          model.stops.whereType<RouteStop>().map((s) => s.label).join(' → '),
          '${_duration(route.path.seconds)} · ${_distance(route.path.meters)}',
          for (final step in route.path.maneuvers)
            '${step.instruction} (${_distance(step.meters)})',
          ...model.plan!.notices,
          'Routing: Valhalla / © OpenStreetMap contributors',
        ].join('\n'),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Directions copied')));
    }
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.model,
    required this.index,
    required this.near,
  });
  final RouteViewModel model;
  final int index;
  final LatLng Function() near;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('${index + 1}.'),
      const SizedBox(width: 4),
      Expanded(
        child: OutlinedButton(
          onPressed: () async {
            final stop = await showDialog<RouteStop>(
              context: context,
              builder: (_) => _PlaceSearchDialog(model: model, near: near()),
            );
            if (stop != null && context.mounted) model.setStop(index, stop);
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              model.stops[index]?.label ??
                  (index == 0
                      ? 'Choose start'
                      : index == model.stops.length - 1
                      ? 'Choose destination'
                      : 'Choose stop'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Pick stop ${index + 1} on map',
        onPressed: () => model.pickStop(index),
        icon: const Icon(Icons.pin_drop_outlined),
      ),
      if (model.stops.length > 2)
        PopupMenuButton<String>(
          tooltip: 'Edit stop ${index + 1}',
          itemBuilder: (_) => [
            if (index > 0)
              const PopupMenuItem(value: 'up', child: Text('Move earlier')),
            if (index < model.stops.length - 1)
              const PopupMenuItem(value: 'down', child: Text('Move later')),
            const PopupMenuItem(value: 'remove', child: Text('Remove stop')),
          ],
          onSelected: (action) {
            if (action == 'remove') {
              model.removeStop(index);
            } else {
              model.moveStop(index, index + (action == 'up' ? -1 : 1));
            }
          },
        ),
    ],
  );
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog({required this.model, required this.near});
  final RouteViewModel model;
  final LatLng near;
  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  final _text = TextEditingController();
  List<RouteStop> _results = [];
  bool _busy = false;
  String? _error;
  Future<void> _search() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await widget.model.geocoder.search(
        _text.text,
        near: widget.near,
      );
      if (mounted) {
        setState(() {
          _results = results;
          if (results.isEmpty) {
            _error = 'No matching places. Try a fuller address.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is RoutingException
              ? e.message
              : 'Place search is unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a route stop'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                labelText: 'Address, place, or lat, lon',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _search,
              child: const Text('Search'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            for (final stop in _results)
              ListTile(
                title: Text(stop.label),
                onTap: () => Navigator.pop(context, stop),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

String _duration(double seconds) => '${(seconds / 60).ceil()} min';
String _distance(double meters) =>
    '${(meters / 1609.344).toStringAsFixed(1)} mi';
