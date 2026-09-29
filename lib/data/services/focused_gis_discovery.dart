import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/arcgis_json.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';

/// Incrementally samples every available catalogue, including inactive layers.
/// A page bounds network work and prompt size; subsequent calls continue it.
/// Discovery is independent of the stricter address/snapshot source selector.
final class FocusedGisDiscovery {
  FocusedGisDiscovery(this.client, {this.pageSize = 16}) : assert(pageSize > 0);

  final http.Client client;
  final int pageSize;
  _Scan? _scan;
  Future<Map<String, Object?>>? _pending;

  Future<Map<String, Object?>> inspect(
    MapWorkspace workspace, {
    String? sourceUrl,
    int fieldOffset = 0,
  }) async {
    // Serialize callers, but capture the focus again after waiting: the user
    // may have changed counties while an earlier page was in flight.
    while (_pending != null) {
      await _pending;
    }
    final future = _inspect(
      workspace,
      sourceUrl: sourceUrl,
      fieldOffset: fieldOffset,
    );
    _pending = future;
    try {
      return await future;
    } finally {
      if (identical(_pending, future)) _pending = null;
    }
  }

  Future<Map<String, Object?>> _inspect(
    MapWorkspace workspace, {
    String? sourceUrl,
    int fieldOffset = 0,
  }) async {
    final model = workspace.requireViewModel;
    final county = workspace.requireCounty;
    if (!model.overlaysAvailable) {
      return {
        'status': 'unavailable',
        'reason': 'GIS discovery needs live mode.',
      };
    }
    await model.discoverPortals();
    final area =
        model.areaSelection?.shape ??
        RectangleArea(model.visibleExtent ?? county.extent);
    final geometry = jsonEncode({
      'rings': [
        [
          for (final p in [...area.ring, area.ring.first])
            [p.longitude, p.latitude],
        ],
      ],
      'spatialReference': {'wkid': 4326},
    });
    final key = '${county.fips}|$geometry';
    var scan = _scan;
    if (scan == null || scan.key != key || !identical(scan.model, model)) {
      scan = _scan = _Scan(key, model, geometry);
      if (county.layers case final layers?) {
        scan.add(
          _Job(
            layers.parcelQuery.toString().replaceFirst(RegExp(r'/query$'), ''),
            county.detectedParcels?.publisherLabel ?? layers.parcelQuery.host,
            _Kind.layer,
          ),
        );
      }
    }
    // Newly discovered city/county portals join the same scan without
    // discarding samples already read for this focus.
    for (final portal in model.portals) {
      scan.add(_Job(portal.root, portal.publisher, _Kind.catalogue));
    }
    final current = scan;
    final page = <Map<String, Object?>>[];
    var remaining = pageSize;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Future<void> visit(_Job job) async {
      try {
        final result = await _visit(
          current,
          job,
          fieldOffset: sourceUrl == null ? 0 : fieldOffset,
        );
        if (result != null) {
          page.add(result);
          if (sourceUrl != null) return;
          current.checked++;
          if (result['parcelOutlineCandidate'] == true ||
              (result['ownerCandidates'] as List? ?? []).isNotEmpty ||
              (result['ownerFields'] as List? ?? []).isNotEmpty) {
            current.findingCount++;
            if (current.findings.length < 60) {
              current.findings.add({
                for (final entry in result.entries)
                  if (entry.key != 'sampleAttributes' && entry.key != 'fields')
                    entry.key: entry.value,
              });
            }
          }
        }
      } on Object catch (error) {
        current.failures++;
        page.add({
          'sourceUrl': job.url,
          'status': 'unavailable',
          'reason': '$error',
        });
      }
    }

    if (sourceUrl != null) {
      final job = current.jobs[sourceUrl.toLowerCase()];
      if (job == null || job.kind != _Kind.layer || fieldOffset < 0) {
        return {
          'status': 'invalidRequest',
          'note':
              'Use a discovered layer sourceUrl and a nonnegative fieldOffset.',
        };
      }
      await visit(job);
    } else {
      while (remaining > 0 &&
          current.queue.isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        final batch = current.queue
            .take(remaining < 4 ? remaining : 4)
            .toList();
        current.queue.removeRange(0, batch.length);
        remaining -= batch.length;
        await Future.wait(batch.map(visit));
      }
    }
    if (!identical(workspace.viewModel, model) ||
        jsonEncode(
              (workspace.requireViewModel.areaSelection?.shape ??
                      RectangleArea(
                        workspace.requireViewModel.visibleExtent ??
                            county.extent,
                      ))
                  .ring
                  .map((p) => [p.longitude, p.latitude])
                  .toList(),
            ) !=
            jsonEncode(
              area.ring.map((p) => [p.longitude, p.latitude]).toList(),
            )) {
      return {
        'status': 'focusChanged',
        'note': 'Discard these results and inspect the current focus again.',
      };
    }
    return {
      'status': current.queue.isEmpty ? 'complete' : 'partial',
      'county': county.displayName,
      'focus': model.areaSelection == null
          ? 'visible extent (county before first viewport)'
          : area.description,
      'bounds': {
        'west': area.bounds.west,
        'south': area.bounds.south,
        'east': area.bounds.east,
        'north': area.bounds.north,
      },
      'layersInspected': current.checked,
      'failedRequests': current.failures,
      'unsupportedServices': current.unsupported,
      'portalDiscoveryStatus': model.discoveryStatus.name,
      'pendingEntries': current.queue.length,
      'hasMore': current.queue.isNotEmpty,
      'findings': current.findings,
      'findingsOmitted': current.findingCount - current.findings.length,
      'sampledLayers': page,
      'note':
          'At most 5 records per spatial layer, not a parcel or owner census. '
          'Candidates are published field values, not verified ownership. '
          'Tables have schema only and cannot be assigned to this area without a verified join. '
          'Complete means all enumerated entries were attempted; failures and unavailable sources remain gaps. '
          'Call discover_area_data again while hasMore is true.',
    };
  }

