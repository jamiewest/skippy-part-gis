import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// The Web Mercator bounding box of one XYZ tile, in EPSG:3857 metres.
///
/// Shared by the `ImageServer` and `MapServer` providers below, which differ
/// only in the endpoint they hand it to.
({double xmin, double ymin, double xmax, double ymax}) tileBounds(
  TileCoordinates coordinates,
) {
  const halfWorld = 20037508.342789244;
  final tilesPerAxis = math.pow(2, coordinates.z).toDouble();
  final worldWidth = halfWorld * 2;
  return (
    xmin: coordinates.x / tilesPerAxis * worldWidth - halfWorld,
    ymin: halfWorld - (coordinates.y + 1) / tilesPerAxis * worldWidth,
    xmax: (coordinates.x + 1) / tilesPerAxis * worldWidth - halfWorld,
    ymax: halfWorld - coordinates.y / tilesPerAxis * worldWidth,
  );
}

/// Converts flutter_map XYZ tiles into ArcGIS ImageServer export requests.
final class ArcGisImageTileProvider extends TileProvider {
  /// Creates an ImageServer tile adapter.
  ArcGisImageTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return NetworkImage(getTileUrl(coordinates, options), headers: headers);
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final serviceUri = Uri.parse(
      options.urlTemplate ??
          (throw ArgumentError('An ImageServer URL is required.')),
    );
    final bounds = tileBounds(coordinates);
    return serviceUri
        .replace(
          path: '${serviceUri.path}/exportImage',
          queryParameters: {
            'bbox':
                '${bounds.xmin},${bounds.ymin},${bounds.xmax},${bounds.ymax}',
            'bboxSR': '3857',
            'imageSR': '3857',
            'size': '${options.tileDimension},${options.tileDimension}',
            'format': 'jpgpng',
            'f': 'image',
          },
        )
        .toString();
  }
}

/// Converts flutter_map XYZ tiles into ArcGIS MapServer export requests.
///
/// `/export` rather than `/tile/{z}/{y}/{x}`, because a direct tile template
/// only works on a fused cache built in Web Mercator and most county caches
/// are not: of San Bernardino's 24, twenty are tiled in EPSG:6424 and two in
/// EPSG:2229 — California State Plane, whose grid does not line up with the
/// map. `/export` works on every MapServer, cached or not, and renders the
/// county's own cartography, which for a flood zone or a zoning map is better
/// than anything this app would invent.
final class ArcGisExportTileProvider extends TileProvider {
  /// Creates a MapServer tile adapter drawing [visibleLayers].
  ///
  /// A null [visibleLayers] draws the service's default layers.
  ArcGisExportTileProvider({this.visibleLayers, super.headers});

  /// Sub-layer ids to draw, or null for the service default.
  final List<int>? visibleLayers;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return NetworkImage(getTileUrl(coordinates, options), headers: headers);
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final serviceUri = Uri.parse(
      options.urlTemplate ??
          (throw ArgumentError('A MapServer URL is required.')),
    );
    final bounds = tileBounds(coordinates);
    final layers = visibleLayers;
    return serviceUri
        .replace(
          path: '${serviceUri.path}/export',
          queryParameters: {
            'bbox':
                '${bounds.xmin},${bounds.ymin},${bounds.xmax},${bounds.ymax}',
            'bboxSR': '3857',
            'imageSR': '3857',
            'size': '${options.tileDimension},${options.tileDimension}',
            'dpi': '96',
            'format': 'png32',
            'transparent': 'true',
            if (layers != null && layers.isNotEmpty)
              'layers': 'show:${layers.join(',')}',
            'f': 'image',
          },
        )
        .toString();
  }
}
