import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/log/dev_log.dart';
import '../../core/ui/app_messenger.dart';
import 'file_read.dart';
import 'gpx_offthread.dart';
import 'track_model.dart';
import 'tracks_repository.dart';

/// Runs GPX imports off the UI thread of control: picks file(s), parses each into
/// its tracks, and stores them one by one. [pending] is the number of tracks
/// still being stored — the header badge shows it. App-global so an import keeps
/// running (and the badge stays correct) even if the user navigates away.
class ImportController extends ChangeNotifier {
  ImportController([TracksRepository? repo])
      : _repo = repo ?? TracksRepository();

  static final ImportController instance = ImportController();

  final TracksRepository _repo;

  int _pending = 0;

  /// Total tracks left to store across the current selection — set once all
  /// picked files are parsed, then counted down as each track lands. So the badge
  /// shows the real total (e.g. 15 for 15 single-track files, or a 15-track file),
  /// not a per-file count.
  int get pending => _pending;

  /// Open the file picker and import everything selected. Returns when the picked
  /// files have been processed (no-op if the user cancels).
  Future<void> run() async {
    final FilePickerResult? result;
    try {
      // Android's picker filters by MIME and has none for `gpx`, so a custom
      // filter throws there — use it only on web (where it sets the `accept`
      // hint) and `any` on mobile (matches the working `track/` approach). We
      // validate the extension after picking. `withData` only on web; on mobile
      // we read the file by path (loading every pick into memory is wasteful).
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: kIsWeb ? FileType.custom : FileType.any,
        allowedExtensions: kIsWeb ? ['gpx'] : null,
        withData: kIsWeb,
      );
    } catch (e) {
      _fail('Could not open the file picker');
      devLog('import', 'picker error: $e');
      return;
    }
    if (result == null) return; // cancelled

    // Immediate feedback before the (brief) parse wait — track counts aren't
    // known yet (they need the parse), so the message is by file.
    final files = result.files;
    showAppMessage(files.length == 1
        ? 'Importing ${files.single.name}…'
        : 'Importing ${files.length} files…');

    // Parse each file off the UI isolate (compute = a real background isolate on
    // mobile, so the UI doesn't freeze). The badge climbs toward the total as
    // files come back; on web compute runs inline, but the per-file await still
    // lets the existing list repaint/scroll between files.
    final toImport = <ParsedTrack>[];
    for (final file in result.files) {
      final parsed = await _parseFile(file);
      if (parsed.isEmpty) continue;
      _pending += parsed.length;
      notifyListeners();
      toImport.addAll(parsed);
    }
    if (toImport.isEmpty) return;

    for (final t in toImport) {
      try {
        await _repo.import(t);
      } catch (e) {
        _fail('Failed to import "${t.name}"');
        devLog('import', 'store error: $e');
      } finally {
        _pending--;
        notifyListeners();
      }
      // Yield so storing many tracks doesn't starve the UI.
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Parse one picked file to its tracks off the UI isolate, recording a friendly
  /// error (and returning empty) on anything invalid. Android's picker may ignore
  /// the .gpx filter, so validate here.
  Future<List<ParsedTrack>> _parseFile(PlatformFile file) async {
    if (!file.name.toLowerCase().endsWith('.gpx')) {
      _fail('Not a GPX file: ${file.name}');
      return const [];
    }
    // Web hands back bytes; mobile hands back a path (we read it ourselves).
    final bytes = file.bytes ??
        (file.path != null ? await readFileBytes(file.path!) : null);
    if (bytes == null) {
      _fail('Could not read ${file.name}');
      return const [];
    }
    // Off-UI parse: a background isolate on mobile, a real Web Worker on web.
    final tracks = await parseGpxOffThread(bytes);
    if (tracks.isEmpty) _fail('No tracks found in ${file.name}');
    return tracks;
  }

  void _fail(String message) {
    devLog('import', message);
    showAppMessage(message);
  }
}
