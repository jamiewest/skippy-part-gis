import 'package:flutter/material.dart';
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';

/// The Material 3 shell for Riverside Atlas.
class RiversideAtlasApp extends StatefulWidget {
  /// Creates the app using [dependencies].
  const RiversideAtlasApp({required this.dependencies, super.key});

  /// The production dependency graph.
  final AppDependencies dependencies;

  @override
  State<RiversideAtlasApp> createState() => _RiversideAtlasAppState();
}

class _RiversideAtlasAppState extends State<RiversideAtlasApp> {
  late CountySource _county = widget.dependencies.initialCounty;
  late GisMapViewModel _viewModel = widget.dependencies.createMapViewModel(
    _county,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    widget.dependencies.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverside Atlas',
      debugShowCheckedModeBanner: false,
      theme: AtlasTheme.light,
      darkTheme: AtlasTheme.dark,
      themeMode: ThemeMode.system,
      home: GisMapScreen(
        key: ValueKey(_county.id),
        viewModel: _viewModel,
        initialCenter: _county.initialCenter,
        initialBounds: _county.extent,
        countySelection: CountySelection(
          options: [
            for (final county in widget.dependencies.counties)
              CountyOption(
                id: county.id,
                label: county.displayName,
                extent: county.extent,
              ),
          ],
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
    if (county == null || county.id == _county.id) {
      return;
    }
    final previous = _viewModel;
    setState(() {
      _county = county;
      _viewModel = widget.dependencies.createMapViewModel(county);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }
}
