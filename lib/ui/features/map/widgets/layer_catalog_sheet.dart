import 'package:flutter/material.dart';
import 'package:riverside_atlas/data/services/layer_themes.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// Browsable list of everything a county's public catalogues publish.
///
/// The counties publish tens of thousands of services and a raw list is
/// unusable — San Bernardino's own catalogue puts `HomelessContactForm` beside
/// its parcels. Entries are therefore filtered to what can be drawn, grouped
/// by theme, and searchable, because any ranking will bury something somebody
/// wants.
class LayerCatalogSheet extends StatefulWidget {
  /// Creates the catalogue browser for [viewModel].
  const LayerCatalogSheet({
    required this.viewModel,
    this.compact = false,
    super.key,
  });

  /// The workspace whose county catalogues are listed.
  final GisMapViewModel viewModel;

  /// Embedded in the phone's workspace sheet, which supplies its own title,
  /// close control and active-layer list.
  final bool compact;

  @override
  State<LayerCatalogSheet> createState() => _LayerCatalogSheetState();
}

class _LayerCatalogSheetState extends State<LayerCatalogSheet> {
  final TextEditingController _search = TextEditingController();
  GisPortal? _portal;

  @override
  void initState() {
    super.initState();
    _portal = widget.viewModel.portals.firstOrNull;
    // Reading a catalogue notifies the view model's listeners, and this runs
    // while the sheet is still mounting. The map screen's listeners are
    // already built and are not descendants of this sheet, so notifying now
    // is a build-during-build. Wait for the frame to finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Opening the panel is what asks whether anything else publishes here.
      // It is dozens of requests and the map does not need the answer, so it
      // waits until somebody actually looks at the list.
      widget.viewModel.discoverPortals();
      if (_portal case final portal?) {
        widget.viewModel.openPortal(portal);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final portals = widget.viewModel.portals;
        if (portals.isEmpty) {
          return _Empty(
            message:
                widget.viewModel.discoveryStatus ==
                    PortalDiscoveryStatus.searching
                ? 'Looking for catalogues published over '
                      '${widget.viewModel.countyName}\u2026'
                : 'No public map catalogue was found for '
                      '${widget.viewModel.countyName}.',
          );
        }
        final portal = _portal ?? portals.first;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 1,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _SheetHeader(
                      viewModel: widget.viewModel,
                      showTitle: !widget.compact,
                      search: _search,
                      onSearch: (_) => setState(() {}),
                    ),
                    _PortalChips(
                      portals: portals,
                      active: portal,
                      onSelected: (selected) {
                        setState(() => _portal = selected);
                        widget.viewModel.openPortal(selected);
                      },
                    ),
                    _DiscoveryNote(status: widget.viewModel.discoveryStatus),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: _PortalBody(
                viewModel: widget.viewModel,
                portal: portal,
                query: _search.text.trim().toLowerCase(),
              ),
            ),
            if (!widget.compact && widget.viewModel.activeOverlays.isNotEmpty)
              _ActiveOverlayBar(viewModel: widget.viewModel, theme: theme),
          ],
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.viewModel,
    required this.search,
    required this.onSearch,
    this.showTitle = true,
  });

  final GisMapViewModel viewModel;
  final bool showTitle;
  final TextEditingController search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'County map layers',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
          Text(
            // Named as tiers rather than as "the county and state agencies":
            // most counties have no state tier at all, and the publishers
            // found live include cities and regional bodies. Each chip is
            // labelled with its own publisher, which is where the specific
            // attribution belongs.
            viewModel.overlaysAvailable
                ? 'Published by local, state and federal agencies covering '
                      '${viewModel.countyName}. Read live; not part of an '
                      'offline snapshot.'
                : 'Unavailable offline. These layers are read live from their '
                      'publishers and are not stored in a snapshot.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: viewModel.overlaysAvailable
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            onChanged: onSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search layers',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalChips extends StatelessWidget {
  const _PortalChips({
    required this.portals,
    required this.active,
    required this.onSelected,
  });

  final List<GisPortal> portals;
  final GisPortal active;
  final ValueChanged<GisPortal> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: portals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final portal = portals[index];
          return Center(
            child: FilterChip(
              selected: portal == active,
              onSelected: (_) => onSelected(portal),
              avatar: Icon(_iconFor(portal.tier), size: 18),
              label: Text(portal.publisher),
              // A discovered publisher was matched to this county minutes
              // ago rather than read by somebody, so the tooltip says as
              // much: the layers are theirs, the placement is a guess.
              tooltip: portal.isDiscovered
                  ? '${portal.host}\nFound by searching for publishers here'
                  : portal.host,
            ),
          );
        },
      ),
    );
  }

  static IconData _iconFor(PortalTier tier) => switch (tier) {
    PortalTier.countyPortal => Icons.account_balance,
    PortalTier.city => Icons.location_city,
    PortalTier.partner => Icons.groups_outlined,
    PortalTier.statewide => Icons.map_outlined,
    PortalTier.national => Icons.public,
  };
}

