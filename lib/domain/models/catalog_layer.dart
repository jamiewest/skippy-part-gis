import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

/// How a catalogue entry can be drawn on the map.
///
/// This is decided from the service type and its advertised capabilities
/// rather than guessed, because the counties differ: San Bernardino publishes
/// 67 map services with no `Query` capability at all, which can only ever be
/// drawn as server-rendered images.
enum OverlayRender {
  /// A `MapServer` drawn through `/export` as transparent image tiles.
  exportImage,

  /// An `ImageServer` drawn through `/exportImage`.
  imageServer,

  /// A `FeatureServer` drawn by querying the viewport for geometry.
  featureQuery,

  /// Recognised but not drawable in this build.
  unsupported,
}

/// One service in a county's public catalogue.
///
/// Deliberately shallow: a folder listing already carries the name and type,
/// and that is enough to show a row and group it by theme. Layer detail is
/// fetched only when the user turns the service on.
@immutable
final class CatalogService {
  /// Creates a catalogue entry.
  const CatalogService({
    required this.portal,
    required this.name,
    required this.type,
    required this.themes,
  });

  /// The catalogue this service was listed from.
  final GisPortal portal;

  /// Service name as the server publishes it, such as `OpenData/Assessor`.
  final String name;

  /// ArcGIS service type, such as `MapServer`.
  final String type;

  /// Themes this service's name matched, for grouping the picker.
  final List<String> themes;

  /// Stable identifier, unique across every portal in a county.
  String get id => '${portal.root}|$name|$type';

  /// The service endpoint.
  Uri get uri => Uri.parse('${portal.root}/$name/$type');

  /// The folder this service lives in, or empty at the catalogue root.
  String get folder => name.contains('/') ? name.split('/').first : '';

  /// Human-readable title: the last path segment, de-punctuated.
  String get title {
    final leaf = name.split('/').last;
    final spaced = leaf
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .trim();
    return spaced.isEmpty ? leaf : spaced;
  }

  /// How this service would be drawn.
  OverlayRender get render => switch (type) {
    'MapServer' => OverlayRender.exportImage,
    'ImageServer' => OverlayRender.imageServer,
    'FeatureServer' => OverlayRender.featureQuery,
    _ => OverlayRender.unsupported,
  };

  /// Whether this service is worth offering in a layer picker.
  ///
  /// Geoprocessing, geometry, geocoding and 3D scene services are not map
  /// layers. Filtering them here removes roughly 320 entries statewide before
  /// a user ever sees a list.
  bool get isDrawable => render != OverlayRender.unsupported;

  @override
  bool operator ==(Object other) => other is CatalogService && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A feature drawn from an overlay layer.
///
/// The attributes are an opaque map on purpose. A county overlay's schema is
/// unknown — `AIRPORT_INFLUENCE_AREAS` has no equivalent anywhere — so parsing
/// it into a domain model would be inventing meaning. They are shown to the
/// user as field and value, and nothing else reads them.
@immutable
final class OverlayFeature {
  /// Creates an overlay feature.
  const OverlayFeature({
    required this.rings,
    required this.paths,
    required this.points,
    required this.attributes,
  });

  /// Polygon rings in WGS84.
  final List<List<LatLng>> rings;

  /// Polyline paths in WGS84.
  final List<List<LatLng>> paths;

  /// Point geometry in WGS84.
  final List<LatLng> points;

  /// The server's attributes, untouched.
  final Map<String, Object?> attributes;

  /// Whether this feature carries any geometry at all.
  bool get isEmpty => rings.isEmpty && paths.isEmpty && points.isEmpty;

  /// Whether [target] falls on this feature, within [tolerance] degrees.
  ///
  /// The tolerance is what makes a point layer tappable at all: a crime
  /// incident is a single coordinate, and nobody can tap an exact one. It is
  /// derived from the zoom by the caller so that the tap target stays the same
  /// size on screen at every scale.
  ///
  /// Polygons are tested by containment rather than by tolerance, so a tap
  /// anywhere inside a zoning district identifies it.
  bool hitTest(LatLng target, {required double tolerance}) {
    for (final point in points) {
      if (_within(point, target, tolerance)) {
        return true;
      }
    }
    for (final ring in rings) {
      if (_contains(ring, target)) {
        return true;
      }
    }
    for (final path in paths) {
      for (var index = 0; index + 1 < path.length; index++) {
        if (_nearSegment(path[index], path[index + 1], target, tolerance)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _within(LatLng point, LatLng target, double tolerance) =>
      (point.longitude - target.longitude).abs() <= tolerance &&
      (point.latitude - target.latitude).abs() <= tolerance;

  /// Ray casting: a point is inside when a ray crosses the ring an odd
  /// number of times.
  static bool _contains(List<LatLng> ring, LatLng target) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final crossesLatitude =
          (ring[i].latitude > target.latitude) !=
          (ring[j].latitude > target.latitude);
      if (!crossesLatitude) {
        continue;
      }
      final span = ring[j].latitude - ring[i].latitude;
      if (span == 0) {
        continue;
      }
      final crossingLongitude =
          ring[i].longitude +
          (target.latitude - ring[i].latitude) *
              (ring[j].longitude - ring[i].longitude) /
              span;
      if (target.longitude < crossingLongitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _nearSegment(
    LatLng start,
    LatLng end,
    LatLng target,
    double tolerance,
  ) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final lengthSquared = dx * dx + dy * dy;
    var position = 0.0;
    if (lengthSquared > 0) {
      position =
          ((target.longitude - start.longitude) * dx +
              (target.latitude - start.latitude) * dy) /
          lengthSquared;
      position = position.clamp(0.0, 1.0);
    }
    final nearest = LatLng(
      start.latitude + position * dy,
      start.longitude + position * dx,
    );
    return _within(nearest, target, tolerance);
  }
}
