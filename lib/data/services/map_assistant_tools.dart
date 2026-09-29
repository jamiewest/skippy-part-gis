/// The tools that let an agent read and drive the map.
///
/// Every tool answers about whatever county workspace is open, through
/// [MapWorkspace], rather than holding a view model that a county switch
/// would leave stale.
///
/// Two rules run through all of them, and both are about not overstating what
/// the sources say:
///
/// - **A tool reports the shape it actually read.** Census figures describe
///   whole tracts, never the circle drawn over them, and the tool says so in
///   its own description so the model sees the caveat rather than only the
///   numbers.
/// - **An absent source is reported, not papered over.** Most counties have
///   no parcel layer and most installs have no Census key; the answer says
///   which, so the model can tell "nothing here" from "cannot look".
library;

import 'package:riverside_atlas/data/services/route_assistant_tools.dart';
import 'package:extensions/ai.dart';
import 'package:extensions/system.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/data/services/focused_gis_discovery.dart';
import 'package:riverside_atlas/data/services/map_layer_tools.dart';
import 'package:riverside_atlas/domain/models/area_selection.dart';
import 'package:riverside_atlas/domain/models/census_area.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/widgets/area_select_overlay.dart';

/// The most addresses one tool answer lists.
///
/// A drawn area can hold thousands, and a list that long is neither readable
/// nor affordable in a prompt. The answer says how many there are either way,
/// so the count stays true even when the list is trimmed.
const assistantAddressLimit = 60;

/// Builds every map tool over [workspace] and [census].
List<AITool> buildMapTools({
  required MapWorkspace workspace,
  required CensusService census,
  FocusedGisDiscovery? discovery,
}) => [
  _describeMap(workspace, discovery),
  ...buildMapLayerTools(workspace),
  ...buildRouteTools(workspace),
  _drawArea(workspace, discovery),
  if (discovery != null) _discoverAreaData(workspace, discovery),
  _listAddresses(workspace),
  _areaDemographics(workspace, census),
  _describeSelection(workspace),
];

/// What county is open, what is on screen, and what is selected.
AIFunction _describeMap(
  MapWorkspace workspace,
  FocusedGisDiscovery? discovery,
) => AIFunctionFactory.create(
  name: 'describe_map',
  description:
      'Returns what the map is currently showing: the county and state being '
      'read, whether parcel and address data exist for it, the visible '
      'extent, which published layers are switched on, and whether an area '
      'has been drawn. Call this first when a question refers to "here", '
      '"this area", "the map", or anything else on screen.',
  callback: (arguments, {CancellationToken? cancellationToken}) async {
    final model = workspace.requireViewModel;
    final county = workspace.requireCounty;
    final selection = model.areaSelection;
    return {
      'county': county.displayName,
      'countyFips': county.fips,
      'hasParcelAndAddressData': model.parcelsAvailable,
      'parcelSource': model.parcelSourceLabel,
      if (!model.parcelsAvailable)
        'coverageNote':
            'No public layer this build knows of publishes parcels or '
            'addresses here. The boundary, the census and the published map '
            'layers still work.',
      'visibleExtent': _boundsJson(model.visibleExtent ?? county.extent),
      'visibleExtentIs': model.visibleExtent == null
          ? 'the whole county; the map has not reported a viewport yet'
          : 'what is on screen right now',
      'activeOverlays': [
        for (final overlay in model.activeOverlays) overlay.service.name,
      ],
      'drawnArea': selection == null
          ? null
          : {
              'shape': selection.shape.description,
              'status': selection.status.name,
              'addressesFound': selection.count,
              'bounds': _boundsJson(selection.bounds),
            },
      'selectedAddress': model.selectedAddress?.fullAddress,
      'selectedParcelApn': model.selectedParcel?.apn,
      'mapCapabilities': describeMapCapabilities(workspace),
      if (discovery != null)
        'dataDiscovery': await discovery.inspect(workspace),
    };
  },
);

