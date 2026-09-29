import 'package:flutter/material.dart';
import 'workspace_layout.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// One selectable county in the workspace county picker.
@immutable
final class CountyOption {
  /// Creates a picker entry for a configured county.
  const CountyOption({
    required this.id,
    required this.label,
    required this.stateName,
    required this.extent,
  });

  /// Stable county identifier, such as `ca_riverside`.
  final String id;

  /// The county's published name, such as `Riverside County`.
  final String label;

  /// The state the county is in, such as `California`.
  ///
  /// Carried because a county name does not identify a county nationally.
  /// Thirty-one states have a Washington County, and a picker that showed
  /// them as thirty-one identical rows would be unusable.
  final String stateName;

  /// The rectangle enclosing the county.
  final GeoBounds extent;

  /// What a typed filter is matched against.
  ///
  /// The state is included so that typing a state name narrows to it, and so
  /// that `riverside ca` finds the right one of the four Riverside counties.
  String get searchKey => '$label $stateName'.toLowerCase();
}

/// The counties a workspace can switch between, and the active one.
///
/// The workspace is rebuilt for the chosen county, so [onSelected] replaces
/// the view model rather than mutating it.
@immutable
final class CountySelection {
  /// Creates a county selection.
  const CountySelection({
    required this.options,
    required this.activeId,
    required this.onSelected,
  });

  /// Every configured county, in picker order.
  final List<CountyOption> options;

  /// Identifier of the county currently being read.
  final String activeId;

  /// Called with the county the user picked.
  final ValueChanged<CountyOption> onSelected;

  /// The active county, falling back to the first configured one.
  CountyOption get active {
    for (final option in options) {
      if (option.id == activeId) {
        return option;
      }
    }
    return options.first;
  }

  /// The county [point] most likely falls in, or `null` when none does.
  ///
  /// County extents are rectangles, so a point near a ragged border can sit
  /// inside several; the smallest is the better guess. This drives an offer to
  /// switch, not an authoritative answer about which county a point is in.
  CountyOption? countyAt(LatLng point) {
    CountyOption? best;
    var bestArea = double.infinity;
    for (final option in options) {
      if (!option.extent.contains(point)) {
        continue;
      }
      final area =
          (option.extent.east - option.extent.west) *
          (option.extent.north - option.extent.south);
      if (area < bestArea) {
        bestArea = area;
        best = option;
      }
    }
    return best;
  }
}

/// A button that switches which county the workspace reads.
///
/// There are 3,235 counties and county equivalents, which is far beyond a
/// menu, so the button opens a searchable list grouped by state. Switching
/// replaces every county-scoped repository, so the button is disabled while a
/// snapshot download holds the current county's store.
class CountyMenuButton extends StatelessWidget {
  /// Creates a county picker button.
  const CountyMenuButton({
    required this.selection,
    this.enabled = true,
    this.disabledTooltip,
    super.key,
  });

  /// Counties available to the workspace.
  final CountySelection selection;

  /// Whether the county may be changed right now.
  final bool enabled;

  /// Explains why the picker is disabled, when it is.
  final String? disabledTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = TextButton.icon(
      key: const Key('county-picker-button'),
      onPressed: enabled ? () => _open(context) : null,
      icon: const Icon(Icons.expand_more, size: 18),
      iconAlignment: IconAlignment.end,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        textStyle: theme.textTheme.bodySmall,
      ),
      label: Text(
        selection.active.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (enabled || disabledTooltip == null) {
      return button;
    }
    return Tooltip(message: disabledTooltip!, child: button);
  }

  Future<void> _open(BuildContext context) async {
    final chosen = WorkspaceLayout.compactOf(context)
        ? await Navigator.of(context).push<CountyOption>(
            MaterialPageRoute(
              builder: (context) =>
                  _CountyPickerDialog(selection: selection, compact: true),
            ),
          )
        : await showDialog<CountyOption>(
            context: context,
            builder: (context) => _CountyPickerDialog(selection: selection),
          );
    if (chosen != null) {
      selection.onSelected(chosen);
    }
  }
}

/// An inline offer to follow the map into the county it has been panned over.
///
/// Parcels are drawn from a statewide layer, so the map keeps showing data
/// after it crosses a county line. What stops matching is everything scoped to
/// the county — its outline, address search, and offline snapshot — so the
/// offer to move with the map is worth making, and worth leaving refusable.
class CountySwitchChip extends StatelessWidget {
  /// Creates a chip offering to switch to [county].
  const CountySwitchChip({
    required this.county,
    required this.onPressed,
    super.key,
  });

  /// The county the map is currently over.
  final CountyOption county;

  /// Called when the user accepts the switch.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: const Key('county-switch-chip'),
      avatar: const Icon(Icons.my_location, size: 18),
      label: Text('Switch to ${county.label}'),
      onPressed: onPressed,
    );
  }
}

class _CountyPickerDialog extends StatefulWidget {
  const _CountyPickerDialog({required this.selection, this.compact = false});
  final bool compact;

  final CountySelection selection;

  @override
  State<_CountyPickerDialog> createState() => _CountyPickerDialogState();
}

class _CountyPickerDialogState extends State<_CountyPickerDialog> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _filter.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.selection.options
        : widget.selection.options
              .where((option) => option.searchKey.contains(query))
              .toList(growable: false);
    final rows = _groupByState(matches);
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            key: const Key('county-filter-field'),
            controller: _filter,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Filter ${widget.selection.options.length} counties',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    'No county matches “${_filter.text.trim()}”.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row.header != null) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                        child: Text(
                          row.header!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    final option = row.option!;
                    final active = option.id == widget.selection.activeId;
                    return ListTile(
                      leading: Icon(
                        active ? Icons.check : Icons.location_on_outlined,
                        color: active ? theme.colorScheme.primary : null,
                      ),
                      title: Text(option.label),
                      selected: active,
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
        ),
      ],
    );
    if (widget.compact) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a county')),
        body: SafeArea(child: content),
      );
    }
    return AlertDialog(
      title: const Text('Choose a county'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(width: 380, height: 460, child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// One line of the picker list: either a state heading or a county.
///
/// The list is a single [ListView.builder] over these rather than a nested
/// structure, because 3,235 counties across 56 states must stay lazily built.
@immutable
final class _PickerRow {
  const _PickerRow.header(String this.header) : option = null;

  const _PickerRow.county(CountyOption this.option) : header = null;

  final String? header;
  final CountyOption? option;
}

/// [options] flattened into rows, with a heading wherever the state changes.
///
/// The options are already in state-then-name order, so this only has to
/// notice the boundaries rather than sort anything.
List<_PickerRow> _groupByState(List<CountyOption> options) {
  final rows = <_PickerRow>[];
  String? state;
  for (final option in options) {
    if (option.stateName != state) {
      state = option.stateName;
      rows.add(_PickerRow.header(state));
    }
    rows.add(_PickerRow.county(option));
  }
  return rows;
}
