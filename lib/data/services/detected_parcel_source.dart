import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/parcel_schema.dart';
import 'package:riverside_atlas/data/services/property_owner_source.dart';
import 'package:riverside_atlas/data/services/statewide_parcel_source.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';

/// A verified parcel source, scoped to a county and safe to persist.
final class DetectedParcelSource {
  const DetectedParcelSource({
    required this.query,
    required this.fields,
    required this.bounds,
    required this.publisherLabel,
    required this.layerName,
    required this.count,
    required this.detectedAt,
    this.countyWhere = '1=1',
    this.supportsCentroid = false,
    this.supportsPagination = false,
    this.uppercaseAddressSearch = true,
    this.origin = 'auto',
    this.maxRecordCount = 1000,
  });
  final Uri query;
  final ParcelFieldMap fields;
  final GeoBounds bounds;
  final String publisherLabel, layerName, countyWhere, origin;
  final int count;
  final int maxRecordCount;
  final DateTime detectedAt;
  final bool supportsCentroid, supportsPagination, uppercaseAddressSearch;
  String get label =>
      '$publisherLabel · $layerName (${origin == 'manual' ? 'selected' : 'detected'})';
  bool get expired =>
      DateTime.now().toUtc().difference(detectedAt).inDays >= 30;
  Map<String, String> get spatialParameters => {
    'geometry': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
    'geometryType': 'esriGeometryEnvelope',
    'inSR': '4326',
    'spatialRel': 'esriSpatialRelIntersects',
  };
  Map<String, Object?> toJson() => {
    'version': 1,
    'query': '$query',
    'fields': fields.toJson(),
    'bounds': [bounds.west, bounds.south, bounds.east, bounds.north],
    'publisher': publisherLabel,
    'layer': layerName,
    'count': count,
    'maxRecordCount': maxRecordCount,
    'detectedAt': detectedAt.toIso8601String(),
    'where': countyWhere,
    'centroid': supportsCentroid,
    'pagination': supportsPagination,
    'uppercase': uppercaseAddressSearch,
    'origin': origin,
  };
  factory DetectedParcelSource.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown parcel source version');
    }
    final b = (json['bounds'] as List).cast<num>();
    return DetectedParcelSource(
      query: Uri.parse(json['query'] as String),
      fields: ParcelFieldMap.fromJson(
        (json['fields'] as Map).cast<String, Object?>(),
      ),
      bounds: GeoBounds(
        west: b[0].toDouble(),
        south: b[1].toDouble(),
        east: b[2].toDouble(),
        north: b[3].toDouble(),
      ),
      publisherLabel: json['publisher'] as String,
      layerName: json['layer'] as String,
      count: json['count'] as int,
      maxRecordCount: json['maxRecordCount'] as int? ?? 1000,
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      countyWhere: json['where'] as String,
      supportsCentroid: json['centroid'] as bool,
      supportsPagination: json['pagination'] as bool,
      uppercaseAddressSearch: json['uppercase'] as bool,
      origin: json['origin'] as String,
    );
  }
  CountyLayers toCountyLayers() => CountyLayers(
    addressQuery: query,
    parcelQuery: query,
    addressFields: fields.outFields,
    parcelFields: fields.outFields,
    addressSearchField: fields.fullAddressField ?? fields.fields['street']!,
    addressNumberField: fields.fullAddressField == null
        ? fields.fields['number']
        : null,
    mapper: DetectedParcelMapper(fields),
    objectIdField: fields.objectIdField,
    addressQueryParameters: supportsCentroid
        ? const {'returnGeometry': 'false', 'returnCentroid': 'true'}
        : const {'returnGeometry': 'true'},
    countyFilter: countyWhere,
    searchBounds: bounds,
    supportsPagination: supportsPagination,
    supportsCentroid: supportsCentroid,
    uppercaseAddressSearch: uppercaseAddressSearch,
  );
}