/// Draws a circle or rectangle on the map and reads what is inside it.
AIFunction _drawArea(
  MapWorkspace workspace,
  FocusedGisDiscovery? discovery,
) => AIFunctionFactory.create(
  name: 'draw_area',
  description:
      'Draws an area on the map and reads the addresses inside it, replacing '
      'any area already drawn. Use a circle for a question about what is '
      'within a distance of a point ("within half a mile of here"); use a '
      'rectangle for a question about a block or a bounded region. The area '
      'stays on the map afterwards, so get_area_demographics and '
      'list_area_addresses then describe it.',
  parametersSchema: const {
    'type': 'object',
    'properties': {
      'shape': {
        'type': 'string',
        'enum': ['circle', 'rectangle'],
        'description': 'Which shape to draw.',
      },
      'centerLatitude': {
        'type': 'number',
        'description': 'Circle centre latitude. Required for a circle.',
      },
      'centerLongitude': {
        'type': 'number',
        'description': 'Circle centre longitude. Required for a circle.',
      },
      'radiusMeters': {
        'type': 'number',
        'description': 'Circle radius in metres. Required for a circle.',
      },
      'west': {'type': 'number', 'description': 'Rectangle west longitude.'},
      'south': {'type': 'number', 'description': 'Rectangle south latitude.'},
      'east': {'type': 'number', 'description': 'Rectangle east longitude.'},
      'north': {'type': 'number', 'description': 'Rectangle north latitude.'},
    },
    'required': ['shape'],
  },
  callback: (arguments, {CancellationToken? cancellationToken}) async {
    final model = workspace.requireViewModel;
    final shape = _shapeFrom(arguments);
    if (shape is String) {
      return shape;
    }
    model.setAreaTool(
      shape is CircleArea ? AreaTool.circle : AreaTool.rectangle,
    );
    await model.selectArea(shape as AreaShape);
    final selection = model.areaSelection;
    return {
      'drew': shape.description,
      'bounds': _boundsJson(shape.bounds),
      'status': selection?.status.name,
      'addressesFound': selection?.count ?? 0,
      if (discovery != null)
        'dataDiscovery': await discovery.inspect(workspace),
      if (selection?.truncated ?? false)
        'note':
            'The address source returned as many rows as it was asked for, '
            'so this is a partial count.',
      if (selection?.message != null) 'message': selection!.message,
      if (!workspace.requireViewModel.parcelsAvailable)
        'note':
            'No address layer covers this county, so the area holds no '
            'addresses to find. Census figures are still available.',
    };
  },
);

AIFunction _discoverAreaData(
  MapWorkspace workspace,
  FocusedGisDiscovery discovery,
) => AIFunctionFactory.create(
  name: 'discover_area_data',
  description:
      'Samples GIS schemas and up to five records from every queryable '
      'spatial layer in the focused area, including inactive services. Finds '
      'potential parcel outlines even without addresses, and possible owner '
      'names with original fields and source URLs. Uses the drawn shape, or '
      'viewport otherwise. Each call continues a bounded page of discovery; '
      'repeat while hasMore is true. A changed focus starts a new scan. '
      'For more columns, pass a discovered layer sourceUrl and its '
      'nextFieldOffset as fieldOffset. Omit both to continue the catalog scan. '
      'Read sampleAttributes and field aliases for unusual schemas. Candidates '
      'are evidence to review, not verified ownership. Nonspatial tables are '
      'schema-only until a parcel-ID join can establish area membership.',
  parametersSchema: const {
    'type': 'object',
    'properties': {
      'sourceUrl': {
        'type': 'string',
        'description': 'Optional layer URL already returned by discovery.',
      },
      'fieldOffset': {
        'type': 'integer',
        'minimum': 0,
        'description':
            'Optional starting column; use nextFieldOffset from the prior result.',
      },
    },
  },
  callback: (arguments, {CancellationToken? cancellationToken}) =>
      discovery.inspect(
        workspace,
        sourceUrl: arguments['sourceUrl'] as String?,
        fieldOffset: (arguments['fieldOffset'] as num?)?.toInt() ?? 0,
      ),
);

/// The addresses inside the drawn area.
AIFunction _listAddresses(MapWorkspace workspace) => AIFunctionFactory.create(
  name: 'list_area_addresses',
  description:
      'Lists the published address points inside the area currently drawn on '
      'the map. Draw one with draw_area first, or ask the user to draw one. '
      'Long lists are trimmed; the count is always the full number found.',
  callback: (arguments, {CancellationToken? cancellationToken}) async {
    final selection = workspace.requireViewModel.areaSelection;
    if (selection == null) {
      return 'No area is drawn on the map. Use draw_area first.';
    }
    if (selection.status != AreaSelectionStatus.ready) {
      return {
        'status': selection.status.name,
        'message': selection.message ?? 'The area is still being read.',
      };
    }
    return {
      'shape': selection.shape.description,
      'addressesFound': selection.count,
      'listed': selection.addresses.take(assistantAddressLimit).length,
      'truncatedBySource': selection.truncated,
      'addresses': [
        for (final address in selection.addresses.take(assistantAddressLimit))
          {
            'address': address.fullAddress,
            'city': address.city,
            'zip': address.zipCode,
            if (address.apn.isNotEmpty) 'apn': address.apn,
          },
      ],
    };
  },
);

