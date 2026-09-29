import 'package:riverside_atlas/domain/models/address.dart';

/// The header row of an exported address list.
const _header = [
  'address',
  'unit',
  'city',
  'state',
  'zip',
  'apn',
  'units',
  'latitude',
  'longitude',
  'county',
];

/// The comma-separated table of [addresses] read from [countyName].
///
/// The header is always written, so an empty rectangle exports a file that
/// says what it would have contained rather than an empty one. Coordinates are
/// written at six decimal places, which is about a tenth of a metre: enough to
/// re-plot the point, and short enough that a spreadsheet shows the whole
/// value.
String addressListCsv({
  required List<Address> addresses,
  String stateCode = 'CA',
  required String countyName,
}) {
  final buffer = StringBuffer()..writeln(_header.join(','));
  for (final address in addresses) {
    buffer.writeln(
      [
        address.fullAddress,
        address.unit,
        address.city,
        stateCode,
        address.zipCode,
        address.apn,
        '${address.numberOfUnits}',
        address.position.latitude.toStringAsFixed(6),
        address.position.longitude.toStringAsFixed(6),
        countyName,
      ].map(csvField).join(','),
    );
  }
  return buffer.toString();
}

/// [value] quoted for CSV when it holds a comma, quote, or line break.
///
/// Street addresses regularly hold commas and the odd quote mark, and a field
/// written raw would silently shift every later column of that row.
String csvField(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

/// The file name for an export taken at [timestamp] in [countyName].
String addressListFileName({
  required String countyName,
  required DateTime timestamp,
}) {
  final local = timestamp.toLocal();
  final stamp = [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
    '-',
    local.hour.toString().padLeft(2, '0'),
    local.minute.toString().padLeft(2, '0'),
    local.second.toString().padLeft(2, '0'),
  ].join();
  final county = countyName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-|-\$'), '');
  return '${county.isEmpty ? 'addresses' : county}-addresses-$stamp.csv';
}
