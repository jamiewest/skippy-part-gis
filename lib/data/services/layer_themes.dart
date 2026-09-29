/// Sorting service names into themes a person would recognise.
///
/// Twenty-six thousand county services is not a list anybody can read, and the
/// servers offer nothing to group them by: county services carry no category
/// field and their descriptions are empty more often than not. Matching
/// keywords against the service name is what is left.
///
/// This is a heuristic for ordering a long list, and it is wrong at the edges
/// — `Mesocarnivore Photo Stations` lands under aerial imagery. Never use it
/// to decide what a layer *is*.
///
/// Kept in step with `tool/gis_inventory/themes.py`, which classifies the same
/// names when the published inventory is regenerated.
library;

/// Theme names in the order a layer picker should show them.
///
/// Ordered by how often somebody looking at a parcel map wants them, not by
/// how many services match — the biggest theme statewide is habitat data.
const layerThemes = <String>[
  'parcels & assessor',
  'zoning & land use',
  'flood & water',
  'fire & hazard',
  'aerial imagery',
  'boundaries & districts',
  'addressing',
  'transportation',
  'permits & code',
  'utilities & infrastructure',
  'public safety',
  'environment & habitat',
  'recreation & parks',
  'basemap & reference',
];

const _patterns = <String, String>{
  'parcels & assessor':
      r'parcel|assessor|apn|ownership|taxrate|tax_rate|situs|subdivision|'
      r'lot|condo',
  'addressing': r'address|situs_?point|centerline|street_?name|road_?name',
  'zoning & land use':
      r'zoning|rezone|landuse|land_?use|general_?plan|specific_?plan|'
      r'overlay_?district|entitlement',
  'aerial imagery':
      r'aerial|imagery|ortho|naip|pictometry|satellite|y\d{4}|_wm$|_is$|photo',
  'flood & water':
      r'flood|fema|firm|dfirm|watershed|creek|river|hydro|levee|storm|drain|'
      r'water|well|groundwater|basin',
  'fire & hazard':
      r'fire|hazard|fhsz|burn|evacuation|seismic|fault|liquefaction|'
      r'landslide|earthquake|hazmat',
  'environment & habitat':
      r'habitat|species|wetland|vegetation|tree|agricult|williamson|soil|'
      r'conservation|open_?space|biolog|environment',
  'transportation':
      r'road|street|highway|transit|bike|trail|traffic|bridge|rail|airport|'
      r'route|pavement|sidewalk',
  'boundaries & districts':
      r'boundar|district|supervisor|city|cities|census|tract|block|precinct|'
      r'school|special_?dist|sphere|annex|municipal|jurisdiction|zip',
  'public safety':
      r'police|sheriff|crime|fire_?station|ems|ambulance|emergency|evac|911|'
      r'dispatch',
  'utilities & infrastructure':
      r'sewer|utility|utilities|electric|power|gas|broadband|fiber|telecom|'
      r'streetlight|facilit|infrastructure',
  'permits & code':
      r'permit|code_?enforce|violation|inspection|building|cannabis|license|'
      r'business',
  'recreation & parks':
      r'park|recreation|golf|campground|open_?space|'
      r'playground',
  'basemap & reference':
      r'basemap|base_?map|topo|contour|elevation|dem|lidar|hillshade|terrain|'
      r'survey|section|township|benchmark|monument|grid',
};

final _compiled = {
  for (final entry in _patterns.entries)
    entry.key: RegExp(entry.value, caseSensitive: false),
};

/// Every theme matching [name]. A service can belong to several.
List<String> themesOf(String name) {
  final subject = name.replaceAll('_', ' ');
  return [
    for (final theme in layerThemes)
      if (_compiled[theme]!.hasMatch(subject)) theme,
  ];
}

/// The single theme a service is filed under in the picker.
///
/// A service matching several themes is filed under the first in
/// [layerThemes], which is ordered by usefulness rather than by match count.
String primaryThemeOf(String name) {
  final matches = themesOf(name);
  return matches.isEmpty ? 'other' : matches.first;
}
