import 'package:riverside_atlas/ui/features/map/widgets/route_builder_panel.dart';
import 'package:riverside_atlas/ui/features/map/widgets/route_map_layer.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/data/services/arcgis_image_tile_provider.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/ui/features/map/widgets/claimit_search_panel.dart';
import 'package:riverside_atlas/domain/models/alpr_camera.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/imagery_layer.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';
import 'package:riverside_atlas/ui/features/map/property_clipboard_text.dart';
import 'package:riverside_atlas/ui/features/map/view_models/active_overlay.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_results_panel.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_edit_layer.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_select_overlay.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_panel.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';
import 'package:riverside_atlas/ui/features/map/widgets/google_search_panel.dart';
import 'package:riverside_atlas/ui/features/map/widgets/layer_catalog_sheet.dart';

import 'package:riverside_atlas/ui/features/map/widgets/workspace_layout.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_composer.dart';
import 'package:riverside_atlas/ui/features/map/widgets/compact_sheet.dart';
import 'package:riverside_atlas/data/services/content_sharing.dart';

part 'compact_workspace.dart';

/// The width at and above which the workspace shows the full desktop layout:
/// the control pane, the map, and room for the search panel beside both.
const _desktopBreakpoint = 940.0;

/// The height the desktop layout also needs.
///
/// Width alone is not enough: a phone held sideways is wider than this
/// breakpoint and barely 400pt tall, and the desktop pane's stacked header,
/// search field and scrolling body have nowhere to go on it.
const _desktopMinHeight = 600.0;

/// The width at and above which the control pane sits beside the map.
///
/// This is the narrowest real tablet in portrait (iPad mini, 744pt). Below it
/// a pane wide enough to read leaves the map narrower than the pane, so the
/// compact layout — a full-bleed map with its chrome floating over it — is
/// the better answer.
const _tabletBreakpoint = 744.0;

const _defaultCenter = LatLng(33.9806, -117.3755);

/// Width of the property card floating over the map.
const _selectionCardWidth = 360.0;

@immutable
class _WebSearchRequest {
  const _WebSearchRequest({
    required this.query,
    required this.searchSubject,
    this.claimItQuery,
  });

  final UnclaimedPropertyQuery? claimItQuery;
  final String query;
  final String searchSubject;
}

Widget _buildWebSearchPanel(
  _WebSearchRequest request,
  GoogleSearchViewBuilder? webViewBuilder,
  VoidCallback onClose,
) {
  if (request.claimItQuery case final query?) {
    return ClaimItSearchPanel(
      key: ValueKey(request),
      query: query,
      onClose: onClose,
      webViewBuilder: webViewBuilder,
    );
  }
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
    this.assistant,
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

  /// Overrides embedded search content for either provider, primarily for tests.
  final GoogleSearchViewBuilder? googleSearchViewBuilder;

  /// The map assistant, or null to leave the workspace without one.
  ///
  /// Opening the panel reserves space beside or below the workspace so map
  /// controls and drawing gestures remain accessible.
  final MapAssistant? assistant;

  @override
  State<GisMapScreen> createState() => _GisMapScreenState();
}

