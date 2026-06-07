import 'dart:io';
import 'dart:typed_data';

/// Native: read the picked file's bytes from its path (file_picker returns a path
/// rather than loading data into memory on mobile/desktop).
Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();
