import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// One California county's identity and geography.
///
/// The values come from the California State Geoportal's `CA_Counties`
/// boundary layer, read once and written down here so that starting the app,
/// listing counties, and framing the map never depend on a network call. The
/// polygon itself is still fetched live; only the identifiers, the centre, and
/// the extent are baked in.
@immutable
final class CaliforniaCounty {
  /// Creates a county entry.
  const CaliforniaCounty({
    required this.id,
    required this.name,
    required this.fips,
    required this.center,
    required this.extent,
  });

  /// Stable snake_case identifier that scopes snapshots and cached lookups.
  ///
  /// This is an on-disk contract. Changing an id orphans every snapshot row
  /// and every cached owner result already saved under the old one.
  final String id;

  /// County name without the word `County`, as the state publishes it.
  final String name;

  /// Five-digit state-plus-county FIPS code, such as `06037`.
  ///
  /// The statewide parcel layer keys on this exact five-digit form, while the
  /// state boundary layer publishes only the trailing three digits.
  final String fips;

  /// A reasonable point to open the map on.
  ///
  /// This is the polygon centroid for most counties, which lands in open
  /// country for the sprawling desert and mountain ones. Switching counties
  /// frames [extent] instead, so the centroid only matters at startup.
  final LatLng center;

  /// The county's bounding rectangle, used to frame the map on a switch.
  final GeoBounds extent;

  /// The three-digit county FIPS the state boundary layer publishes.
  String get countyFips => fips.substring(2);

  /// The name shown in the county picker, such as `Los Angeles County`.
  String get displayName => '$name County';
}

