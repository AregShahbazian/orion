// Phase 1 smoke test: map configuration is sane. The full-screen map uses a
// platform view (MapLibre), which isn't meaningfully testable in a headless
// widget test, so we assert configuration instead.

import 'package:flutter_test/flutter_test.dart';
import 'package:orion/features/map/map_constants.dart';

void main() {
  test('map style is OpenFreeMap liberty', () {
    expect(kMapStyleUrl, contains('openfreemap.org'));
    expect(kMapStyleUrl, contains('liberty'));
  });
}
