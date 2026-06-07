import 'dart:typed_data';

/// Web has no file paths — the picker provides `PlatformFile.bytes` directly, so
/// this is never called. Present only to satisfy the conditional import.
Future<Uint8List> readFileBytes(String path) =>
    throw UnsupportedError('readFileBytes is native-only; web uses PlatformFile.bytes');
