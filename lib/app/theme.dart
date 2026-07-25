import 'package:flutter/material.dart';

/// Extra map colors not represented by Material's standard color roles.
@immutable
class MapColors extends ThemeExtension<MapColors> {
  /// Creates map-specific design tokens.
  const MapColors({
    required this.address,
    required this.addressSelected,
    required this.parcel,
    required this.parcelSelected,
    required this.boundary,
    required this.alprCamera,
    required this.alprFlockCamera,
  });

  /// The standard address-point color.
  final Color address;

  /// The selected address-point color.
  final Color addressSelected;

  /// The parcel fill color.
  final Color parcel;

  /// The selected parcel fill color.
  final Color parcelSelected;

  /// The incorporated-city boundary color.
  final Color boundary;

  /// The color for a license-plate reader from any vendor.
  final Color alprCamera;

  /// The color for a Flock Safety license-plate reader.
  final Color alprFlockCamera;

  @override
  MapColors copyWith({
    Color? address,
    Color? addressSelected,
    Color? parcel,
    Color? parcelSelected,
    Color? boundary,
    Color? alprCamera,
    Color? alprFlockCamera,
  }) {
    return MapColors(
      address: address ?? this.address,
      addressSelected: addressSelected ?? this.addressSelected,
      parcel: parcel ?? this.parcel,
      parcelSelected: parcelSelected ?? this.parcelSelected,
      boundary: boundary ?? this.boundary,
      alprCamera: alprCamera ?? this.alprCamera,
      alprFlockCamera: alprFlockCamera ?? this.alprFlockCamera,
    );
  }

  @override
  MapColors lerp(covariant MapColors? other, double t) {
    if (other == null) {
      return this;
    }
    return MapColors(
      address: Color.lerp(address, other.address, t) ?? address,
      addressSelected:
          Color.lerp(addressSelected, other.addressSelected, t) ??
          addressSelected,
      parcel: Color.lerp(parcel, other.parcel, t) ?? parcel,
      parcelSelected:
          Color.lerp(parcelSelected, other.parcelSelected, t) ?? parcelSelected,
      boundary: Color.lerp(boundary, other.boundary, t) ?? boundary,
      alprCamera: Color.lerp(alprCamera, other.alprCamera, t) ?? alprCamera,
      alprFlockCamera:
          Color.lerp(alprFlockCamera, other.alprFlockCamera, t) ??
          alprFlockCamera,
    );
  }
}

/// Builds the light and dark Material 3 themes.
abstract final class AtlasTheme {
  static const _seed = Color(0xFF006B5F);

  /// The light application theme.
  static ThemeData get light => _build(Brightness.light);

  /// The dark application theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF101411)
          : const Color(0xFFF7F9F4),
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontWeight: FontWeight.w600, height: 1.08),
        headlineSmall: TextStyle(fontWeight: FontWeight.w600, height: 1.15),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(height: 1.45),
        bodyMedium: TextStyle(height: 1.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      extensions: <ThemeExtension<dynamic>>[
        MapColors(
          address: isDark ? const Color(0xFF83D5C7) : const Color(0xFF006B5F),
          addressSelected: const Color(0xFFFFB95C),
          parcel: isDark ? const Color(0xFF5986B8) : const Color(0xFF4A79A8),
          parcelSelected: const Color(0xFFFF8F70),
          boundary: isDark ? const Color(0xFFD6B9FF) : const Color(0xFF77569B),
          alprCamera: isDark
              ? const Color(0xFF9BA4B0)
              : const Color(0xFF5C6672),
          alprFlockCamera: isDark
              ? const Color(0xFFFF8A7A)
              : const Color(0xFFC62828),
        ),
      ],
    );
  }
}
