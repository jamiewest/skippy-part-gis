import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';

/// The smallest drag, in logical pixels, that counts as a drawn area.
///
/// A click that moves a pixel or two is a click, and answering it with an
/// empty list would read as "there are no addresses here".
const _minimumDragExtent = 8.0;

/// The narrowest bar that still has room for the instruction text.
///
/// Below this the bar keeps the shape switcher and the way out and drops the
/// sentence, which is the part a user who has already armed the tool needs
/// least.
const _hintWidthFloor = 420.0;

/// The narrowest bar whose shape switcher can name its shapes as well as show
/// their icons beside the instruction.
const _labelWidthFloor = 520.0;

/// Which shape the area tool draws.
enum AreaTool {
  /// A rectangle, dragged corner to corner.
  rectangle,

  /// A circle, dragged from its centre out to its edge.
  ///
  /// A radius is what a question about surroundings means -- "within half a
  /// mile of this corner" is a circle, and the enclosing square reaches a
  /// further forty per cent into the corners.
  circle;

  /// The label shown on the tool's own toggle.
  String get label => switch (this) {
    AreaTool.rectangle => 'Rectangle',
    AreaTool.circle => 'Circle',
  };

  /// The icon standing in for [label] where there is no room for words.
  IconData get icon => switch (this) {
    AreaTool.rectangle => Icons.crop_square,
    AreaTool.circle => Icons.circle_outlined,
  };
}

/// Draws a rectangle over the map and reports the area it covers.
///
/// The overlay sits above the map and swallows pointer events, so a drag
/// draws instead of panning and a tap does not select the parcel underneath.
class AreaSelectOverlay extends StatefulWidget {
  /// Creates the drawing surface over the map driven by [mapController].
  const AreaSelectOverlay({
    required this.mapController,
    required this.onDrawn,
    required this.onCancel,
    this.tool = AreaTool.rectangle,
    this.onToolChanged,
    super.key,
  });

  /// The controller whose camera converts screen points to coordinates.
  final MapController mapController;

  /// The shape a drag draws.
  final AreaTool tool;

  /// Called when the user switches shape, or null to hide the switcher.
  final ValueChanged<AreaTool>? onToolChanged;

  /// Called with the drawn area once the drag ends.
  final ValueChanged<AreaShape> onDrawn;

  /// Disarms the tool without drawing anything.
  ///
  /// The overlay carries its own way out because the keyboard one does not
  /// exist on a touch device, and the overlay covers the map underneath: with
  /// no button here, an armed tool on a phone has nowhere to go.
  final VoidCallback onCancel;

  @override
  State<AreaSelectOverlay> createState() => _AreaSelectOverlayState();
}

class _AreaSelectOverlayState extends State<AreaSelectOverlay> {
  Offset? _start;
  Offset? _current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rectangle = _rectangle;
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Keep the centre at the press, even before the drag clears touch slop.
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (details) => setState(() {
          _start = details.localPosition;
          _current = details.localPosition;
        }),
        onPanUpdate: (details) =>
            setState(() => _current = details.localPosition),
        onPanEnd: (_) => _finish(),
        onPanCancel: () => setState(() {
          _start = null;
          _current = null;
        }),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.scrim.withValues(alpha: 0.06),
              ),
            ),
            if (rectangle != null)
              Positioned.fromRect(
                rect: rectangle,
                child: DecoratedBox(
                  key: const Key('area-drawing-preview'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    shape: widget.tool == AreaTool.circle
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                  ),
                ),
              ),
            if (widget.tool == AreaTool.circle && _start != null)
              Positioned(
                left: _start!.dx - 5,
                top: _start!.dy - 5,
                child: IgnorePointer(
                  child: Container(
                    key: const Key('area-drawing-center'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Center(
                child: Material(
                  elevation: 3,
                  color: theme.colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // On a phone the shape switcher and the way out are
                          // what the bar is for; the instruction is the part
                          // that can be dropped, because the tool is already
                          // armed and the gesture is a drag either way.
                          if (constraints.maxWidth >= _hintWidthFloor)
                            Flexible(
                              child: Text(
                                _hint(theme),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onInverseSurface,
                                ),
                              ),
                            ),
                          if (widget.onToolChanged case final onChanged?) ...[
                            if (constraints.maxWidth >= _hintWidthFloor)
                              const SizedBox(width: 12),
                            // The switcher lives here rather than in the
                            // toolbar because this is the only surface visible
                            // while the tool is armed: the overlay covers the
                            // map, so a control behind it cannot be reached.
                            SegmentedButton<AreaTool>(
                              key: const Key('area-tool-switcher'),
                              style: SegmentedButton.styleFrom(
                                foregroundColor:
                                    theme.colorScheme.onInverseSurface,
                                selectedForegroundColor:
                                    theme.colorScheme.inverseSurface,
                                selectedBackgroundColor:
                                    theme.colorScheme.onInverseSurface,
                                visualDensity: VisualDensity.compact,
                                textStyle: theme.textTheme.labelMedium,
                              ),
                              showSelectedIcon: false,
                              segments: [
                                for (final tool in AreaTool.values)
                                  ButtonSegment(
                                    value: tool,
                                    icon: Icon(tool.icon, size: 18),
                                    label:
                                        constraints.maxWidth >= _labelWidthFloor
                                        ? Text(tool.label)
                                        : null,
                                    tooltip: tool.label,
                                  ),
                              ],
                              selected: {widget.tool},
                              onSelectionChanged: (selection) =>
                                  onChanged(selection.first),
                            ),
                          ],
                          const SizedBox(width: 8),
                          TextButton(
                            key: const Key('cancel-area-select-button'),
                            onPressed: widget.onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.inversePrimary,
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The instruction, named for the pointer the platform actually has.
  String _hint(ThemeData theme) {
    final what = switch (widget.tool) {
      AreaTool.rectangle => 'across the map to draw a rectangle',
      AreaTool.circle => 'out from the centre to draw a circle',
    };
    return switch (theme.platform) {
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.fuchsia => 'Drag $what',
      _ => 'Drag $what  •  Esc to cancel',
    };
  }

  /// The preview rectangle, which for a circle is the square it inscribes.
  Rect? get _rectangle {
    final start = _start;
    final current = _current;
    if (start == null || current == null) {
      return null;
    }
    if (widget.tool == AreaTool.rectangle) {
      return Rect.fromPoints(start, current);
    }
    return Rect.fromCircle(center: start, radius: (current - start).distance);
  }

  void _finish() {
    final start = _start;
    final current = _current;
    setState(() {
      _start = null;
      _current = null;
    });
    if (start == null || current == null) {
      return;
    }
    final camera = widget.mapController.camera;
    if (widget.tool == AreaTool.circle) {
      if ((current - start).distance < _minimumDragExtent) {
        return;
      }
      // The radius is measured on the ground rather than converted from
      // pixels, so it stays the distance the user dragged to whatever the
      // projection does to the map at this latitude.
      final centre = camera.screenOffsetToLatLng(start);
      final edge = camera.screenOffsetToLatLng(current);
      widget.onDrawn(
        CircleArea(
          center: centre,
          radiusMeters: const Distance().as(LengthUnit.Meter, centre, edge),
        ),
      );
      return;
    }
    final drawn = Rect.fromPoints(start, current);
    if (drawn.width < _minimumDragExtent || drawn.height < _minimumDragExtent) {
      return;
    }
    widget.onDrawn(
      RectangleArea(
        boundsFromCorners(
          camera.screenOffsetToLatLng(drawn.topLeft),
          camera.screenOffsetToLatLng(drawn.bottomRight),
        ),
      ),
    );
  }
}
