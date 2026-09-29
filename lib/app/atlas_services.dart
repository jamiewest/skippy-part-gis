import 'package:extensions/configuration.dart';
import 'package:extensions/dependency_injection.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';

/// Registers the application's long-lived services in the host container.
///
/// The split here is by lifetime, not by layer. Everything registered is
/// something one session has exactly one of: the HTTP client every service
/// shares, the database, and the graph that builds a county workspace. What
/// is deliberately absent is anything county-scoped -- those are rebuilt
/// wholesale by [AppDependencies.createMapViewModel] when the county changes,
/// which is a lifetime the container cannot express and does not need to.
extension AtlasServiceCollectionExtensions on ServiceCollection {
  /// Adds the services a workspace is built from.
  ///
  /// [county] is where the session opens; the workspace can switch afterwards.
  /// [configuration] supplies the keys that must not live in source; a key
  /// that is absent leaves the service that wanted it reporting itself
  /// unavailable rather than failing at the first request.
  ServiceCollection addAtlas({
    required Configuration configuration,
    CountySource? county,
  }) {
    addSingleton<http.Client>((_) => http.Client());
    addSingleton<AppDatabase>((_) => AppDatabase());
    addSingleton<CensusService>(
      (services) => CensusService(
        services.getRequiredService<http.Client>(),
        apiKey: configuration['CENSUS_API_KEY'],
      ),
    );
    addSingleton<AppDependencies>(
      (services) => AppDependencies(
        client: services.getRequiredService<http.Client>(),
        database: services.getRequiredService<AppDatabase>(),
        county: county,
        routeSnapEndpoint: _serviceUri(configuration['ROUTE_SNAP_URL']),
        routingEndpoint: _serviceUri(configuration['ROUTING_URL']),
        geocodingEndpoint: _serviceUri(configuration['GEOCODING_URL']),
        routeCameraEndpoint: _serviceUri(configuration['ROUTE_CAMERA_URL']),
      ),
    );
    return this;
  }
}

Uri? _serviceUri(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.parse(value.trim());
  if (!uri.hasAuthority || !['http', 'https'].contains(uri.scheme)) {
    throw ArgumentError('Service URLs must use HTTP or HTTPS.');
  }
  return uri;
}
