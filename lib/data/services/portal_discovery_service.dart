import 'package:riverside_atlas/data/services/gis_catalog_service.dart';
import 'package:riverside_atlas/domain/models/catalog_layer.dart';
import 'package:riverside_atlas/data/services/layer_themes.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:riverside_atlas/data/services/us_geography.g.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';
import 'package:riverside_atlas/domain/models/us_place.dart';
import 'package:riverside_atlas/domain/repositories/gis_repositories.dart';

/// Finds the public map catalogues published over a county, at runtime.
///
/// The generated registry covers the one state whose inventory has been run.
/// Everywhere else a county opened a panel holding nothing but the federal
/// tier, because no compiled table knew that Dallas County publishes anything.
/// This asks ArcGIS Online instead, which knows about every county in the
/// country and needs no inventory to be re-run when one of them republishes.
///
/// Three channels feed it, because no single one is reliable:
///
/// * **Vanity subdomains.** A `maps.arcgis.com` subdomain answers
///   `/sharing/rest/portals/self` with the organisation that owns it, so
///   guessing the subdomain a government would take is
///   self-verifying — a wrong guess returns no id. This is what recovers
///   Cuyahoga County and Maricopa County Enterprise GIS from nothing but the
///   county's name.
/// * **Name search.** ArcGIS Online's item search, asked for the county and
///   its state. This is what recovers publishers whose subdomain is
///   unguessable — the City of Dallas publishes as `DallasGIS`.
/// * **Organisation search.** Every item an organisation found by the first
///   two channels publishes, which is what turns one hit into a whole
///   catalogue root.
///
/// A fourth was tried and is deliberately absent: ArcGIS Online's `bbox`
/// search parameter does not restrict results — a county-shaped box returns
/// global weather feeds — so it discovers nothing name search does not.
///
/// **Every candidate is then gated geographically.** Search matches text, and
/// text is ambiguous: thirty-one states have a Washington County, and asking
/// for one returns publishers from all of them. Each item carries its own
/// advertised extent, so the share of a root's items that actually fall over
/// this county is measurable at no extra cost, and a root that fails the test
/// is dropped rather than shown. That is what makes the result safe to
/// attribute — and why an ambiguous county with no local publisher comes back
/// empty instead of coming back wrong.
final class PortalDiscoveryService implements PortalDiscoveryRepository {
  /// Creates a discovery service over the shared HTTP client.
  PortalDiscoveryService(this._client);

  final http.Client _client;
  final Map<String, List<GisPortal>> _cache = {};
  final Map<String, Future<List<GisPortal>>> _inFlight = {};
  final Map<String, Set<String>> _countyOrganisations = {};
  final Map<String, List<GisPortal>> _placePortals = {};
  final Map<String, int> _placeBudget = {};
  final Set<String> _searchedPlaces = {};

  /// Item types worth listing. Geoprocessing, geocoding, geometry and scene
  /// services are not map layers, and asking for them widens every search
  /// with results the catalogue would drop anyway.
  static const _itemTypes =
      'type:"Feature Service" OR type:"Map Service" OR type:"Image Service"';

  /// Items whose extent must fall over the county before its root is offered.
  ///
  /// Two would be met by coincidence. This is the difference between finding
  /// a publisher and finding a stray item that mentions the county's name.
  static const _minimumLocalItems = 3;

  /// Share of a root's placed items that must fall over the county.
  ///
  /// A national publisher that happens to cover the county scores near this
  /// county's share of the country and is rejected; the county's own GIS
  /// scores close to one. Measured against the counties this was built on,
  /// everything real sat above 0.8 and everything spurious below 0.3.
  static const _minimumLocalShare = 0.6;

  /// Roots offered per county. Beyond this the panel is a list nobody reads.
  static const _maximumPortals = 12;

  /// Organisations whose whole catalogue is worth enumerating.
  static const _maximumOrganisations = 6;

  /// Municipalities searched for one county before the budget is spent.
  ///
  /// The map moves constantly, and panning across Hartford County puts six
  /// towns on screen at a time. Caching per municipality stops a town being
  /// searched twice; this stops a session from searching a hundred of them.
  /// The whole premise of the lazy catalogue design is that discovery never
  /// becomes the reason the map is slow.
  static const _maximumPlaceSearches = 12;

