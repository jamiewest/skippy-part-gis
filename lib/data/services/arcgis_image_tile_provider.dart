import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Converts flutter_map XYZ tiles into ArcGIS ImageServer export requests.
final class ArcGisImageTileProvider extends TileProvider {
  /// Creates an ImageServer tile adapter.
  ArcGisImageTileProvider({super.headers});

  static const _webMercatorHalfWorld = 20037508.342789244;

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
    final zoom = coordinates.z;
    final tilesPerAxis = math.pow(2, zoom).toDouble();
    final worldWidth = _webMercatorHalfWorld * 2;
    final xmin =
        coordinates.x / tilesPerAxis * worldWidth - _webMercatorHalfWorld;
    final xmax =
        (coordinates.x + 1) / tilesPerAxis * worldWidth - _webMercatorHalfWorld;
    final ymax =
        _webMercatorHalfWorld - coordinates.y / tilesPerAxis * worldWidth;
    final ymin =
        _webMercatorHalfWorld - (coordinates.y + 1) / tilesPerAxis * worldWidth;
    return serviceUri
        .replace(
          path: '${serviceUri.path}/exportImage',
          queryParameters: {
            'bbox': '$xmin,$ymin,$xmax,$ymax',
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
