import 'package:flutter/foundation.dart';

/// A local GIS snapshot's availability and import counts.
@immutable
class SnapshotStatus {
  /// Creates snapshot status.
  const SnapshotStatus({
    required this.isAvailable,
    required this.isImporting,
    required this.addressCount,
    required this.parcelCount,
    required this.progress,
    this.updatedAt,
    this.phase = '',
  });

  /// Status before any local snapshot has been created.
  static const empty = SnapshotStatus(
    isAvailable: false,
    isImporting: false,
    addressCount: 0,
    parcelCount: 0,
    progress: 0,
  );

  /// Whether a complete snapshot can be selected.
  final bool isAvailable;

  /// Whether a new snapshot is being imported.
  final bool isImporting;

  /// Address rows in the active or pending snapshot.
  final int addressCount;

  /// Parcel rows in the active or pending snapshot.
  final int parcelCount;

  /// Import completion from zero to one.
  final double progress;

  /// The last successful activation time.
  final DateTime? updatedAt;

  /// A short description of the active import phase.
  final String phase;

  /// A copy with selected fields replaced.
  SnapshotStatus copyWith({
    bool? isAvailable,
    bool? isImporting,
    int? addressCount,
    int? parcelCount,
    double? progress,
    DateTime? updatedAt,
    String? phase,
  }) {
    return SnapshotStatus(
      isAvailable: isAvailable ?? this.isAvailable,
      isImporting: isImporting ?? this.isImporting,
      addressCount: addressCount ?? this.addressCount,
      parcelCount: parcelCount ?? this.parcelCount,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
      phase: phase ?? this.phase,
    );
  }
}