  /// Municipalities searched per viewport, largest overlap first.
  ///
  /// A city view holds one or two municipalities and a regional view holds
  /// dozens; this is what keeps the second case from spending the whole
  /// budget in one gesture.
  static const _placesPerViewport = 3;

  /// Esri's own global content channels.
  ///
  /// Excluded by organisation id rather than by name, because the id is in
  /// the root and costs no request to read. These publish demonstration and
  /// basemap content over the entire country, so they pass a geographic test
  /// everywhere while never being anybody's local publisher — and a slot they
  /// take is a slot the town does not get.
  static const _esriContentOrganisations = {
    'jIL9msH9OI208GCb', // ArcGIS Living Atlas Team
    '2ycVue24EK6qzjat', // GeoDesign with ArcGIS
    'P3ePLMYs2RVChkJx', // Esri
    'RHVPKKiFTONKtxq3', // Esri live feeds
  };

  /// The Census layers naming the governments under a point on the map.
  ///
  /// Two layers, because which one governs depends on the state. An
  /// incorporated place is the municipality across most of the country; in
  /// New England and the township states the minor civil division is, and
  /// there the place layer is nearly empty.
  static const _placeLayers = {
    4: 'incorporated place',
    1: 'county subdivision',
  };

  static const _placeService =
      'https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/'
      'Places_CouSub_ConCity_SubMCD/MapServer';

  /// Census function statuses that mean a real government.
  ///
  /// `A` active, `B` active but partly consolidated, `C` consolidated with
  /// another unit — Hartford town, coextensive with Hartford city, is `C`.
  /// What this excludes is `S`: a statistical area drawn for tabulation, of
  /// which Texas's census county divisions are the clearest case. Nobody
  /// administers one, so nobody publishes its GIS, and searching for it
  /// spends budget to find noise.
  static const _governingStatuses = "FUNCSTAT IN ('A','B','C')";

  /// Hosts whose roots are never offered.
  ///
  /// `utility.arcgis.com/usrsvcs` is a token-protected proxy to somebody's
  /// on-premises server and answers anonymous listing with an error;
  /// `tiles.arcgis.com` serves hosted tile caches, which are vector tile
  /// services this build has no renderer for, so its catalogues list as
  /// empty.
  static const _excludedHosts = {'utility.arcgis.com', 'tiles.arcgis.com'};

  @override
  Future<List<GisPortal>> discover({
    required UsCounty county,
    required UsState state,
  }) {
    if (_cache[county.id] case final cached?) return Future.value(cached);
    return _inFlight.putIfAbsent(
      county.id,
      () => _discoverCounty(county, state).whenComplete(() {
        _inFlight.remove(county.id);
      }),
    );
  }

  Future<List<GisPortal>> _discoverCounty(
    UsCounty county,
    UsState state,
  ) async {
    final organisations = await _organisations(county, state);
    final tallies = await _tally(
      county,
      organisations,
      _queries(county, state, organisations),
    );
    final accepted = _accept(tallies);
    final portals = await _describe(accepted, county, state, organisations);
    _countyOrganisations[county.id] = organisations.keys.toSet();
    return _cache[county.id] = List.unmodifiable(portals);
  }

