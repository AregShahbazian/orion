/// Read a picked file's bytes from a filesystem path — native only. On web there
/// are no paths (the picker hands back bytes directly), so the web impl throws;
/// the caller uses `PlatformFile.bytes` there instead. Conditional-import,
/// mirroring `track_exporter.dart`.
library;

export 'file_read_io.dart' if (dart.library.js_interop) 'file_read_web.dart';
