import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write the GPX to a temp file and open the system share sheet
/// so the user picks where it goes (Files, Drive, email, …).
Future<void> exportGpx(String filename, String gpx) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(gpx);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/gpx+xml')],
    subject: filename,
  );
}
