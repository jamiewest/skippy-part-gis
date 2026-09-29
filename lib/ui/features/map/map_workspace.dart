import 'package:flutter/foundation.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// A stable handle on whichever county workspace is open.
///
/// Switching county replaces the view model wholesale, so anything that
/// outlives a county -- the assistant and its tools -- cannot hold one
/// directly without going stale the first time the user moves state. This is
/// the indirection that lets a tool registered once at startup read whatever
/// is on screen now.
///
/// It is a [ChangeNotifier] so a panel can rebuild when the workspace is
/// swapped underneath it.
final class MapWorkspace extends ChangeNotifier {
  GisMapViewModel? _viewModel;
  CountySource? _county;

  /// The workspace currently open, or null before the first one is attached.
  GisMapViewModel? get viewModel => _viewModel;

  /// The county currently being read.
  CountySource? get county => _county;

  /// The open workspace, or a thrown error naming what is missing.
  ///
  /// Tools call this: reaching a tool before a workspace exists is a wiring
  /// mistake, and an error saying so is better than a tool that silently
  /// answers about nothing.
  GisMapViewModel get requireViewModel =>
      _viewModel ?? (throw StateError('No county workspace is open.'));

  /// The county being read, or a thrown error when none is.
  CountySource get requireCounty =>
      _county ?? (throw StateError('No county workspace is open.'));

  /// Points the handle at [viewModel], reading [county].
  void attach(GisMapViewModel viewModel, CountySource county) {
    if (identical(_viewModel, viewModel) && _county == county) {
      return;
    }
    _viewModel = viewModel;
    _county = county;
    notifyListeners();
  }
}
