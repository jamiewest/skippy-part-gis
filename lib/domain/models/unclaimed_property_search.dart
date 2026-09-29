import 'package:flutter/foundation.dart';

/// Search terms for a California unclaimed-property record, kept so a saved
/// public-record check can be matched back to a selected owner.
@immutable
final class UnclaimedPropertyQuery {
  /// Creates normalized search terms for an owner and location.
  const UnclaimedPropertyQuery({
    required this.ownerName,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.zipCode,
  });

  /// Creates a best-effort individual or business search from a tax owner.
  factory UnclaimedPropertyQuery.fromOwner({
    required String ownerName,
    required String city,
    required String zipCode,
  }) {
    final normalizedOwner = ownerName.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasBusinessTerm = _businessTerms.any(
      (term) => RegExp(
        '(^|[^A-Z])${RegExp.escape(term)}([^A-Z]|\$)',
      ).hasMatch(normalizedOwner.toUpperCase()),
    );
    // Joint individual owners use the first listed person. A business's
    // conjunctions are part of its name (for example, SMITH & JONES LLC).
    final cleanedOwner = hasBusinessTerm
        ? normalizedOwner
        : normalizedOwner
              .replaceFirst(
                RegExp(r'\s+(?:&|AND)\s+.*$', caseSensitive: false),
                '',
              )
              .replaceFirst(
                RegExp(r'\s+ET\s+AL\.?.*$', caseSensitive: false),
                '',
              )
              .trim();
    final tokens = cleanedOwner
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final looksLikeAssessorPerson =
        tokens.length == 2 ||
        (tokens.length == 3 && tokens.last.replaceAll('.', '').length == 1);
    final isBusiness = hasBusinessTerm || !looksLikeAssessorPerson;

    return UnclaimedPropertyQuery(
      ownerName: ownerName.trim(),
      firstName: !isBusiness && tokens.length > 1 ? tokens[1] : '',
      lastName: isBusiness || tokens.isEmpty ? cleanedOwner : tokens.first,
      city: city.trim(),
      zipCode: zipCode.trim(),
    );
  }

  static const _businessTerms = {
    'LLC',
    'L L C',
    'INC',
    'CORP',
    'CORPORATION',
    'COMPANY',
    'CO',
    'LTD',
    'LP',
    'LLP',
    'TRUST',
    'ESTATE',
    'ASSOCIATION',
    'BANK',
    'CHURCH',
    'CLUB',
    'DISTRICT',
    'FOUNDATION',
    'HOLDINGS',
    'HOSPITAL',
    'HOTEL',
    'INVESTMENTS',
    'MANAGEMENT',
    'PARTNERS',
    'PARTNERSHIP',
    'PROPERTIES',
    'SCHOOL',
    'UNIVERSITY',
  };

  /// Owner text published by the county tax source.
  final String ownerName;

  /// Best-effort first name. The official page remains editable.
  final String firstName;

  /// Best-effort surname or the complete business name.
  final String lastName;

  /// Optional city used to narrow the search.
  final String city;

  /// Optional ZIP code used to narrow the search.
  final String zipCode;

  /// Stable key for reusing the same public-record lookup.
  String get cacheKey => [ownerName, city, zipCode].map(_normalize).join('|');

  static String _normalize(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// A completed exact-match check against California's public search.
@immutable
final class UnclaimedPropertySearchResult {
  /// Creates a completed state search.
  const UnclaimedPropertySearchResult({
    required this.query,
    required this.found,
    required this.resultCount,
    required this.checkedAt,
    required this.sourceUri,
    this.isSaved = false,
  });

  /// Search terms associated with the selected owner.
  final UnclaimedPropertyQuery query;

  /// Whether California reported at least one exact match.
  final bool found;

  /// Number of result records returned by the public search.
  final int resultCount;

  /// Time the official source was checked.
  final DateTime checkedAt;

  /// Official state search page.
  final Uri sourceUri;

  /// Whether this result was restored from persistent storage.
  final bool isSaved;
}
