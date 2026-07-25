import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/data/services/arcgis_image_tile_provider.dart';
import 'package:riverside_atlas/data/services/california_counties.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/ui/features/map/property_clipboard_text.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';
import 'package:riverside_atlas/ui/features/map/widgets/google_search_panel.dart';

const _desktopBreakpoint = 940.0;

/// Height of the compact search field that floats over the map.
///
/// The compact layout stacks the search bar on top of the map, so the map's
/// own floating overlays are pushed below this to stay tappable. The value is
/// a deliberate upper bound: it is scaled as if it were a font size, which
/// overshoots the real height at large text scales so the overlays clear the
/// search bar rather than creep under it.
const _compactSearchFieldHeight = 56.0;
const _defaultCenter = LatLng(33.9806, -117.3755);

@immutable
class _GoogleSearchRequest {
  const _GoogleSearchRequest({
    required this.query,
    required this.searchSubject,
  });

  final String query;
  final String searchSubject;
}

Widget _buildGoogleSearchPanel(
  _GoogleSearchRequest request,
  GoogleSearchViewBuilder? webViewBuilder,
  VoidCallback onClose,
) {
  if (webViewBuilder == null) {
    return GoogleSearchPanel(
      key: ValueKey(request),
      query: request.query,
      searchSubject: request.searchSubject,
      onClose: onClose,
    );
  }
  return GoogleSearchPanel(
    key: ValueKey(request),
    query: request.query,
    searchSubject: request.searchSubject,
    onClose: onClose,
    webViewBuilder: webViewBuilder,
  );
}

/// The adaptive search-and-map workspace.
class GisMapScreen extends StatefulWidget {
  /// Creates a map workspace using [viewModel].
  const GisMapScreen({
    required this.viewModel,
    this.countySelection,
    this.initialCenter = _defaultCenter,
    this.initialBounds,
    this.enableBaseMap = true,
    this.googleSearchViewBuilder,
    super.key,
  });

  /// State and commands for the map experience.
  final GisMapViewModel viewModel;

  /// Counties the workspace can switch between.
  ///
  /// The county menu is hidden when this is null, which is how a workspace
  /// built for a single county behaves.
  final CountySelection? countySelection;

  /// Where the map opens, normally the active county's centre.
  ///
  /// Ignored when [initialBounds] is supplied.
  final LatLng initialCenter;

  /// The rectangle the map frames on open, normally the active county.
  ///
  /// County sizes differ by two orders of magnitude, so opening every one at
  /// the same zoom would put San Francisco under a city block and Inyo under a
  /// mountain range. Framing the extent shows the whole county either way.
  final GeoBounds? initialBounds;

  /// Whether remote raster tiles should be rendered.
  final bool enableBaseMap;

  /// Overrides the embedded Google WebView content, primarily for tests.
  final GoogleSearchViewBuilder? googleSearchViewBuilder;

  @override
  State<GisMapScreen> createState() => _GisMapScreenState();
}

