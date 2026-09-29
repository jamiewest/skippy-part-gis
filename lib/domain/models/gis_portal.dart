import 'package:flutter/foundation.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// Who publishes a catalogue, and therefore who a layer is attributed to.
///
/// This is carried rather than inferred because getting it wrong is a claim
/// about provenance. A council of governments' data drawn under a county's
/// name asserts the county published it, which it did not.
enum PortalTier {
  /// Published by the county government itself.
  countyPortal,

  /// Published by an incorporated city's government, covering that city.
  city,

  /// Published by somebody else whose data covers the county — a council of
  /// governments, a park district, a city, a neighbouring county.
  partner,

  /// Published by a state agency, covering that one state.
  ///
  /// A state agency's data stops at the state line. CAL FIRE's fire hazard
  /// severity zones describe California and say nothing about Nevada, so this
  /// tier is offered only in the state that published it.
  statewide,

  /// Published by a federal agency, covering the whole country.
  ///
  /// Kept apart from [statewide] because the two are different claims about
  /// who vouches for a layer and over what area. This is the tier every
  /// county gets wherever it is.
  national,
}

/// How this build came to know a catalogue exists.
///
/// Carried because it changes what the other fields are worth. A registered
/// entry was enumerated and verified when the inventory ran; a discovered one
/// was matched against a place name minutes ago and is offered on the strength
/// of a geographic test, not a human's reading. The panel says which, so a
/// wrong guess reads as a guess.
enum PortalOrigin {
  /// Written into the generated registry by the offline inventory.
  registered,

  /// Found at runtime by [PortalDiscoveryRepository].
  discovered,
}

/// One public ArcGIS REST catalogue the app can list layers from.
///
/// The root is the only durable fact: services behind it are added and retired
/// continuously, so they are discovered at runtime rather than recorded here.
@immutable
final class GisPortal {
  /// Creates a catalogue reference.
  const GisPortal({
    required this.root,
    required this.publisher,
    required this.tier,
    this.serviceCount = 0,
    this.coverage,
    this.origin = PortalOrigin.registered,
  });

  /// The `.../rest/services` catalogue root.
  final String root;

  /// Display name of the publishing organisation.
  final String publisher;

  /// Whose catalogue this is.
  final PortalTier tier;

  /// Services counted when the inventory last ran.
  ///
  /// A hint for ordering and for warning before an expensive expansion, not a
  /// promise — the live catalogue is what gets listed.
  final int serviceCount;

  /// Where this publisher's data was measured to fall, when it was measured.
  ///
  /// Null means unmeasured, which is offered everywhere the tier applies —
  /// every registry entry, because the inventory scoped those by county
  /// already. A discovered catalogue carries the union of its items' own
  /// advertised extents instead, so a city's catalogue appears when the map
  /// reaches the city and drops away when it leaves. That is the same rule
  /// [CityPortals] applies, generalised to a publisher this build had never
  /// heard of before the user panned there.
  final GeoBounds? coverage;

  /// Whether this entry was registered offline or found at runtime.
  final PortalOrigin origin;

  /// Whether this catalogue was found by live search rather than registered.
  bool get isDiscovered => origin == PortalOrigin.discovered;

  /// The catalogue root as a [Uri].
  Uri get uri => Uri.parse(root);

  /// Host shown when a portal fails, so the user can see which one broke.
  String get host => uri.host;

  /// Whether this catalogue covers far more than the county being viewed.
  ///
  /// State and federal catalogues are grouped below the local ones in the
  /// panel, because a user looking for a county's own zoning map should not
  /// have to scroll past the National Weather Service to reach it.
  bool get isWideArea =>
      tier == PortalTier.statewide || tier == PortalTier.national;

  /// A key equal for two roots that name the same server.
  ///
  /// One server routinely answers on more than one name, and offering both
  /// puts every layer in the panel twice. Three differences are collapsed,
  /// each observed in real catalogues:
  ///
  /// * **Top-level domain** — Cuyahoga answers on `.gov` and on `.us`.
  /// * **A numbered sibling** — Riverside answers on `gis.` and `gis1.`,
  ///   Esri's hosting on `services.` and `services1.`. The organisation id
  ///   that distinguishes two Esri-hosted publishers is in the path, which is
  ///   kept, so collapsing the host digit cannot merge two publishers.
  /// * **Case** — ArcGIS Online publishes item URLs under both
  ///   `/arcgis/rest/services` and `/ArcGIS/rest/services`.
  static String aliasKeyOf(String root) {
    final uri = Uri.parse(root);
    final labels = uri.host.split('.');
    if (labels.isNotEmpty) {
      labels[0] = labels.first.replaceAll(RegExp(r'\d+$'), '');
    }
    final stem = labels.length > 1
        ? labels.sublist(0, labels.length - 1).join('.')
        : labels.join('.');
    return '$stem${uri.path}'.toLowerCase();
  }

  /// This catalogue's [aliasKeyOf].
  String get aliasKey => aliasKeyOf(root);

  /// Whether this catalogue is worth offering while the map shows [viewport].
  ///
  /// Unmeasured and wide-area catalogues are always worth offering; a
  /// measured local one is offered only where its publisher maps. Without
  /// this a county switch in a metropolitan area would list every city
  /// catalogue in the county at once — 88 of them in Los Angeles.
  bool coversViewport(GeoBounds viewport) =>
      isWideArea || coverage == null || coverage!.intersects(viewport);

  @override
  bool operator ==(Object other) =>
      other is GisPortal && other.root == root && other.tier == tier;

  @override
  int get hashCode => Object.hash(root, tier);

  @override
  String toString() => 'GisPortal($root)';
}

/// One incorporated city's public catalogues and where they apply.
///
/// Carried per city rather than flattened into the county's portal list
/// because a county can hold dozens of cities — Los Angeles has 88 — and a
/// city's catalogue is only worth offering while the map is actually over
/// that city. The bounds are what make that decision cheap.
@immutable
final class CityPortals {
  /// Creates a city's catalogue group.
  const CityPortals({
    required this.name,
    required this.bounds,
    required this.portals,
  });

  /// The city's display name, such as `Corona`.
  final String name;

  /// The rectangle enclosing the city's incorporated boundary.
  final GeoBounds bounds;

  /// The city's public catalogues, richest first.
  final List<GisPortal> portals;

  @override
  String toString() => 'CityPortals($name, ${portals.length} portals)';
}
