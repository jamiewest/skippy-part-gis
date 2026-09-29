import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverside_atlas/app/theme.dart';
import 'package:riverside_atlas/domain/repositories/county_data_sources.dart';
import 'package:riverside_atlas/ui/features/map/views/gis_map_screen.dart';
import 'support/fake_map_repositories.dart';

void main() {
  testWidgets('runtime adoption enables parcel controls and shows provenance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final stream = StreamController<CountyDataSources>();
    final model = buildFakeMapViewModel(
      parcelsAvailable: false,
      resolveParcelSource: (_) => stream.stream,
    );
    final sources = CountyDataSources(
      liveAddresses: model.liveAddresses,
      localAddresses: model.localAddresses,
      liveParcels: model.liveParcels,
      localParcels: model.localParcels,
      snapshotManager: model.snapshotManager,
      propertyOwners: model.propertyOwners,
      situsAddresses: model.situsAddresses,
      parcelsAvailable: true,
      parcelSourceLabel: 'Example County · Parcel (detected)',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AtlasTheme.light,
        home: GisMapScreen(viewModel: model, enableBaseMap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final switchFinder = find.descendant(
      of: find.byKey(const Key('address-layer-switch')),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(switchFinder).onChanged, isNull);
    expect(find.text('Looking for a parcel layer…'), findsOneWidget);
    stream.add(sources);
    unawaited(stream.close());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<SwitchListTile>(switchFinder).onChanged, isNotNull);
    expect(
      find.text('From Example County · Parcel (detected)'),
      findsNWidgets(2),
    );
    await tester.tap(switchFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(model.addressesVisible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    await tester.pumpAndSettle();
  });
}
