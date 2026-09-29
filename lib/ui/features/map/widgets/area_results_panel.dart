import 'package:flutter/material.dart';
import 'package:riverside_atlas/data/services/content_sharing.dart';
import 'package:flutter/services.dart';
import 'package:riverside_atlas/data/services/csv_export.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/ui/features/map/address_list_csv.dart';
import 'package:riverside_atlas/ui/features/map/property_clipboard_text.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// The one-line summary of [selection], for a panel header or a map pill.
String areaSelectionHeadline(AreaSelection selection) {
  return switch (selection.status) {
    AreaSelectionStatus.loading => 'Reading the drawn area…',
    AreaSelectionStatus.failed => 'Addresses unavailable',
    AreaSelectionStatus.ready when selection.count == 1 =>
      '1 address in the drawn area',
    AreaSelectionStatus.ready =>
      '${selection.count} addresses in the drawn '
          'area',
  };
}

/// The addresses inside the rectangle drawn on the map.
///
/// The same panel is shown in the desktop side pane and in the compact sheet,
/// so it sizes itself to whatever bounded height its parent gives it.
class AreaResultsPanel extends StatelessWidget {
  /// Creates the panel for the selection held by [viewModel].
  const AreaResultsPanel({
    required this.viewModel,
    required this.selection,
    required this.onAddressSelected,
    super.key,
  });

  /// The workspace holding the drawn selection.
  final GisMapViewModel viewModel;

  /// The rectangle being reported.
  final AreaSelection selection;

  /// Called when a row is tapped, so the map can move to the address.
  final ValueChanged<Address> onAddressSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          areaSelectionHeadline(selection),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        key: const Key('clear-area-selection-button'),
                        tooltip: 'Clear the drawn area',
                        onPressed: viewModel.clearAreaSelection,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (selection.status == AreaSelectionStatus.ready &&
                    selection.addresses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('copy-area-csv-button'),
                          onPressed: () => _copyCsv(context),
                          icon: const Icon(Icons.copy_all_outlined, size: 18),
                          label: const Text('Copy CSV'),
                        ),
                        Builder(
                          builder: (context) => OutlinedButton.icon(
                            key: const Key('share-area-csv-button'),
                            onPressed: () => _shareCsv(context),
                            icon: const Icon(Icons.ios_share, size: 18),
                            label: const Text('Share CSV'),
                          ),
                        ),
                        if (canSaveCsvExport)
                          OutlinedButton.icon(
                            key: const Key('save-area-csv-button'),
                            onPressed: () => _saveCsv(context),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('Save CSV'),
                          ),
                      ],
                    ),
                  ),
                if (selection.truncated)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _PanelNotice(
                      key: const Key('area-selection-truncated-notice'),
                      icon: Icons.filter_alt_outlined,
                      message:
                          'This is the first $areaSelectionLimit addresses the source '
                          'returned, not the whole rectangle. Draw a smaller area for '
                          'a complete list.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(flex: 2, child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    switch (selection.status) {
      case AreaSelectionStatus.loading:
        return const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        );
      case AreaSelectionStatus.failed:
        return _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Addresses unavailable',
          message: selection.message ?? 'The addresses could not be read.',
          action: TextButton.icon(
            key: const Key('retry-area-selection-button'),
            onPressed: viewModel.retryAreaSelection,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        );
      case AreaSelectionStatus.ready:
        if (selection.addresses.isEmpty) {
          return const _EmptyState(
            icon: Icons.location_off_outlined,
            title: 'No addresses here',
            message:
                'The county publishes no address points inside the rectangle. '
                'Draw a larger area, or check a different part of the map.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: selection.addresses.length,
          itemBuilder: (context, index) {
            final address = selection.addresses[index];
            return Material(
              type: MaterialType.transparency,
              child: ListTile(
                key: Key('area-address-${address.sourceId}'),
                dense: true,
                title: Text(address.fullAddress),
                subtitle: Text(
                  [
                    propertyLocationLine(
                      stateCode: viewModel.stateCode,
                      city: address.city,
                      zipCode: address.zipCode,
                    ),
                    if (address.apn.isNotEmpty) 'APN ${address.apn}',
                  ].where((part) => part.isNotEmpty).join('  •  '),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => onAddressSelected(address),
              ),
            );
          },
        );
    }
  }

  String _csv() => addressListCsv(
    addresses: selection.addresses,
    stateCode: viewModel.stateCode,
    countyName: viewModel.countyName,
  );

  Future<void> _copyCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _csv()));
    messenger.showSnackBar(
      SnackBar(
        content: Text('${selection.count} addresses copied as CSV'),
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );
  }

  Future<void> _shareCsv(BuildContext context) async {
    try {
      await SharingScope.of(context).shareCsv(
        _csv(),
        addressListFileName(
          countyName: viewModel.countyName,
          timestamp: DateTime.now(),
        ),
        sharingOrigin(context),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share. Save or copy the CSV instead.'),
          ),
        );
      }
    }
  }

  Future<void> _saveCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = addressListFileName(
      countyName: viewModel.countyName,
      timestamp: DateTime.now(),
    );
    // A sandbox path means nothing to someone holding a phone; the app's
    // folder in Files is where they will actually go looking for the file.
    final onIos = Theme.of(context).platform == TargetPlatform.iOS;
    try {
      final path = await saveCsvExport(fileName: fileName, contents: _csv());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            onIos ? 'Saved $fileName to Atlas in Files' : 'Saved to $path',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The file could not be written. Copy the CSV instead.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _PanelNotice extends StatelessWidget {
  const _PanelNotice({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
