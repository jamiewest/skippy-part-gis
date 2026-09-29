part of 'gis_map_screen.dart';

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    required this.viewModel,
    this.onAssistant,
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

  final VoidCallback? onAssistant;
  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

enum _PhoneSurface {
  property,
  results,
  layers,
  catalog,
  route,
  more,
  downloads,
  overlay,
  layerDetail,
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  _PhoneSurface? _surface;
  double _fraction = .5;
  Object? _selection;
  Object? _identified;
  bool _routeWasOpen = false;
  bool _syncPending = false;
  AreaShape? _draft;
  ActiveOverlay? _activeOverlay;
  final PageStorageBucket _storage = PageStorageBucket();
  GisMapViewModel get model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    model.addListener(_sync);
    model.routing?.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    model.removeListener(_sync);
    model.routing?.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (_syncPending) return;
    _syncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPending = false;
      if (!mounted) return;
      setState(() {
        final selection = model.selectedParcel ?? model.selectedAddress;
        if (selection != _selection) {
          _selection = selection;
          if (selection != null) {
            _surface = _PhoneSurface.property;
            _fraction = .32;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _revealSelection(),
            );
          } else if (_surface == _PhoneSurface.property) {
            _surface = null;
          }
        }
        if (model.identifiedOverlay != _identified) {
          _identified = model.identifiedOverlay;
          if (_identified != null) {
            _surface = _PhoneSurface.overlay;
            _fraction = .5;
          }
        }
        final routeOpen = model.routing?.panelOpen ?? false;
        if (routeOpen && !_routeWasOpen) {
          _surface = _PhoneSurface.route;
          _fraction = .5;
        } else if (!routeOpen && _surface == _PhoneSurface.route) {
          _surface = null;
        }
        _routeWasOpen = routeOpen;
      });
    });
  }

  void _show(_PhoneSurface surface) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (surface != _PhoneSurface.route) model.routing?.showPanel(false);
    model.setAreaSelectMode(false);
    setState(() {
      _draft = null;
      _surface = surface;
      _fraction = .5;
    });
  }

  void _close() {
    if (_surface == _PhoneSurface.route) model.routing?.showPanel(false);
    setState(() => _surface = null);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  double get _textGrowth =>
      (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 1).toDouble();
  double get _barHeight => 68.0 + _textGrowth * 18;
  double get _headerHeight => 60.0 + _textGrowth * 20;

  void _revealSelection() {
    if (!mounted) return;
    final camera = widget.mapController.camera;
    final point =
        model.selectedAddress?.position ??
        (model.selectedParcel == null
            ? null
            : LatLng(
                (model.selectedParcel!.bounds.north +
                        model.selectedParcel!.bounds.south) /
                    2,
                (model.selectedParcel!.bounds.east +
                        model.selectedParcel!.bounds.west) /
                    2,
              ));
    if (point == null) return;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final sheet = (size.height - safe.vertical - _barHeight - 12) * _fraction;
    // Centre the property in the map left visible between header and sheet.
    widget.mapController.move(
      point,
      camera.zoom,
      offset: Offset(
        0,
        (safe.top + _headerHeight - safe.bottom - _barHeight - sheet) / 2,
      ),
    );
  }

  Future<void> _search() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Search addresses')),
          body: SafeArea(
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _SearchField(
                      controller: widget.searchController,
                      focusNode: widget.searchFocus,
                      viewModel: model,
                    ),
                  ),
                  Expanded(
                    child: model.searchResults.isEmpty
                        ? Center(
                            child: Text(
                              model.isSearching
                                  ? 'Searching…'
                                  : 'Search for an address in ${model.countyName}.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _SearchResults(
                            results: model.searchResults,
                            stateCode: model.stateCode,
                            onSelected: (address) {
                              widget.onAddressSelected(address);
                              Navigator.of(context).pop();
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    widget.searchFocus.unfocus();
  }

  void _openSearch() {
    _search();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.searchFocus.requestFocus(),
    );
  }

  void _web(_WebSearchRequest request) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: _buildWebSearchPanel(
              request,
              widget.googleSearchViewBuilder,
              () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _startDrawing() {
    _close();
    setState(() => _draft = null);
    model.setAreaSelectMode(true);
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final drawing = model.areaSelectMode || _draft != null;
    final picking = model.routing?.pickingStop != null;
    final barHeight = _barHeight;
    final headerHeight = _headerHeight;
    return PopScope(
      canPop: _surface == null && !drawing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (drawing) {
          setState(() => _draft = null);
          model.setAreaSelectMode(false);
        } else {
          _close();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final maxSheet = math.max(
              0.0,
              constraints.maxHeight - safe.top - safe.bottom - barHeight - 12,
            );
            final showSheet = _surface != null && !drawing && !picking;
            final height = showSheet
                ? (maxSheet * _fraction)
                      .clamp(math.min(170.0, maxSheet), maxSheet)
                      .toDouble()
                : 0.0;
            final expanded = showSheet && height > maxSheet * .8;
            final padding = EdgeInsets.fromLTRB(
              safe.left,
              safe.top + headerHeight,
              safe.right,
              safe.bottom + barHeight + height,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: _MapSurface(
                    viewModel: model,
                    mapController: widget.mapController,
                    initialCenter: widget.initialCenter,
                    initialBounds: widget.initialBounds,
                    countySelection: widget.countySelection,
                    viewportCounty: widget.viewportCounty,
                    onCenterChanged: widget.onCenterChanged,
                    enableBaseMap: widget.enableBaseMap,
                    onWebSearch: _web,
                    compact: true,
                    overlayPadding: padding,
                    draftArea: _draft,
                    onDraftChanged: (shape) => setState(() => _draft = shape),
                    onDrawn: (shape) {
                      setState(() => _draft = shape);
                      model.setAreaSelectMode(false);
                    },
                    onOpenAreaResults: () => _show(_PhoneSurface.results),
                  ),
                ),
                if (!drawing && !picking && !expanded)
                  Positioned(
                    top: safe.top + 8,
                    left: safe.left + 12,
                    right: safe.right + 12,
                    child: Material(
                      key: const Key('phone-header'),
                      elevation: 3,
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('open-phone-search'),
                            tooltip: 'Search addresses',
                            onPressed: _openSearch,
                            icon: const Icon(Icons.search),
                          ),
                          Expanded(
                            child: widget.countySelection == null
                                ? Text(
                                    model.countyName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : CountyMenuButton(
                                    selection: widget.countySelection!,
                                    enabled: !model.snapshotStatus.isImporting,
                                  ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                if (showSheet)
                  Positioned(
                    left: safe.left,
                    right: safe.right,
                    bottom: safe.bottom + barHeight,
                    child: CompactSheet(
                      title: _title,
                      height: height,
                      maximumHeight: maxSheet,
                      onHeightChanged: (value) =>
                          setState(() => _fraction = value / maxSheet),
                      onClose: _close,
                      onBack:
                          (_surface == _PhoneSurface.catalog ||
                              _surface == _PhoneSurface.layerDetail)
                          ? () => _show(_PhoneSurface.layers)
                          : null,
                      child: PageStorage(bucket: _storage, child: _content()),
                    ),
                  ),
                if (!drawing && !picking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Material(
                      elevation: 8,
                      color: Theme.of(context).colorScheme.surface,
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: barHeight,
                          child: Row(
                            children: [
                              if (widget.onAssistant != null)
                                _action(
                                  'Ask AI',
                                  Icons.auto_awesome_outlined,
                                  widget.onAssistant,
                                  'open-assistant-button',
                                ),
                              _action(
                                'Layers',
                                Icons.layers_outlined,
                                () => _show(_PhoneSurface.layers),
                                'open-phone-layers',
                              ),
                              _action(
                                'Route',
                                Icons.route,
                                model.routing == null
                                    ? null
                                    : () {
                                        _show(_PhoneSurface.route);
                                        model.routing!.showPanel(true);
                                      },
                                'open-route-builder',
                              ),
                              _action(
                                'More',
                                Icons.more_horiz,
                                () => _show(_PhoneSurface.more),
                                'open-map-tools',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (picking)
                  Positioned(
                    left: safe.left + 12,
                    right: safe.right + 12,
                    bottom: safe.bottom + 12,
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      child: ListTile(
                        title: Text(
                          'Tap the map for stop ${model.routing!.pickingStop! + 1}',
                        ),
                        trailing: TextButton(
                          onPressed: () => model.routing!.showPanel(true),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                  ),
                if (_draft != null)
                  Positioned(
                    left: safe.left + 12,
                    right: safe.right + 12,
                    bottom: safe.bottom + 12,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Adjust the area handles'),
                            TextButton(
                              key: const Key('cancel-area-draft-button'),
                              onPressed: () => setState(() => _draft = null),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              key: const Key('confirm-area-draft-button'),
                              onPressed: () {
                                final shape = _draft!;
                                setState(() {
                                  _draft = null;
                                  _surface = _PhoneSurface.results;
                                  _fraction = .5;
                                });
                                model.selectArea(shape);
                              },
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _action(
    String title,
    IconData icon,
    VoidCallback? action,
    String key,
  ) => Expanded(
    child: TextButton(
      key: Key(key),
      onPressed: action,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: const Size(48, 56),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    ),
  );

  String get _title => switch (_surface) {
    _PhoneSurface.property => 'Property',
    _PhoneSurface.results => 'Area results',
    _PhoneSurface.layerDetail => 'Layer details',
    _PhoneSurface.layers => 'Layers & imagery',
    _PhoneSurface.catalog => 'Published layers',
    _PhoneSurface.route => 'Route',
    _PhoneSurface.more => 'Map tools',
    _PhoneSurface.downloads => 'Offline downloads',
    _PhoneSurface.overlay => 'Map feature',
    null => '',
  };

  Widget _content() => switch (_surface) {
    _PhoneSurface.property => ListView(
      key: const PageStorageKey('property'),
      padding: const EdgeInsets.all(8),
      children: [
        if (widget.onAssistant != null)
          TextButton.icon(
            onPressed: widget.onAssistant,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ask AI about this property'),
          ),
        _SelectionCard(viewModel: model, onWebSearch: _web, compact: true),
      ],
    ),
    _PhoneSurface.results =>
      model.areaSelection == null
          ? const Center(child: Text('Draw an area to see its addresses.'))
          : AreaResultsPanel(
              viewModel: model,
              selection: model.areaSelection!,
              onAddressSelected: widget.onAddressSelected,
            ),
    _PhoneSurface.layerDetail => _layerDetails(),
    _PhoneSurface.layers => _layers(),
    _PhoneSurface.catalog => LayerCatalogSheet(viewModel: model, compact: true),
    _PhoneSurface.route => RouteBuilderPanel(
      model: model.routing!,
      near: () => widget.mapController.camera.center,
    ),
    _PhoneSurface.more => ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.draw_outlined),
          title: const Text('Draw an area'),
          onTap: _startDrawing,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Offline downloads'),
          onTap: () => _show(_PhoneSurface.downloads),
        ),
        if (model.areaSelection != null)
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Area results'),
            onTap: () => _show(_PhoneSurface.results),
          ),
      ],
    ),
    _PhoneSurface.downloads => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CoverageNotice(
          message:
              'Download the visible area or the county for offline parcel and address access. Online layers and AI still need a connection.',
        ),
        _SnapshotCard(viewModel: model),
        SegmentedButton<DataMode>(
          segments: const [
            ButtonSegment(value: DataMode.live, label: Text('Live')),
            ButtonSegment(value: DataMode.offline, label: Text('Offline')),
          ],
          selected: {model.mode},
          onSelectionChanged: (values) => model.setMode(values.first),
        ),
      ],
    ),
    _PhoneSurface.overlay =>
      model.identifiedOverlay == null
          ? const SizedBox.shrink()
          : _OverlayIdentifyCard(
              identified: model.identifiedOverlay!,
              onClose: () {
                model.clearIdentifiedOverlay();
                _close();
              },
            ),
    null => const SizedBox.shrink(),
  };

  Widget _layerDetails() {
    // Read the live entry: opacity changes replace the overlay object.
    final chosen = _activeOverlay;
    final overlay =
        model.activeOverlays
            .where((o) => o.id == chosen?.id)
            .firstOrNull ??
        chosen;
    if (overlay == null) {
      return const Center(child: Text('Choose a layer to see its details.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          overlay.service.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SwitchListTile(
          title: const Text('Show on map'),
          value: model.isOverlayActive(overlay.service),
          onChanged: (_) => model.toggleOverlay(overlay.service),
        ),
        Text('Opacity: ${(overlay.opacity * 100).round()}%'),
        Slider(
          value: overlay.opacity,
          label: '${(overlay.opacity * 100).round()}%',
          onChanged: model.isOverlayActive(overlay.service)
              ? (value) => model.setOverlayOpacity(overlay, value)
              : null,
        ),
        if (overlay.notice != null) Text(overlay.notice!),
        const SizedBox(height: 16),
        const Text('Source'),
        SelectableText(overlay.service.uri.toString()),
        TextButton.icon(
          onPressed: () => _web(
            _WebSearchRequest(
              query: overlay.service.uri.toString(),
              searchSubject: 'Layer source',
            ),
          ),
          icon: const Icon(Icons.travel_explore),
          label: const Text('Research source'),
        ),
      ],
    );
  }

  Widget _layers() => ListView(
    key: const PageStorageKey('phone-layers'),
    children: [
      if (model.activeOverlays.isNotEmpty) ...[
        const ListTile(title: Text('Active layers')),
        for (final overlay in model.activeOverlays)
          ListTile(
            key: ValueKey('active-layer-${overlay.id}'),
            title: Text(overlay.service.title),
            subtitle: Text('${(overlay.opacity * 100).round()}% opacity'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _activeOverlay = overlay;
              _show(_PhoneSurface.layerDetail);
            },
          ),
      ],
      _LayerSwitch(
        key: const Key('address-layer-switch'),
        icon: Icons.location_on_outlined,
        title: 'Addresses',
        subtitle: 'Address points',
        value: model.addressesVisible,
        onChanged: model.setAddressesVisible,
      ),
      _LayerSwitch(
        key: const Key('parcel-layer-switch'),
        icon: Icons.grid_4x4_outlined,
        title: 'Parcels',
        subtitle: 'Property boundaries',
        value: model.parcelsVisible,
        onChanged: model.setParcelsVisible,
      ),
      _LayerSwitch(
        key: const Key('alpr-layer-switch'),
        icon: Icons.videocam_outlined,
        title: 'License-plate readers',
        subtitle: 'Flock and other ALPRs',
        value: model.alprCamerasVisible,
        onChanged: model.alprCamerasAvailable
            ? model.setAlprCamerasVisible
            : null,
      ),
      _LayerSwitch(
        key: const Key('boundary-layer-switch'),
        icon: Icons.polyline_outlined,
        title: 'County boundary',
        subtitle: model.countyName,
        value: model.boundaryVisible,
        onChanged: model.setBoundaryVisible,
      ),
      ListTile(
        key: const Key('open-layer-catalog'),
        leading: const Icon(Icons.travel_explore),
        title: const Text('Browse published layers'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _show(_PhoneSurface.catalog),
      ),
      if (model.imageryAvailable) _ImageryCard(viewModel: model),
    ],
  );
}
