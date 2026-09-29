import 'package:riverside_atlas/domain/models/address.dart';
import 'package:riverside_atlas/domain/models/parcel.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';
import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';
import 'package:riverside_atlas/ui/features/map/view_models/gis_map_view_model.dart';

/// The `CITY, CA ZIP` line for a property, with missing parts left out.
///
/// Counties do not all publish both parts: San Bernardino parcels carry no ZIP
/// code at all. Interpolating the blanks would produce `HESPERIA, CA ` or
/// `, CA `, which reads as real data once it is pasted somewhere else.
String propertyLocationLine({
  required String city,
  required String zipCode,
  String stateCode = 'CA',
}) {
  if (city.isEmpty && zipCode.isEmpty) {
    return '';
  }
  if (zipCode.isEmpty) {
    return '$city, $stateCode';
  }
  if (city.isEmpty) {
    return '$stateCode $zipCode';
  }
  return '$city, $stateCode $zipCode';
}

/// The one-line outcome of a saved California unclaimed-property check.
String unclaimedPropertySummary(UnclaimedPropertySearchResult result) {
  final records = result.resultCount == 1 ? 'record' : 'records';
  final counted = '${result.resultCount} $records returned';
  final outcome = result.found
      ? 'Possible match • $counted • exact owner match reported'
      : 'No exact owner match • $counted';
  return '$outcome • California ClaimIt checked '
      '${_formatDate(result.checkedAt)}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// The `LABEL: value` block describing the selected address or parcel.
///
/// Returns null when nothing is selected. A field the county does not publish
/// is omitted rather than copied as a blank or as the panel's `Not provided`
/// placeholder, so every line that is pasted is a fact from the source.
String? propertyClipboardText({
  required String countyName,
  String stateCode = 'CA',
  String? parcelSourceLabel,
  required Address? address,
  required Parcel? parcel,
  required PropertyOwnership? ownership,
  required OwnerLookupStatus ownerLookupStatus,
  required UnclaimedPropertySearchResult? unclaimedProperty,
}) {
  final lines = <String>[];
  void add(String label, String value) {
    if (value.isNotEmpty) {
      lines.add('$label: $value');
    }
  }

  // A pending, missing, or unavailable lookup has no owner to report, and an
  // unavailable one is the normal case outside Riverside County.
  final ownerName = ownerLookupStatus == OwnerLookupStatus.found
      ? ownership?.ownerName ?? ''
      : '';
  final unclaimed = unclaimedProperty == null
      ? ''
      : unclaimedPropertySummary(unclaimedProperty);

  if (address != null) {
    add('ADDRESS', address.fullAddress);
    add('UNIT', address.unit);
    add(
      'LOCATION',
      propertyLocationLine(
        stateCode: stateCode,
        city: address.city,
        zipCode: address.zipCode,
      ),
    );
    add('APN', address.apn);
    add('OWNER', ownerName);
    add('UNCLAIMED', unclaimed);
    add(
      'ADDRESS TYPE',
      address.addressType.isEmpty ? '' : 'County code ${address.addressType}',
    );
    add('UNITS', '${address.numberOfUnits}');
    add('SOURCE', parcelSourceLabel ?? '$countyName Address Points');
  } else if (parcel != null) {
    add('ADDRESS', parcel.situsAddress);
    add(
      'LOCATION',
      propertyLocationLine(
        stateCode: stateCode,
        city: parcel.city,
        zipCode: parcel.zipCode,
      ),
    );
    add('APN', parcel.apn);
    add('OWNER', ownerName);
    add('UNCLAIMED', unclaimed);
    add('LAND USE', parcel.landUse);
    add('ACREAGE', parcel.acreage?.toStringAsFixed(2) ?? '');
    add('SOURCE', parcelSourceLabel ?? '$countyName Assessor');
  }

  return lines.isEmpty ? null : lines.join('\n');
}
