import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/region_boundary.dart';

/// A recoverable error returned by a county ArcGIS service.
final class ArcGisException implements Exception {
  /// Creates a service exception with a user-safe [message].
  const ArcGisException(this.message);

  /// A concise description of the failure.
  final String message;

  @override
  String toString() => message;
}

/// Query-only access to one county's public ArcGIS layers.
final class ArcGisService {
  /// Creates a service using an injected HTTP [client].
  ///
  /// Reads Riverside County unless another [county] is supplied.
  ArcGisService(this._client, {CountySource? county, this.onInvalidSource})
    : source = county ?? CountySources.riverside;

  /// The fewest rows a spatially filtered query should ever ask a layer for.
  ///
  /// A hosted feature layer answers a small `resultRecordCount` off a slow
  /// path. Against the 13-million-row statewide layer the same envelope query
  /// took 12 seconds at a limit of 100 and 0.4 seconds at 200 — the larger
  /// request is both faster and bigger. Queries below this floor therefore ask
  /// for the floor and discard the surplus, which costs a few kilobytes and
  /// saves tens of seconds.
  static const fastPathRecordCount = 250;

  /// Endpoints and attribute schema for the county being read.
  final CountySource source;

  /// The parcel and address layers, which every caller here requires.
  ///
  /// Reaching this on a county with no parcel coverage is a wiring mistake,
  /// not a user-facing condition: [AppDependencies] gives such a county
  /// empty address and parcel repositories, and the workspace reports the
  /// absence through [CountySource.hasParcelCoverage] instead of querying.
  CountyLayers get _layers =>
      source.layers ??
      (throw StateError(
        'No public layer publishes parcels for ${source.displayName}.',
      ));

  final http.Client _client;
  final void Function()? onInvalidSource;
  final RetryOptions _retryOptions = const RetryOptions(maxAttempts: 3);

  /// Fetches the county-maintained boundary polygon.
  ///
  /// The layer publishes every California county, so the FIPS filter on the
  /// source is what isolates this one.
  Future<RegionBoundary> fetchCountyBoundary() async {
    final json = await _post(source.effectiveBoundaryQuery, {
      'where': source.boundaryFilter,
      'outFields': '${source.boundaryNameField},${source.boundaryFipsField}',
      'returnGeometry': 'true',
      'outSR': '4326',
      'f': 'json',
    });
    final features = arcGisFeatures(json);
    if (features.isEmpty) {
      throw ArcGisException(
        'The ${source.displayName} boundary was not found.',
      );
    }
    final feature = features.first;
    final attributes = arcGisObject(feature['attributes']);
    return RegionBoundary(
      name: arcGisString(attributes[source.boundaryNameField]),
      fips: arcGisString(attributes[source.boundaryFipsField]),
      rings: arcGisRings(arcGisObject(feature['geometry'])['rings']),
    );
  }

  /// Searches live county address points by normalized address prefix.
  ///
  /// The search is scoped to the county even when the underlying layer is
  /// statewide, because a suggestion list that silently crosses the county line
  /// is worse than a short one.
  Future<List<Address>> searchAddresses(String query, {int limit = 20}) async {
    final normalized = _searchPrefix(query);
    if (normalized.isEmpty) {
      return const [];
    }
    final field = _layers.addressSearchField;
    var prefix = normalized;
    var numberClause = '1=1';
    if (_layers.addressNumberField case final numberField?) {
      final parts = RegExp(r'^(\d+)\s+(.+)$').firstMatch(normalized);
      if (parts != null) {
        numberClause = "$numberField = '${parts[1]}'";
        prefix = parts[2]!;
      }
    }
    final matcher = _layers.uppercaseAddressSearch ? 'UPPER($field)' : field;
    final json = await _post(_layers.addressQuery, {
      'where': _and(
        _layers.countyFilter,
        _and(numberClause, "$matcher LIKE '$prefix%'"),
      ),
      if (_layers.searchBounds case final bounds?)
        ..._envelopeParameters(bounds),
      'outFields': _layers.addressFields,
      ..._layers.addressQueryParameters,
      'outSR': '4326',
      'orderByFields': '$field ASC',
      'resultRecordCount': '$limit',
      'f': 'json',
    });
    return _addresses(json);
  }

  /// Fetches live address points intersecting [bounds].
  Future<List<Address>> fetchAddressesInBounds(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    final json = await _post(_layers.addressQuery, {
      'where': '1=1',
      ..._envelopeParameters(bounds),
      'outFields': _layers.addressFields,
      ..._layers.addressQueryParameters,
      'outSR': '4326',
      'resultRecordCount': '${_spatialRecordCount(limit)}',
      'f': 'json',
    });
    return _addresses(json).take(limit).toList(growable: false);
  }

