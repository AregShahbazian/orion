import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'track_format.dart';

/// One summary row: color swatch + name, with start date / distance / duration
/// beneath. Tapping the body opens detail; the ⋮ menu exports (the only action
/// for now — batch/edit/delete deferred).
class TrackListTile extends StatelessWidget {
  const TrackListTile({super.key, required this.track});

  final Track track;

  void _dispatch(String id) =>
      InteractionController.instance.dispatch(id, payload: {'id': track.id});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: parseTrackColor(track.color),
        radius: 12,
      ),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatDate(track.startedAt)} · ${track.distanceFormatted} · ${track.durationFormatted}',
      ),
      onTap: () => _dispatch(InteractionIds.tracksOpen),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (_) => _dispatch(InteractionIds.tracksExport),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'export', child: Text('Export')),
        ],
      ),
    );
  }
}