/// Census figures for the tracts the drawn area touches.
AIFunction _areaDemographics(MapWorkspace workspace, CensusService census) =>
    AIFunctionFactory.create(
      name: 'get_area_demographics',
      description:
          'Returns American Community Survey figures for the census tracts '
          'that the drawn area touches: population, households, median age, '
          'median household income, median home value, median rent, tenure, '
          'vacancy, education and employment. '
          'IMPORTANT: these describe WHOLE TRACTS that the shape intersects, '
          'not the shape itself. A circle never lines up with tract '
          'boundaries. Report the figures as being for the tracts the area '
          'covers, say how many tracts were read, and do not scale them down '
          'to the area or present them as counts inside the drawn shape. '
          'Counts are summed across tracts; medians are given as a range '
          'because averaging medians describes nobody.',
      callback: (arguments, {CancellationToken? cancellationToken}) async {
        final selection = workspace.requireViewModel.areaSelection;
        if (selection == null) {
          return 'No area is drawn on the map. Use draw_area first.';
        }
        // The shape itself goes to the server, which does the intersection
        // test against the real outline. Filtering here on the tract centre
        // would drop the tract the user drew inside whenever they drew
        // off-centre, which is most of the time.
        final profile = await census.profile(
          await census.tractsIn(selection.shape),
        );
        return {
          'source':
              'US Census Bureau, American Community Survey 5-year estimates',
          'dataset': censusDataset,
          'sourceUrl': 'https://api.census.gov/data/$censusDataset.html',
          'area': selection.shape.description,
          'tractsRead': profile.tractCount,
          'coversWholeTracts': true,
          'figuresAvailable': profile.hasValues,
          if (profile.message != null) 'note': profile.message,
          'tracts': [for (final tract in profile.tracts) tract.name],
          if (profile.hasValues) 'measures': _measures(profile),
        };
      },
    );

/// The parcel or address the user has selected, with what is known about it.
AIFunction _describeSelection(
  MapWorkspace workspace,
) => AIFunctionFactory.create(
  name: 'describe_selection',
  description:
      'Returns the parcel or address the user has selected on the map, '
      'including its assessor parcel number, land use, acreage, resolved '
      'street address and published owner name where those exist. Many '
      'counties publish none of these; the answer says which are missing '
      'rather than leaving them blank.',
  callback: (arguments, {CancellationToken? cancellationToken}) async {
    final model = workspace.requireViewModel;
    final parcel = model.selectedParcel;
    final address = model.selectedAddress;
    if (parcel == null && address == null) {
      return 'Nothing is selected on the map.';
    }
    final ownership = model.propertyOwnership;
    return {
      if (address != null)
        'address': {
          'full': address.fullAddress,
          'city': address.city,
          'zip': address.zipCode,
          if (address.apn.isNotEmpty) 'apn': address.apn,
        },
      if (parcel != null)
        'parcel': {
          'apn': parcel.apn,
          if (parcel.situsAddress.isNotEmpty) 'situs': parcel.situsAddress,
          if (parcel.landUse.isNotEmpty) 'landUse': parcel.landUse,
          if (parcel.acreage != null) 'acreage': parcel.acreage,
          'city': parcel.city,
        },
      if (model.resolvedSitus case final situs?)
        'resolvedStreetAddress':
            '${situs.streetAddress}, ${situs.city} ${situs.zipCode}',
      'ownerLookup': model.ownerLookupStatus.name,
      if (ownership != null) 'owner': ownership.ownerName,
      if (!workspace.requireCounty.hasOwnerNames)
        'ownerNote':
            'No configured owner lookup source. GIS discovery may find additional owner fields.',
    };
  },
);

/// The profile's measures, summed where that is meaningful and ranged where
/// it is not.
Map<String, Object?> _measures(CensusAreaProfile profile) {
  final measures = <String, Object?>{};
  for (final variable in censusVariables) {
    if (variable.measure == CensusMeasure.count) {
      final total = profile.total(variable);
      if (total != null) {
        measures[variable.label] = {
          'totalAcrossTracts': total,
          'formatted': variable.format(total),
        };
      }
      continue;
    }
    final span = profile.range(variable);
    if (span != null) {
      measures[variable.label] = {
        'lowestTract': variable.format(span.low),
        'highestTract': variable.format(span.high),
      };
    }
  }
  return measures;
}

/// The shape described by [arguments], or a message saying what is missing.
Object _shapeFrom(Map<String, Object?> arguments) {
  final shape = '${arguments['shape']}';
  if (shape == 'circle') {
    final latitude = _number(arguments['centerLatitude']);
    final longitude = _number(arguments['centerLongitude']);
    final radius = _number(arguments['radiusMeters']);
    if (latitude == null || longitude == null || radius == null) {
      return 'A circle needs centerLatitude, centerLongitude and radiusMeters.';
    }
    if (radius <= 0) {
      return 'radiusMeters must be greater than zero.';
    }
    return CircleArea(
      center: LatLng(latitude, longitude),
      radiusMeters: radius,
    );
  }
  final west = _number(arguments['west']);
  final south = _number(arguments['south']);
  final east = _number(arguments['east']);
  final north = _number(arguments['north']);
  if (west == null || south == null || east == null || north == null) {
    return 'A rectangle needs west, south, east and north.';
  }
  return RectangleArea(
    GeoBounds(
      west: west < east ? west : east,
      south: south < north ? south : north,
      east: west > east ? west : east,
      north: south > north ? south : north,
    ),
  );
}

/// [value] as a double, accepting the string a model sometimes sends.
double? _number(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text),
  _ => null,
};

Map<String, double> _boundsJson(GeoBounds bounds) => {
  'west': bounds.west,
  'south': bounds.south,
  'east': bounds.east,
  'north': bounds.north,
};