  /// Names build a shortlist; only schema and sample inspection adopts data.
  Future<List<CatalogService>> findParcelServiceCandidates({
    required UsCounty county,
    required UsState state,
    required GisCatalogService catalog,
    List<GisPortal> registered = const [],
  }) async {
    final portals = await discover(county: county, state: state);
    final organisations = {
      ...?_countyOrganisations[county.id],
      for (final p in portals) ?_hostedOrganisationId(p.root),
    };
    const words =
        '(parcel OR parcels OR assessor OR cadastral OR "tax parcels")';
    final queries = [
      '(type:"Feature Service" OR type:"Map Service") AND "${_placeStem(county.name)}" AND "${state.name}" AND $words',
      for (final id in organisations.take(6))
        'orgid:$id AND $words AND (type:"Feature Service" OR type:"Map Service")',
    ];
    final found = <String, CatalogService>{};
    // Search and catalogue failures are independent; a county server can still
    // answer when ArcGIS Online is down.
    for (final query in queries) {
      for (final item in await _search(query)) {
        final extent = _extentOf(item['extent']);
        final url = item['url']?.toString();
        if (url == null ||
            extent == null ||
            !extent.intersects(county.extent)) {
          continue;
        }
        final root = _rootOf(url);
        final match = RegExp(
          r'/(.+)/(MapServer|FeatureServer)(?:/\d+)?/?$',
          caseSensitive: false,
        ).firstMatch(root == null ? '' : url.substring(root.length));
        if (root == null || _isExcluded(root) || match == null) continue;
        final name = match[1]!;
        final service = CatalogService(
          portal: GisPortal(
            root: root,
            publisher: Uri.parse(url).host,
            tier: PortalTier.partner,
            origin: PortalOrigin.discovered,
          ),
          name: name,
          type: match[2]!.toLowerCase() == 'mapserver'
              ? 'MapServer'
              : 'FeatureServer',
          themes: themesOf(name),
        );
        found.putIfAbsent(service.uri.toString().toLowerCase(), () => service);
      }
    }
    final roots = {
      for (final p in [...registered, ...portals])
        if (p.tier != PortalTier.national) p.aliasKey: p,
    };
    for (final portal in roots.values) {
      try {
        for (final service in await catalog.listServices(portal)) {
          if (service.type != 'ImageServer' &&
              service.themes.any(
                (t) => t == 'parcels & assessor' || t == 'addressing',
              )) {
            found[service.uri.toString().toLowerCase()] = service;
          }
        }
      } on Object {
        /* Continue with the other publishers. */
      }
    }
    final itemOrder = {
      for (final (index, key) in found.keys.indexed) key: index,
    };
    final values = found.values.toList()
      ..sort((a, b) {
        int priority(CatalogService s) {
          final leaf = s.name.split('/').last.toLowerCase();
          final broad = RegExp(
            r'^(parcels?|assessor|tax[_ ]?parcels?|parcel[_ ]?data)([_ ]?(view|public))?$|parcel.*addr|realprop|property.*info',
          ).hasMatch(leaf);
          final subset = RegExp(
            'delinquent|lien|unincorporated|vacant|sales|flood|hazard|municipal|government|owned|within|residential|commercial|shopping|concern',
            caseSensitive: false,
          ).hasMatch(s.name);
          return (subset ? 100 : 0) +
              (broad ? 0 : 20) +
              (s.themes.contains('parcels & assessor') ? 0 : 40) +
              (s.uri.host.endsWith('.gov') ? 0 : 5) +
              (s.portal.tier == PortalTier.countyPortal ? 0 : 2);
        }

        final p = priority(a).compareTo(priority(b));
        // Preserve the item search's popularity order for otherwise equal entries.
        return p != 0
            ? p
            : itemOrder[a.uri.toString().toLowerCase()]!.compareTo(
                itemOrder[b.uri.toString().toLowerCase()]!,
              );
      });
    return values.take(25).toList();
  }

  @override
  Future<List<GisPortal>> discoverPlaces({
    required GeoBounds viewport,
    required UsCounty county,
    required UsState state,
  }) async {
    final budget = _placeBudget[county.id] ?? 0;
    if (budget >= _maximumPlaceSearches) {
      return _placePortals[county.id] ?? const [];
    }
    final places = await _placesIn(viewport);
    final fresh = [
      for (final place in places)
        if (!_searchedPlaces.contains(place.geoid)) place,
    ].take(_maximumPlaceSearches - budget).toList();
    if (fresh.isEmpty) {
      return _placePortals[county.id] ?? const [];
    }
    _placeBudget[county.id] = budget + fresh.length;
    _searchedPlaces.addAll(fresh.map((place) => place.geoid));

    // Gated on the county, not on the municipality. The municipality's name
    // is what makes the search specific — it was measured to return the same
    // publishers under either box — and the county gate is the one whose
    // thresholds have been calibrated. Narrowing the box would be a second
    // change with nothing to show for it.
    final tallies = await _tally(county, {}, [
      for (final place in fresh) _placeQuery(place, state),
    ]);
    final found = await _describe(_accept(tallies), county, state, {});
    final kept = <String, GisPortal>{
      for (final portal in _placePortals[county.id] ?? const <GisPortal>[])
        portal.aliasKey: portal,
    };
    for (final portal in found) {
      kept.putIfAbsent(portal.aliasKey, () => portal);
    }
    return _placePortals[county.id] = List.unmodifiable(kept.values);
  }

  /// The search run for one municipality.
  ///
  /// The state is included for the same reason it is in the county search: a
  /// bare `Windsor` is a town in Connecticut, Colorado, Vermont and Ontario.
  static String _placeQuery(UsPlace place, UsState state) {
    final stateName = UsGeography.stateByFips(place.stateFips)?.name;
    return '($_itemTypes) AND ("${place.name}") '
        'AND ("${stateName ?? state.name}")';
  }