  Future<Map<String, Object?>?> _visit(
    _Scan scan,
    _Job job, {
    int fieldOffset = 0,
  }) async {
    final data = await _read(job.url);
    if (job.kind == _Kind.catalogue) {
      for (final folder
          in (data['folders'] as List? ?? []).whereType<String>()) {
        scan.add(_Job('${job.url}/$folder', job.publisher, _Kind.catalogue));
      }
      final root = Uri.parse(job.url);
      final marker = root.path.toLowerCase().indexOf('/rest/services');
      final base = marker < 0
          ? job.url
          : root
                .replace(
                  path: root.path.substring(
                    0,
                    marker + '/rest/services'.length,
                  ),
                )
                .toString();
      final services =
          (data['services'] as List? ?? []).whereType<Map>().toList()..sort(
            (a, b) =>
                _priority('${b['name']}').compareTo(_priority('${a['name']}')),
          );
      // Insert ahead of other roots so the first page produces real samples.
      for (final service in services.reversed) {
        if (service['type'] == 'MapServer' ||
            service['type'] == 'FeatureServer') {
          scan.add(
            _Job(
              '$base/${service['name']}/${service['type']}',
              job.publisher,
              _Kind.service,
            ),
            first: true,
          );
        } else {
          scan.unsupported++;
        }
      }
      return null;
    }
    if (job.kind == _Kind.service && data['fields'] is! List) {
      final children = [
        ...(data['layers'] as List? ?? []),
        ...(data['tables'] as List? ?? []),
      ];
      for (final layer in children.reversed.whereType<Map>()) {
        if (layer['id'] is num && layer['type'] != 'Group Layer') {
          scan.add(
            _Job('${job.url}/${layer['id']}', job.publisher, _Kind.layer),
            first: true,
          );
        }
      }
      return null;
    }
    final fields = (data['fields'] as List? ?? []).whereType<Map>().toList();
    final parcelFields = fields
        .where((f) => _parcelField(f))
        .map((f) => '${f['name']}')
        .toList();
    final owners = fields
        .where((f) => _ownerField(f))
        .map((f) => '${f['name']}')
        .toList();
    final genericNames = fields
        .where(
          (f) =>
              [
                'name',
                'fullname',
                'legalname',
              ].contains(_key('${f['name']}')) ||
              ['name', 'fullname', 'legalname'].contains(_key('${f['alias']}')),
        )
        .map((f) => '${f['name']}')
        .toList();
    final visibleFields = fields.skip(fieldOffset).take(24).toList();
    final nextField = fieldOffset + visibleFields.length;
    final result = <String, Object?>{
      'sourceUrl': job.url,
      'publisher': job.publisher,
      'layer': data['name'],
      'geometryType': data['geometryType'],
      'parcelIdFields': parcelFields,
      'ownerFields': owners,
      'fields': [
        for (final field in visibleFields)
          {
            'name': field['name'],
            'alias': field['alias'],
            'type': field['type'],
          },
      ],
      'fieldOffset': fieldOffset,
      'nextFieldOffset': nextField < fields.length ? nextField : null,
      'fieldCount': fields.length,
    };
    if (data['geometryType'] == null) {
      return {
        ...result,
        'status': 'schemaOnly',
        'note':
            'Nonspatial table: area association requires a verified parcel-ID join.',
      };
    }
    final capabilities = data['capabilities']?.toString().toLowerCase();
    if (capabilities != null &&
        !capabilities.split(',').map((s) => s.trim()).contains('query')) {
      return {
        ...result,
        'status': 'unavailable',
        'note': 'Layer does not advertise Query capability.',
      };
    }
    final sample = await _read('${job.url}/query', {
      'where': '1=1',
      'geometry': scan.geometry,
      'geometryType': 'esriGeometryPolygon',
      'inSR': '4326',
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': '*',
      'outSR': '4326',
      'returnGeometry': 'true',
      'geometryPrecision': '6',
      'resultRecordCount': '5',
    });
    if (sample['features'] is! List) {
      throw const FormatException('No feature list returned');
    }
    final rows = arcGisFeatures(sample).take(5).toList();
    final parcelHint =
        parcelFields.isNotEmpty || _priority('${data['name']}') > 0;
    final polygon = data['geometryType'] == 'esriGeometryPolygon';
    return {
      ...result,
      'status': rows.isEmpty ? 'emptySample' : 'sampled',
      'sampleCount': rows.length,
      'sampleLimited':
          sample['exceededTransferLimit'] == true || rows.length >= 5,
      'parcelOutlineCandidate':
          polygon &&
          parcelHint &&
          rows.any(
            (f) => arcGisRings(arcGisObject(f['geometry'])['rings']).isNotEmpty,
          ),
      'outlineEvidence': polygon && parcelHint
          ? 'Parcel-like schema/title; polygon geometry checked in area sample. Review before adopting.'
          : null,
      'ownerCandidates': [
        for (final row in rows)
          for (final field in {...owners, ...genericNames})
            if (_nameValue(arcGisObject(row['attributes'])[field])
                case final value?)
              {
                'field': field,
                'value': value,
                'confidence': owners.contains(field)
                    ? 'owner-labelled field'
                    : 'ambiguous name field; may not be an owner',
                'parcelIds': {
                  for (final id in parcelFields)
                    id: arcGisObject(row['attributes'])[id],
                },
              },
      ],
      'sampleAttributes': [
        for (final row in rows)
          {
            for (final field in visibleFields)
              '${field['name']}': _shortValue(
                arcGisObject(row['attributes'])['${field['name']}'],
              ),
          },
      ],
      'sampleAttributesMayBeTrimmed':
          fieldOffset > 0 || nextField < fields.length,
    };
  }

