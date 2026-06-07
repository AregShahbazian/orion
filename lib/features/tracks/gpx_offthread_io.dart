import 'package:flutter/foundation.dart';

import 'gpx_parser.dart';
import 'track_model.dart';

/// Native: parse in a background isolate via [compute]. [parseGpxBytes] is a
/// top-level function (decode + parse), runnable in an isolate.
Future<List<ParsedTrack>> parseGpxOffThread(Uint8List bytes) =>
    compute(parseGpxBytes, bytes);
