import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'location_service.dart';

/// Outcome of a location-FAB tap, so the UI can react (e.g. a SnackBar) without
/// this controller depending on Flutter's widget/`BuildContext` layer.
enum LocationTapResult {
  /// Enabled (permission granted, or web) and now following.
  following,

  /// Already enabled — cycled to the next follow mode.
  cycled,

  /// Permission denied this time; nothing more to do.
  denied,

  /// Permission permanently denied — the UI should point the user to Settings.
  permanentlyDenied,
}

/// Owns the "my location" dot + follow-me state machine and its MapLibre
/// coupling, so [MapScreen] stays a thin view. Exposes [enabled] (drives the
/// blue dot) and [trackingMode] (camera follow) and notifies listeners on every
/// change. Deliberately UI-free (no `BuildContext`) so it stays unit-testable.
class LocationController extends ChangeNotifier {
  LocationController({LocationService? service})
      : _service = service ?? LocationService();

  final LocationService _service;
  MapLibreMapController? _map;
  bool _disposed = false;

  bool _enabled = false;
  bool get enabled => _enabled;

  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  MyLocationTrackingMode get trackingMode => _trackingMode;

  bool get isFollowing => _trackingMode != MyLocationTrackingMode.none;

  // True while [resetOrientation] orchestrates its exit-follow → reset →
  // re-enter sequence, so the tracking-dismissed callback that the programmatic
  // camera move provokes doesn't knock us back to off.
  bool _suppressDismiss = false;

  /// Bind the map controller once it's created.
  void attach(MapLibreMapController map) => _map = map;

  /// Enable the dot on startup. Native: request foreground permission first
  /// (denied → stays off, silently — no crash, no nagging). Web: just enable;
  /// the browser geolocate control handles its own prompt.
  Future<void> init() async {
    if (kIsWeb) {
      _setEnabled(true);
      return;
    }
    if (await _service.requestPermission()) _setEnabled(true);
  }

  /// Handle a FAB tap; returns what happened so the caller can surface UI.
  Future<LocationTapResult> onFabPressed() async {
    if (_enabled) {
      await _cycleTrackingMode();
      return LocationTapResult.cycled;
    }
    return _enableAndFollow();
  }

  Future<LocationTapResult> _enableAndFollow() async {
    if (!kIsWeb && !await _service.requestPermission()) {
      return await _service.isPermanentlyDenied()
          ? LocationTapResult.permanentlyDenied
          : LocationTapResult.denied;
    }
    _setEnabled(true);
    await setTrackingMode(MyLocationTrackingMode.tracking);
    return LocationTapResult.following;
  }

  /// Cycle none → tracking → trackingCompass → none.
  Future<void> _cycleTrackingMode() async {
    final previous = _trackingMode;
    final next = switch (previous) {
      MyLocationTrackingMode.none => MyLocationTrackingMode.tracking,
      MyLocationTrackingMode.tracking => MyLocationTrackingMode.trackingCompass,
      _ => MyLocationTrackingMode.none,
    };
    await setTrackingMode(next);
    // Leaving follow+heading rotates the camera to the device heading; turning
    // off should restore the default north-up, flat view (same as reset).
    if (previous == MyLocationTrackingMode.trackingCompass &&
        next == MyLocationTrackingMode.none) {
      unawaited(resetOrientation());
    }
  }

  Future<void> setTrackingMode(MyLocationTrackingMode mode) async {
    await _map?.updateMyLocationTrackingMode(mode);
    _trackingMode = mode;
    _notify();
  }

  /// Reset rotation/tilt to north-up/flat — always animating the camera so the
  /// reset is real — without ever dropping the follow.
  ///
  /// A programmatic camera move makes the native SDK dismiss tracking, so when
  /// following we orchestrate it explicitly: leave follow, animate the reset on
  /// a free camera, then re-enter plain follow (collapsing follow+heading to
  /// plain follow so the camera doesn't snap back to the heading). The
  /// dismissals this provokes are swallowed via [_suppressDismiss].
  Future<void> resetOrientation() async {
    final map = _map;
    final pos = map?.cameraPosition;
    if (map == null || pos == null) return;

    final reset = CameraUpdate.newCameraPosition(
      CameraPosition(target: pos.target, zoom: pos.zoom, bearing: 0, tilt: 0),
    );

    if (!isFollowing) {
      await map.animateCamera(reset);
      return;
    }

    _suppressDismiss = true;
    try {
      await map.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      await map.animateCamera(reset);
      await map.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
      _trackingMode = MyLocationTrackingMode.tracking;
      _notify();
    } finally {
      _suppressDismiss = false;
    }
  }

  /// MapLibre fires this when a camera move overrides follow. Ignore the ones
  /// our own reset provokes; otherwise the user panned/zoomed by hand → drop to
  /// the free (none) state.
  void onCameraTrackingDismissed() {
    if (_suppressDismiss) return;
    if (_trackingMode != MyLocationTrackingMode.none) {
      _trackingMode = MyLocationTrackingMode.none;
      _notify();
    }
  }

  /// Open the OS app-settings page (for the permanently-denied recovery path).
  Future<void> openAppSettings() => _service.openSettings();

  void _setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _notify();
  }

  // Async permission flows can resolve after the widget (and this controller)
  // is disposed; guard so a late notify doesn't throw "used after dispose".
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
