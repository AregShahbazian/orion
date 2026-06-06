import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'compass_button.dart';
import 'location_service.dart';
import 'map_constants.dart';
import 'offline_indicator.dart';

/// Phase 1: the whole app — a single full-screen map. No other UI.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  final LocationService _location = LocationService();

  // Flipped on once foreground location permission is granted (native) or
  // unconditionally on web. Drives the MapLibre blue dot via [MapLibreMap]'s
  // myLocationEnabled — see _initLocation.
  bool _locationEnabled = false;

  // Camera-follow mode, cycled by the location FAB: none → tracking →
  // trackingCompass → none. Reset to none if the user pans manually
  // (onCameraTrackingDismissed).
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;

  // Drive the compass/reset-orientation button without rebuilding the map.
  // _bearing rotates the needle; _oriented (bearing≠0 || tilt≠0) shows the button.
  final ValueNotifier<double> _bearing = ValueNotifier(0);
  final ValueNotifier<bool> _oriented = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _initLocation();
  }

  /// Enable the blue "my location" dot.
  ///
  /// Native (Android/iOS): request foreground permission once. Granted → enable
  /// the dot; denied → leave it off (dot simply absent — no crash, no nagging).
  /// We request *before* enabling so the native SDK never turns on the location
  /// layer without a grant.
  ///
  /// Web: `permission_handler` has no real implementation; MapLibre's geolocate
  /// control handles the browser prompt itself, so just enable it (the dot shows
  /// after the user taps the locate button). Auto-follow on web comes with the
  /// later Follow-Me task, which legitimately flips the tracking mode.
  Future<void> _initLocation() async {
    if (kIsWeb) {
      if (mounted) setState(() => _locationEnabled = true);
      return;
    }
    final granted = await _location.requestPermission();
    if (granted && mounted) {
      setState(() => _locationEnabled = true);
    }
  }

  Future<void> _initConnectivity() async {
    final initial = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = _online(initial));
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOnline = _online(results));
    });
  }

  bool _online(List<ConnectivityResult> results) =>
      !results.contains(ConnectivityResult.none);

  @override
  void dispose() {
    _connSub?.cancel();
    _controller?.removeListener(_onCameraChanged);
    _bearing.dispose();
    _oriented.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.addListener(_onCameraChanged);
  }

  /// Mirror the camera's bearing/tilt into the notifiers. 0.5° dead-zones avoid
  /// flicker from sub-degree float noise at rest.
  void _onCameraChanged() {
    final pos = _controller?.cameraPosition;
    if (pos == null) return;
    _bearing.value = pos.bearing;
    _oriented.value = pos.bearing.abs() > 0.5 || pos.tilt > 0.5;
  }

  /// Restore the default north-up, flat view (bearing 0, tilt 0).
  void _resetOrientation() {
    final pos = _controller?.cameraPosition;
    if (pos == null) return;
    _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos.target, zoom: pos.zoom, bearing: 0, tilt: 0),
      ),
    );
  }

  // ── Location follow (FAB) ──

  /// Icon reflects the current follow state (ported from track).
  IconData get _locationFabIcon {
    if (!_locationEnabled) return Icons.location_disabled;
    switch (_trackingMode) {
      case MyLocationTrackingMode.trackingCompass:
        return Icons.explore;
      case MyLocationTrackingMode.tracking:
        return Icons.my_location;
      default:
        return Icons.location_searching;
    }
  }

  /// Tap the location FAB. If location isn't enabled yet, request permission
  /// (and guide to Settings when permanently denied — the user asked for it by
  /// tapping). Otherwise cycle none → tracking → trackingCompass → none.
  Future<void> _onLocationFabPressed() async {
    if (!_locationEnabled) {
      // Web: the geolocate control prompts the browser itself; just enable +
      // follow so the dot shows.
      if (kIsWeb) {
        setState(() => _locationEnabled = true);
        await _setTrackingMode(MyLocationTrackingMode.tracking);
        return;
      }
      final granted = await _location.requestPermission();
      if (granted) {
        setState(() => _locationEnabled = true);
        await _setTrackingMode(MyLocationTrackingMode.tracking);
      } else if (mounted && await _location.isPermanentlyDenied() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is off. Enable it in Settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: _location.openSettings,
            ),
          ),
        );
      }
      return;
    }

    final MyLocationTrackingMode next;
    switch (_trackingMode) {
      case MyLocationTrackingMode.none:
        next = MyLocationTrackingMode.tracking;
        break;
      case MyLocationTrackingMode.tracking:
        next = MyLocationTrackingMode.trackingCompass;
        break;
      default:
        next = MyLocationTrackingMode.none;
    }
    await _setTrackingMode(next);
  }

  Future<void> _setTrackingMode(MyLocationTrackingMode mode) async {
    await _controller?.updateMyLocationTrackingMode(mode);
    if (mounted) setState(() => _trackingMode = mode);
  }

  /// MapLibre fires this when the user pans/zooms while following — drop back to
  /// the free (none) state so the FAB reflects reality.
  void _onCameraTrackingDismissed() {
    if (mounted && _trackingMode != MyLocationTrackingMode.none) {
      setState(() => _trackingMode = MyLocationTrackingMode.none);
    }
  }

  /// Frame the whole Philippines once the style is ready. Fitting to bounds
  /// (rather than a fixed zoom) keeps the framing correct across screen sizes
  /// and after rotation.
  Future<void> _fitPhilippines() async {
    await _controller?.moveCamera(
      CameraUpdate.newLatLngBounds(
        kPhBounds,
        left: 24,
        top: 24,
        right: 24,
        bottom: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The native attribution "i" lives in the platform view, outside Flutter's
    // tree, so SafeArea can't reach it — the plugin's margin param is the only
    // lever. Inset it by the device safe-area padding so it clears the nav bar,
    // camera cutout and rounded corners. The plugin multiplies these margins by
    // display density itself (Convert.toPoint), so pass logical dp here — NOT
    // physical pixels. (The native compass is disabled; our Flutter
    // CompassButton in the HUD layer replaces it.)
    // Pinned bottom-LEFT so the bottom-right corner is free for the location FAB.
    final pad = MediaQuery.paddingOf(context);
    final attributionMargins =
        Point(pad.left + kHudEdgeInset, pad.bottom + kHudEdgeInset);

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: kMapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: kPhCenter,
              zoom: kPhInitialZoom,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _fitPhilippines,
            // User panned/zoomed while following → exit follow mode.
            onCameraTrackingDismissed: _onCameraTrackingDismissed,
            // Avoid a blank flash when the native GL surface is recreated on
            // resume from background (Android lifecycle).
            translucentTextureSurface: true,
            // Native compass disabled — replaced by the Flutter CompassButton
            // below so one control handles both rotation and tilt. Track the
            // camera so we can mirror bearing/tilt into the button.
            compassEnabled: false,
            trackCameraPosition: true,
            // Keep the native attribution inside the safe area (bottom-left).
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            attributionButtonMargins: attributionMargins,
            // All gestures enabled (PRD req. 5).
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            // "My location" blue dot. Enabled once permission is granted (native)
            // or on web (_initLocation). Plain dot — no heading cone (heading-arrow
            // task). Camera-follow driven by the location FAB (_trackingMode).
            myLocationEnabled: _locationEnabled,
            myLocationRenderMode: MyLocationRenderMode.normal,
            myLocationTrackingMode: _trackingMode,
          ),

          // Single safe-area-inset layer for ALL Flutter HUD. Add future buttons
          // and panels as children here — they inherit the inset automatically,
          // no per-widget MediaQuery math. (Native controls above are the one
          // exception, since they aren't in this tree.)
          Positioned.fill(
            child: SafeArea(
              minimum: const EdgeInsets.all(kHudEdgeInset),
              child: Stack(
                children: [
                  if (!_isOnline) const OfflineBanner(),
                  Align(
                    alignment: Alignment.topRight,
                    child: CompassButton(
                      bearing: _bearing,
                      visible: _oriented,
                      onReset: _resetOrientation,
                    ),
                  ),
                  // My-location / follow-me FAB (track's location FAB).
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FloatingActionButton.small(
                      heroTag: 'location',
                      onPressed: _onLocationFabPressed,
                      foregroundColor:
                          _trackingMode != MyLocationTrackingMode.none
                              ? Theme.of(context).colorScheme.primary
                              : null,
                      child: Icon(_locationFabIcon),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
