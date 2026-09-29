import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

import 'support/fake_map_repositories.dart';

void main() {
  const drawn = GeoBounds(west: -117.4, south: 33.9, east: -117.3, north: 34.0);

  test('normalizes a rectangle dragged towards the north-west', () {
    final bounds = boundsFromCorners(
      const LatLng(34.0, -117.3),
      const LatLng(33.9, -117.4),
    );

    check(bounds.west).equals(-117.4);
    check(bounds.south).equals(33.9);
    check(bounds.east).equals(-117.3);
    check(bounds.north).equals(34.0);
  });

  test('lists the addresses inside the rectangle in street order', () async {
    final viewModel = buildFakeMapViewModel(
      addresses: _StubAddressRepository([
        _address('200 MAIN ST', 'MAIN', 200, const LatLng(33.95, -117.35)),
        _address('40 MAIN ST', 'MAIN', 40, const LatLng(33.96, -117.36)),
        _address('1 ASH AVE', 'ASH', 1, const LatLng(33.94, -117.34)),
      ]),
    );
    addTearDown(viewModel.dispose);

    await viewModel.selectArea(RectangleArea(drawn));

    final selection = viewModel.areaSelection!;
    check(selection.status).equals(AreaSelectionStatus.ready);
    check(
      selection.addresses.map((address) => address.fullAddress).toList(),
    ).deepEquals(['1 ASH AVE', '40 MAIN ST', '200 MAIN ST']);
    check(selection.truncated).isFalse();
  });

  test(
    'drops a point the source returned from outside the rectangle',
    () async {
      final viewModel = buildFakeMapViewModel(
        addresses: _StubAddressRepository([
          _address('1 IN ST', 'IN', 1, const LatLng(33.95, -117.35)),
          _address('2 OUT ST', 'OUT', 2, const LatLng(35.5, -120.0)),
        ]),
      );
      addTearDown(viewModel.dispose);

      await viewModel.selectArea(RectangleArea(drawn));

      check(viewModel.areaSelection!.count).equals(1);
    },
  );

  test('reports a list the source capped at its limit', () async {
    final viewModel = buildFakeMapViewModel(
      addresses: _StubAddressRepository([
        for (var index = 0; index < areaSelectionLimit; index++)
          _address(
            '$index MAIN ST',
            'MAIN',
            index,
            const LatLng(33.95, -117.35),
          ),
      ]),
    );
    addTearDown(viewModel.dispose);

    await viewModel.selectArea(RectangleArea(drawn));

    check(viewModel.areaSelection!.truncated).isTrue();
  });

  test('disarms the tool once a rectangle has been drawn', () async {
    final viewModel = buildFakeMapViewModel(
      addresses: _StubAddressRepository(const []),
    );
    addTearDown(viewModel.dispose);
    viewModel.setAreaSelectMode(true);
    check(viewModel.areaSelectMode).isTrue();

    await viewModel.selectArea(RectangleArea(drawn));

    check(viewModel.areaSelectMode).isFalse();
    check(viewModel.areaSelection!.status).equals(AreaSelectionStatus.ready);
    check(viewModel.areaSelection!.count).equals(0);
  });

  test('says the addresses could not be read and reads them again', () async {
    final repository = _StubAddressRepository(const [], failing: true);
    final viewModel = buildFakeMapViewModel(addresses: repository);
    addTearDown(viewModel.dispose);

    await viewModel.selectArea(RectangleArea(drawn));

    check(viewModel.areaSelection!.status).equals(AreaSelectionStatus.failed);
    check(viewModel.areaSelection!.message).isNotNull();

    repository
      ..failing = false
      ..addresses = [
        _address('1 ASH AVE', 'ASH', 1, const LatLng(33.95, -117.35)),
      ];
    viewModel.retryAreaSelection();
    await pumpEventQueue();

    check(viewModel.areaSelection!.status).equals(AreaSelectionStatus.ready);
    check(viewModel.areaSelection!.count).equals(1);
  });

  test('drops the drawn area when the data source changes', () async {
    final viewModel = buildFakeMapViewModel(
      addresses: _StubAddressRepository(const []),
      snapshotAvailable: true,
    );
    addTearDown(viewModel.dispose);
    await viewModel.initialize();
    await viewModel.selectArea(RectangleArea(drawn));
    check(viewModel.areaSelection).isNotNull();

    await viewModel.setMode(DataMode.offline);

    check(viewModel.areaSelection).isNull();
  });

  test('clears the drawn area on request', () async {
    final viewModel = buildFakeMapViewModel(
      addresses: _StubAddressRepository(const []),
    );
    addTearDown(viewModel.dispose);
    await viewModel.selectArea(RectangleArea(drawn));

    viewModel.clearAreaSelection();

    check(viewModel.areaSelection).isNull();
  });
}

final class _StubAddressRepository implements AddressRepository {
  _StubAddressRepository(this.addresses, {this.failing = false});

  List<Address> addresses;
  bool failing;

  @override
  Future<List<Address>> queryViewport(
    GeoBounds bounds, {
    int limit = 2000,
  }) async {
    if (failing) {
      throw StateError('unreachable');
    }
    return addresses.take(limit).toList(growable: false);
  }

  @override
  Future<List<Address>> search(String query, {int limit = 20}) async =>
      const [];
}

Address _address(String full, String street, int number, LatLng position) {
  return Address(
    objectId: number,
    sourceId: number,
    fullAddress: full,
    houseNumber: number,
    streetName: street,
    streetType: 'ST',
    unit: '',
    city: 'RIVERSIDE',
    zipCode: '92501',
    apn: '',
    addressType: '',
    numberOfUnits: 1,
    position: position,
  );
}
