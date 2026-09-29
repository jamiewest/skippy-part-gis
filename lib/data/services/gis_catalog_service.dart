import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/layer_themes.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Lists the services a public ArcGIS catalogue publishes.
///
/// Enumeration is lazy and one level at a time: the catalogue root names its
/// folders, and a folder is only opened when the user expands it. Riverside
/// alone has 54 folders across seven roots, so walking everything on a county
/// switch would be a hundred requests before the map draws — and none of them
/// needed, because the layer panel opens long after the map does.
///
/// Results are cached for the life of the session. The county catalogues
/// change on the order of months; re-reading one per app run is not worth a
/// database migration.
final class GisCatalogService implements LayerCatalogRepository {
  /// Creates a catalogue reader over the shared HTTP client.
  GisCatalogService(this._client);

  final http.Client _client;
  final Map<String, List<CatalogService>> _cache = {};
  final Map<String, Map<String, Object?>> _metadata = {};

  @override
  Future<List<CatalogService>> listServices(GisPortal portal) async {
    if (_cache[portal.root] case final cached?) {
      return cached;
    }
    final root = await _read(Uri.parse(portal.root));
    final services = <CatalogService>[..._parse(portal, root['services'])];
    final folders = <String>[
      for (final folder in root['folders'] as List<Object?>? ?? const [])
        if (folder is String) folder,
    ];
    final listings = await Future.wait([
      for (final folder in folders)
        _read(
          Uri.parse('${portal.root}/$folder'),
        ).catchError((_) => <String, Object?>{}),
    ]);
    for (final listing in listings) {
      services.addAll(_parse(portal, listing['services']));
    }
    final drawable = services.where((service) => service.isDrawable).toList()
      ..sort((first, second) => first.title.compareTo(second.title));
    return _cache[portal.root] = List.unmodifiable(drawable);
  }

  @override
  Future<Map<String, Object?>> describe(CatalogService service) async {
    if (_metadata[service.id] case final cached?) {
      return cached;
    }
    return _metadata[service.id] = await _read(service.uri);
  }

  @override
  void forget(GisPortal portal) {
    _cache.remove(portal.root);
  }

  List<CatalogService> _parse(GisPortal portal, Object? raw) {
    if (raw is! List<Object?>) {
      return const [];
    }
    return [
      for (final entry in raw)
        if (entry is Map<String, Object?>)
          if (entry['name'] case final String name)
            if (entry['type'] case final String type)
              CatalogService(
                portal: portal,
                name: name,
                type: type,
                themes: themesOf(name),
              ),
    ];
  }

  Future<Map<String, Object?>> _read(Uri endpoint) async {
    final uri = endpoint.replace(
      queryParameters: {...endpoint.queryParameters, 'f': 'json'},
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'The catalogue returned HTTP ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The catalogue response is invalid.');
    }
    return decoded;
  }
}
