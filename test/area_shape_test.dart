import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

void main() {
  group('CircleArea', () {
    // Downtown Riverside, with a radius of one kilometre.
    const centre = LatLng(33.9806, -117.3755);
    const circle = CircleArea(center: centre, radiusMeters: 1000);

    test('encloses itself in a rectangle a query can use', () {
      final bounds = circle.bounds;

      check(bounds.contains(centre)).isTrue();
      // The rectangle must reach at least the radius in every direction, or
      // an envelope query would miss rows the circle contains.
      const distance = Distance();
      for (final bearing in [0, 90, 180, 270]) {
        final edge = distance.offset(centre, 999, bearing.toDouble());
        check(bounds.contains(edge), because: 'bearing $bearing').isTrue();
      }
    });

    test('excludes the corners its bounding rectangle includes', () {
      // This is the whole point of carrying a shape rather than a rectangle:
      // the corner of the enclosing square is 1.41 radii from the centre, so
      // a rectangle answers a "within a kilometre" question with points half
      // as far again.
      final bounds = circle.bounds;
      final corner = LatLng(bounds.north, bounds.east);

      check(bounds.contains(corner)).isTrue();
      check(circle.contains(corner)).isFalse();
    });

    test('contains a point inside the radius and not one outside', () {
      const distance = Distance();

      check(circle.contains(distance.offset(centre, 900, 45))).isTrue();
      check(circle.contains(distance.offset(centre, 1100, 45))).isFalse();
    });

    test('draws an outline every point of which is on the radius', () {
      const distance = Distance();
      final ring = circle.ring;

      check(ring).length.equals(72);
      for (final point in ring) {
        check(distance.as(LengthUnit.Meter, centre, point)).isCloseTo(1000, 1);
      }
    });

    test('describes itself in units a person asked the question in', () {
      check(circle.description).equals('a 0.6 mile circle');
      check(
        const CircleArea(center: centre, radiusMeters: 50).description,
      ).equals('a 50 metre circle');
    });

    test('survives a latitude where longitude degrees are short', () {
      // At 70 degrees north a degree of longitude is a third of its length at
      // the equator, so a box built without the cosine correction would be
      // far too narrow and clip the circle it is meant to enclose.
      const arctic = CircleArea(center: LatLng(70, -150), radiusMeters: 1000);
      const distance = Distance();

      check(
        arctic.bounds.contains(distance.offset(arctic.center, 999, 90)),
      ).isTrue();
    });
  });

  group('RectangleArea', () {
    test('contains exactly what its bounds contain', () {
      const bounds = GeoBounds(
        west: -117.4,
        south: 33.9,
        east: -117.3,
        north: 34.0,
      );
      const rectangle = RectangleArea(bounds);

      check(rectangle.bounds).equals(bounds);
      check(rectangle.contains(const LatLng(33.95, -117.35))).isTrue();
      check(rectangle.contains(const LatLng(33.95, -117.29))).isFalse();
      check(rectangle.ring).length.equals(4);
    });
  });
}
