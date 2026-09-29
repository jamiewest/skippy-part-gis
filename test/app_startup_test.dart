import 'package:drift/native.dart';
import 'package:extensions/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/app/app.dart';
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/data/database/app_database.dart';
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'package:riverside_atlas/ui/features/map/widgets/county_menu_button.dart';

void main() {
  testWidgets('Atlas opens on the US, then frames a selected county', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dependencies = AppDependencies(
      client: MockClient(
        (_) async => http.Response('{"features":[],"items":[]}', 200),
      ),
      database: AppDatabase.forTesting(NativeDatabase.memory()),
    );
    await tester.pumpWidget(
      RiversideAtlasApp(
        services: ServiceCollection().buildServiceProvider(),
        dependencies: dependencies,
      ),
    );
    await tester.pump();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Atlas');
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.mapController!.camera.visibleBounds.contains(const LatLng(48, -124)),
      isTrue,
    );
    expect(
      map.mapController!.camera.visibleBounds.contains(const LatLng(25, -80)),
      isTrue,
    );
    // Selecting even the already-active data county leaves the national view.
    await tester.tap(find.byType(CountyMenuButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('county-filter-field')),
      'Riverside',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Riverside County'));
    await tester.pump();
    final selected = tester.widget<GisMapScreen>(find.byType(GisMapScreen));
    expect(selected.initialBounds, CountySources.riverside.extent);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
