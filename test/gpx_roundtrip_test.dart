// Unit tests (dev/testing strategy ~/ai/orion/dev/testing/prd.md — unit
// category) for the GPX parse/import + export logic, exercised against two
// *real* fixtures, one per supported exporter:
//   - test/fixtures/mytracks_sample.gpx — MyTracks: one <trk> (topografix:color)
//   - test/fixtures/gaia_sample.gpx     — Gaia: many <trk> in one file (gpx_style)
// The delivery half of export (share sheet / browser download) is platform IO
// and out of scope; the serialization is covered here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/core/db/app_database.dart';
import 'package:orion/features/tracks/gpx_parser.dart';
import 'package:orion/features/tracks/gpx_writer.dart';
import 'package:orion/features/tracks/track_model.dart';

void main() {
  final myTracksGpx =
      File('test/fixtures/mytracks_sample.gpx').readAsStringSync();
  final gaiaGpx = File('test/fixtures/gaia_sample.gpx').readAsStringSync();

  group('MyTracks sample (single <trk>, topografix:color)', () {
    test('parseGpx imports the one track', () {
      final tracks = parseGpx(myTracksGpx);

      expect(tracks, hasLength(1));
      final t = tracks.single;
      expect(t.name, 'Mindanao 2022-12-24 16:13');
      expect(t.description, isNull); // empty <desc> CDATA → null
      expect(t.color, '#3A73E2'); // topografix:color 3A73E2 → normalized
      expect(t.points, hasLength(737));

      final first = t.points.first;
      expect(first.lat, 13.753825);
      expect(first.lon, 121.044832);
      expect(first.ele, 50.4);
      expect(first.time.toUtc(), DateTime.utc(2022, 12, 24, 8, 13, 42, 799));
    });

    test('buildGpx → parseGpx round-trips the track', () {
      _expectRoundTrips(parseGpx(myTracksGpx).single);
    });
  });

  group('Gaia sample (one file, many <trk>, gpx_style line color)', () {
    test('parseGpx imports every track — one ParsedTrack per <trk>', () {
      final tracks = parseGpx(gaiaGpx);

      expect(tracks, hasLength(15));
      expect(tracks.first.name, 'Mindanao 2022-12-27 09:22');
      // Gaia writes the colour as a gpx_style <line><color>; all 15 share it.
      expect(tracks.every((t) => t.color == '#2D3FC7'), isTrue);
      // No tracks merged/dropped — points are split across the 15 entries.
      expect(tracks.fold<int>(0, (n, t) => n + t.points.length), 37775);

      final first = tracks.first.points.first;
      expect(first.lat, 11.919155);
      expect(first.lon, 121.976275);
      expect(first.ele, 67.7);
      expect(first.time.toUtc(), DateTime.utc(2022, 12, 27, 1, 22, 50));
    });

    test('buildGpx → parseGpx round-trips one of its tracks', () {
      _expectRoundTrips(parseGpx(gaiaGpx).first);
    });
  });
}

/// Export [original] via buildGpx, re-parse it, and assert the track survived —
/// name, desc, colour, point count, and the endpoints. buildGpx serializes the
/// DB types, so map the parsed track onto a [Track] + [TrackPoint]s first (only
/// name/desc/colour/points reach the writer — stats are placeholders).
void _expectRoundTrips(ParsedTrack original) {
  final track = Track(
    id: 1,
    name: original.name,
    description: original.description,
    color: original.color,
    startedAt: original.points.first.time,
    endedAt: original.points.last.time,
    distanceMeters: 0,
    pointCount: original.points.length,
    elevationGain: 0,
    elevationLoss: 0,
    elevMin: null,
    elevMax: null,
    maxSpeedMs: 0,
    importedAt: original.points.first.time,
  );
  final points = [
    for (final (i, p) in original.points.indexed)
      TrackPoint(
          id: i + 1,
          trackId: 1,
          seq: i,
          lat: p.lat,
          lon: p.lon,
          ele: p.ele,
          time: p.time),
  ];

  final reparsed = parseGpx(buildGpx(track, points)).single;

  expect(reparsed.name, original.name);
  expect(reparsed.description, original.description);
  expect(reparsed.color, original.color);
  expect(reparsed.points, hasLength(original.points.length));
  _expectSamePoint(reparsed.points.first, original.points.first);
  _expectSamePoint(reparsed.points.last, original.points.last);
}

void _expectSamePoint(ParsedPoint a, ParsedPoint b) {
  expect(a.lat, b.lat);
  expect(a.lon, b.lon);
  expect(a.ele, b.ele);
  expect(a.time.toUtc(), b.time.toUtc());
}
