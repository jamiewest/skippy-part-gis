import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// How far in front of a camera its field-of-view wedge reaches, in metres.
const alprConeLengthMeters = 90.0;

/// The total field of view a camera wedge spans, in degrees.
const alprConeSpreadDegrees = 50.0;

/// The Wikidata entity OpenStreetMap uses for Flock Safety.
const _flockWikidata = 'Q108485435';

/// Bearings for the compass abbreviations OpenStreetMap allows in `direction`.
const _compassBearings = <String, double>{
  'N': 0,
  'NNE': 22.5,
  'NE': 45,
  'ENE': 67.5,
  'E': 90,
  'ESE': 112.5,
  'SE': 135,
  'SSE': 157.5,
  'S': 180,
  'SSW': 202.5,
  'SW': 225,
  'WSW': 247.5,
  'W': 270,
  'WNW': 292.5,
  'NW': 315,
  'NNW': 337.5,
};

/// An automated license-plate reader mapped in OpenStreetMap.
///
/// OpenStreetMap records these as `man_made=surveillance` features carrying
/// `surveillance:type=ALPR`. Flock Safety hardware is the most common vendor,
/// but the same tagging also covers toll gantries and rival manufacturers, so
/// [isFlock] distinguishes them rather than the query.
@immutable
class AlprCamera {
  /// Creates a camera record.
  const AlprCamera({
    required this.osmType,
    required this.osmId,
    required this.position,
    this.manufacturer,
    this.operatorName,
    this.name,
    this.direction,
    this.mount,
    this.zone,
  });

  /// Builds a camera from one Overpass element.
  ///
  /// Nodes report `lat`/`lon` directly. Ways and relations report a centroid
  /// under `center`, which the `out center` statement adds, so both shapes
  /// collapse to a single point.
  ///
  /// Throws a [FormatException] when the element carries no usable position.
  factory AlprCamera.fromOverpassJson(Map<String, dynamic> json) {
    final center = json['center'];
    final rawLatitude = center is Map ? center['lat'] : json['lat'];
    final rawLongitude = center is Map ? center['lon'] : json['lon'];
    if (rawLatitude is! num || rawLongitude is! num) {
      throw const FormatException('Overpass element has no position.');
    }
    final tags = json['tags'] is Map
        ? (json['tags'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    String? tag(String key) {
      final value = tags[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return AlprCamera(
      osmType: json['type'] is String ? json['type'] as String : 'node',
      osmId: json['id'] is num ? (json['id'] as num).toInt() : 0,
      position: LatLng(rawLatitude.toDouble(), rawLongitude.toDouble()),
      manufacturer:
          tag('manufacturer') ??
          tag('brand') ??
          (tag('manufacturer:wikidata') == _flockWikidata ||
                  tag('brand:wikidata') == _flockWikidata
              ? 'Flock Safety'
              : null),
      operatorName: tag('operator'),
      name: tag('name'),
      direction: _parseDirection(tag('direction')),
      mount: tag('camera:mount'),
      zone: tag('surveillance:zone'),
    );
  }

  /// The OpenStreetMap element kind, such as `node` or `way`.
  final String osmType;

  /// The OpenStreetMap element identifier.
  final int osmId;

  /// The camera location, or the centroid of a mapped way.
  final LatLng position;

  /// The vendor recorded by `manufacturer` or `brand`.
  final String? manufacturer;

  /// The agency recorded by `operator`.
  final String? operatorName;

  /// The camera's mapped name, when it has one.
  final String? name;

  /// The compass bearing the camera faces, in degrees clockwise from north.
  final double? direction;

  /// What the camera is attached to, such as `pole` or `street_lamp`.
  final String? mount;

  /// The area the camera watches, such as `traffic` or `parking_entrance`.
  final String? zone;

  /// A stable key combining [osmType] and [osmId].
  String get sourceId => '$osmType/$osmId';

  /// Whether Flock Safety is the recorded vendor.
  bool get isFlock =>
      manufacturer != null &&
      manufacturer!.toLowerCase().contains('flock safety');

  /// The ground the camera watches, as a polygon ring on the map.
  ///
  /// This is the wedge DeFlock draws: a circular sector with its apex on the
  /// camera that widens to an arc [lengthMeters] away, so the wide end shows
  /// where the camera is looking. Empty when the feature has no [direction].
  ///
  /// The ring is measured in metres rather than screen pixels, so it keeps
  /// covering the same roadway as the map zooms.
  List<LatLng> viewCone({
    double lengthMeters = alprConeLengthMeters,
    double spreadDegrees = alprConeSpreadDegrees,
    int arcSegments = 8,
  }) {
    final bearing = direction;
    const earthRadiusMeters = 6371000.0;
    final latitudeScale = math.cos(position.latitude * math.pi / 180);
    if (bearing == null || latitudeScale.abs() < 1e-6) {
      return const [];
    }
    final lengthDegrees = lengthMeters / earthRadiusMeters * 180 / math.pi;

    LatLng edgeAt(double degrees) {
      final radians = degrees * math.pi / 180;
      return LatLng(
        position.latitude + lengthDegrees * math.cos(radians),
        position.longitude + lengthDegrees * math.sin(radians) / latitudeScale,
      );
    }

    final start = bearing - spreadDegrees / 2;
    return [
      position,
      for (var step = 0; step <= arcSegments; step++)
        edgeAt(start + spreadDegrees * step / arcSegments),
    ];
  }

  /// A short human-readable summary for tooltips and semantics.
  String get description {
    final parts = <String>[
      name ?? manufacturer ?? 'Unknown vendor',
      if (name != null && manufacturer != null) manufacturer!,
      if (operatorName != null) 'Operated by $operatorName',
      if (zone != null) 'Watches ${zone!.replaceAll('_', ' ')}',
      if (mount != null) 'On a ${mount!.replaceAll('_', ' ')}',
      if (direction != null) 'Faces ${_compassLabel(direction!)}',
    ];
    return parts.join(' • ');
  }

  static double? _parseDirection(String? value) {
    if (value == null) {
      return null;
    }
    final degrees = double.tryParse(value);
    if (degrees != null) {
      return degrees % 360;
    }
    return _compassBearings[value.toUpperCase()];
  }
}

/// The nearest eight-point compass label for [bearing] degrees.
String _compassLabel(double bearing) {
  const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((bearing % 360) / 45).round() % labels.length;
  return labels[index];
}
