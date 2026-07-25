/// Text normalization shared by county public-record lookups.
///
/// Counties publish the same parcel number and situs address under different
/// punctuation, casing, and HTML escaping, so resolvers compare values through
/// these helpers instead of comparing raw strings.
library;

final _nonDigits = RegExp(r'[^0-9]');
final _nonAlphanumeric = RegExp(r'[^A-Z0-9]+');
final _runsOfWhitespace = RegExp(r'\s+');
final _characterReference = RegExp(r'&#(x?[0-9a-fA-F]+);');

const _namedEntities = <String, String>{
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
};

/// The digits in [value], with separators, letters, and spacing removed.
///
/// Counties format parcel numbers inconsistently — `213-191-035` and
/// `213191035` name the same Riverside parcel — so the digits are the only
/// portable form to compare and to key a cache by.
String digitsOnly(String value) => value.replaceAll(_nonDigits, '');

/// [value] upper-cased with every run of punctuation collapsed to one space.
String normalizeForMatching(String value) => value
    .toUpperCase()
    .replaceAll(_nonAlphanumeric, ' ')
    .replaceAll(_runsOfWhitespace, ' ')
    .trim();

/// The distinct normalized words in [value].
Set<String> matchTokens(String value) => normalizeForMatching(
  value,
).split(' ').where((token) => token.isNotEmpty).toSet();

/// [value] with the HTML entities county pages emit replaced by their text.
///
/// County portals render owner names straight into HTML, so an ampersand in a
/// trust name arrives escaped and has to be restored before display.
String decodeHtmlEntities(String value) {
  var decoded = value;
  for (final entity in _namedEntities.entries) {
    decoded = decoded.replaceAll(entity.key, entity.value);
  }
  return decoded.replaceAllMapped(_characterReference, (match) {
    final reference = match.group(1)!;
    final codePoint = reference.startsWith('x')
        ? int.tryParse(reference.substring(1), radix: 16)
        : int.tryParse(reference);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
}
