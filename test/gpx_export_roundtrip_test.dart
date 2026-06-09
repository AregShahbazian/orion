// Unit test (dev/testing strategy ~/ai/orion/dev/testing/prd.md — unit category).
//
// The valuable, deterministic half of the export flow: buildGpx() serializes a
// track to GPX. Re-parsing that output must yield an equivalent track — name,
// description, colour and every point preserved, in order. (The delivery half —
// share sheet / browser download — is platform IO and not unit-testable; that's
// covered manually.)

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/core/db/app_database.dart';
import 'package:orion/features/tracks/gpx_parser.dart';
import 'package:orion/features/tracks/gpx_writer.dart';

void main() {
  test('buildGpx → parseGpx round-trips name, desc, colour and points', () {
    final t0 = DateTime.utc(2022, 12, 24, 16, 13, 34);
    final track = Track(
      id: 7,
      name: 'Mindanao Route',
      description: 'a test track',
      color: '#FF8800',
      startedAt: t0,
      endedAt: t0.add(const Duration(minutes: 2)),
      distanceMeters: 0,
      pointCount: 3,
      elevationGain: 0,
      elevationLoss: 0,
      elevMin: null,
      elevMax: null,
      maxSpeedMs: 0,
      importedAt: t0,
    );
    final points = [
      TrackPoint(id: 1, trackId: 7, seq: 0, lat: 7.1, lon: 125.5, ele: 12.5, time: t0),
      TrackPoint(
          id: 2,
          trackId: 7,
          seq: 1,
          lat: 7.2,
          lon: 125.6,
          ele: 18.0,
          time: t0.add(const Duration(minutes: 1))),
      TrackPoint(
          id: 3,
          trackId: 7,
          seq: 2,
          lat: 7.3,
          lon: 125.7,
          ele: null,
          time: t0.add(const Duration(minutes: 2))),
    ];

    final parsed = parseGpx(buildGpx(track, points));

    expect(parsed, hasLength(1));
    final pt = parsed.single;
    expect(pt.name, 'Mindanao Route');
    expect(pt.description, 'a test track');
    expect(pt.color, '#FF8800'); // written hex-without-#, read back normalized.

    expect(pt.points, hasLength(3));
    expect(pt.points.map((p) => p.lat), [7.1, 7.2, 7.3]);
    expect(pt.points.map((p) => p.lon), [125.5, 125.6, 125.7]);
    expect(pt.points[0].ele, 12.5);
    expect(pt.points[2].ele, isNull);
    expect(pt.points[0].time.toUtc(), t0);
  });
}