/// Reads parcel polygons and address positions from the same verified mapping.
final class DetectedParcelMapper implements ArcGisFeatureMapper {
  const DetectedParcelMapper(this.fields);
  final ParcelFieldMap fields;
  @override
  Address address(Map<String, Object?> feature) {
    final a = arcGisObject(feature['attributes']);
    final full = fields.address(a);
    final parsed = RegExp(r'^(\d+)\s+(.+)$').firstMatch(full);
    final id = arcGisInt(a[fields.objectIdField]);
    return Address(
      objectId: id,
      sourceId: id,
      fullAddress: full,
      houseNumber:
          int.tryParse(fields.value(a, 'number')) ??
          int.tryParse(parsed?.group(1) ?? ''),
      streetName: fields.fullAddressField != null
          ? parsed?.group(2) ?? ''
          : ['prefix', 'street']
                .map((r) => fields.value(a, r))
                .where((v) => v.isNotEmpty)
                .join(' '),
      streetType: fields.fullAddressField == null
          ? fields.value(a, 'type')
          : '',
      unit: '',
      city: fields.value(a, 'city'),
      zipCode: fields.value(a, 'zip'),
      apn: fields.value(a, 'apn'),
      addressType: '',
      numberOfUnits: 0,
      position: statewideCentroid(feature),
    );
  }

  @override
  Parcel parcel(Map<String, Object?> feature) {
    final a = arcGisObject(feature['attributes']);
    return Parcel(
      sourceId: arcGisInt(a[fields.objectIdField]),
      apn: fields.value(a, 'apn'),
      situsAddress: fields.address(a),
      city: fields.value(a, 'city'),
      zipCode: fields.value(a, 'zip'),
      landUse: fields.value(a, 'landUse'),
      acreage: double.tryParse(fields.value(a, 'acreage')),
      rings: arcGisRings(arcGisObject(feature['geometry'])['rings']),
    );
  }
}

/// Public owner attributes on a verified ArcGIS parcel layer.
final class DetectedOwnerSource implements PropertyOwnerSource {
  const DetectedOwnerSource(this.client, this.source);
  final http.Client client;
  final DetectedParcelSource source;
  @override
  Uri get sourceUri =>
      Uri.parse(source.query.toString().replaceFirst(RegExp(r'/query$'), ''));
  @override
  Future<PropertyOwnership?> lookupByApn(OwnerQuery query) => _lookup(
    "${source.fields.apnField} = '${_quote(query.apn)}'",
    query,
    false,
  );
  @override
  Future<PropertyOwnership?> lookupByAddress(OwnerQuery query) {
    if (!query.hasStreetAddress) return Future.value();
    final field =
        source.fields.fullAddressField ?? source.fields.fields['street']!;
    final prefix = source.fields.fullAddressField == null
        ? query.streetName
        : '${query.houseNumber} ${query.streetName}';
    // User punctuation cannot become LIKE wildcards.
    final safe = prefix.toUpperCase().replaceAll(RegExp(r'[%_]'), '');
    return _lookup("UPPER($field) LIKE '${_quote(safe)}%'", query, true);
  }

  Future<PropertyOwnership?> _lookup(
    String where,
    OwnerQuery query,
    bool addressMatch,
  ) async {
    final response = await client
        .get(
          source.query.replace(
            queryParameters: {
              'f': 'json',
              'where': '(${source.countyWhere}) AND ($where)',
              ...source.spatialParameters,
              'outFields': source.fields.outFields,
              'returnGeometry': 'false',
              'resultRecordCount': '250',
            },
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Owner source returned ${response.statusCode}');
    }
    final json = (jsonDecode(response.body) as Map).cast<String, Object?>();
    if (json.containsKey('error')) throw StateError('Owner query failed');
    // A truncated response cannot establish uniqueness.
    if (json['exceededTransferLimit'] == true) return null;
    final rows = arcGisFeatures(
      json,
    ).map((f) => arcGisObject(f['attributes'])).toList();
    String situs(Map<String, Object?> row) => [
      source.fields.address(row),
      source.fields.value(row, 'city'),
      source.fields.value(row, 'zip'),
    ].where((v) => v.isNotEmpty).join(', ');
    final candidates = <OwnerCandidate>[];
    for (var i = 0; i < rows.length; i++) {
      if (addressMatch && !situsMatchesQuery(situs(rows[i]), query)) continue;
      candidates.add(
        OwnerCandidate(
          parcelId: source.fields.value(rows[i], 'apn'),
          recordKey: '$i',
          situs: situs(rows[i]),
        ),
      );
    }
    final selected = selectOwnerCandidate(candidates, preferredApn: query.apn);
    if (selected == null) return null;
    final name = source.fields.value(
      rows[int.parse(selected.recordKey)],
      'owner',
    );
    if (name.isEmpty) return null;
    return PropertyOwnership(
      ownerName: name,
      parcelId: selected.parcelId,
      matchedAddress: selected.situs,
      sourceUri: sourceUri,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  static String _quote(String value) => value.replaceAll("'", "''");
}
