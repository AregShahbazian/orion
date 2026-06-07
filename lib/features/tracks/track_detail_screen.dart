import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'track_format.dart';
import 'tracks_repository.dart';

/// Full-stats page for one imported track. Loads the row once on open (stats are
/// stored, so no points are needed for the numbers). No map render yet (Phase 7).
class TrackDetailScreen extends StatefulWidget {
  const TrackDetailScreen({super.key, required this.trackId, this.repository});

  final int trackId;
  final TracksRepository? repository;

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  late final TracksRepository _repo = widget.repository ?? TracksRepository();
  late final Future<Track?> _future = _repo.getTrack(widget.trackId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Track?>(
      future: _future,
      builder: (context, snapshot) {
        final track = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(track?.name ?? 'Track'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => InteractionController.instance
                  .dispatch(InteractionIds.navScreenClose),
            ),
            actions: [
              if (track != null)
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Export',
                  onPressed: () => InteractionController.instance.dispatch(
                      InteractionIds.tracksExport,
                      payload: {'id': track.id}),
                ),
            ],
          ),
          body: !snapshot.hasData && snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : track == null
                  ? const Center(child: Text('Track not found'))
                  : _Stats(track: track),
        );
      },
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Distance', track.distanceFormatted),
      ('Duration', track.durationFormatted),
      ('Avg speed', track.avgSpeedFormatted),
      ('Max speed', track.maxSpeedFormatted),
      ('Elevation gain', '${track.elevationGain.round()} m'),
      ('Elevation loss', '${track.elevationLoss.round()} m'),
      if (track.elevMin != null) ('Min elevation', '${track.elevMin!.round()} m'),
      if (track.elevMax != null) ('Max elevation', '${track.elevMax!.round()} m'),
      ('Points', '${track.pointCount}'),
      ('Start', formatDateTime(track.startedAt)),
      ('End', formatDateTime(track.endedAt)),
      if (track.description != null) ('Description', track.description!),
    ];
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => ListTile(
        title: Text(rows[i].$1),
        trailing: Text(
          rows[i].$2,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
