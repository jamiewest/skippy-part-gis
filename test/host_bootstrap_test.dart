import 'dart:io';

import 'package:checks/checks.dart';
import 'package:extensions_flutter/extensions_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/app/atlas_services.dart';
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/data/services/county_source.dart';

void main() {
  // Resolving the graph constructs the real database, which asks
  // path_provider for a directory over a platform channel and then opens the
  // file asynchronously. The answer is installed once for the whole suite
  // rather than per test, because the open completes after the test that
  // triggered it has already finished.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final directory = Directory.systemTemp.createTempSync('atlas-host');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
  });

  /// A container holding the application's registrations over [settings].
  ServiceProvider provider([Map<String, String> settings = const {}]) {
    final configuration =
        (ConfigurationBuilder()..addInMemoryCollection(settings.entries))
            .build();
    return (ServiceCollection()
          ..addLogging()
          ..addAtlas(configuration: configuration))
        .buildServiceProvider();
  }

  test('shares one HTTP client and one graph across the container', () async {
    final services = provider();
    final dependencies = services.getRequiredService<AppDependencies>();
    addTearDown(dependencies.close);

    // Every service sharing one client is the point of registering it: the
    // county services, the catalogue reader and the census reader would
    // otherwise open three connection pools to the same handful of hosts.
    check(
      identical(
        services.getRequiredService<http.Client>(),
        dependencies.client,
      ),
    ).isTrue();
    check(
      identical(services.getRequiredService<AppDependencies>(), dependencies),
    ).isTrue();
    check(dependencies.initialCounty.id).equals(riversideCountyId);
  });

  test('leaves the census reader keyless when nothing configures one', () {
    // The tract lookup still works without a key; only the published figures
    // behind it need one, which the profile says rather than hides.
    check(provider().getRequiredService<CensusService>().hasApiKey).isFalse();
  });

  test('gives the census reader the configured key', () {
    final services = provider({'CENSUS_API_KEY': 'from-configuration'});

    check(services.getRequiredService<CensusService>().hasApiKey).isTrue();
  });
}