class _GisMapScreenState extends State<GisMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  _WebSearchRequest? _webSearch;
  bool _assistantOpen = false;
  final AssistantComposer _composer = AssistantComposer();
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
    _composer.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assistant = widget.assistant;
    if (assistant == null) {
      return _workspace();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (WorkspaceLayout.isCompact(constraints.biggest)) {
          return _workspace();
        }
        final panelWidth = math.min(400.0, constraints.maxWidth * 0.4);
        return Stack(
          children: [
            Positioned.fill(
              right: _assistantOpen ? panelWidth : 0,
              child: _workspace(),
            ),
            if (_assistantOpen)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: panelWidth,
                child: SafeArea(
                  child: AssistantPanel(
                    assistant: assistant,
                    composer: _composer,
                    onClose: () => setState(() => _assistantOpen = false),
                  ),
                ),
              )
            else
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  key: const Key('open-assistant-button'),
                  tooltip: 'Ask about the map',
                  onPressed: () => setState(() => _assistantOpen = true),
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openPhoneAssistant() async {
    final assistant = widget.assistant;
    if (assistant == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) => AssistantPanel(
                assistant: assistant,
                composer: _composer,
                compact: true,
                contextLabel:
                    widget.viewModel.selectedAddress?.fullAddress ??
                    widget.viewModel.selectedParcel?.situsAddress ??
                    (widget.viewModel.areaSelection != null
                        ? '${widget.viewModel.countyName} · Drawn area'
                        : '${widget.viewModel.countyName} · Map view'),
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workspace() {
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
                if (constraints.maxWidth >= _desktopBreakpoint &&
                    constraints.maxHeight >= _desktopMinHeight) {
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
                    webSearch: _webSearch,
                    googleSearchViewBuilder: widget.googleSearchViewBuilder,
                    onWebSearch: _openWebSearch,
                    onCloseWebSearch: _closeWebSearch,
                  );
                }
                if (constraints.maxWidth >= _tabletBreakpoint &&
                    constraints.maxHeight >= _desktopMinHeight) {
                  return _TabletWorkspace(
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
                    webSearch: _webSearch,
                    googleSearchViewBuilder: widget.googleSearchViewBuilder,
                    onWebSearch: _openWebSearch,
                    onCloseWebSearch: _closeWebSearch,
                  );
                }
                // A narrow workspace on a large screen is one sharing the
                // screen with docked chat, which is already open.
                return _CompactWorkspace(
                  onAssistant:
                      widget.assistant == null ||
                          !WorkspaceLayout.compactOf(context)
                      ? null
                      : _openPhoneAssistant,
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
                  webSearch: _webSearch,
                  googleSearchViewBuilder: widget.googleSearchViewBuilder,
                  onWebSearch: _openWebSearch,
                  onCloseWebSearch: _closeWebSearch,
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

  void _openWebSearch(_WebSearchRequest request) {
    setState(() => _webSearch = request);
  }

  void _closeWebSearch() {
    setState(() => _webSearch = null);
  }

  void _handleEscape() {
    final routing = widget.viewModel.routing;
    if (routing != null && (routing.panelOpen || routing.pickingStop != null)) {
      routing.showPanel(false);
      return;
    }
    if (_webSearch != null) {
      _closeWebSearch();
      return;
    }
    if (widget.viewModel.areaSelectMode) {
      widget.viewModel.setAreaSelectMode(false);
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
    required this.webSearch,
    required this.googleSearchViewBuilder,
    required this.onWebSearch,
    required this.onCloseWebSearch,
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
  final _WebSearchRequest? webSearch;
  final GoogleSearchViewBuilder? googleSearchViewBuilder;
  final ValueChanged<_WebSearchRequest> onWebSearch;
  final VoidCallback onCloseWebSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = (constraints.maxWidth * 0.28).clamp(380.0, 440.0);
        final panelWidth = ((constraints.maxWidth - paneWidth) * 0.55).clamp(
          320.0,
          480.0,
        );
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: paneWidth,
                  child: _ControlPane(
                    viewModel: viewModel,
                    countySelection: countySelection,
                    searchController: searchController,
                    searchFocus: searchFocus,
                    onAddressSelected: onAddressSelected,
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
                    onWebSearch: onWebSearch,
                    showSelectionCard: true,
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerRight,
                    child: webSearch == null
                        ? const SizedBox.shrink()
                        : Row(
                            key: ValueKey(webSearch),
                            children: [
                              VerticalDivider(
                                width: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              SizedBox(
                                width: panelWidth,
                                child: _buildWebSearchPanel(
                                  webSearch!,
                                  googleSearchViewBuilder,
                                  onCloseWebSearch,
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

/// The layout for tablets and for phones held sideways.
///
/// Wide enough for the control pane beside the map, but not wide enough to
/// also give the search panel a column of its own: it arrives as a side sheet
/// over the map instead, so opening it never squeezes the map to a strip.
class _TabletWorkspace extends StatelessWidget {
  const _TabletWorkspace({
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
    required this.webSearch,
    required this.googleSearchViewBuilder,
    required this.onWebSearch,
    required this.onCloseWebSearch,
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
  final _WebSearchRequest? webSearch;
  final GoogleSearchViewBuilder? googleSearchViewBuilder;
  final ValueChanged<_WebSearchRequest> onWebSearch;
  final VoidCallback onCloseWebSearch;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrower than the desktop pane, but not so narrow that the layer
        // rows wrap to four lines each; the map keeps the majority of the
        // width at every tablet size either way.
        final paneWidth = (constraints.maxWidth * 0.44).clamp(320.0, 380.0);
        final panelWidth = (constraints.maxWidth * 0.62).clamp(320.0, 560.0);
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: paneWidth,
                      child: _ControlPane(
                        viewModel: viewModel,
                        countySelection: countySelection,
                        searchController: searchController,
                        searchFocus: searchFocus,
                        onAddressSelected: onAddressSelected,
                        // A phone on its side is this wide and half as tall;
                        // the pane's header gives up its padding so the list
                        // underneath keeps its rows.
                        dense: constraints.maxHeight < _desktopMinHeight,
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
                        onWebSearch: onWebSearch,
                        showSelectionCard: true,
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: _WebSearchSideSheet(
                    request: webSearch,
                    viewBuilder: googleSearchViewBuilder,
                    onClose: onCloseWebSearch,
                    width: panelWidth,
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

/// The search panel as a sheet sliding in over the map.
///
/// The layouts too narrow to give the panel a column of its own share this:
/// it dims what is behind it, closes on a tap outside, and takes no layout
/// width, so the map keeps the size it had before the panel opened.
class _WebSearchSideSheet extends StatelessWidget {
  const _WebSearchSideSheet({
    required this.request,
    required this.viewBuilder,
    required this.onClose,
    required this.width,
  });

  /// The search to show, or null when the sheet is closed.
  final _WebSearchRequest? request;

  final GoogleSearchViewBuilder? viewBuilder;
  final VoidCallback onClose;

  /// How wide the sheet is when open.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: request == null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: request == null ? 0 : 1,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
                child: GestureDetector(onTap: onClose),
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
            child: request == null
                ? const SizedBox.shrink()
                : Align(
                    key: ValueKey(request),
                    alignment: Alignment.centerRight,
                    child: SafeArea(
                      left: false,
                      child: SizedBox(
                        width: width,
                        child: _buildWebSearchPanel(
                          request!,
                          viewBuilder,
                          onClose,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
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
    this.dense = false,
  });

  final GisMapViewModel viewModel;
  final CountySelection? countySelection;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<Address> onAddressSelected;

  /// Whether the pane is short enough that its header has to earn its height.
  ///
  /// A phone held sideways is barely 400pt tall: the wordmark is the first
  /// thing to go, because the county menu and the search field under it are
  /// what the pane is for.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: dense
                ? const EdgeInsets.fromLTRB(20, 10, 20, 8)
                : const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: _BrandHeader(
              mode: viewModel.mode,
              countyName: viewModel.countyName,
              countySelection: countySelection,
              canSwitchCounty: !viewModel.snapshotStatus.isImporting,
              dense: dense,
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
                // Keyed by the rectangle itself, not by whether there is one,
                // so a second area drawn while the first is listed replaces
                // the list rather than pouring new rows into it at the old
                // scroll position.
                key: ValueKey((
                  viewModel.searchResults.isNotEmpty,
                  viewModel.areaSelection?.bounds.west,
                  viewModel.areaSelection?.bounds.south,
                  viewModel.areaSelection?.bounds.east,
                  viewModel.areaSelection?.bounds.north,
                )),
                viewModel: viewModel,
                onAddressSelected: onAddressSelected,
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
    this.dense = false,
  });

  final DataMode mode;
  final String countyName;
  final CountySelection? countySelection;
  final bool canSwitchCounty;

  /// Whether to drop the mark and the wordmark for want of vertical room.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (!dense) ...[
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
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!dense) Text('Atlas', style: theme.textTheme.titleLarge),
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
    // ⌘K is offered only where there is a keyboard to press it on. On a
    // touch platform it would be a hint about a shortcut that does not exist,
    // taking the space where the clear button appears once there is text.
    final showShortcutHint = Theme.of(context).platform == TargetPlatform.macOS;
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
              ? (showShortcutHint
                    ? Tooltip(
                        message: 'Press ⌘K to search',
                        child: const Icon(Icons.keyboard_command_key, size: 18),
                      )
                    : null)
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
    super.key,
  });

  final GisMapViewModel viewModel;
  final ValueChanged<Address> onAddressSelected;

  @override
  Widget build(BuildContext context) {
    if (viewModel.searchResults.isNotEmpty) {
      return _SearchResults(
        results: viewModel.searchResults,
        stateCode: viewModel.stateCode,
        onSelected: onAddressSelected,
      );
    }
    // The selected property is no longer shown here: it floats over the map
    // beside the parcel it describes. The pane carries the drawn area's
    // address list instead, which is a list and belongs in a list-shaped
    // space.
    if (viewModel.areaSelection case final selection?) {
      return AreaResultsPanel(
        viewModel: viewModel,
        selection: selection,
        onAddressSelected: onAddressSelected,
      );
    }
    return _ToolsContent(viewModel: viewModel);
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.onSelected,
    required this.stateCode,
  });
  final String stateCode;

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
                  subtitle: Text(
                    '${address.city}, $stateCode ${address.zipCode}',
                  ),
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

class _ToolsContent extends StatelessWidget {
  const _ToolsContent({required this.viewModel});

  final GisMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
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
        if (viewModel.parcelSourceLabel != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: viewModel.forgetParcelSource,
              child: const Text('Forget parcel source'),
            ),
          ),
        const SizedBox(height: 10),
        if (viewModel.coverageMessage case final message?) ...[
          _CoverageNotice(message: message),
          const SizedBox(height: 10),
        ],
        Card(
          child: Column(
            children: [
              _LayerSwitch(
                key: const Key('address-layer-switch'),
                icon: Icons.home_work_outlined,
                title: 'Address points',
                subtitle: viewModel.parcelsAvailable
                    ? (viewModel.parcelSourceLabel == null
                          ? 'Select a marker to inspect its address'
                          : 'From ${viewModel.parcelSourceLabel}')
                    : 'No public address layer covers this county',
                value: viewModel.addressesVisible,
                onChanged: viewModel.parcelsAvailable
                    ? viewModel.setAddressesVisible
                    : null,
              ),
              const Divider(height: 1, indent: 58),
              _LayerSwitch(
                key: const Key('parcel-layer-switch'),
                icon: Icons.grid_4x4_outlined,
                title: 'Parcel boundaries',
                subtitle: viewModel.parcelsAvailable
                    ? (viewModel.parcelSourceLabel == null
                          ? 'Property facts from the assessor layer'
                          : 'From ${viewModel.parcelSourceLabel}')
                    : 'No public parcel layer covers this county',
                value: viewModel.parcelsVisible,
                onChanged: viewModel.parcelsAvailable
                    ? viewModel.setParcelsVisible
                    : null,
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
        if (viewModel.portals.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel(
            label: 'COUNTY MAP LAYERS',
            icon: Icons.layers_outlined,
          ),
          const SizedBox(height: 10),
          _CatalogCard(viewModel: viewModel),
        ],
        if (viewModel.imageryAvailable) ...[
          const SizedBox(height: 24),
          _SectionLabel(
            label: 'HISTORICAL IMAGERY',
            icon: Icons.satellite_alt_outlined,
          ),
          const SizedBox(height: 10),
          _ImageryCard(viewModel: viewModel),
        ],
        if (viewModel.parcelsAvailable) ...[
          const SizedBox(height: 24),
          _SectionLabel(
            label: 'OFFLINE SNAPSHOT',
            icon: Icons.download_outlined,
          ),
          const SizedBox(height: 10),
          _SnapshotCard(viewModel: viewModel),
        ],
        const SizedBox(height: 20),
        _SourceNotice(countyName: viewModel.countyName),
      ],
    );
  }
}

/// One line describing what the catalogue holds and how it was found.
///
/// The old wording called every wide-area catalogue "statewide", which was
/// never true of the National Weather Service and is misleading in the 49
/// states with no state tier at all. It also could not say that a search was
/// still running, so a county outside the inventoried state read as having
/// nothing rather than as not having looked yet.
String _catalogSummary(
  GisMapViewModel viewModel,
  int localCount,
  int wideCount,
) {
  if (!viewModel.overlaysAvailable) {
    return 'Live mode only; not stored in snapshots';
  }
  final wide = '$wideCount state and federal';
  if (localCount > 0) {
    return '$localCount local and $wide catalogues';
  }
  // "None published locally" is a claim, and it is only true once something
  // has looked. Before that the honest line is that the search has not
  // finished, which is also what the user sees for the first second.
  return switch (viewModel.discoveryStatus) {
    PortalDiscoveryStatus.idle when viewModel.discoveryAvailable =>
      'Looking for local catalogues\u2026',
    PortalDiscoveryStatus.searching => 'Looking for local catalogues\u2026',
    PortalDiscoveryStatus.unavailable =>
      '$wide catalogues; local search unavailable',
    _ => '$wide catalogues; none published locally',
  };
}

/// Entry point to everything the county's catalogues publish.
///
/// The catalogue itself is a sheet rather than another section of this pane:
/// a county publishes hundreds of services, and the control pane is for the
/// handful of layers the app understands.
class _CatalogCard extends StatefulWidget {
  const _CatalogCard({required this.viewModel});

  final GisMapViewModel viewModel;

  @override
  State<_CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends State<_CatalogCard> {
  @override
  void initState() {
    super.initState();
    _discover();
  }

  @override
  void didUpdateWidget(_CatalogCard old) {
    super.didUpdateWidget(old);
    // Switching county replaces the view model but not this widget, so
    // Flutter reuses this State and [initState] does not run again. Without
    // this, every county after the first would report only its federal tier.
    if (!identical(old.viewModel, widget.viewModel)) {
      _discover();
    }
  }

  /// Asks what else publishes here, once the current frame is done.
  ///
  /// The pane says how many catalogues this county has, so it has to ask
  /// before the user opens anything — otherwise every county outside the
  /// inventoried state reads as having only the federal tier until the sheet
  /// is opened. Deferred past the frame because discovery notifies listeners.
  void _discover() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.viewModel.discoverPortals();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final theme = Theme.of(context);
    final active = viewModel.activeOverlays;
    final local = viewModel.portals.where((portal) => !portal.isWideArea);
    final localCount = local.length;
    final wideCount = viewModel.portals.length - localCount;
    return Card(
      child: Column(
        children: [
          ListTile(
            key: const Key('open-layer-catalog'),
            leading: const Icon(Icons.travel_explore_outlined),
            title: Text(
              active.isEmpty
                  ? 'Browse published layers'
                  : '${active.length} on',
            ),
            subtitle: Text(_catalogSummary(viewModel, localCount, wideCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => FractionallySizedBox(
                heightFactor: 0.9,
                child: LayerCatalogSheet(viewModel: viewModel),
              ),
            ),
          ),
          if (active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final overlay in active)
                    InputChip(
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: overlay.color,
                      ),
                      label: Text(
                        overlay.service.title,
                        style: theme.textTheme.labelSmall,
                      ),
                      onDeleted: () => viewModel.toggleOverlay(overlay.service),
                    ),
                ],
              ),
            ),
        ],
      ),
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

/// Says why a county's parcel and address controls are switched off.
///
/// There is no national parcel layer. Most counties in the country are
/// covered by neither a state fabric nor a service of their own, and a map
/// that simply drew nothing would read as broken rather than as empty. What
/// still works is said alongside what does not, because the boundary, the
/// catalogues and every overlay tier are the reason to stay on this county.
class _CoverageNotice extends StatelessWidget {
  const _CoverageNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('coverage-notice'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
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
  const _SelectionCard({
    required this.viewModel,
    required this.onWebSearch,
    this.compact = false,
  });

  final bool compact;

  final GisMapViewModel viewModel;
  final ValueChanged<_WebSearchRequest> onWebSearch;

  @override
  Widget build(BuildContext context) {
    final address = viewModel.selectedAddress;
    final parcel = viewModel.selectedParcel;
    final addressQuery = switch ((address, parcel)) {
      (final address?, _) => _searchableAddress(
        address.fullAddress,
        propertyLocationLine(
          stateCode: viewModel.stateCode,
          city: address.city,
          zipCode: address.zipCode,
        ),
      ),
      (_, final parcel?) when parcel.situsAddress.isNotEmpty =>
        _searchableAddress(
          parcel.situsAddress,
          propertyLocationLine(
            stateCode: viewModel.stateCode,
            city: parcel.city,
            zipCode: parcel.zipCode,
          ),
        ),
      _ => null,
    };
    final clipboardText = propertyClipboardText(
      parcelSourceLabel: viewModel.parcelSourceLabel,
      stateCode: viewModel.stateCode,
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
                if (!compact && clipboardText != null) ...[
                  _CopyButton(
                    key: const Key('copy-selection-button'),
                    tooltip: 'Copy all details',
                    icon: Icons.copy_all_outlined,
                    text: clipboardText,
                    confirmation: 'Property details copied',
                  ),
                  const SizedBox(width: 4),
                ],
                if (!compact && addressQuery != null) ...[
                  _GoogleSearchButton(
                    key: const Key('google-address-search-button'),
                    tooltip: 'Search this address on Google',
                    onPressed: () => onWebSearch(
                      _WebSearchRequest(
                        query: addressQuery,
                        searchSubject: 'Address',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!compact)
                  IconButton(
                    tooltip: 'Close details',
                    onPressed: viewModel.clearSelection,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 8),
              Text(
                'APN ${parcel?.apn ?? address?.apn ?? "Not provided"}',
                style: theme.textTheme.bodyMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (clipboardText != null) ...[
                    _CopyButton(
                      key: const Key('copy-selection-button'),
                      tooltip: 'Copy all details',
                      text: clipboardText,
                      confirmation: 'Property details copied',
                    ),
                    Builder(
                      builder: (context) => TextButton.icon(
                        key: const Key('share-property-button'),
                        onPressed: () => shareProperty(context, clipboardText),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                  if (addressQuery != null)
                    TextButton.icon(
                      key: const Key('google-address-search-button'),
                      onPressed: () => onWebSearch(
                        _WebSearchRequest(
                          query: addressQuery,
                          searchSubject: 'Address',
                        ),
                      ),
                      icon: const Icon(Icons.travel_explore),
                      label: const Text('Research'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (address != null) ...[
              _LocationDetailRow(
                stateCode: viewModel.stateCode,
                city: address.city,
                zipCode: address.zipCode,
              ),
              if (address.unit.isNotEmpty)
                _DetailRow(label: 'UNIT', value: address.unit),
              _OwnerDetailRow(viewModel: viewModel, onWebSearch: onWebSearch),
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
                value:
                    viewModel.parcelSourceLabel ??
                    '${viewModel.countyName} Address Points',
              ),
            ],
            if (parcel != null) ...[
              _OwnerDetailRow(viewModel: viewModel, onWebSearch: onWebSearch),
              _UnclaimedPropertyDetail(viewModel: viewModel),
              _ApnDetailRow(label: 'APN', apn: parcel.apn),
              if (parcel.situsAddress.isEmpty &&
                  viewModel.resolvedSitus != null) ...[
                _DetailRow(
                  key: const Key('resolved-situs-row'),
                  label: 'STREET',
                  value: viewModel.resolvedSitus!.formatAddress(
                    viewModel.stateCode,
                  ),
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
                stateCode: viewModel.stateCode,
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
                value:
                    viewModel.parcelSourceLabel ??
                    '${viewModel.countyName} Assessor',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OwnerDetailRow extends StatelessWidget {
  const _OwnerDetailRow({required this.viewModel, required this.onWebSearch});

  final GisMapViewModel viewModel;
  final ValueChanged<_WebSearchRequest> onWebSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = viewModel.ownerLookupStatus;
    final ownership = viewModel.propertyOwnership;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Flex(
        direction: WorkspaceLayout.compactOf(context)
            ? Axis.vertical
            : Axis.horizontal,
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
          _OwnerValue(
            child: switch (status) {
              OwnerLookupStatus.loading => const Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('Looking up public owner record…')),
                ],
              ),
              OwnerLookupStatus.found => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        ownership?.ownerName ?? '',
                        style: theme.textTheme.bodyMedium,
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
                          onPressed: () => onWebSearch(
                            _WebSearchRequest(
                              query: owner.ownerName,
                              searchSubject: 'Owner name',
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('claimit-owner-search-button'),
                          tooltip:
                              'Search this owner name on California ClaimIt',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(
                            Icons.account_balance_outlined,
                            size: 18,
                          ),
                          onPressed: () => onWebSearch(
                            _WebSearchRequest(
                              query: owner.ownerName,
                              searchSubject: 'Owner name',
                              claimItQuery: UnclaimedPropertyQuery.fromOwner(
                                ownerName: owner.ownerName,
                                city: '',
                                zipCode: '',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${viewModel.parcelSourceLabel ?? ownership?.sourceUri.host ?? viewModel.countyName}'
                    '${ownership?.isSaved == true ? ' • saved locally' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              OwnerLookupStatus.notFound => _OwnerLookupMessage(
                message: 'No exact public owner-record match',
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

class _OwnerValue extends StatelessWidget {
  const _OwnerValue({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      WorkspaceLayout.compactOf(context) ? child : Expanded(child: child);
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
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
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
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
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
  const _LocationDetailRow({
    required this.city,
    required this.zipCode,
    required this.stateCode,
  });

  final String stateCode;

  final String city;
  final String zipCode;

  @override
  Widget build(BuildContext context) {
    final location = propertyLocationLine(
      stateCode: stateCode,
      city: city,
      zipCode: zipCode,
    );
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
    if (WorkspaceLayout.compactOf(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                ?trailing,
              ],
            ),
          ],
        ),
      );
    }
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
  _MapSurface({
    required this.viewModel,
    required this.mapController,
    required this.initialCenter,
    required this.initialBounds,
    required this.countySelection,
    required this.viewportCounty,
    required this.onCenterChanged,
    required this.enableBaseMap,
    required this.onWebSearch,
    this.showSelectionCard = false,
    this.compact = false,
    this.onDrawn,
    this.draftArea,
    this.onDraftChanged,
    this.onOpenAreaResults,
    this.overlayPadding = EdgeInsets.zero,
  }) : super(key: GlobalObjectKey(mapController));

  // Keep the map's camera and gestures when docking chat changes the workspace
  // layout. Remounting FlutterMap would apply its initial county bounds again.

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

  /// Opens the search panel for a property shown in the floating card.
  final ValueChanged<_WebSearchRequest> onWebSearch;

  /// Whether the selected property floats over the map here.
  ///
  /// The desktop layout shows it here; the compact layout has its own place
  /// for it at the bottom of the screen, clear of the thumb.
  final bool showSelectionCard;
  final bool compact;
  final ValueChanged<AreaShape>? onDrawn;
  final AreaShape? draftArea;
  final ValueChanged<AreaShape>? onDraftChanged;

  /// Opens the drawn area's address list, where it is not already on screen.
  ///
  /// The desktop layout keeps the list in its side pane and passes nothing.
  final VoidCallback? onOpenAreaResults;

  /// Space reserved around the map for chrome drawn by the parent, such as the
  /// compact layout's floating search bar.
  final EdgeInsets overlayPadding;

  /// Width kept clear on the right of the compact status pills for the
  /// map buttons.
  static const double _compactButtonsGutter = 76;

  /// Whether the map left between the compact chrome fits the button stack.
  bool _roomForMapButtons(BuildContext context) =>
      MediaQuery.sizeOf(context).height - overlayPadding.vertical >=
      MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5) * 220;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel.routing?.dragActivity ?? viewModel,
    builder: (context, _) => _buildMap(context),
  );

  Widget _buildMap(BuildContext context) {
    final theme = Theme.of(context);
    final mapColors = theme.extension<MapColors>()!;
    final boundary = viewModel.boundary;
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
            // A phone needs this wider view to navigate across the country.
            minZoom: 2,
            maxZoom: 20,
            // Data coverage controls the layers, not where users can pan.
            cameraConstraint: const CameraConstraint.unconstrained(),
            backgroundColor: theme.colorScheme.surfaceContainer,
            onMapReady: () {
              final camera = mapController.camera;
              _sendViewport(camera);
            },
            onPositionChanged: (camera, _) => _sendViewport(camera),
            onTap: (_, point) => _handleTap(point),
            // A drag draws the rectangle while the area tool is armed, so the
            // gestures that would move the map underneath it are off.
            interactionOptions: viewModel.routing?.dragging == true
                ? const InteractionOptions(flags: InteractiveFlag.none)
                : viewModel.areaSelectMode
                ? const InteractionOptions(
                    flags:
                        InteractiveFlag.all &
                        ~InteractiveFlag.drag &
                        ~InteractiveFlag.flingAnimation &
                        ~InteractiveFlag.pinchMove,
                  )
                : const InteractionOptions(),
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
            // County overlays sit above the basemap and below the boundary,
            // parcels and selection: a layer switched on for context must
            // never hide the property the user is looking at.
            for (final overlay in viewModel.activeOverlays)
              if (overlay.isImagery)
                Opacity(
                  opacity: overlay.opacity,
                  child: TileLayer(
                    key: ValueKey('overlay-${overlay.id}'),
                    urlTemplate: overlay.service.uri.toString(),
                    tileProvider:
                        overlay.service.render == OverlayRender.imageServer
                        ? ArcGisImageTileProvider()
                        : ArcGisExportTileProvider(),
                    userAgentPackageName: 'com.skippy.riversideAtlas',
                    maxNativeZoom: 20,
                    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                  ),
                )
              else ...[
                PolygonLayer(
                  polygons: [
                    for (final feature in overlay.features)
                      for (final ring in feature.rings)
                        Polygon(
                          points: ring,
                          color: overlay.color.withValues(
                            alpha: 0.18 * overlay.opacity,
                          ),
                          borderColor: overlay.color.withValues(
                            alpha: overlay.opacity,
                          ),
                          borderStrokeWidth: 1.6,
                        ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    for (final feature in overlay.features)
                      for (final path in feature.paths)
                        Polyline(
                          points: path,
                          color: overlay.color.withValues(
                            alpha: overlay.opacity,
                          ),
                          strokeWidth: 2.4,
                        ),
                  ],
                ),
                CircleLayer(
                  circles: [
                    for (final feature in overlay.features)
                      for (final point in feature.points)
                        CircleMarker(
                          point: point,
                          radius: 4,
                          color: overlay.color.withValues(
                            alpha: overlay.opacity,
                          ),
                          borderColor: theme.colorScheme.surface,
                          borderStrokeWidth: 1,
                        ),
                  ],
                ),
              ],
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
                            stateCode: viewModel.stateCode,
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
            if (draftArea case final draft?)
              AreaEditLayer(shape: draft, onChanged: onDraftChanged!)
            else if (viewModel.areaSelection case final area?)
              AreaEditLayer(
                shape: area.shape,
                editable: !viewModel.areaSelectMode && draftArea == null,
                onChanged: viewModel.selectArea,
              ),
            if (viewModel.routing case final routing?)
              RouteMapLayer(
                model: routing,
                editable: !viewModel.areaSelectMode && draftArea == null,
                controller: mapController,
                reserved: overlayPadding,
                managedPanel: compact,
              ),
            _MapAttribution(
              imagery: viewModel.selectedImagery,
              creditsOpenStreetMapData:
                  viewModel.alprCamerasVisible || viewModel.routing != null,
              countyName: viewModel.countyName,
            ),
          ],
        ),
        // On a phone the buttons give way to a draft being edited and to a
        // sheet tall enough that they would sit on it. They stay otherwise:
        // they are the only zoom a VoiceOver user has.
        if (!compact || (draftArea == null && _roomForMapButtons(context)))
          Positioned(
            right: overlayPadding.right + (compact ? 12 : 18),
            top: overlayPadding.top + (compact ? 12 : 18),
            child: _MapButtons(
              countyName: viewModel.countyName,
              areaSelectActive: viewModel.areaSelectMode,
              onToggleAreaSelect: () =>
                  viewModel.setAreaSelectMode(!viewModel.areaSelectMode),
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
        if (!compact ||
            (overlayPadding.bottom < MediaQuery.sizeOf(context).height * .7 &&
                !viewModel.areaSelectMode &&
                draftArea == null))
          Positioned(
            left: overlayPadding.left + 16,
            right: compact
                ? overlayPadding.right + _compactButtonsGutter
                : null,
            top: overlayPadding.top + 16,
            bottom: overlayPadding.bottom + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                if (onOpenAreaResults case final openResults?)
                  if (viewModel.areaSelection case final area?) ...[
                    const SizedBox(height: 8),
                    _AreaResultsPill(selection: area, onPressed: openResults),
                  ],
                if (viewModel.identifiedOverlay case final identified?
                    when !compact)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: _selectionCardWidth,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: _OverlayIdentifyCard(
                            identified: identified,
                            onClose: viewModel.clearIdentifiedOverlay,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showSelectionCard &&
                    (viewModel.selectedAddress != null ||
                        viewModel.selectedParcel != null))
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: _selectionCardWidth,
                        // The map is directly underneath: without this, a tap on
                        // the card's background falls through and selects the
                        // parcel it is covering.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: SingleChildScrollView(
                            child: _SelectionCard(
                              viewModel: viewModel,
                              onWebSearch: onWebSearch,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (viewModel.routing case final routing? when !compact)
          Positioned.fill(
            child: RouteBuilderOverlay(
              model: routing,
              padding: overlayPadding,
              near: () => mapController.camera.center,
              onOpen: () => viewModel.setAreaSelectMode(false),
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
        if (viewModel.areaSelectMode)
          Positioned.fill(
            key: const Key('area-select-overlay'),
            child: AreaSelectOverlay(
              mapController: mapController,
              tool: viewModel.areaTool,
              onToolChanged: viewModel.setAreaTool,
              onDrawn: onDrawn ?? viewModel.selectArea,
              onCancel: () => viewModel.setAreaSelectMode(false),
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

  /// Identifies an overlay feature under the tap, or selects a parcel.
  ///
  /// Overlays are offered the tap first: they are what the user just switched
  /// on, and a parcel is still one tap away anywhere they have not drawn.
  void _handleTap(LatLng point) {
    if (viewModel.routing?.acceptMapPoint(point) ?? false) return;
    // Roughly ten logical pixels of slack, converted to degrees at the
    // current zoom, so a point feature stays tappable at every scale.
    final tolerance = 10 * 360 / (256 * math.pow(2, mapController.camera.zoom));
    if (viewModel.identifyOverlayAt(point, tolerance: tolerance.toDouble())) {
      return;
    }
    viewModel.clearIdentifiedOverlay();
    viewModel.selectParcelAt(point);
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

/// The attributes of one tapped overlay feature.
///
/// Deliberately a plain field/value list: this app has not read the schema of
/// an arbitrary county layer, so it shows what the publisher published rather
/// than inventing labels for it.
class _OverlayIdentifyCard extends StatelessWidget {
  const _OverlayIdentifyCard({required this.identified, required this.onClose});

  final OverlayIdentification identified;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = identified.fields;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.circle, size: 14, color: identified.color),
            title: Text(
              identified.title,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
              onPressed: onClose,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: fields.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This feature carries no attributes.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: fields.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final (:field, :value) = fields[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SelectableText(
                              value,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddressMarker extends StatelessWidget {
  const _AddressMarker({
    required this.stateCode,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final String stateCode;
  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MapColors>()!;
    final color = selected ? colors.addressSelected : colors.address;
    return Semantics(
      button: true,
      label: 'View ${address.formatAddress(stateCode)}',
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
    required this.areaSelectActive,
    required this.onToggleAreaSelect,
  });

  /// County named in the fit-to-boundary tooltip.
  final String countyName;

  /// Whether a drag on the map currently draws a rectangle.
  final bool areaSelectActive;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onToggleAreaSelect;

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
          const Divider(height: 1),
          IconButton(
            key: const Key('area-select-tool-button'),
            tooltip: areaSelectActive
                ? 'Cancel area selection'
                : 'List the addresses in an area',
            isSelected: areaSelectActive,
            onPressed: onToggleAreaSelect,
            icon: const Icon(Icons.highlight_alt_outlined),
            selectedIcon: const Icon(Icons.highlight_alt),
          ),
        ],
      ),
    );
  }
}

/// The compact layout's way back into the drawn area's address list.
class _AreaResultsPill extends StatelessWidget {
  const _AreaResultsPill({required this.selection, required this.onPressed});

  final AreaSelection selection;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('area-results-pill'),
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.list_alt_outlined, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  areaSelectionHeadline(selection),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
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