  /// The governing municipalities [viewport] covers, largest overlap first.
  ///
  /// Both Census layers are asked at once and the answers merged, because a
  /// state has one or the other and asking only the common one would leave
  /// New England with nothing. A municipality appearing in both — a
  /// consolidated city and its coextensive town — is one entry, because it
  /// is one government and searching for it twice would spend the budget
  /// twice.
  Future<List<UsPlace>> _placesIn(GeoBounds viewport) async {
    final envelope =
        '${viewport.west},${viewport.south},'
        '${viewport.east},${viewport.north}';
    final pages = await Future.wait([
      for (final layer in _placeLayers.keys)
        _read(Uri.parse('$_placeService/$layer/query'), {
          'where': _governingStatuses,
          'outFields': 'GEOID,BASENAME,STATE',
          'geometry': envelope,
          'geometryType': 'esriGeometryEnvelope',
          'inSR': '4326',
          'outSR': '4326',
          'spatialRel': 'esriSpatialRelIntersects',
          'returnGeometry': 'true',
          // The outline is never drawn; only its box is read, so the
          // coarsest generalisation the service offers is the right one.
          'maxAllowableOffset': '0.01',
          'resultRecordCount': '25',
        }),
    ]);
    final byName = <String, UsPlace>{};
    for (final page in pages) {
      for (final feature
          in page?['features'] as List<Object?>? ?? const <Object?>[]) {
        if (_placeOf(feature) case final place?) {
          byName.putIfAbsent('${place.name}|${place.stateFips}', () => place);
        }
      }
    }
    final places = byName.values.toList()
      ..sort(
        (first, second) => _overlapArea(
          second.bounds,
          viewport,
        ).compareTo(_overlapArea(first.bounds, viewport)),
      );
    return places.take(_placesPerViewport).toList();
  }

  static UsPlace? _placeOf(Object? feature) {
    if (feature is! Map<String, Object?>) {
      return null;
    }
    final attributes = feature['attributes'];
    if (attributes is! Map<String, Object?>) {
      return null;
    }
    final geoid = attributes['GEOID'];
    final name = attributes['BASENAME'];
    final stateFips = attributes['STATE'];
    if (geoid is! String || name is! String || name.trim().isEmpty) {
      return null;
    }
    final bounds = _ringBounds(feature['geometry']);
    if (bounds == null) {
      return null;
    }
    return UsPlace(
      geoid: geoid,
      name: name.trim(),
      stateFips: stateFips is String ? stateFips : '',
      bounds: bounds,
    );
  }

  static GeoBounds? _ringBounds(Object? geometry) {
    if (geometry is! Map<String, Object?>) {
      return null;
    }
    var west = double.infinity;
    var south = double.infinity;
    var east = double.negativeInfinity;
    var north = double.negativeInfinity;
    for (final ring in geometry['rings'] as List<Object?>? ?? const []) {
      for (final point in ring as List<Object?>? ?? const []) {
        if (point is! List<Object?> || point.length < 2) {
          continue;
        }
        final x = _asDouble(point[0]);
        final y = _asDouble(point[1]);
        if (x == null || y == null) {
          continue;
        }
        west = math.min(west, x);
        south = math.min(south, y);
        east = math.max(east, x);
        north = math.max(north, y);
      }
    }
    if (west > east || south > north) {
      return null;
    }
    return GeoBounds(west: west, south: south, east: east, north: north);
  }

  /// How much of [viewport] a municipality covers, as a bare area.
  ///
  /// The ordering key: the town filling the screen is the one the user is
  /// looking at, and a neighbour clipped at the edge is not.
  static double _overlapArea(GeoBounds bounds, GeoBounds viewport) {
    final width =
        math.min(bounds.east, viewport.east) -
        math.max(bounds.west, viewport.west);
    final height =
        math.min(bounds.north, viewport.north) -
        math.max(bounds.south, viewport.south);
    return width <= 0 || height <= 0 ? 0 : width * height;
  }

  // --- Channel one: self-verifying vanity subdomains -----------------------