class _GisMapScreenState extends State<GisMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  _GoogleSearchRequest? _googleSearch;
  CountyOption? _viewportCounty;

  /// Tracks which county the map is over so the workspace can offer a switch.
  ///
  /// The map reports its centre on every frame of a pan, so this only rebuilds
  /// when the answer actually changes.
  void _handleCenterChanged(LatLng center) {
    final selection = widget.countySelection;
    if (selection == null) {
      return;
    }
    final over = selection.countyAt(center);
    final offer = over == null || over.id == selection.activeId ? null : over;
    if (offer?.id == _viewportCounty?.id) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _viewportCounty = offer);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.viewModel.initialize();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _desktopBreakpoint) {
                  return _DesktopWorkspace(
                    viewModel: widget.viewModel,
                    countySelection: widget.countySelection,
                    initialCenter: widget.initialCenter,
                    initialBounds: widget.initialBounds,
                    viewportCounty: _viewportCounty,
                    onCenterChanged: _handleCenterChanged,
                    mapController: _mapController,
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    onAddressSelected: _selectAddress,
                    enableBaseMap: widget.enableBaseMap,
                    googleSearch: _googleSearch,
                    googleSearchViewBuilder: widget.googleSearchViewBuilder,
                    onGoogleSearch: _openGoogleSearch,
                    onCloseGoogleSearch: _closeGoogleSearch,
                  );
                }
                return _CompactWorkspace(
                  viewModel: widget.viewModel,
                  countySelection: widget.countySelection,
                  initialCenter: widget.initialCenter,
                  initialBounds: widget.initialBounds,
                  viewportCounty: _viewportCounty,
                  onCenterChanged: _handleCenterChanged,
                  mapController: _mapController,
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  onAddressSelected: _selectAddress,
                  enableBaseMap: widget.enableBaseMap,
                  googleSearch: _googleSearch,
                  googleSearchViewBuilder: widget.googleSearchViewBuilder,
                  onGoogleSearch: _openGoogleSearch,
                  onCloseGoogleSearch: _closeGoogleSearch,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _selectAddress(Address address) {
    widget.viewModel.selectAddress(address);
    _searchController.text = address.fullAddress;
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    _mapController.move(address.position, 18);
    _searchFocus.unfocus();
  }

  void _openGoogleSearch(_GoogleSearchRequest request) {
    setState(() => _googleSearch = request);
  }

  void _closeGoogleSearch() {
    setState(() => _googleSearch = null);
  }

  void _handleEscape() {
    if (_googleSearch != null) {
      _closeGoogleSearch();
      return;
    }
    widget.viewModel.clearSelection();
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.viewModel,
    required this.countySelection,
    required this.initialCenter,
    required this.initialBounds,
    required this.viewportCounty,
    required this.onCenterChanged,
    required this.mapController,
    required this.searchController,
    required this.searchFocus,
    required this.onAddressSelected,
    required this.enableBaseMap,
    required this.googleSearch,
    required this.googleSearchViewBuilder,
    required this.onGoogleSearch,
    required this.onCloseGoogleSearch,
  });

  final GisMapViewModel viewModel;
  final CountySelection? countySelection;
  final LatLng initialCenter;
  final GeoBounds? initialBounds;
  final CountyOption? viewportCounty;
  final ValueChanged<LatLng> onCenterChanged;
  final MapController mapController;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<Address> onAddressSelected;
  final bool enableBaseMap;
  final _GoogleSearchRequest? googleSearch;
  final GoogleSearchViewBuilder? googleSearchViewBuilder;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;
  final VoidCallback onCloseGoogleSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = ((constraints.maxWidth - 380) * 0.55).clamp(
          320.0,
          480.0,
        );
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _ControlPane(
                    viewModel: viewModel,
                    countySelection: countySelection,
                    searchController: searchController,
                    searchFocus: searchFocus,
                    onAddressSelected: onAddressSelected,
                    onGoogleSearch: onGoogleSearch,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _MapSurface(
                    viewModel: viewModel,
                    mapController: mapController,
                    initialCenter: initialCenter,
                    initialBounds: initialBounds,
                    countySelection: countySelection,
                    viewportCounty: viewportCounty,
                    onCenterChanged: onCenterChanged,
                    enableBaseMap: enableBaseMap,
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child: googleSearch == null
                        ? const SizedBox.shrink()
                        : Row(
                            key: ValueKey(googleSearch),
                            children: [
                              VerticalDivider(
                                width: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              SizedBox(
                                width: panelWidth,
                                child: _buildGoogleSearchPanel(
                                  googleSearch!,
                                  googleSearchViewBuilder,
                                  onCloseGoogleSearch,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({
    required this.viewModel,
    required this.countySelection,
    required this.initialCenter,
    required this.initialBounds,
    required this.viewportCounty,
    required this.onCenterChanged,
    required this.mapController,
    required this.searchController,
    required this.searchFocus,
    required this.onAddressSelected,
    required this.enableBaseMap,
    required this.googleSearch,
    required this.googleSearchViewBuilder,
    required this.onGoogleSearch,
    required this.onCloseGoogleSearch,
  });

  final GisMapViewModel viewModel;
  final CountySelection? countySelection;
  final LatLng initialCenter;
  final GeoBounds? initialBounds;
  final CountyOption? viewportCounty;
  final ValueChanged<LatLng> onCenterChanged;
  final MapController mapController;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<Address> onAddressSelected;
  final bool enableBaseMap;
  final _GoogleSearchRequest? googleSearch;
  final GoogleSearchViewBuilder? googleSearchViewBuilder;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;
  final VoidCallback onCloseGoogleSearch;

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final googlePanelWidth = (MediaQuery.sizeOf(context).width * 0.92).clamp(
      0.0,
      560.0,
    );
    final searchBarBottom =
        safePadding.top +
        12 +
        MediaQuery.textScalerOf(context).scale(_compactSearchFieldHeight);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _MapSurface(
              viewModel: viewModel,
              mapController: mapController,
              initialCenter: initialCenter,
              initialBounds: initialBounds,
              countySelection: countySelection,
              viewportCounty: viewportCounty,
              onCenterChanged: onCenterChanged,
              enableBaseMap: enableBaseMap,
              overlayPadding: EdgeInsets.only(top: searchBarBottom),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: safePadding.top + 12,
            child: Column(
              children: [
                _SearchField(
                  controller: searchController,
                  focusNode: searchFocus,
                  viewModel: viewModel,
                ),
                if (viewModel.searchResults.isNotEmpty)
                  _FloatingSearchResults(
                    results: viewModel.searchResults,
                    onSelected: onAddressSelected,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: safePadding.bottom + 20,
            child: _CompactLayerBar(
              viewModel: viewModel,
              onOpenTools: () => _showTools(context),
            ),
          ),
          if (viewModel.selectedAddress != null ||
              viewModel.selectedParcel != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: safePadding.bottom + 84,
              child: _SelectionCard(
                viewModel: viewModel,
                onGoogleSearch: onGoogleSearch,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: googleSearch == null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: googleSearch == null ? 0 : 1,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: GestureDetector(onTap: onCloseGoogleSearch),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      ),
                    ),
                child: child,
              ),
              child: googleSearch == null
                  ? const SizedBox.shrink()
                  : Align(
                      key: ValueKey(googleSearch),
                      alignment: Alignment.centerRight,
                      child: SafeArea(
                        left: false,
                        child: SizedBox(
                          width: googlePanelWidth,
                          child: _buildGoogleSearchPanel(
                            googleSearch!,
                            googleSearchViewBuilder,
                            onCloseGoogleSearch,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTools(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => FractionallySizedBox(
          heightFactor: 0.76,
          child: _ToolsContent(
            viewModel: viewModel,
            countySelection: countySelection,
          ),
        ),
      ),
    );
  }
}

class _ControlPane extends StatelessWidget {
  const _ControlPane({
    required this.viewModel,
    required this.countySelection,
    required this.searchController,
    required this.searchFocus,
    required this.onAddressSelected,
    required this.onGoogleSearch,
  });

  final GisMapViewModel viewModel;
  final CountySelection? countySelection;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<Address> onAddressSelected;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: _BrandHeader(
              mode: viewModel.mode,
              countyName: viewModel.countyName,
              countySelection: countySelection,
              canSwitchCounty: !viewModel.snapshotStatus.isImporting,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SearchField(
              controller: searchController,
              focusNode: searchFocus,
              viewModel: viewModel,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _PaneBody(
                key: ValueKey((
                  viewModel.searchResults.isNotEmpty,
                  viewModel.selectedAddress?.sourceId,
                  viewModel.selectedParcel?.sourceId,
                )),
                viewModel: viewModel,
                onAddressSelected: onAddressSelected,
                onGoogleSearch: onGoogleSearch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.mode,
    required this.countyName,
    required this.countySelection,
    required this.canSwitchCounty,
  });

  final DataMode mode;
  final String countyName;
  final CountySelection? countySelection;
  final bool canSwitchCounty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: ShapeDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          child: Icon(
            Icons.map_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Riverside Atlas', style: theme.textTheme.titleLarge),
              if (countySelection case final selection?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: CountyMenuButton(
                    selection: selection,
                    enabled: canSwitchCounty,
                    disabledTooltip:
                        'Finish or pause the snapshot download before '
                        'changing county.',
                  ),
                )
              else
                Text(
                  countyName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Tooltip(
          message: mode == DataMode.live
              ? 'Using live county data'
              : 'Using a local snapshot',
          child: Badge(
            backgroundColor: mode == DataMode.live
                ? theme.colorScheme.tertiary
                : theme.colorScheme.secondary,
            smallSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.viewModel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final GisMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: TextField(
        key: const Key('address-search-field'),
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.characters,
        onChanged: viewModel.search,
        decoration: InputDecoration(
          hintText: 'Search a ${viewModel.countyName} address',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: viewModel.isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isEmpty
              ? Tooltip(
                  message: 'Press ⌘K to search',
                  child: const Icon(Icons.keyboard_command_key, size: 18),
                )
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    viewModel.clearSearch();
                    focusNode.requestFocus();
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
  }
}

class _PaneBody extends StatelessWidget {
  const _PaneBody({
    required this.viewModel,
    required this.onAddressSelected,
    required this.onGoogleSearch,
    super.key,
  });

  final GisMapViewModel viewModel;
  final ValueChanged<Address> onAddressSelected;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;

  @override
  Widget build(BuildContext context) {
    if (viewModel.searchResults.isNotEmpty) {
      return _SearchResults(
        results: viewModel.searchResults,
        onSelected: onAddressSelected,
      );
    }
    if (viewModel.selectedAddress != null || viewModel.selectedParcel != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: _SelectionCard(
          viewModel: viewModel,
          onGoogleSearch: onGoogleSearch,
        ),
      );
    }
    return _ToolsContent(viewModel: viewModel);
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onSelected});

  final List<Address> results;
  final ValueChanged<Address> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Text(
            '${results.length} matching addresses',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final address = results[index];
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: Key('search-result-${address.sourceId}'),
                  leading: const CircleAvatar(
                    child: Icon(Icons.home_work_outlined),
                  ),
                  title: Text(address.fullAddress),
                  subtitle: Text('${address.city}, CA ${address.zipCode}'),
                  trailing: const Icon(Icons.arrow_outward),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () => onSelected(address),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FloatingSearchResults extends StatelessWidget {
  const _FloatingSearchResults({
    required this.results,
    required this.onSelected,
  });

  final List<Address> results;
  final ValueChanged<Address> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final address = results[index];
            return ListTile(
              title: Text(address.fullAddress),
              subtitle: Text('${address.city}, CA ${address.zipCode}'),
              onTap: () => onSelected(address),
            );
          },
        ),
      ),
    );
  }
}

class _ToolsContent extends StatelessWidget {
  const _ToolsContent({required this.viewModel, this.countySelection});

  final GisMapViewModel viewModel;
  final CountySelection? countySelection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (countySelection case final selection?) ...[
          _SectionLabel(label: 'COUNTY', icon: Icons.location_on_outlined),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: CountyMenuButton(
              selection: selection,
              enabled: !viewModel.snapshotStatus.isImporting,
              disabledTooltip:
                  'Finish or pause the snapshot download before changing '
                  'county.',
            ),
          ),
          const SizedBox(height: 24),
        ],
        _SectionLabel(label: 'DATA SOURCE', icon: Icons.storage_outlined),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DataMode>(
            key: const Key('data-mode-control'),
            segments: const [
              ButtonSegment(
                value: DataMode.live,
                icon: Icon(Icons.cloud_outlined),
                label: Text('Live'),
              ),
              ButtonSegment(
                value: DataMode.offline,
                icon: Icon(Icons.offline_pin_outlined),
                label: Text('Offline'),
              ),
            ],
            selected: {viewModel.mode},
            onSelectionChanged: (selection) {
              viewModel.setMode(selection.first);
            },
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel(label: 'MAP LAYERS', icon: Icons.layers_outlined),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _LayerSwitch(
                key: const Key('address-layer-switch'),
                icon: Icons.home_work_outlined,
                title: 'Address points',
                subtitle: 'Select a marker to inspect its address',
                value: viewModel.addressesVisible,
                onChanged: viewModel.setAddressesVisible,
              ),
              const Divider(height: 1, indent: 58),
              _LayerSwitch(
                key: const Key('parcel-layer-switch'),
                icon: Icons.grid_4x4_outlined,
                title: 'Parcel boundaries',
                subtitle: 'Property facts from the assessor layer',
                value: viewModel.parcelsVisible,
                onChanged: viewModel.setParcelsVisible,
              ),
              const Divider(height: 1, indent: 58),
              _LayerSwitch(
                key: const Key('alpr-layer-switch'),
                icon: Icons.videocam_outlined,
                title: 'License-plate readers',
                subtitle: viewModel.alprCamerasAvailable
                    ? 'Flock and other ALPRs from OpenStreetMap'
                    : 'Live mode only; not stored in snapshots',
                value: viewModel.alprCamerasVisible,
                onChanged: viewModel.alprCamerasAvailable
                    ? viewModel.setAlprCamerasVisible
                    : null,
              ),
              const Divider(height: 1, indent: 58),
              _LayerSwitch(
                key: const Key('boundary-layer-switch'),
                icon: Icons.polyline_outlined,
                title: 'County boundary',
                subtitle: '${viewModel.countyName} limits',
                value: viewModel.boundaryVisible,
                onChanged: viewModel.setBoundaryVisible,
              ),
            ],
          ),
        ),
        if (viewModel.imageryAvailable) ...[
          const SizedBox(height: 24),
          _SectionLabel(
            label: 'HISTORICAL IMAGERY',
            icon: Icons.satellite_alt_outlined,
          ),
          const SizedBox(height: 10),
          _ImageryCard(viewModel: viewModel),
        ],
        const SizedBox(height: 24),
        _SectionLabel(label: 'OFFLINE SNAPSHOT', icon: Icons.download_outlined),
        const SizedBox(height: 10),
        _SnapshotCard(viewModel: viewModel),
        const SizedBox(height: 20),
        _SourceNotice(countyName: viewModel.countyName),
      ],
    );
  }
}

class _ImageryCard extends StatelessWidget {
  const _ImageryCard({required this.viewModel});

  static const _streetMapId = '__street_map__';

  final GisMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (viewModel.isLoadingImagery) {
      return const Card(
        child: ListTile(
          leading: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Loading aerial history…'),
        ),
      );
    }

    final layers = viewModel.imageryLayers;
    final selected = viewModel.selectedImagery;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.history_toggle_off,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected == null
                            ? 'Street map'
                            : '${selected.year} aerial imagery',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        viewModel.imageryMessage ??
                            (selected?.description.isNotEmpty == true
                                ? selected!.description
                                : '${layers.length} captures • newest first'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (layers.isNotEmpty) ...[
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<String>(
                  key: ValueKey(
                    'imagery-year-menu-${selected?.id ?? _streetMapId}',
                  ),
                  width: constraints.maxWidth,
                  initialSelection: selected?.id ?? _streetMapId,
                  label: const Text('Map background'),
                  leadingIcon: const Icon(Icons.photo_library_outlined),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(
                      value: _streetMapId,
                      label: 'Street map',
                      leadingIcon: Icon(Icons.map_outlined),
                    ),
                    for (final layer in layers)
                      DropdownMenuEntry(
                        value: layer.id,
                        label: '${layer.year} aerial imagery',
                        leadingIcon: const Icon(Icons.satellite_alt_outlined),
                      ),
                  ],
                  onSelected: (value) => viewModel.selectImagery(
                    value == _streetMapId ? null : value,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${layers.length} ${viewModel.countyName} captures • '
                'most recent first',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _LayerSwitch extends StatelessWidget {
  const _LayerSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.viewModel});

  final GisMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final status = viewModel.snapshotStatus;
    final theme = Theme.of(context);
    final updatedAt = status.updatedAt?.toLocal();
    final updatedLabel = updatedAt == null
        ? 'No offline snapshot yet'
        : 'Updated ${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';

    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status.isAvailable
                      ? Icons.check_circle_outline
                      : Icons.cloud_download_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(updatedLabel, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            if (status.isAvailable) ...[
              const SizedBox(height: 8),
              Text(
                '${_formatCount(status.addressCount)} addresses  •  '
                '${_formatCount(status.parcelCount)} parcels',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (!status.isImporting) ...[
              const SizedBox(height: 8),
              Text(
                'Download the visible map area, or all of '
                '${viewModel.countyName} where it is small enough to fit. '
                'Each download replaces the offline area.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (status.isImporting) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: status.progress),
              const SizedBox(height: 8),
              Text(status.phase, style: theme.textTheme.bodySmall),
            ] else if (status.phase.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(status.phase, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 14),
            if (status.isImporting)
              OutlinedButton.icon(
                key: const Key('cancel-snapshot-button'),
                onPressed: viewModel.cancelSnapshot,
                icon: const Icon(Icons.pause),
                label: const Text('Pause download'),
              )
            else ...[
              FilledButton.tonalIcon(
                key: const Key('download-snapshot-button'),
                onPressed: viewModel.downloadSnapshot,
                icon: const Icon(Icons.download),
                label: Text(
                  status.isAvailable
                      ? 'Replace offline area'
                      : 'Download this area',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('download-county-button'),
                onPressed: viewModel.downloadCountySnapshot,
                icon: const Icon(Icons.map_outlined),
                label: Text('Download all of ${viewModel.countyName}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) {
    final digits = '$value';
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice({required this.countyName});

  final String countyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$countyName GIS data is approximate and for reference only. '
            'Parcel lines are not legal survey boundaries.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// A street address joined to its city and ZIP, skipping a location the county
/// left blank so the query never trails a stray separator.
String _searchableAddress(String street, String location) =>
    location.isEmpty ? street : '$street, $location';

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.viewModel, required this.onGoogleSearch});

  final GisMapViewModel viewModel;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;

  @override
  Widget build(BuildContext context) {
    final address = viewModel.selectedAddress;
    final parcel = viewModel.selectedParcel;
    final addressQuery = switch ((address, parcel)) {
      (final address?, _) => _searchableAddress(
        address.fullAddress,
        propertyLocationLine(city: address.city, zipCode: address.zipCode),
      ),
      (_, final parcel?) when parcel.situsAddress.isNotEmpty =>
        _searchableAddress(
          parcel.situsAddress,
          propertyLocationLine(city: parcel.city, zipCode: parcel.zipCode),
        ),
      _ => null,
    };
    final clipboardText = propertyClipboardText(
      countyName: viewModel.countyName,
      address: address,
      parcel: parcel,
      ownership: viewModel.propertyOwnership,
      ownerLookupStatus: viewModel.ownerLookupStatus,
      unclaimedProperty: viewModel.unclaimedPropertyResult,
    );
    final theme = Theme.of(context);
    return Card(
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    address != null
                        ? Icons.home_work_outlined
                        : Icons.grid_4x4_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address?.fullAddress ??
                        (parcel?.situsAddress.isNotEmpty == true
                            ? parcel!.situsAddress
                            : viewModel.resolvedSitus?.streetAddress ??
                                  'Parcel ${parcel?.apn ?? ''}'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (clipboardText != null) ...[
                  _CopyButton(
                    key: const Key('copy-selection-button'),
                    tooltip: 'Copy all details',
                    icon: Icons.copy_all_outlined,
                    text: clipboardText,
                    confirmation: 'Property details copied',
                  ),
                  const SizedBox(width: 4),
                ],
                if (addressQuery != null) ...[
                  _GoogleSearchButton(
                    key: const Key('google-address-search-button'),
                    tooltip: 'Search this address on Google',
                    onPressed: () => onGoogleSearch(
                      _GoogleSearchRequest(
                        query: addressQuery,
                        searchSubject: 'Address',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  tooltip: 'Close details',
                  onPressed: viewModel.clearSelection,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (address != null) ...[
              _LocationDetailRow(city: address.city, zipCode: address.zipCode),
              if (address.unit.isNotEmpty)
                _DetailRow(label: 'UNIT', value: address.unit),
              _OwnerDetailRow(
                viewModel: viewModel,
                onGoogleSearch: onGoogleSearch,
              ),
              _UnclaimedPropertyDetail(viewModel: viewModel),
              _ApnDetailRow(
                label: 'PARCEL',
                apn: address.apn,
                placeholder: 'Not linked',
              ),
              _DetailRow(
                label: 'ADDRESS TYPE',
                value: address.addressType.isEmpty
                    ? 'Not provided'
                    : 'County code ${address.addressType}',
              ),
              _DetailRow(label: 'UNITS', value: '${address.numberOfUnits}'),
              _DetailRow(
                label: 'SOURCE',
                value: '${viewModel.countyName} Address Points',
              ),
            ],
            if (parcel != null) ...[
              _OwnerDetailRow(
                viewModel: viewModel,
                onGoogleSearch: onGoogleSearch,
              ),
              _UnclaimedPropertyDetail(viewModel: viewModel),
              _ApnDetailRow(label: 'APN', apn: parcel.apn),
              if (parcel.situsAddress.isEmpty &&
                  viewModel.resolvedSitus != null) ...[
                _DetailRow(
                  key: const Key('resolved-situs-row'),
                  label: 'STREET',
                  value: viewModel.resolvedSitus!.fullAddress,
                ),
                _DetailRow(
                  label: 'STREET SOURCE',
                  value: 'California statewide parcel fabric',
                ),
              ] else
                _DetailRow(
                  label: 'STREET',
                  value: parcel.situsAddress.isEmpty
                      ? 'No address on record'
                      : parcel.situsAddress,
                ),
              _LocationDetailRow(
                city: parcel.city.isEmpty
                    ? viewModel.resolvedSitus?.city ?? ''
                    : parcel.city,
                zipCode: parcel.zipCode.isEmpty
                    ? viewModel.resolvedSitus?.zipCode ?? ''
                    : parcel.zipCode,
              ),
              _DetailRow(
                label: 'LAND USE',
                value: parcel.landUse.isEmpty ? 'Not provided' : parcel.landUse,
              ),
              _DetailRow(
                label: 'ACREAGE',
                value: parcel.acreage == null
                    ? 'Not provided'
                    : parcel.acreage!.toStringAsFixed(2),
              ),
              _DetailRow(
                label: 'SOURCE',
                value: '${viewModel.countyName} Assessor',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OwnerDetailRow extends StatelessWidget {
  const _OwnerDetailRow({
    required this.viewModel,
    required this.onGoogleSearch,
  });

  final GisMapViewModel viewModel;
  final ValueChanged<_GoogleSearchRequest> onGoogleSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = viewModel.ownerLookupStatus;
    final ownership = viewModel.propertyOwnership;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              'OWNER',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: switch (status) {
              OwnerLookupStatus.loading => const Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('Looking up county tax record…')),
                ],
              ),
              OwnerLookupStatus.found => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ownership?.ownerName ?? '',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (ownership case final owner?
                          when owner.ownerName.isNotEmpty) ...[
                        _CopyButton(
                          key: const Key('copy-owner-button'),
                          tooltip: 'Copy owner name',
                          text: owner.ownerName,
                          confirmation: 'Owner name copied',
                        ),
                        _GoogleSearchButton(
                          key: const Key('google-owner-search-button'),
                          tooltip: 'Search this owner name on Google',
                          onPressed: () => onGoogleSearch(
                            _GoogleSearchRequest(
                              query: owner.ownerName,
                              searchSubject: 'Owner name',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Riverside County Treasurer–Tax Collector • saved locally',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              OwnerLookupStatus.notFound => _OwnerLookupMessage(
                message: 'No exact public tax-record match',
                onRetry: viewModel.retryOwnerLookup,
              ),
              OwnerLookupStatus.unavailable => _OwnerLookupMessage(
                message: 'County owner lookup unavailable',
                onRetry: viewModel.retryOwnerLookup,
              ),
              OwnerLookupStatus.idle => const Text('Not requested'),
            },
          ),
        ],
      ),
    );
  }
}

class _OwnerLookupMessage extends StatelessWidget {
  const _OwnerLookupMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Retry owner lookup',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 19),
        ),
      ],
    );
  }
}

class _GoogleSearchButton extends StatelessWidget {
  const _GoogleSearchButton({
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: const EdgeInsets.all(6),
      icon: const Icon(Icons.travel_explore_outlined, size: 18),
    );
  }
}

/// Reports a saved California unclaimed-property check inline with the other
/// property details.
///
/// The check itself is a stored public record. Nothing here opens the state
/// website: when a saved result exists its content is written into this row,
/// and when none exists the row is omitted.
class _UnclaimedPropertyDetail extends StatelessWidget {
  const _UnclaimedPropertyDetail({required this.viewModel});

  final GisMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final result = viewModel.unclaimedPropertyResult;
    if (result == null) {
      return const SizedBox.shrink();
    }
    return _DetailRow(
      label: 'UNCLAIMED',
      value: unclaimedPropertySummary(result),
    );
  }
}

/// Copies [text] to the clipboard and reports it in a snack bar.
class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.tooltip,
    required this.text,
    required this.confirmation,
    this.icon = Icons.copy_outlined,
    super.key,
  });

  final String tooltip;

  /// Exactly what the clipboard receives.
  final String text;

  /// The snack-bar message shown once the copy lands.
  final String confirmation;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _copy(context),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: const EdgeInsets.all(6),
      icon: Icon(icon, size: 18),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(confirmation),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

/// The assessor parcel number, copyable when the county published one.
class _ApnDetailRow extends StatelessWidget {
  const _ApnDetailRow({
    required this.label,
    required this.apn,
    this.placeholder = 'Not provided',
  });

  /// How this row is titled, which the address and parcel panels word
  /// differently.
  final String label;

  final String apn;

  /// Stands in for an APN the source did not publish.
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return _DetailRow(
      label: label,
      value: apn.isEmpty ? placeholder : apn,
      trailing: apn.isEmpty
          ? null
          : _CopyButton(
              key: const Key('copy-apn-button'),
              tooltip: 'Copy APN',
              text: apn,
              confirmation: 'APN copied',
            ),
    );
  }
}

/// The city and ZIP line, copyable when either part exists.
class _LocationDetailRow extends StatelessWidget {
  const _LocationDetailRow({required this.city, required this.zipCode});

  final String city;
  final String zipCode;

  @override
  Widget build(BuildContext context) {
    final location = propertyLocationLine(city: city, zipCode: zipCode);
    return _DetailRow(
      label: 'LOCATION',
      value: location.isEmpty ? 'Not provided' : location,
      trailing: location.isEmpty
          ? null
          : _CopyButton(
              key: const Key('copy-location-button'),
              tooltip: 'Copy location',
              text: location,
              confirmation: 'Location copied',
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;

  /// An action drawn after the value, such as a copy button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

class _MapSurface extends StatelessWidget {
  const _MapSurface({
    required this.viewModel,
    required this.mapController,
    required this.initialCenter,
    required this.initialBounds,
    required this.countySelection,
    required this.viewportCounty,
    required this.onCenterChanged,
    required this.enableBaseMap,
    this.overlayPadding = EdgeInsets.zero,
  });

  final GisMapViewModel viewModel;
  final MapController mapController;

  /// Where the map opens before the user pans.
  final LatLng initialCenter;

  /// The rectangle framed on open, in preference to [initialCenter].
  final GeoBounds? initialBounds;

  /// Counties the workspace can switch between, when it can switch at all.
  final CountySelection? countySelection;

  /// The county the map has been panned over, when it is not the active one.
  final CountyOption? viewportCounty;

  /// Reports the map centre so the workspace can offer a county switch.
  final ValueChanged<LatLng> onCenterChanged;

  final bool enableBaseMap;

  /// Space reserved around the map for chrome drawn by the parent, such as the
  /// compact layout's floating search bar.
  final EdgeInsets overlayPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapColors = theme.extension<MapColors>()!;
    final boundary = viewModel.boundary;
    // Panning is bounded by the state, not by the selected county: parcels
    // come from a statewide layer, so a map that stopped at the county line
    // would refuse to show data it can load.
    final cameraConstraint = CameraConstraint.containCenter(
      bounds: LatLngBounds(
        LatLng(
          CaliforniaCounties.stateExtent.south,
          CaliforniaCounties.stateExtent.west,
        ),
        LatLng(
          CaliforniaCounties.stateExtent.north,
          CaliforniaCounties.stateExtent.east,
        ),
      ),
    );
    final initialFit = initialBounds == null
        ? null
        : CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(initialBounds!.south, initialBounds!.west),
              LatLng(initialBounds!.north, initialBounds!.east),
            ),
            padding: const EdgeInsets.all(32),
          );

    return Stack(
      children: [
        FlutterMap(
          key: const Key('riverside-map'),
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 12.4,
            initialCameraFit: initialFit,
            minZoom: 5,
            maxZoom: 20,
            cameraConstraint: cameraConstraint,
            backgroundColor: theme.colorScheme.surfaceContainer,
            onMapReady: () {
              final camera = mapController.camera;
              _sendViewport(camera);
            },
            onPositionChanged: (camera, _) => _sendViewport(camera),
            onTap: (_, point) => viewModel.selectParcelAt(point),
          ),
          children: [
            if (enableBaseMap && viewModel.selectedImagery == null)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.skippy.riversideAtlas',
                maxNativeZoom: 19,
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
              ),
            if (enableBaseMap)
              if (viewModel.selectedImagery case final imagery?)
                TileLayer(
                  key: ValueKey('imagery-${imagery.id}'),
                  urlTemplate: imagery.serviceUri.toString(),
                  tileProvider: ArcGisImageTileProvider(),
                  userAgentPackageName: 'com.skippy.riversideAtlas',
                  maxNativeZoom: 20,
                  evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                ),
            if (viewModel.boundaryVisible && boundary != null)
              PolygonLayer(
                polygons: boundary.rings
                    .map(
                      (ring) => Polygon(
                        points: ring,
                        color: mapColors.boundary.withValues(alpha: 0.05),
                        borderColor: mapColors.boundary,
                        borderStrokeWidth: 3,
                        pattern: StrokePattern.dashed(segments: [8, 6]),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (viewModel.parcelsVisible)
              PolygonLayer(
                polygons: [
                  for (final parcel in viewModel.parcels)
                    for (final ring in parcel.rings)
                      Polygon(
                        points: ring,
                        color:
                            (viewModel.selectedParcel?.sourceId ==
                                        parcel.sourceId
                                    ? mapColors.parcelSelected
                                    : mapColors.parcel)
                                .withValues(alpha: 0.14),
                        borderColor:
                            viewModel.selectedParcel?.sourceId ==
                                parcel.sourceId
                            ? mapColors.parcelSelected
                            : mapColors.parcel.withValues(alpha: 0.82),
                        borderStrokeWidth:
                            viewModel.selectedParcel?.sourceId ==
                                parcel.sourceId
                            ? 3
                            : 1.2,
                      ),
                ],
              ),
            if (viewModel.addressesVisible)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxZoom: 17,
                  maxClusterRadius: 50,
                  size: const Size(44, 44),
                  padding: const EdgeInsets.all(36),
                  markers: viewModel.addresses
                      .map(
                        (address) => Marker(
                          key: Key('address-marker-${address.sourceId}'),
                          point: address.position,
                          width: 38,
                          height: 38,
                          child: _AddressMarker(
                            address: address,
                            selected:
                                viewModel.selectedAddress?.sourceId ==
                                address.sourceId,
                            onTap: () => viewModel.selectAddress(address),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  builder: (context, markers) =>
                      _ClusterMarker(count: markers.length),
                ),
              ),
            if (viewModel.alprCamerasVisible)
              PolygonLayer(
                polygons: [
                  for (final camera in viewModel.alprCameraList)
                    if (camera.viewCone() case final cone when cone.isNotEmpty)
                      Polygon(
                        points: cone,
                        color: _alprColor(
                          mapColors,
                          camera,
                        ).withValues(alpha: 0.35),
                        borderColor: _alprColor(
                          mapColors,
                          camera,
                        ).withValues(alpha: 0.7),
                        borderStrokeWidth: 2,
                      ),
                ],
              ),
            if (viewModel.alprCamerasVisible)
              MarkerLayer(
                markers: viewModel.alprCameraList
                    .map(
                      (camera) => Marker(
                        key: Key('alpr-marker-${camera.sourceId}'),
                        point: camera.position,
                        width: 24,
                        height: 24,
                        child: _AlprCameraMarker(camera: camera),
                      ),
                    )
                    .toList(growable: false),
              ),
            _MapAttribution(
              imagery: viewModel.selectedImagery,
              creditsOpenStreetMapData: viewModel.alprCamerasVisible,
              countyName: viewModel.countyName,
            ),
          ],
        ),
        Positioned(
          right: overlayPadding.right + 18,
          top: overlayPadding.top + 18,
          child: _MapButtons(
            countyName: viewModel.countyName,
            onZoomIn: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom + 1,
            ),
            onZoomOut: () => mapController.move(
              mapController.camera.center,
              mapController.camera.zoom - 1,
            ),
            onFit: () => _fitBoundary(boundary),
          ),
        ),
        Positioned(
          left: overlayPadding.left + 16,
          top: overlayPadding.top + 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (viewportCounty case final county?
                  when countySelection != null &&
                      !viewModel.snapshotStatus.isImporting) ...[
                CountySwitchChip(
                  county: county,
                  onPressed: () => countySelection!.onSelected(county),
                ),
                const SizedBox(height: 8),
              ],
              if (viewModel.isLoadingMap)
                const _StatusPill(
                  icon: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: 'Loading map data',
                )
              else if (viewModel.mapMessage case final message?)
                _StatusPill(
                  icon: const Icon(Icons.zoom_in_map, size: 18),
                  label: message,
                )
              else if (viewModel.selectedImagery case final imagery?)
                _StatusPill(
                  icon: const Icon(Icons.satellite_alt_outlined, size: 18),
                  label: '${imagery.year} aerial imagery',
                ),
              if (viewModel.alprMessage case final message?) ...[
                const SizedBox(height: 8),
                _StatusPill(
                  icon: const Icon(Icons.videocam_off_outlined, size: 18),
                  label: message,
                ),
              ],
            ],
          ),
        ),
        if (viewModel.errorMessage case final error?)
          Positioned(
            left: 16,
            right: 76,
            bottom: 38,
            child: _ErrorBanner(
              message: error,
              onDismiss: viewModel.dismissError,
            ),
          ),
        if (viewModel.isInitializing)
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.surface.withValues(alpha: 0.82),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  void _sendViewport(MapCamera camera) {
    onCenterChanged(camera.center);
    final bounds = camera.visibleBounds;
    viewModel.updateViewport(
      GeoBounds(
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
      ),
      camera.zoom,
    );
  }

  void _fitBoundary(RegionBoundary? boundary) {
    if (boundary == null) {
      return;
    }
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(boundary.bounds.south, boundary.bounds.west),
          LatLng(boundary.bounds.north, boundary.bounds.east),
        ),
        padding: const EdgeInsets.all(48),
      ),
    );
  }
}

class _AddressMarker extends StatelessWidget {
  const _AddressMarker({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MapColors>()!;
    final color = selected ? colors.addressSelected : colors.address;
    return Semantics(
      button: true,
      label: 'View ${address.displayAddress}',
      child: Tooltip(
        message: address.fullAddress,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: selected ? 10 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: selected ? 22 : 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// The map color identifying [camera] by vendor.
Color _alprColor(MapColors colors, AlprCamera camera) =>
    camera.isFlock ? colors.alprFlockCamera : colors.alprCamera;

/// A license-plate reader drawn as a dot at its mapped position.
///
/// Facing is carried by the separate field-of-view wedge rather than the
/// marker, so the dot only has to mark the hardware itself.
class _AlprCameraMarker extends StatelessWidget {
  const _AlprCameraMarker({required this.camera});

  final AlprCamera camera;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MapColors>()!;
    return Semantics(
      label: 'License-plate reader. ${camera.description}',
      child: Tooltip(
        message: camera.description,
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _alprColor(colors, camera),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({
    required this.imagery,
    required this.creditsOpenStreetMapData,
    required this.countyName,
  });

  final ImageryLayer? imagery;

  /// County credited alongside the basemap.
  final String countyName;

  /// Whether an OpenStreetMap data layer is drawn, which ODbL requires
  /// crediting separately from the basemap tiles.
  final bool creditsOpenStreetMapData;

  @override
  Widget build(BuildContext context) {
    final base = imagery == null
        ? '© OpenStreetMap contributors • $countyName GIS'
        : '$countyName GIS • Aerial ${imagery!.year}';
    final credit = creditsOpenStreetMapData && imagery != null
        ? '$base • ALPR data © OpenStreetMap contributors (ODbL)'
        : creditsOpenStreetMapData
        ? '$base • ALPR data ODbL'
        : base;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(credit, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MapButtons extends StatelessWidget {
  const _MapButtons({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.countyName,
  });

  /// County named in the fit-to-boundary tooltip.
  final String countyName;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: 'Fit $countyName',
            onPressed: onFit,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }
}

class _CompactLayerBar extends StatelessWidget {
  const _CompactLayerBar({required this.viewModel, required this.onOpenTools});

  final GisMapViewModel viewModel;
  final VoidCallback onOpenTools;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Address points',
            isSelected: viewModel.addressesVisible,
            onPressed: () =>
                viewModel.setAddressesVisible(!viewModel.addressesVisible),
            icon: const Icon(Icons.home_work_outlined),
            selectedIcon: const Icon(Icons.home_work),
          ),
          IconButton(
            tooltip: 'Parcel boundaries',
            isSelected: viewModel.parcelsVisible,
            onPressed: () =>
                viewModel.setParcelsVisible(!viewModel.parcelsVisible),
            icon: const Icon(Icons.grid_4x4_outlined),
            selectedIcon: const Icon(Icons.grid_4x4),
          ),
          IconButton(
            tooltip: 'License-plate readers',
            isSelected: viewModel.alprCamerasVisible,
            onPressed: viewModel.alprCamerasAvailable
                ? () => viewModel.setAlprCamerasVisible(
                    !viewModel.alprCamerasVisible,
                  )
                : null,
            icon: const Icon(Icons.videocam_outlined),
            selectedIcon: const Icon(Icons.videocam),
          ),
          IconButton(
            tooltip: 'Data and layer settings',
            onPressed: onOpenTools,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
