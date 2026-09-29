import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// How a census measure behaves when several areas are combined.
///
/// This is the difference between a number that can be added up and one that
/// cannot. Populations of two tracts sum to the population of both; their
/// median incomes do not average to anything real. Carrying the distinction
/// is what stops a summary inventing a figure.
enum CensusMeasure {
  /// A count of people, households, or housing units. Additive.
  count,

  /// A median or other rate. Not additive across areas.
  median,
}

/// One published American Community Survey measure.
@immutable
final class CensusVariable {
  /// Creates a variable description.
  const CensusVariable({
    required this.code,
    required this.label,
    required this.measure,
    this.unit = '',
  });

  /// The ACS variable code, such as `B19013_001E`.
  final String code;

  /// A short human label, such as `Median household income`.
  final String label;

  /// Whether the measure can be summed across areas.
  final CensusMeasure measure;

  /// A unit suffix or prefix, such as `$` or ` years`.
  final String unit;

  /// [value] rendered the way this measure is normally written.
  String format(num? value) {
    if (value == null) {
      return 'not published';
    }
    final digits = value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return unit == r'$' ? '$unit$digits' : '$digits$unit';
  }
}

/// The ACS measures this application asks for.
///
/// A curated list rather than the full 27,000 ACS variables: the point is a
/// question a person would actually ask about a place. Every code here was
/// checked against the 2023 five-year metadata.
const censusVariables = <CensusVariable>[
  CensusVariable(
    code: 'B01003_001E',
    label: 'Population',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B11001_001E',
    label: 'Households',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B01002_001E',
    label: 'Median age',
    measure: CensusMeasure.median,
    unit: ' years',
  ),
  CensusVariable(
    code: 'B19013_001E',
    label: 'Median household income',
    measure: CensusMeasure.median,
    unit: r'$',
  ),
  CensusVariable(
    code: 'B25077_001E',
    label: 'Median home value',
    measure: CensusMeasure.median,
    unit: r'$',
  ),
  CensusVariable(
    code: 'B25064_001E',
    label: 'Median gross rent',
    measure: CensusMeasure.median,
    unit: r'$',
  ),
  CensusVariable(
    code: 'B25035_001E',
    label: 'Median year structure built',
    measure: CensusMeasure.median,
  ),
  CensusVariable(
    code: 'B25003_002E',
    label: 'Owner-occupied homes',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B25003_003E',
    label: 'Renter-occupied homes',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B25002_003E',
    label: 'Vacant homes',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B15003_022E',
    label: "Adults with a bachelor's degree",
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B23025_003E',
    label: 'Civilian labor force',
    measure: CensusMeasure.count,
  ),
  CensusVariable(
    code: 'B23025_005E',
    label: 'Unemployed',
    measure: CensusMeasure.count,
  ),
];

/// One census tract, and the measures published for it.
@immutable
final class CensusTract {
  /// Creates a tract.
  const CensusTract({
    required this.geoid,
    required this.name,
    required this.center,
    this.values = const {},
  });

  /// The eleven-digit tract GEOID, such as `06065031100`.
  final String geoid;

  /// The published name, such as `Census Tract 311`.
  final String name;

  /// The tract's internal point.
  final LatLng center;

  /// Measured values by ACS variable code, absent where none is published.
  final Map<String, num> values;

  /// Five-digit state-plus-county FIPS code this tract is in.
  String get countyFips => geoid.substring(0, 5);

  /// A copy of this tract carrying [values].
  CensusTract withValues(Map<String, num> values) =>
      CensusTract(geoid: geoid, name: name, center: center, values: values);
}

/// What the census publishes about the tracts a drawn area touches.
///
/// The distinction this type exists to keep is between the area the user drew
/// and the areas the census measures. They are never the same. A circle drawn
/// on a map crosses tract boundaries, and the census publishes nothing about
/// part of a tract, so every number here describes **whole tracts that the
/// shape touches** and not the shape itself. Apportioning the figures to the
/// overlap would produce numbers that look precise and are invented; saying
/// which tracts were read leaves the reader able to judge the fit.
@immutable
final class CensusAreaProfile {
  /// Creates a profile over [tracts].
  const CensusAreaProfile({
    required this.tracts,
    required this.hasValues,
    this.message,
  });

  /// The tracts the drawn shape intersects.
  final List<CensusTract> tracts;

  /// Whether measured values were read, as opposed to tract identities only.
  ///
  /// False when no Census API key is configured: the tract geometry is public
  /// and needs no key, while the measures behind it do.
  final bool hasValues;

  /// Why values are missing, when they are.
  final String? message;

  /// The number of tracts read.
  int get tractCount => tracts.length;

  /// The whole-tract total for [variable], or null when it cannot be summed.
  ///
  /// Null for a median: adding two medians produces a number that describes
  /// no population. Callers report those per tract, or as a range.
  num? total(CensusVariable variable) {
    if (variable.measure != CensusMeasure.count) {
      return null;
    }
    num? sum;
    for (final tract in tracts) {
      final value = tract.values[variable.code];
      if (value != null) {
        sum = (sum ?? 0) + value;
      }
    }
    return sum;
  }

  /// The lowest and highest published value of [variable] across the tracts.
  ///
  /// This is what a median is summarised by. A range says honestly that the
  /// area spans tracts from one figure to another; a single averaged number
  /// would claim a precision the source does not support.
  ({num low, num high})? range(CensusVariable variable) {
    num? low;
    num? high;
    for (final tract in tracts) {
      final value = tract.values[variable.code];
      if (value == null) {
        continue;
      }
      low = low == null || value < low ? value : low;
      high = high == null || value > high ? value : high;
    }
    return low == null || high == null ? null : (low: low, high: high);
  }
}