  /// Organisations found by probing the subdomains a government would use.
  ///
  /// Both the county's and the state's are probed. The state's is what lights
  /// up every county in a state at once when one exists: Utah's AGRC publishes
  /// parcels, addresses and zoning for all twenty-nine of its counties, and no
  /// county-name search finds it.
  Future<Map<String, _Organisation>> _organisations(
    UsCounty county,
    UsState state,
  ) async {
    final keys = {..._countyKeys(county, state), ..._stateKeys(state)};
    final probes = await Future.wait([
      for (final key in keys) _organisationAt(key),
    ]);
    final found = <String, _Organisation>{};
    for (final organisation in probes) {
      if (organisation != null) {
        found.putIfAbsent(organisation.id, () => organisation);
      }
    }
    return found;
  }

  Future<_Organisation?> _organisationAt(String key) async {
    final payload = await _read(
      Uri.parse('https://$key.maps.arcgis.com/sharing/rest/portals/self'),
    );
    if (payload?['id'] case final String id when id.isNotEmpty) {
      return _Organisation(id: id, name: payload?['name'] as String? ?? key);
    }
    return null;
  }

  static Set<String> _countyKeys(UsCounty county, UsState state) {
    final slug = _slug(_placeStem(county.name));
    final dashed = _slug(_placeStem(county.name), separator: '-');
    return {
      '${slug}county',
      'countyof$slug',
      '$dashed-county',
      '$slug${state.abbreviation}',
      slug,
      '${slug}gis',
      '${slug}countygis',
    };
  }

  static Set<String> _stateKeys(UsState state) {
    final slug = _slug(state.name);
    return {slug, '${slug}gis', 'stateof$slug', '${state.abbreviation}gis'};
  }

  // --- Channel two and three: item search ----------------------------------

  /// The searches run for this county, widest recall first.
  ///
  /// Two name shapes rather than one because both are common and neither is
  /// dominant, and one qualified by the state because a bare county name is
  /// ambiguous nationally. Recall is deliberately generous: the geographic
  /// gate is what makes the result correct, so a query that also matches the
  /// wrong Washington County costs nothing but a rejected row.
  static List<String> _queries(
    UsCounty county,
    UsState state,
    Map<String, _Organisation> organisations,
  ) {
    final name = _placeStem(county.name);
    return [
      '($_itemTypes) AND ("${county.name}" OR "County of $name")',
      '($_itemTypes) AND ("${county.name}") AND ("${state.name}")',
      for (final id in organisations.keys.take(_maximumOrganisations))
        'orgid:$id AND ($_itemTypes)',
    ];
  }

  /// Counts, per catalogue root, how much of what it publishes lands here.
  Future<Map<String, _RootTally>> _tally(
    UsCounty county,
    Map<String, _Organisation> organisations,
    List<String> queries,
  ) async {
    final pages = await Future.wait([for (final q in queries) _search(q)]);
    final tallies = <String, _RootTally>{};
    for (final page in pages) {
      for (final item in page) {
        final root = _rootOf(item['url']);
        if (root == null || _isExcluded(root)) {
          continue;
        }
        // One server answers on both `/arcgis/rest/services` and
        // `/ArcGIS/rest/services`, and ArcGIS Online publishes item URLs in
        // both forms. Counting them apart would list the same catalogue
        // twice and spend two of the twelve slots on it, so the tally is
        // keyed case-insensitively while the publisher's own spelling is
        // what gets requested.
        final tally = tallies.putIfAbsent(
          root.toLowerCase(),
          () => _RootTally(root),
        );
        final extent = _extentOf(item['extent']);
        if (extent == null) {
          continue;
        }
        if (extent.intersects(county.extent)) {
          tally.local++;
          tally.coverage = tally.coverage?.union(extent) ?? extent;
        } else {
          tally.remote++;
        }
      }
    }
    return tallies;
  }

  Future<List<Map<String, Object?>>> _search(String query) async {
    final payload = await _read(
      Uri.parse('https://www.arcgis.com/sharing/rest/search'),
      {'q': query, 'num': '100', 'sortField': 'numviews', 'sortOrder': 'desc'},
    );
    return [
      for (final result in payload?['results'] as List<Object?>? ?? const [])
        if (result is Map<String, Object?>) result,
    ];
  }

  // --- The geographic gate -------------------------------------------------

