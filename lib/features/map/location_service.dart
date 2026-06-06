import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around foreground location permission, mirroring `track`'s
/// service. Native only — on web the browser (via MapLibre's geolocate control)
/// handles the prompt, so callers should guard with `kIsWeb` before using this.
class LocationService {
  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> isPermanentlyDenied() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isPermanentlyDenied;
  }

  Future<void> openSettings() => openAppSettings();
}
