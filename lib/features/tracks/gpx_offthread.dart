/// Parse GPX bytes off the UI thread: a background isolate (`compute`) on native,
/// a real Web Worker on web (dart2js has no isolates, so `compute` would run
/// inline and freeze the page). Conditional-import, mirroring `track_exporter.dart`.
library;

export 'gpx_offthread_io.dart'
    if (dart.library.js_interop) 'gpx_offthread_web.dart';