  /// The roots whose publishers really map this county, strongest first.
  ///
  /// Host aliases are collapsed here rather than shown twice — see
  /// [GisPortal.aliasKeyOf] for what counts as the same server. The `.gov`
  /// name wins, as it does in the offline inventory.
  List<_RootTally> _accept(Map<String, _RootTally> tallies) {
    final passed = [
      for (final tally in tallies.values)
        if (tally.qualifies) tally,
    ]..sort((first, second) => second.local.compareTo(first.local));
    final canonical = <String, _RootTally>{};
    for (final tally in passed) {
      final alias = GisPortal.aliasKeyOf(tally.root);
      final held = canonical[alias];
      if (held == null ||
          (_prefersGov(tally.root) && !_prefersGov(held.root))) {
        canonical[alias] = tally;
      }
    }
    return canonical.values.take(_maximumPortals).toList();
  }

  // --- Attribution ---------------------------------------------------------

  /// Turns accepted roots into portals attributed to their own publishers.
  ///
  /// A hosted root carries its organisation's id in its own path, so the
  /// publisher's real name is one request away and is never invented here.
  /// Anything else falls back to the hostname, which is what the offline
  /// inventory writes down for a self-hosted server too.
  Future<List<GisPortal>> _describe(
    List<_RootTally> accepted,
    UsCounty county,
    UsState state,
    Map<String, _Organisation> organisations,
  ) async {
    final names = await Future.wait([
      for (final tally in accepted) _publisherOf(tally.root, organisations),
    ]);
    final portals = <GisPortal>[];
    for (var index = 0; index < accepted.length; index++) {
      final tally = accepted[index];
      final publisher = names[index] ?? Uri.parse(tally.root).host;
      portals.add(
        GisPortal(
          root: tally.root,
          publisher: publisher,
          tier: _tierOf(publisher, county, state),
          coverage: tally.coverage,
          origin: PortalOrigin.discovered,
        ),
      );
    }
    return portals;
  }

  Future<String?> _publisherOf(
    String root,
    Map<String, _Organisation> organisations,
  ) async {
    final id = _hostedOrganisationId(root);
    if (id == null) {
      return null;
    }
    if (organisations[id] case final known?) {
      return known.name;
    }
    final payload = await _read(
      Uri.parse('https://www.arcgis.com/sharing/rest/portals/$id'),
    );
    return payload?['name'] as String?;
  }

  /// Which tier a publisher belongs to, judged only by the name it gave.
  ///
  /// Conservative on purpose. Attributing a partner's layer to the county
  /// asserts the county published it, which is the one error [PortalTier]
  /// exists to prevent, so anything that does not plainly claim to be the
  /// county, the state, or a city government is a partner. Being listed as a
  /// partner understates a publisher; being listed as the county misstates it.
  static PortalTier _tierOf(String publisher, UsCounty county, UsState state) {
    final name = publisher.toLowerCase();
    final stem = _placeStem(county.name).toLowerCase();
    final suffix = _placeSuffix(county.name).toLowerCase();
    if (name.contains(stem) && suffix.isNotEmpty && name.contains(suffix)) {
      return PortalTier.countyPortal;
    }
    if (_notLocalGovernment.hasMatch(name)) {
      return PortalTier.partner;
    }
    if (_cityGovernment.hasMatch(name)) {
      return PortalTier.city;
    }
    // Naming the state is not enough on its own: a city writes itself
    // `Buckeye, Arizona`, and calling that a state agency would offer its
    // layers over all fifteen Arizona counties. A state agency also says what
    // kind of body it is, so both halves are required.
    if (name.contains(state.name.toLowerCase()) &&
        _stateAgency.hasMatch(name)) {
      return PortalTier.statewide;
    }
    return PortalTier.partner;
  }

  /// Publishers that pass a place-name test while not being that government.
  static final _notLocalGovernment = RegExp(
    r'college|universit|school|unified|chamber|association|church|realtors|'
    r'conservancy|tribe|rancheria|\besri\b|\bcog\b|council of governments',
    caseSensitive: false,
  );

  /// What a state agency calls itself, as distinct from a place in the state.
  ///
  /// A regional council or an association of governments is deliberately
  /// absent: those cover a metropolitan area, not a state, and belong in the
  /// partner tier where the registry already puts them.
  static final _stateAgency = RegExp(
    r'\b(department|division|commission|agency|bureau|survey|authority|'
    r'office|board|center|centre|institute|geoportal)\b|\bstate of\b',
    caseSensitive: false,
  );

  static final _cityGovernment = RegExp(
    r'\b(city|town|village|borough) of\b|\bcity gis\b',
    caseSensitive: false,
  );

