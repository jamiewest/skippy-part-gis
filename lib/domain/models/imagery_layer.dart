import 'package:flutter/foundation.dart';
import 'package:riverside_atlas/domain/models/geo_bounds.dart';

/// A dated Riverside County aerial-imagery service.
@immutable
final class ImageryLayer {
  /// Creates a selectable imagery layer.
  const ImageryLayer({
    required this.id,
    required this.title,
    required this.year,
    required this.serviceUri,
    required this.description,
    required this.extent,
  });

  /// ArcGIS Online item identifier.
  final String id;

  /// Publisher-supplied layer title.
  final String title;

  /// Image capture year parsed from the publisher metadata.
  final int year;

  /// Public ArcGIS ImageServer endpoint.
  final Uri serviceUri;

  /// Publisher-supplied resolution or coverage summary.
  final String description;

  /// Geographic coverage advertised by ArcGIS Online.
  final GeoBounds extent;

  /// Creates a layer from an ArcGIS Online search result.
  factory ImageryLayer.fromArcGisJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final yearMatch = RegExp(r'(?:19|20)\d{2}').firstMatch(title);
    final rawExtent = json['extent'];
    if (yearMatch == null || rawExtent is! List || rawExtent.length != 2) {
      throw const FormatException('Imagery metadata is incomplete.');
    }
    final southwest = rawExtent[0];
    final northeast = rawExtent[1];
    if (southwest is! List ||
        southwest.length != 2 ||
        northeast is! List ||
        northeast.length != 2) {
      throw const FormatException('Imagery extent is invalid.');
    }
    return ImageryLayer(
      id: json['id']?.toString() ?? '',
      title: title,
      year: int.parse(yearMatch.group(0)!),
      serviceUri: Uri.parse(json['url']?.toString() ?? ''),
      description:
          json['snippet']?.toString() ??
          _plainText(json['description']?.toString() ?? ''),
      extent: GeoBounds(
        west: (southwest[0] as num).toDouble(),
        south: (southwest[1] as num).toDouble(),
        east: (northeast[0] as num).toDouble(),
        north: (northeast[1] as num).toDouble(),
      ),
    );
  }

  static String _plainText(String value) => value
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
