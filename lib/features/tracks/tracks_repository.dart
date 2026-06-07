import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import 'track_model.dart';

/// Persistence for imported tracks. The list reads cheap row-only summaries
/// (a reactive Drift stream); points load only for detail/export.
class TracksRepository {
  TracksRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  /// Persist one parsed track: stats computed once here, then a batched
  /// transaction inserts the row and all its points (one commit, not N). No
  /// dedup — always a new row. Returns the new track id.
  Future<int> import(ParsedTrack t) {
    final stats = TrackStats.from(t.points);
    return _db.transaction(() async {
      final trackId = await _db.into(_db.tracks).insert(TracksCompanion.insert(
            name: t.name,
            description: Value(t.description),
            color: t.color,
            startedAt: stats.startedAt,
            endedAt: stats.endedAt,
            distanceMeters: stats.distanceMeters,
            pointCount: stats.pointCount,
            elevationGain: stats.elevationGain,
            elevationLoss: stats.elevationLoss,
            elevMin: Value(stats.elevMin),
            elevMax: Value(stats.elevMax),
            maxSpeedMs: stats.maxSpeedMs,
            importedAt: DateTime.now(),
          ));
      await _db.batch((b) {
        b.insertAll(_db.trackPoints, [
          for (var i = 0; i < t.points.length; i++)
            TrackPointsCompanion.insert(
              trackId: trackId,
              seq: i,
              lat: t.points[i].lat,
              lon: t.points[i].lon,
              ele: Value(t.points[i].ele),
              time: t.points[i].time,
            ),
        ]);
      });
      return trackId;
    });
  }

  /// Reactive list of track rows (no points), newest import first. Emits on every
  /// insert/delete — the list page rebuilds itself.
  Stream<List<Track>> watchSummaries() =>
      (_db.select(_db.tracks)..orderBy([(t) => OrderingTerm.desc(t.importedAt)]))
          .watch();

  Future<Track?> getTrack(int id) =>
      (_db.select(_db.tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Delete every track and its points. The list stream emits empty afterwards.
  /// (Both tables cleared explicitly — FK cascade isn't relied on.)
  Future<void> deleteAll() => _db.transaction(() async {
        await _db.delete(_db.trackPoints).go();
        await _db.delete(_db.tracks).go();
      });

  /// A track's points in order — for detail/export, the one place points load.
  Future<List<TrackPoint>> getPoints(int id) => (_db.select(_db.trackPoints)
        ..where((p) => p.trackId.equals(id))
        ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
      .get();
}
