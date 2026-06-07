import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';

/// Display helpers for a persisted [Track] row (stats are already stored, so
/// these only format). Lives here (not in `track_model.dart`) so the parse chain
/// stays free of Drift/Flutter and can compile into the web worker.
extension TrackFormatting on Track {
  Duration get duration => endedAt.difference(startedAt);

  /// Average speed in m/s over the whole track.
  double get averageSpeedMs {
    final secs = duration.inSeconds;
    return secs == 0 ? 0 : distanceMeters / secs;
  }

  String get distanceFormatted => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(2)} km';

  String get durationFormatted {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  String get avgSpeedFormatted =>
      '${(averageSpeedMs * 3.6).toStringAsFixed(1)} km/h';

  String get maxSpeedFormatted =>
      '${(maxSpeedMs * 3.6).toStringAsFixed(1)} km/h';
}

/// Parse a `#RRGGBB` (or `RRGGBB`) hex string to a [Color], opaque. Falls back to
/// grey on anything unparseable.
Color parseTrackColor(String hex) {
  var s = hex.startsWith('#') ? hex.substring(1) : hex;
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return Colors.grey;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `23 Dec 2022` — a plain, locale-agnostic date (i18n arrives in Phase 9).
String formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// `23 Dec 2022, 17:09` — date + 24h time.
String formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  return '${formatDate(dt)}, ${_two(d.hour)}:${_two(d.minute)}';
}
