import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/county_source.dart';
import 'package:riverside_atlas/data/services/statewide_parcel_source.dart';
import 'package:riverside_atlas/data/services/statewide_situs_service.dart';
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Builds the situs resolver a state's parcel fabric can answer from.
typedef SitusSourceFactory =
    SitusAddressRepository Function(http.Client client);

/// One statewide parcel fabric, covering every county in that state.
///
/// This is the tier that made California work without per-county effort: one
/// public layer carrying an assessor parcel number and a mailable address for
/// all 58 counties. It is a state-level fact, not a national one. There is no
/// free national parcel layer, and this type exists to say so precisely --
/// a state with no entry has no parcel coverage, rather than having coverage
/// this build has not found.
@immutable
final class StateParcelSource {
  /// Creates a statewide parcel fabric description.
  const StateParcelSource({
    required this.query,
    required this.parcelFields,
    required this.addressFields,
    required this.addressSearchField,
    required this.countyFilterField,
    required this.parcelMapper,
    required this.addressMapper,
    this.addressQueryParameters = const {'returnGeometry': 'true'},
    this.uppercaseAddressSearch = true,
    this.situsSource,
  });

  /// The layer's `query` endpoint, answering both parcels and addresses.
  final Uri query;

  /// `outFields` needed to draw and describe a parcel.
  final String parcelFields;

  /// `outFields` needed to describe a parcel as an address point.
  final String addressFields;

  /// The field an address prefix search matches against.
  final String addressSearchField;

  /// The field holding a five-digit county FIPS code.
  ///
  /// This is what scopes a shared layer to one county for address search and
  /// offline download. Naming the field rather than the clause lets each
  /// county build its own filter from its own FIPS code.
  final String countyFilterField;

  /// Attribute translation for the layer's parcel schema.
  final ArcGisFeatureMapper parcelMapper;

  /// Attribute translation for the layer's address schema.
  final ArcGisFeatureMapper addressMapper;

  /// Extra query parameters the layer needs to answer as address points.
  final Map<String, String> addressQueryParameters;

  /// Whether an address prefix search must upper-case the field first.
  final bool uppercaseAddressSearch;

  /// Resolves a parcel's street address of record from a map point.
  ///
  /// Null means this state's fabric cannot answer the question, so a county
  /// with no situs of its own reports the address as unavailable rather than
  /// showing a blank line where one should be.
  final SitusSourceFactory? situsSource;

  /// The `where` clause restricting this layer to the county at [countyFips].
  String countyFilter(String countyFips) => "$countyFilterField='$countyFips'";
}

/// What a state publishes that covers all of its counties.
///
/// Nationally this is usually nothing: most states run no statewide parcel
/// service, and their counties are read through whatever each county
/// publishes, or not at all. The type is still worth having for every state,
/// because it is where a state's fabric gets added when one is found -- one
/// entry lights up every county in that state at once, exactly as California's
/// did.
@immutable
final class StateSource {
  /// Creates a state configuration.
  const StateSource({required this.fips, this.parcels});

  /// Two-digit state FIPS code, such as `06`.
  final String fips;

  /// The statewide parcel fabric, when the state publishes one.
  final StateParcelSource? parcels;

  /// The state's identity and geography.
  UsState get state => UsGeography.stateByFips(fips)!;

  /// Whether any public layer covers parcels across this whole state.
  bool get hasStatewideParcels => parcels != null;
}

/// The statewide fabrics this build reads, by two-digit state FIPS code.
///
/// California is the only entry so far. It is here rather than special-cased
/// because the shape is what generalises: finding, say, a North Carolina or a
/// Montana statewide parcel service is a matter of adding one entry, after
/// which every county in that state gets parcels, address search, and offline
/// download with no further work.
///
/// A state absent from this map is not a state without parcel data; it is a
/// state whose data this build has not found a single public source for. The
/// distinction matters, and [CountySource.hasParcelCoverage] is what the
/// application reports rather than showing an empty map.
abstract final class StateSources {
  /// California, read through CAL FIRE's republished statewide parcel view.
  ///
  /// See [statewideParcelQuery] for what that layer is and why its hostname
  /// is not the durable handle for it.
  static final california = StateSource(
    fips: '06',
    parcels: StateParcelSource(
      query: statewideParcelQuery,
      parcelFields: statewideParcelFields,
      addressFields: statewideAddressFields,
      addressSearchField: statewideAddressSearchField,
      addressQueryParameters: statewideAddressQueryParameters,
      uppercaseAddressSearch: false,
      countyFilterField: 'FIPS_CODE',
      parcelMapper: const StatewideParcelMapper(),
      addressMapper: const StatewideAddressMapper(),
      situsSource: StatewideSitusService.new,
    ),
  );

  /// Every state with a configured statewide fabric, by FIPS code.
  static final byFips = Map<String, StateSource>.unmodifiable({
    california.fips: california,
  });

  /// The configuration for the state at [fips], or `null` when none exists.
  static StateSource? forFips(String fips) => byFips[fips];
}
