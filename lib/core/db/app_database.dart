import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// One row per imported track. Stats are computed once at import and stored here
/// so the list and detail pages never recompute or load points just for numbers.
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  RealColumn get distanceMeters => real()();
  IntColumn get pointCount => integer()();
  RealColumn get elevationGain => real()();
  RealColumn get elevationLoss => real()();
  RealColumn get elevMin => real().nullable()();
  RealColumn get elevMax => real().nullable()();
  RealColumn get maxSpeedMs => real()();
  DateTimeColumn get importedAt => dateTime()();
}

/// Full-resolution track geometry. Kept whole (no simplification) — re-export and
/// the future map render (Phase 7) need every point. `seq` preserves order.
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  RealColumn get ele => real().nullable()();
  DateTimeColumn get time => dateTime()();
}

@DriftDatabase(tables: [Tracks, TrackPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// App-global instance. The ctor stays public so tests can pass an in-memory
  /// executor.
  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 2;

  /// Index the points by `(track_id, seq)` — SQLite does not index a foreign-key
  /// child column on its own, so without this every [TracksRepository.getPoints]
  /// (and every cascade delete) full-scans the whole points table. The composite
  /// covers both the `where track_id = ?` filter and the `order by seq`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createPointIndex();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await _createPointIndex();
        },
      );

  Future<void> _createPointIndex() => customStatement(
        'CREATE INDEX IF NOT EXISTS idx_track_points_track_seq '
        'ON track_points (track_id, seq)',
      );

  /// Cross-platform connection: a file under the app documents dir on native,
  /// the WASM build (OPFS/IndexedDB) on web. The web assets (`sqlite3.wasm`,
  /// `drift_worker.js`) live in `web/`.
  static QueryExecutor _open() => driftDatabase(
        name: 'orion',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
          // No-op handler to suppress drift's default `print` about missing
          // browser features (fires on normal web loads without COOP/COEP).
          onResult: (_) {},
        ),
      );
}
