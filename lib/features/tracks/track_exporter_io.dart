import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Mobile/desktop: open the native "save as" dialog so the user picks a real
/// on-device location (Downloads, Files, an SD card, …) — not a share target.
/// On mobile `saveFile` writes the bytes at the chosen spot; on desktop it only
/// returns the chosen path, so we write it ourselves.
Future<void> exportGpx(String filename, String gpx) async {
  final bytes = utf8.encode(gpx);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save GPX',
    fileName: filename,
    type: FileType.any,
    bytes: bytes,
  );
  if (path == null) return; // user cancelled
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    await File(path).writeAsBytes(bytes);
  }
}
