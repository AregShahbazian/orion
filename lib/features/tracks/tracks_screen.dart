import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'import_controller.dart';
import 'track_list_tile.dart';
import 'tracks_repository.dart';

/// Imported-tracks list. Header carries the import action (with a progress badge);
/// the body is a reactive Drift stream, so newly imported tracks appear on their
/// own. Pushed over the live map (the map stays mounted beneath — Phase 5).
class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key, this.repository, this.importController});

  final TracksRepository? repository;
  final ImportController? importController;

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  late final TracksRepository _repo = widget.repository ?? TracksRepository();
  late final ImportController _imports =
      widget.importController ?? ImportController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracks'),
        // Same back action as Android hardware back — both pop (Phase 5).
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => InteractionController.instance
              .dispatch(InteractionIds.navScreenClose),
        ),
        actions: [_importAction()],
      ),
      body: StreamBuilder<List<Track>>(
        stream: _repo.watchSummaries(),
        builder: (context, snapshot) {
          final tracks = snapshot.data;
          if (tracks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tracks.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => TrackListTile(track: tracks[i]),
          );
        },
      ),
    );
  }

  /// Import icon with a badge showing how many tracks are still being processed.
  Widget _importAction() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedBuilder(
        animation: _imports,
        builder: (context, child) => Badge.count(
          count: _imports.pending,
          isLabelVisible: _imports.pending > 0,
          child: child,
        ),
        child: IconButton(
          icon: const Icon(Icons.file_upload),
          tooltip: 'Import GPX',
          onPressed: () => InteractionController.instance
              .dispatch(InteractionIds.tracksImportStart),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('No tracks yet'),
          const SizedBox(height: 4),
          Text(
            'Import a GPX file with the button above.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
