import 'package:flutter/material.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';

/// Progress of one overlay the user has switched on.
enum OverlayStatus {
  /// Resolving the service's own metadata.
  resolving,

  /// Reading features for the current viewport.
  loading,

  /// Drawing.
  ready,

  /// The service answered, but has nothing here at this zoom.
  empty,

  /// The service could not be read.
  failed,
}

/// One overlay feature the user tapped, and the overlay it came from.
///
/// The attributes are shown as the publisher wrote them — field name and
/// value, in the layer's own order. This app has not read the schema of an
/// arbitrary county layer and must not pretend it knows what a field means.
@immutable
final class OverlayIdentification {
  /// Creates an identification result.
  const OverlayIdentification({
    required this.title,
    required this.color,
    required this.feature,
  });

  /// The overlay's display title.
  final String title;

  /// The colour the overlay draws in, so the card matches the map.
  final Color color;

  /// The feature tapped.
  final OverlayFeature feature;

  /// Field/value pairs worth showing, in the server's own order.
  ///
  /// Null and empty values are dropped: an ArcGIS layer routinely returns
  /// forty fields of which a handful are populated, and showing the empty
  /// ones buries the ones that matter.
  List<({String field, String value})> get fields => [
    for (final entry in feature.attributes.entries)
      if (_describe(entry.value) case final value?)
        (field: entry.key, value: value),
  ];

  static String? _describe(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

/// A catalogue service the user has turned on, and what it is doing.
///
/// Mutable because it is view state that changes in place — a viewport move
/// re-reads features for every active overlay, and rebuilding the list each
/// time would lose the user's opacity and ordering choices.
final class ActiveOverlay {
  /// Creates an overlay in its initial resolving state.
  ActiveOverlay({required this.service, required this.color});

  /// The catalogue entry this overlay draws.
  final CatalogService service;

  /// The colour vector features are drawn in.
  ///
  /// Only used for [OverlayRender.featureQuery]. Server-rendered overlays
  /// arrive with the publisher's own cartography, which for a flood zone or a
  /// zoning map is better than anything this app would pick.
  final Color color;

  /// What this overlay is doing.
  OverlayStatus status = OverlayStatus.resolving;

  /// How strongly it draws, 0 to 1.
  double opacity = 0.75;

  /// Query endpoints resolved from the service's sub-layers.
  ///
  /// Empty for server-rendered overlays, which need no per-layer endpoint.
  List<Uri> featureQueries = const [];

  /// Features currently drawn, for a queried overlay.
  List<OverlayFeature> features = const [];

  /// Why this overlay is not drawing, when it is not.
  String? message;

  /// Sub-layers of this service that are not being drawn.
  ///
  /// A county map service can carry sixty layers and only the first few are
  /// queried. Saying so beats letting the map look complete when it is not.
  int droppedSubLayers = 0;

  /// What to tell the user about this overlay, if anything.
  String? get notice {
    if (message case final reason?) {
      return reason;
    }
    return droppedSubLayers > 0
        ? 'Drawing the first ${featureQueries.length} of '
              '${featureQueries.length + droppedSubLayers} layers.'
        : null;
  }

  /// Stable key.
  String get id => service.id;

  /// Whether this overlay draws as server-rendered image tiles.
  bool get isImagery =>
      service.render == OverlayRender.exportImage ||
      service.render == OverlayRender.imageServer;
}