class _PortalBody extends StatelessWidget {
  const _PortalBody({
    required this.viewModel,
    required this.portal,
    required this.query,
  });

  final GisMapViewModel viewModel;
  final GisPortal portal;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingPortal(portal)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.portalMessage(portal) case final message?) {
      return _Empty(message: message);
    }
    final services = viewModel
        .servicesIn(portal)
        .where((service) => _matches(service, query))
        .toList(growable: false);
    if (services.isEmpty) {
      return _Empty(
        message: query.isEmpty
            ? 'This catalogue publishes no map layers.'
            : 'No layer here matches “$query”.',
      );
    }

    final grouped = <String, List<CatalogService>>{};
    for (final service in services) {
      grouped.putIfAbsent(primaryThemeOf(service.name), () => []).add(service);
    }
    final order = [
      ...layerThemes.where(grouped.containsKey),
      if (grouped.containsKey('other')) 'other',
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: order.length,
      itemBuilder: (context, index) {
        final theme = order[index];
        final entries = grouped[theme]!;
        return ExpansionTile(
          initiallyExpanded: order.length <= 2 || query.isNotEmpty,
          title: Text(theme == 'other' ? 'Everything else' : theme),
          subtitle: Text('${entries.length} layers'),
          children: [
            for (final service in entries)
              CheckboxListTile(
                dense: true,
                value: viewModel.isOverlayActive(service),
                onChanged: viewModel.overlaysAvailable
                    ? (_) => viewModel.toggleOverlay(service)
                    : null,
                secondary: service.type == 'ImageServer'
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Parcel source options',
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'parcels',
                            child: Text('Use as parcel source'),
                          ),
                        ],
                        onSelected: (_) async {
                          final message = await viewModel.useAsParcelSource(
                            service,
                          );
                          if (!context.mounted) return;
                          // A root snackbar sits behind this modal sheet.
                          // Keep the result above the catalogue so rejection
                          // reasons remain readable without closing it.
                          await showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Parcel source'),
                              content: Text(message),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                title: Text(service.title),
                subtitle: Text(
                  service.folder.isEmpty
                      ? service.type
                      : '${service.folder} · ${service.type}',
                ),
              ),
          ],
        );
      },
    );
  }

  static bool _matches(CatalogService service, String query) {
    if (query.isEmpty) {
      return true;
    }
    return service.name.toLowerCase().contains(query) ||
        service.title.toLowerCase().contains(query);
  }
}

class _ActiveOverlayBar extends StatelessWidget {
  const _ActiveOverlayBar({required this.viewModel, required this.theme});

  final GisMapViewModel viewModel;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    viewModel.activeOverlays.length == 1
                        ? '1 layer on'
                        : '${viewModel.activeOverlays.length} layers on',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: viewModel.clearOverlays,
                  child: const Text('Turn all off'),
                ),
              ],
            ),
            for (final overlay in viewModel.activeOverlays)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: overlay.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overlay.service.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          if (overlay.notice case final notice?)
                            Text(
                              notice,
                              maxLines: 2,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Slider(
                        value: overlay.opacity,
                        onChanged: (value) =>
                            viewModel.setOverlayOpacity(overlay, value),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => viewModel.toggleOverlay(overlay.service),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Turn off',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

/// What the live search for other publishers is doing, in one line.
///
/// Worth a line of its own because the panel is otherwise indistinguishable
/// between "this county publishes nothing local" and "nobody has looked yet",
/// and those call for different things from the user — the first is an answer,
/// the second is a wait.
class _DiscoveryNote extends StatelessWidget {
  const _DiscoveryNote({required this.status});

  final PortalDiscoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String? message, bool busy) = switch (status) {
      PortalDiscoveryStatus.searching => (
        'Searching for local catalogues\u2026',
        true,
      ),
      PortalDiscoveryStatus.none => (
        'No local publisher found here; showing state and federal layers.',
        false,
      ),
      PortalDiscoveryStatus.unavailable => (
        'Could not search for local catalogues.',
        false,
      ),
      PortalDiscoveryStatus.idle ||
      PortalDiscoveryStatus.found => (null, false),
    };
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('portal-discovery-note'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (busy)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (busy) const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
