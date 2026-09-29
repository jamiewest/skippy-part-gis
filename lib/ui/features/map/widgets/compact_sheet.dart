import 'package:flutter/material.dart';

/// A single workspace sheet. Dragging the header resizes it; content keeps its
/// own scroll position and never competes with the map for a drag gesture.
class CompactSheet extends StatelessWidget {
  const CompactSheet({
    super.key,
    required this.title,
    required this.height,
    required this.maximumHeight,
    required this.onHeightChanged,
    required this.onClose,
    required this.child,
    this.onBack,
  });

  final String title;
  final double height;
  final double maximumHeight;
  final ValueChanged<double> onHeightChanged;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget child;

  double get minimumHeight =>
      (maximumHeight * .3).clamp(150, 220).clamp(0.0, maximumHeight).toDouble();

  void _snap() {
    final stops = [minimumHeight, maximumHeight * .55, maximumHeight]..sort();
    stops.sort((a, b) => (a - height).abs().compareTo((b - height).abs()));
    onHeightChanged(stops.first);
  }

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('compact-workspace-sheet'),
    elevation: 8,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: height,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) => onHeightChanged(
              (height - details.delta.dy).clamp(minimumHeight, maximumHeight),
            ),
            onVerticalDragEnd: (_) => _snap(),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Row(
                  children: [
                    if (onBack != null)
                      BackButton(onPressed: onBack)
                    else
                      const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: height >= maximumHeight - 1
                          ? 'Collapse sheet'
                          : 'Expand sheet',
                      onPressed: () => onHeightChanged(
                        height >= maximumHeight - 1
                            ? minimumHeight
                            : maximumHeight,
                      ),
                      icon: Icon(
                        height >= maximumHeight - 1
                            ? Icons.expand_more
                            : Icons.expand_less,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close sheet',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
