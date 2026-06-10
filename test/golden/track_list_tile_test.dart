// Golden test (dev/testing strategy ~/ai/orion/dev/testing/prd.md — golden
// category). Pixel-pins the track-list row. Name + colour come from the real
// Gaia fixture (test/fixtures/gaia_sample.gpx); the date/distance/duration are
// fixed constants so the rendered text doesn't shift with the machine timezone.
// Non-map UI only — goldens never cover the platform-view map.
//
// Update the baseline after an intentional UI change:
//   flutter test --update-goldens test/golden/track_list_tile_test.dart
// Baseline: test/golden/goldens/track_list_tile_gaia.png

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orion/core/db/app_database.dart';
import 'package:orion/features/tracks/gpx_parser.dart';
import 'package:orion/features/tracks/track_list_tile.dart';

void main() {
  testWidgets('track-list row (Gaia sample track)', tags: 'golden',
      (tester) async {
    final gaia = parseGpx(
        File('test/fixtures/gaia_sample.gpx').readAsStringSync());
    final sample = gaia.first; // real name + colour from the Gaia export.

    final track = Track(
      id: 1,
      name: sample.name, // 'Mindanao 2022-12-27 09:22'
      description: sample.description,
      color: sample.color, // '#2D3FC7'
      // Fixed (local) constants → timezone-independent rendered text.
      startedAt: DateTime(2022, 12, 27, 9, 22),
      endedAt: DateTime(2022, 12, 27, 11, 35),
      distanceMeters: 8123,
      pointCount: 2480,
      elevationGain: 312,
      elevationLoss: 298,
      elevMin: 41,
      elevMax: 377,
      maxSpeedMs: 4.2,
      importedAt: DateTime(2022, 12, 27, 9, 22),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 400, child: TrackListTile(track: track)),
        ),
      ),
    ));

    await expectLater(
      find.byType(TrackListTile),
      matchesGoldenFile('goldens/track_list_tile_gaia.png'),
    );
  });
}
