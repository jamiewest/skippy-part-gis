import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// One selectable county in the workspace county picker.
@immutable
final class CountyOption {
  /// Creates a picker entry for a configured county.
  const CountyOption({
    required this.id,
    required this.label,
    required this.extent,
  });

  /// Stable county identifier.
  final String id;

  /// Human-readable county name.
  final String label;

  /// The rectangle enclosing the county.
  final GeoBounds extent;

  /// The label with the trailing `County` removed, for matching what is typed.
  String get searchKey => label.toLowerCase();
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
/// California has 58 counties, which is far too many for a flat menu, so the
/// button opens a searchable list instead of a drop-down. Switching replaces
/// every county-scoped repository, so the button is disabled while a snapshot
/// download holds the current county's store.
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
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        textStyle: theme.textTheme.bodySmall,
      ),
      label: Text(selection.active.label),
    );
    if (enabled || disabledTooltip == null) {
      return button;
    }
    return Tooltip(message: disabledTooltip!, child: button);
  }

  Future<void> _open(BuildContext context) async {
    final chosen = await showDialog<CountyOption>(
      context: context,
      builder: (context) => _CountyPickerDialog(selection: selection),
    );
    if (chosen != null && chosen.id != selection.activeId) {
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
  const _CountyPickerDialog({required this.selection});

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
    return AlertDialog(
      title: const Text('Choose a county'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 380,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                key: const Key('county-filter-field'),
                controller: _filter,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filter 58 counties',
                  border: OutlineInputBorder(),
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
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final option = matches[index];
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