  /// Fetches live county parcels intersecting [bounds].
  ///
  /// Parcel outlines are surveyed to a precision no screen can show. Asking the
  /// server to generalize them to roughly one pixel of the current view cuts
  /// the response to a fraction of its full-precision size and changes nothing
  /// a viewer could see. Offline snapshots deliberately do not do this, because
  /// stored geometry is re-drawn at every later zoom.
  Future<List<Parcel>> fetchParcelsInBounds(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    final json = await _post(_layers.parcelQuery, {
      'where': '1=1',
      ..._envelopeParameters(bounds),
      'outFields': _layers.parcelFields,
      'returnGeometry': 'true',
      'maxAllowableOffset': '${_pixelSize(bounds)}',
      'outSR': '4326',
      'resultRecordCount': '${_spatialRecordCount(limit)}',
      'f': 'json',
    });
    return _parcels(json).take(limit).toList(growable: false);
  }

  /// All address object IDs intersecting [bounds].
  Future<List<int>> fetchAddressObjectIds(GeoBounds bounds) {
    return _fetchObjectIds(_layers.addressQuery, bounds);
  }

  /// All parcel object IDs intersecting [bounds].
  Future<List<int>> fetchParcelObjectIds(GeoBounds bounds) {
    return _fetchObjectIds(_layers.parcelQuery, bounds);
  }

  /// How many county address points fall inside [bounds].
  Future<int> countAddresses(GeoBounds bounds) {
    return _count(_layers.addressQuery, bounds);
  }

  /// How many county parcels fall inside [bounds].
  Future<int> countParcels(GeoBounds bounds) {
    return _count(_layers.parcelQuery, bounds);
  }

  /// Fetches one ordered page of address points inside [bounds].
  ///
  /// Paging beats enumerating object IDs for anything larger than a viewport:
  /// an ID list is capped by the service and costs a full extra round of the
  /// county's index before a single feature arrives.
  Future<List<Address>> fetchAddressPage(
    GeoBounds bounds, {
    required int offset,
    required int limit,
  }) async {
    final json = await _post(_layers.addressQuery, {
      'where': _and(_layers.countyFilter, '1=1'),
      ..._envelopeParameters(bounds),
      'outFields': _layers.addressFields,
      ..._layers.addressQueryParameters,
      'outSR': '4326',
      'orderByFields': '${_layers.objectIdField} ASC',
      'resultOffset': '$offset',
      'resultRecordCount': '$limit',
      'f': 'json',
    });
    return _addresses(json);
  }

  /// Fetches one ordered page of parcels inside [bounds].
  Future<List<Parcel>> fetchParcelPage(
    GeoBounds bounds, {
    required int offset,
    required int limit,
  }) async {
    final json = await _post(_layers.parcelQuery, {
      'where': _and(_layers.countyFilter, '1=1'),
      ..._envelopeParameters(bounds),
      'outFields': _layers.parcelFields,
      'returnGeometry': 'true',
      'outSR': '4326',
      'orderByFields': '${_layers.objectIdField} ASC',
      'resultOffset': '$offset',
      'resultRecordCount': '$limit',
      'f': 'json',
    });
    return _parcels(json);
  }

  /// Whether one query can answer as both address points and parcels.
  ///
  /// A county read through the statewide fabric has no separate address layer:
  /// its address points are parcel centroids. Downloading such a county twice
  /// would double the traffic for one set of rows.
  bool get sharesAddressLayer => _layers.sharesAddressLayer;

  /// Fetches one page as both address points and parcels in a single request.
  ///
  /// Only meaningful when [sharesAddressLayer] is true. The response carries
  /// the polygon rings and the server-computed centroid side by side, so each
  /// feature is mapped twice rather than fetched twice.
  Future<({List<Address> addresses, List<Parcel> parcels})> fetchCombinedPage(
    GeoBounds bounds, {
    required int offset,
    required int limit,
  }) async {
    final json = await _post(_layers.parcelQuery, {
      'where': _and(_layers.countyFilter, '1=1'),
      ..._envelopeParameters(bounds),
      'outFields': _mergeFields(_layers.addressFields, _layers.parcelFields),
      'returnGeometry': 'true',
      if (_layers.supportsCentroid) 'returnCentroid': 'true',
      'outSR': '4326',
      'orderByFields': '${_layers.objectIdField} ASC',
      'resultOffset': '$offset',
      'resultRecordCount': '$limit',
      'f': 'json',
    });
    final features = arcGisFeatures(json);
    return (
      addresses: features
          .map(_layers.effectiveAddressMapper.address)
          .toList(growable: false),
      parcels: features.map(_layers.mapper.parcel).toList(growable: false),
    );
  }

  /// Fetches a deterministic batch of addresses by ArcGIS object ID.
  Future<List<Address>> fetchAddressBatch(List<int> objectIds) async {
    final json = await _post(_layers.addressQuery, {
      'objectIds': objectIds.join(','),
      'outFields': _layers.addressFields,
      ..._layers.addressQueryParameters,
      'outSR': '4326',
      'f': 'json',
    });
    return _addresses(json);
  }

  /// Fetches a deterministic batch of parcels by ArcGIS object ID.
  Future<List<Parcel>> fetchParcelBatch(List<int> objectIds) async {
    final json = await _post(_layers.parcelQuery, {
      'objectIds': objectIds.join(','),
      'outFields': _layers.parcelFields,
      'returnGeometry': 'true',
      'outSR': '4326',
      'f': 'json',
    });
    return _parcels(json);
  }

