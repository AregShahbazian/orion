import 'package:go_router/go_router.dart';

import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import '../../core/log/dev_log.dart';
import 'gpx_writer.dart';
import 'import_controller.dart';
import 'track_exporter.dart';
import 'tracks_repository.dart';

/// Wire the Phase 6 track ids to the router / import controller / repository so
/// they run through the [InteractionController] both ways — drivable from the dev
/// bridges (`orion.dispatch('tracks.export', {id})`). App-lifetime; call once at
/// startup. These are trigger ids and record by default; the resulting screen
/// open is logged separately by the nav observer (same split as the settings cog).
void registerTracksInteractions(
  GoRouter router, {
  InteractionController? ic,
  ImportController? importController,
  TracksRepository? repository,
}) {
  final interactions = ic ?? InteractionController.instance;
  final imports = importController ?? ImportController.instance;
  final repo = repository ?? TracksRepository();

  interactions
    ..register(InteractionIds.hudTracksTap, (_) {
      router.goNamed('tracks');
      return null;
    })
    ..register(InteractionIds.tracksImportStart, (_) {
      // Fire-and-forget: import runs non-blocking, the badge tracks progress.
      imports.run();
      return null;
    })
    ..register(InteractionIds.tracksOpen, (payload) {
      final id = (payload?['id'] as num?)?.toInt();
      if (id == null) throw ArgumentError('tracks.open requires an "id"');
      router.goNamed('trackDetail', pathParameters: {'id': '$id'});
      return null;
    })
    ..register(InteractionIds.tracksExport, (payload) async {
      final id = (payload?['id'] as num?)?.toInt();
      if (id == null) throw ArgumentError('tracks.export requires an "id"');
      final track = await repo.getTrack(id);
      if (track == null) {
        devLog('tracks', 'export: no track $id');
        return null;
      }
      final points = await repo.getPoints(id);
      await exportGpx(gpxFileName(track), buildGpx(track, points));
      return null;
    })
    ..register(InteractionIds.dataTracksClear, (_) async {
      await repo.deleteAll();
      return null;
    });
}
