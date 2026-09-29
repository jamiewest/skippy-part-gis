/// Census tract geography and the measures published for it.
///
/// Two different services, with two different access rules, and the split is
/// the important thing about this file:
///
/// - **Tract geometry comes from TIGERweb and needs no key.** Asking which
///   tracts a drawn shape touches always works.
/// - **The measured values come from the ACS API, which requires a key.**
///   Without one the data endpoint answers a `302` redirect to an HTML page
///   headed `Missing Key`, so a client that only checks for a 200 and decodes
///   JSON sees an empty result rather than a refusal. That is why the status
///   code is checked before the body is parsed.
///
/// A free key takes a minute to obtain at
/// `https://api.census.gov/data/key_signup.html` and is read from
/// configuration; see `CensusOptions`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:retry/retry.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/census_area.dart';

/// The TIGERweb layer publishing every census tract in the country.
final censusTractQuery = Uri.parse(
  'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/'
  'Tracts_Blocks/MapServer/0/query',
);

/// The American Community Survey five-year release the measures come from.
///
/// The five-year release rather than the one-year because it is the only one
/// published at tract level; the one-year covers areas above 65,000 people.
const censusDataset = '2023/acs/acs5';

/// A recoverable error from a census service.
final class CensusException implements Exception {
  /// Creates a census failure with a user-safe [message].
  const CensusException(this.message);

  /// A concise description of the failure.
  final String message;

  @override
  String toString() => message;
}

/// Reads census tracts and their published measures.
final class CensusService {
  /// Creates a census reader using an injected HTTP [client].
  ///
  /// [apiKey] is the Census API key. Without one the tract lookup still works
  /// and the measures do not, which the profile says rather than hides.
  CensusService(this._client, {String? apiKey})
    : _apiKey = (apiKey ?? '').trim();

  /// The most tracts one profile will read.
  ///
  /// A shape covering a whole county can touch several hundred tracts, and a
  /// list that long answers no question anyone asked. The profile says when
  /// it stopped rather than silently reporting part of the area.
  static const tractLimit = 40;

  final http.Client _client;
  final String _apiKey;
  final RetryOptions _retryOptions = const RetryOptions(maxAttempts: 2);

