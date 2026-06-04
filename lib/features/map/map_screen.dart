import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_constants.dart';

/// Phase 1: the whole app — a single full-screen map. No other UI.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;

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
    return Scaffold(
      body: MapLibreMap(
        styleString: kMapStyleUrl,
        initialCameraPosition: const CameraPosition(
          target: kPhCenter,
          zoom: kPhInitialZoom,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _fitPhilippines,
        // All gestures enabled (PRD req. 5).
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        // Zero-permission Phase 1 — no location.
        myLocationEnabled: false,
      ),
    );
  }
}
