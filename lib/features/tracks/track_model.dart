import 'dart:math' as math;

/// A single GPX track point as parsed from a file — before persistence. The
/// canonical shape both Gaia and MyTracks parse into.
class ParsedPoint {
  const ParsedPoint({
    required this.lat,
    required this.lon,
    this.ele,
    required this.time,
  });

  final double lat;
  final double lon;
  final double? ele;
  final DateTime time;
}

/// One parsed track: name/desc/color verbatim from the GPX plus its points. The
/// single canonical model for every source format (Gaia, MyTracks, …).
class ParsedTrack {
  const ParsedTrack({
    required this.name,
    this.description,
    required this.color,
    required this.points,
  });

  final String name;
  final String? description;
  final String color;
  final List<ParsedPoint> points;
}

/// Aggregate stats computed once at import and stored on the [Tracks] row, so the
/// list/detail never recompute or load points just for the numbers.
class TrackStats {
  const TrackStats({
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.pointCount,
    required this.elevationGain,
    required this.elevationLoss,
    this.elevMin,
    this.elevMax,
    required this.maxSpeedMs,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final int pointCount;
  final double elevationGain;
  final double elevationLoss;
  final double? elevMin;
  final double? elevMax;
  final double maxSpeedMs;

  /// Derive all aggregates in a single pass over [points]. Points are assumed
  /// time-ordered with non-null times (the parser guarantees this).
  factory TrackStats.from(List<ParsedPoint> points) {
    var distance = 0.0;
    var gain = 0.0;
    var loss = 0.0;
    var maxSpeed = 0.0;
    double? elevMin;
    double? elevMax;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.ele != null) {
        elevMin = elevMin == null ? p.ele : math.min(elevMin, p.ele!);
        elevMax = elevMax == null ? p.ele : math.max(elevMax, p.ele!);
      }
      if (i == 0) continue;
      final prev = points[i - 1];
      final d = _haversine(prev.lat, prev.lon, p.lat, p.lon);
      distance += d;
      final dt = p.time.difference(prev.time).inMilliseconds / 1000.0;
      if (dt > 0) maxSpeed = math.max(maxSpeed, d / dt);
      if (prev.ele != null && p.ele != null) {
        final de = p.ele! - prev.ele!;
        if (de > 0) {
          gain += de;
        } else {
          loss += -de;
        }
      }
    }

    return TrackStats(
      startedAt: points.first.time,
      endedAt: points.last.time,
      distanceMeters: distance,
      pointCount: points.length,
      elevationGain: gain,
      elevationLoss: loss,
      elevMin: elevMin,
      elevMax: elevMax,
      maxSpeedMs: maxSpeed,
    );
  }
}

/// Great-circle distance in metres between two lat/lon pairs.
double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final h = sinLat * sinLat +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          sinLon *
          sinLon;
  return 2 * r * math.asin(math.sqrt(h));
}
