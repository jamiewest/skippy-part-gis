import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/ui/features/map/view_models/active_overlay.dart';

const _incident = OverlayFeature(
  rings: [],
  paths: [],
  points: [LatLng(33.95, -117.4)],
  attributes: {
    'OFFENSE': 'BURGLARY',
    'REPORT_DT': '2026-08-01',
    'CASE_NO': null,
    'NOTES': '  ',
  },
);

const _district = OverlayFeature(
  rings: [
    [
      LatLng(33.9, -117.5),
      LatLng(33.9, -117.3),
      LatLng(34.0, -117.3),
      LatLng(34.0, -117.5),
    ],
  ],
  paths: [],
  points: [],
  attributes: {'DISTRICT': 'WEST'},
);

void main() {
  group('point features', () {
    test(
      'a tap near a dot hits it, because nobody taps an exact coordinate',
      () {
        // Roughly a ten-pixel slack at street zoom.
        const tolerance = 0.0005;
        check(
          _incident.hitTest(
            const LatLng(33.9503, -117.4003),
            tolerance: tolerance,
          ),
        ).isTrue();
      },
    );

    test('a tap well away from a dot misses it', () {
      check(
        _incident.hitTest(const LatLng(33.96, -117.41), tolerance: 0.0005),
      ).isFalse();
    });
  });

  group('polygon features', () {
    test('a tap anywhere inside a district identifies it', () {
      check(
        _district.hitTest(const LatLng(33.95, -117.4), tolerance: 0.0),
      ).isTrue();
    });

    test('a tap outside the ring does not', () {
      check(
        _district.hitTest(const LatLng(33.95, -117.1), tolerance: 0.0),
      ).isFalse();
    });
  });

  group('attribute display', () {
    test('shows populated fields as the publisher wrote them', () {
      const identified = OverlayIdentification(
        title: 'Crime Incidents',
        color: Colors.red,
        feature: _incident,
      );

      check(identified.fields).deepEquals([
        (field: 'OFFENSE', value: 'BURGLARY'),
        (field: 'REPORT_DT', value: '2026-08-01'),
      ]);
    });

    test('drops null and blank fields rather than burying the real ones', () {
      const identified = OverlayIdentification(
        title: 'Crime Incidents',
        color: Colors.red,
        feature: _incident,
      );

      check(
        identified.fields.map((entry) => entry.field),
      ).not((it) => it.contains('CASE_NO'));
      check(
        identified.fields.map((entry) => entry.field),
      ).not((it) => it.contains('NOTES'));
    });
  });
}