  List<Address> _addresses(Map<String, Object?> json) {
    return arcGisFeatures(
      json,
    ).map(_layers.effectiveAddressMapper.address).toList(growable: false);
  }

  List<Parcel> _parcels(Map<String, Object?> json) {
    return arcGisFeatures(
      json,
    ).map(_layers.mapper.parcel).toList(growable: false);
  }

  Future<int> _count(Uri endpoint, GeoBounds bounds) async {
    final json = await _post(endpoint, {
      'where': _and(_layers.countyFilter, '1=1'),
      ..._envelopeParameters(bounds),
      'returnCountOnly': 'true',
      'f': 'json',
    });
    final count = json['count'];
    if (count is! num) {
      throw const ArcGisException('The county returned no feature count.');
    }
    return count.toInt();
  }

  Future<List<int>> _fetchObjectIds(Uri endpoint, GeoBounds bounds) async {
    final json = await _post(endpoint, {
      'where': _layers.countyFilter,
      ..._envelopeParameters(bounds),
      'returnIdsOnly': 'true',
      'f': 'json',
    });
    final objectIds = json['objectIds'];
    if (objectIds is! List<Object?>) {
      throw const ArcGisException('The county returned no object IDs.');
    }
    return objectIds.whereType<num>().map((value) => value.toInt()).toList()
      ..sort();
  }

  Future<Map<String, Object?>> _post(
    Uri endpoint,
    Map<String, String> body,
  ) async {
    // Older MapServers cannot page by offset. Enumerate this bounded tile's
    // IDs and fetch a stable slice instead of repeating the first page.
    if (body.containsKey('resultOffset') && !_layers.supportsPagination) {
      final idsResponse = await _post(endpoint, {
        'f': 'json',
        'where': body['where'] ?? '1=1',
        for (final key in ['geometry', 'geometryType', 'inSR', 'spatialRel'])
          key: ?body[key],
        'returnIdsOnly': 'true',
      });
      if (idsResponse['objectIds'] is! List ||
          idsResponse['exceededTransferLimit'] == true) {
        throw const ArcGisException(
          'The parcel source cannot enumerate this area completely.',
        );
      }
      final ids =
          (idsResponse['objectIds'] as List)
              .whereType<num>()
              .map((n) => n.toInt())
              .toList()
            ..sort();
      final batch = ids
          .skip(int.parse(body['resultOffset']!))
          .take(int.parse(body['resultRecordCount']!))
          .toList();
      if (batch.isEmpty) return {'features': <Object?>[]};
      body = {...body, 'objectIds': batch.join(',')}
        ..remove('resultOffset')
        ..remove('orderByFields');
    }
    final response = await _retryOptions.retry(() async {
      final current = await _client
          .post(
            endpoint,
            headers: const {'User-Agent': 'RiversideAtlas/1.0 (GIS prototype)'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (current.statusCode >= 500) {
        throw ArcGisException(
          'The county GIS service is temporarily unavailable.',
        );
      }
      return current;
    }, retryIf: (_) => true);

    if (response.statusCode != 200) {
      if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          endpoint != source.effectiveBoundaryQuery) {
        onInvalidSource?.call();
      }
      throw ArcGisException(
        'The county GIS service returned ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const ArcGisException('The county returned an invalid response.');
    }
    if (decoded['error'] case final Map<String, Object?> error) {
      final code = error['code'];
      if (endpoint != source.effectiveBoundaryQuery &&
          ((code is num && code >= 400 && code < 500) ||
              RegExp(
                'field|column|invalid.*query',
                caseSensitive: false,
              ).hasMatch('$error'))) {
        onInvalidSource?.call();
      }
      throw ArcGisException(
        arcGisString(
          error['message'],
          fallback: 'The county rejected the query.',
        ),
      );
    }
    return decoded;
  }

  Map<String, String> _envelopeParameters(GeoBounds bounds) => {
    'geometry': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
    'geometryType': 'esriGeometryEnvelope',
    'inSR': '4326',
    'spatialRel': 'esriSpatialRelIntersects',
  };

  /// The row count to request for a spatially filtered query wanting [limit].
  int _spatialRecordCount(int limit) =>
      limit < fastPathRecordCount ? fastPathRecordCount : limit;

  /// Roughly one screen pixel of [bounds], in degrees.
  ///
  /// The map width is not known here, so this assumes a wide desktop window;
  /// guessing narrow would generalize geometry a wide window could resolve.
  double _pixelSize(GeoBounds bounds) => (bounds.east - bounds.west) / 1600;

  /// The union of two `outFields` lists, in first-seen order.
  String _mergeFields(String left, String right) {
    final merged = <String>{...left.split(','), ...right.split(',')}
      ..removeWhere((field) => field.isEmpty);
    return merged.join(',');
  }

  /// Joins two `where` clauses, dropping either when it selects everything.
  String _and(String left, String right) {
    if (left == '1=1') {
      return right;
    }
    if (right == '1=1') {
      return left;
    }
    return '$left AND $right';
  }

  String _searchPrefix(String value) {
    return value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9#\-\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
