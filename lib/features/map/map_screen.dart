import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
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
    // The native MapLibre controls (compass, attribution "i") live in the
    // platform view, outside Flutter's tree, so SafeArea can't reach them — the
    // plugin's margin params are the only lever. Inset them by the device
    // safe-area padding so they clear the status bar, nav bar, camera cutout and
    // rounded corners. The plugin multiplies these margins by display density
    // itself (Convert.toPoint), so pass logical dp here — NOT physical pixels.
    final pad = MediaQuery.paddingOf(context);
    final compassMargins = Point(pad.right + kHudEdgeInset, pad.top + kHudEdgeInset);
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
            // Keep native controls inside the safe area (recomputed on rotation).
            compassViewPosition: CompassViewPosition.topRight,
            compassViewMargins: compassMargins,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
