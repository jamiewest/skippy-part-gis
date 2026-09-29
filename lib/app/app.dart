import 'package:extensions_flutter/extensions_flutter.dart';
import 'package:flutter/material.dart';
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';

/// The Material 3 shell for the workspace.
class RiversideAtlasApp extends StatefulWidget {
  /// Creates the app over the host container's [services].
  ///
  /// [dependencies] is for tests and takes precedence when supplied, so a
  /// widget test can drive the shell without standing up a host.
  const RiversideAtlasApp({
    required this.services,
    this.dependencies,
    super.key,
  });

  /// The host container the long-lived services come from.
  final ServiceProvider services;

  /// An explicit graph, or null to resolve one from [services].
  final AppDependencies? dependencies;

  @override
  State<RiversideAtlasApp> createState() => _RiversideAtlasAppState();
}

class _RiversideAtlasAppState extends State<RiversideAtlasApp> {
  /// The graph, resolved once rather than on every rebuild.
  late final AppDependencies _dependencies =
      widget.dependencies ??
      widget.services.getRequiredService<AppDependencies>();

  /// Every county, as picker entries, built once.
  ///
  /// The list is 3,235 rows and the same on every rebuild, so building it in
  /// `build` would redo the work on every frame the workspace repaints.
  late final List<CountyOption> _options = [
    for (final county in _dependencies.counties)
      CountyOption(
        id: county.id,
        label: county.name,
        stateName: UsGeography.stateByFips(county.stateFips)?.name ?? '',
        extent: county.extent,
      ),
  ];

  /// The assistant, and the handle its tools read the open county through.
  ///
  /// Both outlive a county switch, which is why the workspace handle exists:
  /// the tools are built once at startup and must still answer about whatever
  /// county is open now.
  late final MapAssistant? _assistant = widget.dependencies != null
      ? null
      : widget.services.getRequiredService<MapAssistant>();
  late final MapWorkspace? _workspace = widget.dependencies != null
      ? null
      : widget.services.getRequiredService<MapWorkspace>();

  // Frame the lower 48 on launch; county selections use their own extents.
  static const _unitedStates = GeoBounds(
    west: -125,
    south: 24,
    east: -66,
    north: 50,
  );
  bool _hasSelectedCounty = false;

  late CountySource _county = _dependencies.initialCounty;
  late GisMapViewModel _viewModel = _dependencies.createMapViewModel(_county);

  @override
  void dispose() {
    _viewModel.dispose();
    // The container holds the HTTP client and the database as singletons but
    // does not close them -- neither implements the container's disposal
    // interface -- so the root widget's teardown stays the one place they are
    // released, as it was before the host existed.
    _dependencies.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _workspace?.attach(_viewModel, _county);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: AtlasTheme.light,
      darkTheme: AtlasTheme.dark,
      themeMode: ThemeMode.system,
      home: GisMapScreen(
        key: ValueKey('${_county.id}:$_hasSelectedCounty'),
        viewModel: _viewModel,
        assistant: _assistant,
        initialCenter: _county.initialCenter,
        initialBounds: _hasSelectedCounty ? _county.extent : _unitedStates,
        countySelection: CountySelection(
          options: _options,
          activeId: _county.id,
          onSelected: _selectCounty,
        ),
      ),
    );
  }

  /// Rebuilds the workspace against the chosen county.
  ///
  /// The previous model is disposed after the frame that removes the old
  /// screen, so its listeners are detached before the notifier goes away.
  void _selectCounty(CountyOption option) {
    final county = CountySources.byId(option.id);
    if (county == null || (_hasSelectedCounty && county.id == _county.id)) {
      return;
    }
    final previous = _viewModel;
    setState(() {
      _hasSelectedCounty = true;
      _county = county;
      _viewModel = _dependencies.createMapViewModel(county);
    });
    // The assistant's tools read through the handle, so pointing it at the
    // new workspace is what stops them answering about the county the user
    // just left.
    _workspace?.attach(_viewModel, county);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }
}