  // --- Parsing helpers -----------------------------------------------------

  /// The catalogue root inside a service item's URL.
  static String? _rootOf(Object? url) {
    if (url is! String) {
      return null;
    }
    final marker = url.toLowerCase().indexOf('/rest/services');
    if (marker <= 0) {
      return null;
    }
    return url.substring(0, marker + '/rest/services'.length);
  }

  /// The rectangle an item advertises, or null when it says nothing useful.
  ///
  /// A whole-world extent is the ArcGIS default for an item nobody set one
  /// on. Counting it as coverage would pass every publisher on Earth through
  /// the geographic gate, so it is treated as unmeasured rather than as a
  /// claim to cover this county.
  static GeoBounds? _extentOf(Object? raw) {
    if (raw is! List<Object?> || raw.length != 2) {
      return null;
    }
    final lower = raw[0];
    final upper = raw[1];
    if (lower is! List<Object?> ||
        upper is! List<Object?> ||
        lower.length < 2 ||
        upper.length < 2) {
      return null;
    }
    final west = _asDouble(lower[0]);
    final south = _asDouble(lower[1]);
    final east = _asDouble(upper[0]);
    final north = _asDouble(upper[1]);
    if (west == null || south == null || east == null || north == null) {
      return null;
    }
    if (west <= -179 && east >= 179) {
      return null;
    }
    return GeoBounds(west: west, south: south, east: east, north: north);
  }

  static double? _asDouble(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };

  /// `Dallas County` becomes `Dallas`, `Orleans Parish` becomes `Orleans`.
  ///
  /// The suffix is what a search should not insist on — a county's GIS
  /// organisation is `dallascountygis`, not `dallascountycountygis` — and
  /// what tells a county government from a city one, so both halves are kept
  /// and read separately.
  static String _placeStem(String name) {
    final match = _placeSuffixes.firstMatch(name);
    return match == null ? name : name.substring(0, match.start).trim();
  }

  static String _placeSuffix(String name) =>
      _placeSuffixes.firstMatch(name)?.group(0)?.trim() ?? '';

  /// Every form the Census uses for a county equivalent.
  static final _placeSuffixes = RegExp(
    r'\s+(County|Parish|Borough|Census Area|Municipality|Municipio|'
    r'City and Borough|Planning Region|city)$',
    caseSensitive: false,
  );

  static String _slug(String name, {String separator = ''}) => name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), separator)
      .replaceAll(RegExp('^$separator|$separator\$'), '');

  static bool _isExcluded(String root) =>
      _excludedHosts.contains(Uri.parse(root).host) ||
      _esriContentOrganisations.contains(_hostedOrganisationId(root));

  /// The hosted organisation id a `services*.arcgis.com` root carries.
  static String? _hostedOrganisationId(String root) {
    final uri = Uri.parse(root);
    if (!uri.host.endsWith('.arcgis.com') || uri.pathSegments.isEmpty) {
      return null;
    }
    final first = uri.pathSegments.first;
    return RegExp(r'^[A-Za-z0-9]{10,}$').hasMatch(first) ? first : null;
  }

  static bool _prefersGov(String root) => Uri.parse(root).host.endsWith('.gov');

  Future<Map<String, Object?>?> _read(
    Uri endpoint, [
    Map<String, String> parameters = const {},
  ]) async {
    try {
      final uri = endpoint.replace(
        queryParameters: {
          ...endpoint.queryParameters,
          ...parameters,
          'f': 'json',
        },
      );
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, Object?> ? decoded : null;
    } on Object {
      // Discovery is a best-effort survey of dozens of endpoints, several of
      // which are guesses that are meant to fail. One unreachable probe is
      // not a failed discovery, and a failed discovery is not a failed map.
      return null;
    }
  }
}

/// One ArcGIS Online organisation, as it names itself.
final class _Organisation {
  _Organisation({required this.id, required this.name});

  final String id;
  final String name;
}

/// How much of one catalogue root's published work lands over the county.
final class _RootTally {
  _RootTally(this.root);

  /// The root as its publisher first spelled it.
  final String root;

  int local = 0;
  int remote = 0;
  GeoBounds? coverage;

  /// Whether this root passes the geographic gate.
  bool get qualifies =>
      local >= PortalDiscoveryService._minimumLocalItems &&
      local / (local + remote) >= PortalDiscoveryService._minimumLocalShare;
}