/// Every California county, alphabetically.
abstract final class CaliforniaCounties {
  /// All 58 counties.
  static const all = <CaliforniaCounty>[
    CaliforniaCounty(
      id: 'alameda',
      name: 'Alameda',
      fips: '06001',
      center: LatLng(37.6464, -121.8877),
      extent: GeoBounds(
        west: -122.3426,
        south: 37.4538,
        east: -121.4691,
        north: 37.9056,
      ),
    ),
    CaliforniaCounty(
      id: 'alpine',
      name: 'Alpine',
      fips: '06003',
      center: LatLng(38.5979, -119.8201),
      extent: GeoBounds(
        west: -120.0727,
        south: 38.328,
        east: -119.5421,
        north: 38.9334,
      ),
    ),
    CaliforniaCounty(
      id: 'amador',
      name: 'Amador',
      fips: '06005',
      center: LatLng(38.446, -120.6518),
      extent: GeoBounds(
        west: -121.0279,
        south: 38.2174,
        east: -120.0724,
        north: 38.706,
      ),
    ),
    CaliforniaCounty(
      id: 'butte',
      name: 'Butte',
      fips: '06007',
      center: LatLng(39.667, -121.6009),
      extent: GeoBounds(
        west: -122.072,
        south: 39.2952,
        east: -121.0766,
        north: 40.1518,
      ),
    ),
    CaliforniaCounty(
      id: 'calaveras',
      name: 'Calaveras',
      fips: '06009',
      center: LatLng(38.205, -120.5537),
      extent: GeoBounds(
        west: -120.9957,
        south: 37.8329,
        east: -120.0178,
        north: 38.5099,
      ),
    ),
    CaliforniaCounty(
      id: 'colusa',
      name: 'Colusa',
      fips: '06011',
      center: LatLng(39.1776, -122.2371),
      extent: GeoBounds(
        west: -122.7851,
        south: 38.9238,
        east: -121.7951,
        north: 39.4146,
      ),
    ),
    CaliforniaCounty(
      id: 'contra_costa',
      name: 'Contra Costa',
      fips: '06013',
      center: LatLng(37.9174, -121.9247),
      extent: GeoBounds(
        west: -122.4294,
        south: 37.7184,
        east: -121.5344,
        north: 38.1037,
      ),
    ),
    CaliforniaCounty(
      id: 'del_norte',
      name: 'Del Norte',
      fips: '06015',
      center: LatLng(41.7432, -123.8971),
      extent: GeoBounds(
        west: -124.2558,
        south: 41.3809,
        east: -123.5178,
        north: 42.0007,
      ),
    ),
    CaliforniaCounty(
      id: 'el_dorado',
      name: 'El Dorado',
      fips: '06017',
      center: LatLng(38.7787, -120.5252),
      extent: GeoBounds(
        west: -121.1487,
        south: 38.5023,
        east: -119.877,
        north: 39.0674,
      ),
    ),
    CaliforniaCounty(
      id: 'fresno',
      name: 'Fresno',
      fips: '06019',
      center: LatLng(36.7585, -119.6507),
      extent: GeoBounds(
        west: -120.9192,
        south: 35.9067,
        east: -118.3613,
        north: 37.5859,
      ),
    ),
    CaliforniaCounty(
      id: 'glenn',
      name: 'Glenn',
      fips: '06021',
      center: LatLng(39.5983, -122.3924),
      extent: GeoBounds(
        west: -122.9383,
        south: 39.3829,
        east: -121.855,
        north: 39.8005,
      ),
    ),
    CaliforniaCounty(
      id: 'humboldt',
      name: 'Humboldt',
      fips: '06023',
      center: LatLng(40.6988, -123.8737),
      extent: GeoBounds(
        west: -124.4096,
        south: 40.0013,
        east: -123.4058,
        north: 41.4658,
      ),
    ),
    CaliforniaCounty(
      id: 'imperial',
      name: 'Imperial',
      fips: '06025',
      center: LatLng(33.0397, -115.3653),
      extent: GeoBounds(
        west: -116.1062,
        south: 32.6184,
        east: -114.4628,
        north: 33.4337,
      ),
    ),
    CaliforniaCounty(
      id: 'inyo',
      name: 'Inyo',
      fips: '06027',
      center: LatLng(36.511, -117.4107),
      extent: GeoBounds(
        west: -118.79,
        south: 35.7866,
        east: -115.6483,
        north: 37.4648,
      ),
    ),
    CaliforniaCounty(
      id: 'kern',
      name: 'Kern',
      fips: '06029',
      center: LatLng(35.3427, -118.7301),
      extent: GeoBounds(
        west: -120.1944,
        south: 34.7885,
        east: -117.6162,
        north: 35.7983,
      ),
    ),
    CaliforniaCounty(
      id: 'kings',
      name: 'Kings',
      fips: '06031',
      center: LatLng(36.0754, -119.8154),
      extent: GeoBounds(
        west: -120.3151,
        south: 35.7885,
        east: -119.4743,
        north: 36.4889,
      ),
    ),
    CaliforniaCounty(
      id: 'lake',
      name: 'Lake',
      fips: '06033',
      center: LatLng(39.1, -122.7534),
      extent: GeoBounds(
        west: -123.0942,
        south: 38.668,
        east: -122.3397,
        north: 39.5814,
      ),
    ),
    CaliforniaCounty(
      id: 'lassen',
      name: 'Lassen',
      fips: '06035',
      center: LatLng(40.6738, -120.5945),
      extent: GeoBounds(
        west: -121.3321,
        south: 39.7075,
        east: -119.9956,
        north: 41.1847,
      ),
    ),
    CaliforniaCounty(
      id: 'los_angeles',
      name: 'Los Angeles',
      fips: '06037',
      center: LatLng(34.3231, -118.2248),
      extent: GeoBounds(
        west: -118.9448,
        south: 32.8007,
        east: -117.6462,
        north: 34.8233,
      ),
    ),
    CaliforniaCounty(
      id: 'madera',
      name: 'Madera',
      fips: '06039',
      center: LatLng(37.2179, -119.7628),
      extent: GeoBounds(
        west: -120.5455,
        south: 36.7629,
        east: -119.0228,
        north: 37.7782,
      ),
    ),
    CaliforniaCounty(
      id: 'marin',
      name: 'Marin',
      fips: '06041',
      center: LatLng(38.0724, -122.7222),
      extent: GeoBounds(
        west: -123.0243,
        south: 37.8153,
        east: -122.4183,
        north: 38.3211,
      ),
    ),
    CaliforniaCounty(
      id: 'mariposa',
      name: 'Mariposa',
      fips: '06043',
      center: LatLng(37.5813, -119.9058),
      extent: GeoBounds(
        west: -120.3954,
        south: 37.183,
        east: -119.3092,
        north: 37.9028,
      ),
    ),
    CaliforniaCounty(
      id: 'mendocino',
      name: 'Mendocino',
      fips: '06045',
      center: LatLng(39.4403, -123.3913),
      extent: GeoBounds(
        west: -124.0232,
        south: 38.7583,
        east: -122.8178,
        north: 40.004,
      ),
    ),
    CaliforniaCounty(
      id: 'merced',
      name: 'Merced',
      fips: '06047',
      center: LatLng(37.1926, -120.7179),
      extent: GeoBounds(
        west: -121.2476,
        south: 36.7404,
        east: -120.0525,
        north: 37.6335,
      ),
    ),
    CaliforniaCounty(
      id: 'modoc',
      name: 'Modoc',
      fips: '06049',
      center: LatLng(41.5899, -120.7252),
      extent: GeoBounds(
        west: -121.4582,
        south: 41.1838,
        east: -119.9987,
        north: 41.9977,
      ),
    ),
    CaliforniaCounty(
      id: 'mono',
      name: 'Mono',
      fips: '06051',
      center: LatLng(37.9386, -118.8861),
      extent: GeoBounds(
        west: -119.6515,
        south: 37.4622,
        east: -117.8312,
        north: 38.7141,
      ),
    ),
    CaliforniaCounty(
      id: 'monterey',
      name: 'Monterey',
      fips: '06053',
      center: LatLng(36.2172, -121.239),
      extent: GeoBounds(
        west: -121.9788,
        south: 35.7886,
        east: -120.2119,
        north: 36.9197,
      ),
    ),
    CaliforniaCounty(
      id: 'napa',
      name: 'Napa',
      fips: '06055',
      center: LatLng(38.507, -122.3305),
      extent: GeoBounds(
        west: -122.6468,
        south: 38.1549,
        east: -122.0614,
        north: 38.8644,
      ),
    ),
    CaliforniaCounty(
      id: 'nevada',
      name: 'Nevada',
      fips: '06057',
      center: LatLng(39.3015, -120.7678),
      extent: GeoBounds(
        west: -121.2799,
        south: 39.0053,
        east: -120.0032,
        north: 39.5268,
      ),
    ),
    CaliforniaCounty(
      id: 'orange',
      name: 'Orange',
      fips: '06059',
      center: LatLng(33.703, -117.7613),
      extent: GeoBounds(
        west: -118.119,
        south: 33.3869,
        east: -117.4127,
        north: 33.9473,
      ),
    ),
    CaliforniaCounty(
      id: 'placer',
      name: 'Placer',
      fips: '06061',
      center: LatLng(39.064, -120.7172),
      extent: GeoBounds(
        west: -121.4845,
        south: 38.7112,
        east: -120.0029,
        north: 39.3164,
      ),
    ),
    CaliforniaCounty(
      id: 'plumas',
      name: 'Plumas',
      fips: '06063',
      center: LatLng(40.0047, -120.8385),
      extent: GeoBounds(
        west: -121.4981,
        south: 39.5973,
        east: -120.099,
        north: 40.4497,
      ),
    ),
    CaliforniaCounty(
      id: 'riverside',
      name: 'Riverside',
      fips: '06065',
      center: LatLng(33.9806, -117.3755),
      extent: GeoBounds(
        west: -117.6764,
        south: 33.4259,
        east: -114.4348,
        north: 34.08,
      ),
    ),
    CaliforniaCounty(
      id: 'sacramento',
      name: 'Sacramento',
      fips: '06067',
      center: LatLng(38.4498, -121.3438),
      extent: GeoBounds(
        west: -121.8628,
        south: 38.0185,
        east: -121.0271,
        north: 38.7363,
      ),
    ),
    CaliforniaCounty(
      id: 'san_benito',
      name: 'San Benito',
      fips: '06069',
      center: LatLng(36.6055, -121.0748),
      extent: GeoBounds(
        west: -121.6442,
        south: 36.1968,
        east: -120.5967,
        north: 36.9888,
      ),
    ),
    CaliforniaCounty(
      id: 'san_bernardino',
      name: 'San Bernardino',
      fips: '06071',
      center: LatLng(34.1083, -117.2898),
      extent: GeoBounds(
        west: -117.8025,
        south: 33.8711,
        east: -114.1308,
        north: 35.8092,
      ),
    ),
    CaliforniaCounty(
      id: 'san_diego',
      name: 'San Diego',
      fips: '06073',
      center: LatLng(33.0355, -116.7336),
      extent: GeoBounds(
        west: -117.5962,
        south: 32.5343,
        east: -116.081,
        north: 33.5053,
      ),
    ),
    CaliforniaCounty(
      id: 'san_francisco',
      name: 'San Francisco',
      fips: '06075',
      center: LatLng(37.7475, -122.4392),
      extent: GeoBounds(
        west: -123.0137,
        south: 37.604,
        east: -122.3297,
        north: 37.8324,
      ),
    ),
    CaliforniaCounty(
      id: 'san_joaquin',
      name: 'San Joaquin',
      fips: '06077',
      center: LatLng(37.9347, -121.2713),
      extent: GeoBounds(
        west: -121.5848,
        south: 37.4819,
        east: -120.9172,
        north: 38.3001,
      ),
    ),
    CaliforniaCounty(
      id: 'san_luis_obispo',
      name: 'San Luis Obispo',
      fips: '06079',
      center: LatLng(35.3868, -120.404),
      extent: GeoBounds(
        west: -121.3478,
        south: 34.8975,
        east: -119.4724,
        north: 35.7952,
      ),
    ),
    CaliforniaCounty(
      id: 'san_mateo',
      name: 'San Mateo',
      fips: '06081',
      center: LatLng(37.4208, -122.3283),
      extent: GeoBounds(
        west: -122.5252,
        south: 37.107,
        east: -122.1151,
        north: 37.7087,
      ),
    ),
    CaliforniaCounty(
      id: 'santa_barbara',
      name: 'Santa Barbara',
      fips: '06083',
      center: LatLng(34.6731, -120.0174),
      extent: GeoBounds(
        west: -120.6717,
        south: 33.4651,
        east: -119.0276,
        north: 35.1145,
      ),
    ),
    CaliforniaCounty(
      id: 'santa_clara',
      name: 'Santa Clara',
      fips: '06085',
      center: LatLng(37.231, -121.6941),
      extent: GeoBounds(
        west: -122.2027,
        south: 36.893,
        east: -121.2082,
        north: 37.4846,
      ),
    ),
    CaliforniaCounty(
      id: 'santa_cruz',
      name: 'Santa Cruz',
      fips: '06087',
      center: LatLng(37.057, -122.0033),
      extent: GeoBounds(
        west: -122.3175,
        south: 36.8493,
        east: -121.5855,
        north: 37.2864,
      ),
    ),
    CaliforniaCounty(
      id: 'shasta',
      name: 'Shasta',
      fips: '06089',
      center: LatLng(40.7634, -122.0402),
      extent: GeoBounds(
        west: -123.0689,
        south: 40.2854,
        east: -121.3196,
        north: 41.1855,
      ),
    ),
    CaliforniaCounty(
      id: 'sierra',
      name: 'Sierra',
      fips: '06091',
      center: LatLng(39.5806, -120.5159),
      extent: GeoBounds(
        west: -121.0583,
        south: 39.3916,
        east: -120.001,
        north: 39.7769,
      ),
    ),
    CaliforniaCounty(
      id: 'siskiyou',
      name: 'Siskiyou',
      fips: '06093',
      center: LatLng(41.5926, -122.5404),
      extent: GeoBounds(
        west: -123.7192,
        south: 40.9921,
        east: -121.446,
        north: 42.0095,
      ),
    ),
    CaliforniaCounty(
      id: 'solano',
      name: 'Solano',
      fips: '06095',
      center: LatLng(38.2791, -121.9259),
      extent: GeoBounds(
        west: -122.407,
        south: 38.0397,
        east: -121.593,
        north: 38.5403,
      ),
    ),
    CaliforniaCounty(
      id: 'sonoma',
      name: 'Sonoma',
      fips: '06097',
      center: LatLng(38.5285, -122.8875),
      extent: GeoBounds(
        west: -123.5338,
        south: 38.1121,
        east: -122.3497,
        north: 38.8527,
      ),
    ),
    CaliforniaCounty(
      id: 'stanislaus',
      name: 'Stanislaus',
      fips: '06099',
      center: LatLng(37.5596, -120.9975),
      extent: GeoBounds(
        west: -121.4851,
        south: 37.1345,
        east: -120.3877,
        north: 38.0775,
      ),
    ),
    CaliforniaCounty(
      id: 'sutter',
      name: 'Sutter',
      fips: '06101',
      center: LatLng(39.0347, -121.6948),
      extent: GeoBounds(
        west: -121.9483,
        south: 38.7346,
        east: -121.4145,
        north: 39.3056,
      ),
    ),
    CaliforniaCounty(
      id: 'tehama',
      name: 'Tehama',
      fips: '06103',
      center: LatLng(40.1252, -122.2348),
      extent: GeoBounds(
        west: -123.066,
        south: 39.7974,
        east: -121.3421,
        north: 40.4461,
      ),
    ),
    CaliforniaCounty(
      id: 'trinity',
      name: 'Trinity',
      fips: '06105',
      center: LatLng(40.6506, -123.1126),
      extent: GeoBounds(
        west: -123.6238,
        south: 39.977,
        east: -122.4457,
        north: 41.3686,
      ),
    ),
    CaliforniaCounty(
      id: 'tulare',
      name: 'Tulare',
      fips: '06107',
      center: LatLng(36.2203, -118.7999),
      extent: GeoBounds(
        west: -119.5732,
        south: 35.7867,
        east: -117.9807,
        north: 36.7531,
      ),
    ),
    CaliforniaCounty(
      id: 'tuolumne',
      name: 'Tuolumne',
      fips: '06109',
      center: LatLng(38.0278, -119.9544),
      extent: GeoBounds(
        west: -120.6532,
        south: 37.6335,
        east: -119.1955,
        north: 38.4358,
      ),
    ),
    CaliforniaCounty(
      id: 'ventura',
      name: 'Ventura',
      fips: '06111',
      center: LatLng(34.4567, -119.084),
      extent: GeoBounds(
        west: -119.5788,
        south: 33.2145,
        east: -118.6321,
        north: 34.9011,
      ),
    ),
    CaliforniaCounty(
      id: 'yolo',
      name: 'Yolo',
      fips: '06113',
      center: LatLng(38.6869, -121.9012),
      extent: GeoBounds(
        west: -122.4228,
        south: 38.3133,
        east: -121.5014,
        north: 38.9259,
      ),
    ),
    CaliforniaCounty(
      id: 'yuba',
      name: 'Yuba',
      fips: '06115',
      center: LatLng(39.2693, -121.3512),
      extent: GeoBounds(
        west: -121.6361,
        south: 38.9183,
        east: -121.0096,
        north: 39.6394,
      ),
    ),
  ];

  /// The rectangle enclosing every California county.
  ///
  /// This is the union of the 58 county extents below, and it is what bounds
  /// map panning: parcels come from a statewide layer, so the map stays useful
  /// anywhere in the state rather than only inside the selected county.
  static const stateExtent = GeoBounds(
    west: -124.4096,
    south: 32.5343,
    east: -114.1308,
    north: 42.0095,
  );

  /// The county matching [id], or `null` when no such county exists.
  static CaliforniaCounty? byId(String id) {
    for (final county in all) {
      if (county.id == id) {
        return county;
      }
    }
    return null;
  }
}