  /// Whether measured values can be read at all.
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// The tracts intersecting [area].
  ///
  /// The shape's own outline is sent as the query geometry, not its bounding
  /// rectangle, so a circle asks about the tracts a circle touches. The
  /// enclosing square of a circle is a third larger and reaches into corner
  /// tracts the circle never enters.
  ///
  /// Intersection is the right test rather than containment: a tract is
  /// almost always larger than the area drawn on it, so requiring the tract
  /// to be inside the shape would usually return nothing, and requiring the
  /// tract's centre to be inside would drop the very tract the user is
  /// looking at whenever they drew off-centre.
  Future<List<CensusTract>> tractsIn(AreaShape area) async {
    final response = await _retryOptions.retry(
      () => _client
          .post(
            censusTractQuery,
            headers: const {'User-Agent': 'RiversideAtlas/1.0 (GIS prototype)'},
            body: {
              'geometry': _geometryOf(area),
              'geometryType': area is CircleArea
                  ? 'esriGeometryPolygon'
                  : 'esriGeometryEnvelope',
              'inSR': '4326',
              'spatialRel': 'esriSpatialRelIntersects',
              'outFields': 'GEOID,NAME,INTPTLAT,INTPTLON',
              'returnGeometry': 'false',
              'f': 'json',
            },
          )
          .timeout(const Duration(seconds: 20)),
      retryIf: (_) => true,
    );
    if (response.statusCode != 200) {
      throw CensusException(
        'The census tract service returned ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?> || decoded['error'] != null) {
      throw const CensusException(
        'The census tract service rejected the query.',
      );
    }
    return [for (final feature in arcGisFeatures(decoded)) ?_tract(feature)];
  }

  /// The measures published for [tracts], grouped by the county they are in.
  ///
  /// The ACS API is queried per county because its geography predicate names
  /// a state and a county and then lists tracts inside it; a shape crossing a
  /// county line therefore costs one request per county, not one per tract.
  ///
  /// Returns a profile carrying tract identities and no values when no key is
  /// configured. That is a real answer to "which tracts is this?" and an
  /// honest refusal of "what are the numbers?", which is better than either
  /// throwing or returning zeros.
  Future<CensusAreaProfile> profile(List<CensusTract> tracts) async {
    if (tracts.isEmpty) {
      return const CensusAreaProfile(
        tracts: [],
        hasValues: false,
        message: 'No census tract covers this area.',
      );
    }
    final capped = tracts.take(tractLimit).toList(growable: false);
    if (!hasApiKey) {
      return CensusAreaProfile(
        tracts: capped,
        hasValues: false,
        message:
            'No Census API key is configured, so the tracts here can be '
            'named but their published figures cannot be read. A free key '
            'from https://api.census.gov/data/key_signup.html, set as '
            'ATLAS_CENSUS_API_KEY, turns these into numbers.',
      );
    }
    final byCounty = <String, List<CensusTract>>{};
    for (final tract in capped) {
      (byCounty[tract.countyFips] ??= []).add(tract);
    }
    final values = <String, Map<String, num>>{};
    for (final entry in byCounty.entries) {
      values.addAll(await _valuesForCounty(entry.key, entry.value));
    }
    return CensusAreaProfile(
      tracts: [
        for (final tract in capped)
          tract.withValues(values[tract.geoid] ?? const {}),
      ],
      hasValues: true,
      message: tracts.length > tractLimit
          ? 'This area touches ${tracts.length} tracts; the nearest '
                '$tractLimit were read.'
          : null,
    );
  }

  /// Values by tract GEOID for the tracts of one county.
  Future<Map<String, Map<String, num>>> _valuesForCounty(
    String countyFips,
    List<CensusTract> tracts,
  ) async {
    final codes = censusVariables.map((variable) => variable.code).join(',');
    final url = Uri.parse('https://api.census.gov/data/$censusDataset').replace(
      queryParameters: {
        'get': codes,
        'for': 'tract:${tracts.map((t) => t.geoid.substring(5)).join(',')}',
        'in':
            'state:${countyFips.substring(0, 2)} '
            'county:${countyFips.substring(2)}',
        'key': _apiKey,
      },
    );
    final response = await _retryOptions.retry(
      () => _client.get(url).timeout(const Duration(seconds: 20)),
      retryIf: (_) => true,
    );
    // A missing or rejected key redirects to an HTML page rather than
    // answering with an error document, so anything but a 200 is a refusal
    // and the body must not be parsed as JSON.
    if (response.statusCode != 200) {
      throw CensusException(
        response.statusCode == 302 || response.statusCode == 401
            ? 'The Census API rejected the configured key.'
            : 'The Census API returned ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.length < 2) {
      throw const CensusException('The Census API returned no rows.');
    }
    // The response is a table: the first row names the columns, and the
    // trailing geography columns identify the tract the row describes.
    final header = [for (final cell in decoded.first as List) '$cell'];
    final stateColumn = header.indexOf('state');
    final countyColumn = header.indexOf('county');
    final tractColumn = header.indexOf('tract');
    if (stateColumn < 0 || countyColumn < 0 || tractColumn < 0) {
      throw const CensusException(
        'The Census API answered without tract identifiers.',
      );
    }
    final byGeoid = <String, Map<String, num>>{};
    for (final row in decoded.skip(1)) {
      if (row is! List) {
        continue;
      }
      final geoid =
          '${row[stateColumn]}${row[countyColumn]}${row[tractColumn]}';
      final measures = <String, num>{};
      for (var column = 0; column < header.length; column++) {
        final value = _measure(row[column]);
        if (value != null) {
          measures[header[column]] = value;
        }
      }
      byGeoid[geoid] = measures;
    }
    return byGeoid;
  }

  /// [area] as the geometry parameter of an ArcGIS spatial query.
  ///
  /// A rectangle goes as an envelope, which is what it is. Anything else goes
  /// as its outline ring, so the server does the intersection test against
  /// the real shape rather than the box around it.
  static String _geometryOf(AreaShape area) {
    if (area is! CircleArea) {
      final bounds = area.bounds;
      return '{"xmin":${bounds.west},"ymin":${bounds.south},'
          '"xmax":${bounds.east},"ymax":${bounds.north}}';
    }
    final ring = [
      for (final point in area.ring) '[${point.longitude},${point.latitude}]',
    ];
    // ArcGIS rings must close, so the first point is repeated at the end.
    return '{"rings":[[${ring.join(',')},${ring.first}]]}';
  }

  /// The tract described by [feature], or null when it carries no identifier.
  CensusTract? _tract(Map<String, Object?> feature) {
    final attributes = arcGisObject(feature['attributes']);
    final geoid = arcGisString(attributes['GEOID']);
    if (geoid.isEmpty) {
      return null;
    }
    return CensusTract(
      geoid: geoid,
      name: arcGisString(attributes['NAME']),
      center: LatLng(
        double.tryParse(arcGisString(attributes['INTPTLAT'])) ?? 0,
        double.tryParse(arcGisString(attributes['INTPTLON'])) ?? 0,
      ),
    );
  }

  /// [cell] as a number, or null where the census publishes none.
  ///
  /// The ACS uses large negative sentinels such as `-666666666` for a value it
  /// suppressed or could not compute. Reading one as a number would put a
  /// median income of minus six hundred million on the screen.
  static num? _measure(Object? cell) {
    final value = num.tryParse('$cell');
    if (value == null || value <= -666666) {
      return null;
    }
    return value;
  }
}
