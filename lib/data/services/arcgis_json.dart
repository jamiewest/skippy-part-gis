/// Readers that turn loosely typed ArcGIS REST JSON into Dart values.
///
/// County deployments disagree about whether a field arrives as a number or
/// as a string, so every reader coerces instead of casting.
library;

import 'package:latlong2/latlong.dart';

/// The object at [value], or an empty map when the shape is unexpected.
Map<String, Object?> arcGisObject(Object? value) =>
    value is Map<String, Object?> ? value : const {};

/// The feature list inside an ArcGIS query response.
List<Map<String, Object?>> arcGisFeatures(Map<String, Object?> json) {
  final features = json['features'];
  if (features is! List<Object?>) {
    return const [];
  }
  return features.whereType<Map<String, Object?>>().toList(growable: false);
}

/// Polygon rings converted from ArcGIS `[longitude, latitude]` pairs.
///
/// Rings with fewer than three points cannot be drawn and are dropped.
List<List<LatLng>> arcGisRings(Object? rawRings) {
  if (rawRings is! List<Object?>) {
    return const [];
  }
  return rawRings
      .whereType<List<Object?>>()
      .map(
        (ring) => ring
            .whereType<List<Object?>>()
            .where((pair) => pair.length >= 2)
            .map((pair) => LatLng(arcGisDouble(pair[1]), arcGisDouble(pair[0])))
            .toList(growable: false),
      )
      .where((ring) => ring.length >= 3)
      .toList(growable: false);
}

/// The trimmed text at [value], or [fallback] when the field is absent.
String arcGisString(Object? value, {String fallback = ''}) {
  return value?.toString().trim() ?? fallback;
}

/// The integer at [value], or [fallback] when it cannot be parsed.
int arcGisInt(Object? value, {int fallback = 0}) {
  return value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}

/// The integer at [value], or `null` when it cannot be parsed.
int? arcGisNullableInt(Object? value) {
  return value is num ? value.toInt() : int.tryParse('$value');
}

/// The double at [value], or [fallback] when it cannot be parsed.
double arcGisDouble(Object? value, {double fallback = 0}) {
  return value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? fallback;
}

/// The double at [value], or `null` when it cannot be parsed.
double? arcGisNullableDouble(Object? value) {
  return value is num ? value.toDouble() : double.tryParse('$value');
}

/// The instant at an ArcGIS epoch-milliseconds field, when one is present.
DateTime? arcGisEpochMillis(Object? value) {
  return value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : null;
}
