import 'package:riverside_atlas/data/services/snapshot_manager.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Repositories replaced atomically when a runtime parcel source changes.
final class CountyDataSources {
  const CountyDataSources({
    required this.liveAddresses,
    required this.liveParcels,
    required this.localAddresses,
    required this.localParcels,
    required this.snapshotManager,
    required this.propertyOwners,
    required this.situsAddresses,
    required this.parcelsAvailable,
    this.parcelSourceLabel,
  });
  final AddressRepository liveAddresses, localAddresses;
  final ParcelRepository liveParcels, localParcels;
  final GisSnapshotController snapshotManager;
  final PropertyOwnerRepository propertyOwners;
  final SitusAddressRepository situsAddresses;
  final bool parcelsAvailable;
  final String? parcelSourceLabel;
}
