import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// How far the bounding rectangle is grown past the drawn outline.
///
/// The outline is a polygon inscribed in the circle, so its widest points sit
/// slightly inside the true ones -- about a thousandth of the radius at 72
/// sides. One per cent is comfortably more than that and still far tighter
/// than the rectangle a caller would otherwise draw by hand.
const _ringInsetMargin = 0.01;

/// The number of segments a circle is drawn and tested with.
///
/// Seventy-two is one point every five degrees, which is indistinguishable
/// from a circle at any zoom the map offers and keeps the ring small enough
/// to hand to a tool call verbatim.
const _circleSegments = 72;

/// A region of the map the user has marked out.
///
/// Rectangles are what a drag draws; circles are what a radius question
/// wants -- "within half a mile of here" is a circle, and answering it with
/// the enclosing square would include corners a third further out. Both
/// carry a bounding rectangle because every source underneath queries by
/// envelope, and both can say precisely which points they contain, which is
/// what turns the envelope's answer back into the shape's.
@immutable
sealed class AreaShape {
  const AreaShape();

  /// The rectangle enclosing this shape, used to query sources.
  GeoBounds get bounds;

  /// Whether [point] falls inside this shape.
  bool contains(LatLng point);

  /// The outline, for drawing and for describing the shape to a tool.
  List<LatLng> get ring;

  /// A short human description, such as `a 0.5 mile circle`.
  String get description;
}

/// A rectangle drawn by dragging across the map.
@immutable
final class RectangleArea extends AreaShape {
  /// Creates a rectangular area covering [bounds].
  const RectangleArea(this.bounds);

  @override
  final GeoBounds bounds;

  @override
  bool contains(LatLng point) => bounds.contains(point);

  @override
  List<LatLng> get ring => [
    LatLng(bounds.north, bounds.west),
    LatLng(bounds.north, bounds.east),
    LatLng(bounds.south, bounds.east),
    LatLng(bounds.south, bounds.west),
  ];

  @override
  String get description => 'a rectangle';
}

/// A circle of [radiusMeters] around [center].
@immutable
final class CircleArea extends AreaShape {
  /// Creates a circular area.
  const CircleArea({required this.center, required this.radiusMeters});

  /// The point the circle is centred on.
  final LatLng center;

  /// The circle's radius in metres.
  final double radiusMeters;

  /// Distance calculator shared by containment and outline generation.
  static const _distance = Distance();

  @override
  GeoBounds get bounds {
    // Derived from the outline rather than from a degrees-per-metre constant.
    // The circle's own distance calculator is what [contains] measures with,
    // so building the rectangle from points that calculator produced is what
    // guarantees the rectangle encloses everything the circle accepts. A
    // constant would have to match the library's earth model exactly, and a
    // degree of latitude is not the same length as a degree of longitude at
    // the equator, nor the same at two latitudes.
    //
    // The outline is a 72-sided polygon inscribed in the circle, so its
    // extremes fall a fraction inside the true ones; the margin covers that
    // gap several times over.
    final box = GeoBounds.enclosing([ring]);
    final margin = _ringInsetMargin;
    return box.inflate(
      latitude: (box.north - box.south) * margin,
      longitude: (box.east - box.west) * margin,
    );
  }

  @override
  bool contains(LatLng point) =>
      _distance.as(LengthUnit.Meter, center, point) <= radiusMeters;

  @override
  List<LatLng> get ring => [
    for (var segment = 0; segment < _circleSegments; segment++)
      _distance.offset(center, radiusMeters, segment * 360 / _circleSegments),
  ];

  @override
  String get description {
    final miles = radiusMeters / 1609.344;
    return miles >= 0.1
        ? 'a ${miles.toStringAsFixed(miles >= 10 ? 0 : 1)} mile circle'
        : 'a ${radiusMeters.round()} metre circle';
  }
}

/// How far a rectangle drawn on the map has got.
enum AreaSelectionStatus {
  /// The addresses inside the rectangle are still being read.
  loading,

  /// The rectangle has been read and [AreaSelection.addresses] is complete.
  ready,

  /// The source could not be read; [AreaSelection.message] says why.
  failed,
}

/// The addresses inside a rectangle the user drew on the map.
@immutable
final class AreaSelection {
  /// Creates a selection covering [shape].
  const AreaSelection({
    required this.shape,
    required this.status,
    this.addresses = const [],
    this.truncated = false,
    this.message,
  });

  /// The region the user marked out.
  final AreaShape shape;

  /// The rectangle enclosing [shape], which is what sources are queried with.
  GeoBounds get bounds => shape.bounds;

  /// Whether the addresses have been read yet.
  final AreaSelectionStatus status;

  /// The address points inside [bounds], nearest the north-west corner first.
  final List<Address> addresses;

  /// Whether the source returned as many rows as were asked for.
  ///
  /// A capped answer is not the whole rectangle, and a list or an export that
  /// did not say so would read as complete.
  final bool truncated;

  /// Why the read failed, when it did.
  final String? message;

  /// The number of addresses found.
  int get count => addresses.length;

  /// The shape's outline, for drawing it on the map.
  List<LatLng> get ring => shape.ring;

  /// A copy of this selection with the given fields replaced.
  AreaSelection copyWith({
    AreaSelectionStatus? status,
    List<Address>? addresses,
    bool? truncated,
    String? message,
  }) {
    return AreaSelection(
      shape: shape,
      status: status ?? this.status,
      addresses: addresses ?? this.addresses,
      truncated: truncated ?? this.truncated,
      message: message ?? this.message,
    );
  }
}

/// The rectangle enclosing [first] and [second], in either drag direction.
///
/// A drag that ends north-west of where it started would otherwise produce an
/// inverted rectangle, which contains nothing and matches nothing.
GeoBounds boundsFromCorners(LatLng first, LatLng second) {
  return GeoBounds(
    west: first.longitude < second.longitude
        ? first.longitude
        : second.longitude,
    south: first.latitude < second.latitude ? first.latitude : second.latitude,
    east: first.longitude > second.longitude
        ? first.longitude
        : second.longitude,
    north: first.latitude > second.latitude ? first.latitude : second.latitude,
  );
}
