import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'compass_button.dart';
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

  // Drive the compass/reset-orientation button without rebuilding the map.
  // _bearing rotates the needle; _oriented (bearing≠0 || tilt≠0) shows the button.
  final ValueNotifier<double> _bearing = ValueNotifier(0);
  final ValueNotifier<bool> _oriented = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _initConnectivity();
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
    final pad = MediaQuery.paddingOf(context);
    final attributionMargins =
        Point(pad.right + kHudEdgeInset, pad.bottom + kHudEdgeInset);

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
            // Avoid a blank flash when the native GL surface is recreated on
            // resume from background (Android lifecycle).
            translucentTextureSurface: true,
            // Native compass disabled — replaced by the Flutter CompassButton
            // below so one control handles both rotation and tilt. Track the
            // camera so we can mirror bearing/tilt into the button.
            compassEnabled: false,
            trackCameraPosition: true,
            // Keep the native attribution inside the safe area.
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            attributionButtonMargins: attributionMargins,
            // All gestures enabled (PRD req. 5).
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            // Zero-permission Phase 1 — no location.
            myLocationEnabled: false,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
