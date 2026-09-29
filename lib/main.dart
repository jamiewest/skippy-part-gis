import 'package:extensions_flutter/extensions_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:riverside_atlas/app/app.dart';
import 'package:riverside_atlas/app/atlas_assistant.dart';
import 'package:riverside_atlas/app/atlas_configuration.dart';
import 'package:riverside_atlas/app/atlas_services.dart';

/// Builds the host and runs the workspace inside it.
///
/// Everything the application owns is registered before `build()` and nothing
/// is added afterwards: the host is the one place a service's lifetime is
/// decided, and `runApp` lives inside `addFlutter` so the Flutter binding,
/// the logging pipeline and the application lifetime all start together.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final builder = Host.createApplicationBuilder();
  addAtlasConfiguration(builder.configuration);
  builder.services
    ..addLogging((logging) => logging.addSimpleConsole())
    ..addAtlas(configuration: builder.configuration)
    ..addMapAssistant(configuration: builder.configuration)
    ..addFlutter(
      (flutter) =>
          flutter.runApp((services) => RiversideAtlasApp(services: services)),
    );

  await builder.build().run();
}
