import 'package:flutter/foundation.dart';
import 'package:riverside_atlas/core/text_matching.dart';
import 'package:riverside_atlas/domain/models/owner_query.dart';
import 'package:riverside_atlas/domain/models/property_ownership.dart';

/// One county's public source for current property-owner names.
///
/// Counties publish owners through unrelated systems — a tax-collector search,
/// an assessor portal, a records request — so each county writes its own
/// implementation and only the request and result shapes are shared. There is
/// deliberately no shared base class: the request and response shape of the
/// next county's site is unknown until it is read, and a template that does
/// not fit is worse than none. Reuse comes from the helpers below, which an
/// implementation calls rather than inherits.
///
/// A `null` result and a thrown error mean different things and the map
/// reports them differently. Return `null` when the source answered but had no
/// unambiguous match; throw when the source could not be reached, could not be
/// parsed, or refused the request.
abstract interface class PropertyOwnerSource {
  /// The public page a matched record is attributed to.
  ///
  /// Used as the recorded provenance when a lookup finds nothing, so a saved
  /// no-match row still names the source that was checked.
  Uri get sourceUri;

  /// The owner published for [query]'s parcel number.
  Future<PropertyOwnership?> lookupByApn(OwnerQuery query);

  /// The owner published for [query]'s street address.
  Future<PropertyOwnership?> lookupByAddress(OwnerQuery query);
}

/// One row a county search returned, before its owner detail is read.
///
/// County searches answer with a list before the owner is known, so every
/// implementation narrows that list to a single row through
/// [selectOwnerCandidate] and only then spends a request on the detail page.
@immutable
final class OwnerCandidate {
  /// Creates a search result row.
  const OwnerCandidate({
    required this.parcelId,
    required this.recordKey,
    required this.situs,
  });

  /// The parcel number as this county published it.
  final String parcelId;

  /// The county's own key for the matching record's detail page.
  ///
  /// Opaque and county-specific: Riverside uses a tax-roll alternate key,
  /// another county may use an account number or a row identifier.
  final String recordKey;

  /// The situs address the county published for the row.
  final String situs;
}

/// The one row that unambiguously answers a lookup, or `null`.
///
/// A single distinct row is accepted outright. When a search returns several,
/// only an exact [preferredApn] match resolves it; anything still ambiguous is
/// reported as no match rather than guessed, because naming the wrong owner of
/// a property is worse than naming none.
OwnerCandidate? selectOwnerCandidate(
  Iterable<OwnerCandidate> candidates, {
  required String preferredApn,
}) {
  final unique = <String, OwnerCandidate>{
    for (final candidate in candidates)
      '${candidate.parcelId}|${candidate.recordKey}': candidate,
  }.values.toList(growable: false);
  if (unique.length == 1) {
    return unique.single;
  }
  final apn = normalizeApn(preferredApn);
  if (apn.isEmpty) {
    return null;
  }
  final apnMatches = unique
      .where((candidate) => normalizeApn(candidate.parcelId) == apn)
      .toList(growable: false);
  return apnMatches.length == 1 ? apnMatches.single : null;
}

/// Whether [situs] carries every address component [query] published.
///
/// County search endpoints match loosely and will answer a house number on one
/// street with the same number on another, so each component the GIS layer
/// published has to appear in the returned situs before the row is trusted.
/// Components the county left blank are not held against the row.
bool situsMatchesQuery(String situs, OwnerQuery query) {
  final published = matchTokens(situs);
  final houseNumber = query.houseNumber?.toString();
  if (situs.isEmpty ||
      houseNumber == null ||
      !published.contains(houseNumber) ||
      !matchTokens(query.streetName).every(published.contains)) {
    return false;
  }
  for (final component in [query.streetType, query.city, query.unit]) {
    final tokens = matchTokens(component);
    if (tokens.isNotEmpty && !tokens.every(published.contains)) {
      return false;
    }
  }
  final zipCode = digitsOnly(query.zipCode);
  return zipCode.isEmpty || published.contains(zipCode);
}
