import 'dart:convert';

import 'package:riverside_atlas/domain/models/unclaimed_property_search.dart';

/// Fills ClaimIt's public form and clicks its normal search button once.
///
/// The caller retries while Angular builds the form. Verification remains
/// entirely with ClaimIt; this does not call its API or interact with Turnstile.
String claimItSearchScript(UnclaimedPropertyQuery query) {
  final terms = jsonEncode({
    'lastName': query.lastName,
    'firstName': query.firstName,
  });
  return '''
(() => {
  if (location.origin !== 'https://claimit.ca.gov' ||
      location.pathname !== '/app/claim-search') return 'away';
  if (window.__atlasClaimItSubmitted) return 'submitted';
  const terms = $terms;
  const last = document.querySelector('input[name="lastName"]');
  const first = document.querySelector('input[name="firstName"]');
  const button = document.querySelector('#btn-turnstile, #search-property');
  if (!last || !first || !button) return 'waiting';
  if (!window.__atlasClaimItFilled) {
    const setValue = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype, 'value').set;
    const fill = (input, value) => {
      setValue.call(input, value);
      input.dispatchEvent(new Event('input', {bubbles: true}));
      input.dispatchEvent(new Event('change', {bubbles: true}));
      input.dispatchEvent(new Event('blur', {bubbles: true}));
    };
    fill(last, terms.lastName);
    fill(first, terms.firstName);
    // Search by name only; clear optional filters restored by the site.
    for (const name of ['city', 'searchZipCode', 'propertyID']) {
      const input = document.querySelector('input[name="' + name + '"]');
      if (input) fill(input, '');
    }
    window.__atlasClaimItFilled = true;
    return 'waiting';
  }
  if (button.disabled) return 'waiting';
  window.__atlasClaimItSubmitted = true;
  button.click();
  return 'submitted';
})()
''';
}
