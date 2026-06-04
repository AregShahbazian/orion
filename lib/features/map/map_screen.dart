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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: kMapStyleUrl,
        initialCameraPosition: const CameraPosition(
          target: kPhCenter,
          zoom: kPhInitialZoom,
        ),
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
