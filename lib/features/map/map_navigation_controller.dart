import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/interaction/interaction.dart';
import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';

/// Immutable read of the map camera at one instant. Plain numbers so it crosses
/// the console bridge (and the native VM-service bridge) as a flat JS/JSON object.
class CameraSnapshot {
  const CameraSnapshot({
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.bearing,
    required this.tilt,
  });

  final double lat;
  final double lng;

  /// MapLibre zoom level (continuous; ~0 world … ~22 building).
  final double zoom;

  /// Compass bearing the map is rotated to, degrees (0 = north-up).
  final double bearing;

  /// Pitch away from straight-down, degrees (0 = flat).
  final double tilt;

  Map<String, Object?> toMap() => {
        'lat': lat,
        'lng': lng,
        'zoom': zoom,
        'bearing': bearing,
        'tilt': tilt,
      };

  @override
  String toString() =>
      'Camera(lat: $lat, lng: $lng, zoom: $zoom, bearing: $bearing, tilt: $tilt)';
}

/// Programmatic map navigation — the piece the dispatch ids alone couldn't give:
///
///  * a **camera getter** ([camera]) reading the live map state, and
///  * **relative** moves (by distance/heading, by zoom/rotate/tilt delta) that
///    the raw `map.*.changed` ids — which only take absolute targets — can't.
///
/// It is a thin layer, not a parallel control path: each relative move reads the
/// current [camera], computes the absolute target, and routes it through the same
/// [InteractionController] dispatch the UI uses (origin=programmatic). So every
/// move is still recorded in the interaction log and runs the exact camera handler
/// a real gesture would.
///
/// A singleton (like [InteractionController.instance]) so the console bridge,
/// installed in `main` before any map exists, can hold a stable reference; the
/// [MapScreen] [attach]es the live controller once the map is created.
class MapNavigationController {
  MapNavigationController({InteractionController? interactions})
      : _interactions = interactions ?? InteractionController.instance;

  /// The instance the bridge and UI share. (Ctor stays public for tests.)
  static final MapNavigationController instance = MapNavigationController();

  final InteractionController _interactions;
  MapLibreMapController? _map;

  /// Bind the live map controller (called from `MapScreen._onMapCreated`).
  void attach(MapLibreMapController map) => _map = map;

  /// Drop the reference when the map goes away (widget dispose).
  void detach() => _map = null;

  /// The live camera, or `null` before the map is ready (no controller yet, or
  /// its first position hasn't been reported). Requires `trackCameraPosition`.
  CameraSnapshot? get camera {
    final pos = _map?.cameraPosition;
    if (pos == null) return null;
    return CameraSnapshot(
      lat: pos.target.latitude,
      lng: pos.target.longitude,
      zoom: pos.zoom,
      bearing: pos.bearing,
      tilt: pos.tilt,
    );
  }

  // --- Absolute moves: straight through the bus, reusing the map_screen handlers.

  /// Pan the center to ([lat], [lng]).
  Future<void> panTo(double lat, double lng) =>
      _dispatch(InteractionIds.mapScroll, {'lat': lat, 'lng': lng});

  /// Zoom to an absolute level.
  Future<void> zoomTo(double zoom) =>
      _dispatch(InteractionIds.mapZoom, {'zoom': zoom});

  /// Rotate to an absolute compass bearing (degrees, 0 = north-up).
  Future<void> rotateTo(double bearing) =>
      _dispatch(InteractionIds.mapRotate, {'bearing': bearing});

  /// Tilt to an absolute pitch (degrees, 0 = flat).
  Future<void> tiltTo(double tilt) =>
      _dispatch(InteractionIds.mapTilt, {'tilt': tilt});

  // --- Relative moves: read current camera, apply the delta, dispatch absolute.

  /// Move the center [meters] along compass [headingDegrees] (0 = N, 90 = E,
  /// 180 = S, 270 = W). Screen "right" ≈ heading 90 when the map is north-up.
  Future<void> moveBy(
      {required double meters, required double headingDegrees}) {
    final c = _require();
    final dest = _destination(c.lat, c.lng, meters, headingDegrees);
    return panTo(dest.latitude, dest.longitude);
  }

  /// Zoom in (positive) or out (negative) by [delta] levels.
  Future<void> zoomBy(double delta) => zoomTo(_require().zoom + delta);

  /// Rotate by [degrees] relative to the current bearing.
  Future<void> rotateBy(double degrees) =>
      rotateTo(_require().bearing + degrees);

  /// Tilt by [degrees] relative to the current pitch.
  Future<void> tiltBy(double degrees) => tiltTo(_require().tilt + degrees);

  Future<void> _dispatch(String id, Map<String, Object?> payload) =>
      _interactions.dispatch(id,
          origin: InteractionOrigin.programmatic, payload: payload);

  CameraSnapshot _require() {
    final c = camera;
    if (c == null) {
      throw StateError('Map not ready — no camera yet (await orion.ready).');
    }
    return c;
  }

  /// Great-circle destination from ([lat], [lng]) after travelling [meters] along
  /// compass [headingDegrees]. Spherical earth — sub-metre error at city scale,
  /// far below what map navigation needs.
  static LatLng _destination(
      double lat, double lng, double meters, double headingDegrees) {
    const earthRadius = 6371000.0; // metres
    final angular = meters / earthRadius;
    final heading = _rad(headingDegrees);
    final lat1 = _rad(lat);
    final lng1 = _rad(lng);

    final lat2 = math.asin(math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(heading));
    final lng2 = lng1 +
        math.atan2(math.sin(heading) * math.sin(angular) * math.cos(lat1),
            math.cos(angular) - math.sin(lat1) * math.sin(lat2));

    return LatLng(_deg(lat2), _deg(lng2));
  }

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;
}