  Future<Map<String, Object?>> _read(
    String url, [
    Map<String, String> parameters = const {},
  ]) async {
    final response = await client
        .get(
          Uri.parse(url).replace(queryParameters: {'f': 'json', ...parameters}),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid ArcGIS response');
    }
    if (data['error'] != null) throw StateError('ArcGIS: ${data['error']}');
    return data;
  }
}

enum _Kind { catalogue, service, layer }

final class _Job {
  const _Job(this.url, this.publisher, this.kind);
  final String url, publisher;
  final _Kind kind;
}

final class _Scan {
  _Scan(this.key, this.model, this.geometry);
  final String key, geometry;
  final Object model;
  final queue = <_Job>[];
  final jobs = <String, _Job>{};
  final findings = <Map<String, Object?>>[];
  int checked = 0, failures = 0, unsupported = 0, findingCount = 0;
  void add(_Job job, {bool first = false}) {
    if (jobs.containsKey(job.url.toLowerCase())) return;
    jobs[job.url.toLowerCase()] = job;
    first ? queue.insert(0, job) : queue.add(job);
  }
}

String _key(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
int _priority(String s) =>
    RegExp('parcel|cadastr|assessor|taxlot', caseSensitive: false).hasMatch(s)
    ? 1
    : 0;
bool _parcelField(Map f) => [f['name'], f['alias']].any(
  (v) => RegExp(
    r'^(apn|ain|pin|pin(num|number)?|parcel(id|number|no|apn)|taxparcelid|assessorparcelnumber|prclnum|propertyid)$',
  ).hasMatch(_key('$v')),
);
bool _ownerField(Map f) => [f['name'], f['alias']].any((v) {
  final key = _key('$v');
  if (RegExp(
    r'addr|mail|city|state|zip|type|code|status|percent|date|phone|email|id$',
  ).hasMatch(key)) {
    return false;
  }
  return RegExp(
    r'^(owner(s|name)?[0-9]*|owner(first|last|full)name|ownernm[0-9]*|ownname[0-9]*|taxpayer(name)?[0-9]*|taxownername|deedholder|proprietor|vestedowner)$',
  ).hasMatch(key);
});
String? _nameValue(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty ||
      !RegExp(r'[A-Za-z\u00c0-\uffff]').hasMatch(text) ||
      RegExp(
        r'^(null|none|n/?a|unknown|not available|redacted|withheld|confidential|private|exempt)$',
        caseSensitive: false,
      ).hasMatch(text)) {
    return null;
  }
  return _shortValue(text) as String;
}

Object? _shortValue(Object? value) => value is String && value.length > 200
    ? '${value.substring(0, 200)}…'
    : value;
