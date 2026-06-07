import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/interaction/console_bridge.dart';
import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'compass_button.dart';
import 'hud_button.dart';
import 'location_controller.dart';
import 'location_fab.dart';
import 'map_attribution.dart';
import 'map_constants.dart';
import 'map_navigation_controller.dart';
import 'offline_indicator.dart';

/// Shown when location is permanently denied and the user taps the FAB. Kept as
/// a single constant for now; moves into l10n with the language-support phase.
const String _kLocationDeniedMessage =
    'Location permission is off. Enable it in Settings.';

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

  // Owns the my-location dot + follow-me state machine. We rebuild the map (and
  // FAB) whenever it changes so its enabled/trackingMode props stay in sync.
  final LocationController _location = LocationController();

  // App-global command bus: every HUD/map interaction is dispatched through it,
  // so it's recorded/logged and can be driven programmatically (Phase 3).
  final InteractionController _interactions = InteractionController.instance;

  // Drive the compass/reset-orientation button without rebuilding the map.
  // _bearing rotates the needle; _oriented (bearing≠0 || tilt≠0) shows the button.
  final ValueNotifier<double> _bearing = ValueNotifier(0);
  final ValueNotifier<bool> _oriented = ValueNotifier(false);

  // Gesture capture: the camera at the last settle, diffed against the next one
  // to classify what the user changed. _programmaticCamera suppresses the capture
  // for camera moves we initiate ourselves (e.g. console dispatch), so they
  // aren't misrecorded as user gestures.
  CameraPosition? _lastIdleCamera;
  bool _programmaticCamera = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _location.addListener(_onLocationChanged);
    _location.init();
    // Bind the HUD/map interactions to the existing controller methods. The UI
    // dispatches the ids below instead of calling these directly.
    _interactions
      ..register(InteractionIds.followMeTap, (_) => _location.onFabPressed())
      ..register(
          InteractionIds.resetOrientationTap, (_) => _location.resetOrientation())
      ..register(InteractionIds.mapTrackingDismissed,
          (_) => _location.onCameraTrackingDismissed())
      // Programmatic camera gestures: drive the map to a target value. Captured
      // user gestures (observe, below) re-use the same ids with origin=user.
      ..register(InteractionIds.mapZoom,
          (p) => _moveCamera(CameraUpdate.zoomTo(_num(p, 'zoom'))))
      ..register(
          InteractionIds.mapScroll,
          (p) => _moveCamera(CameraUpdate.newLatLng(
              LatLng(_num(p, 'lat'), _num(p, 'lng')))))
      ..register(InteractionIds.mapRotate,
          (p) => _moveCamera(CameraUpdate.bearingTo(_num(p, 'bearing'))))
      ..register(InteractionIds.mapTilt,
          (p) => _moveCamera(CameraUpdate.tiltTo(_num(p, 'tilt'))));
  }

  /// Read a numeric payload field, tolerating the `num` that arrives from the
  /// JS console bridge (and the `int` a hand-written dispatch might pass).
  static double _num(Map<String, Object?>? p, String key) =>
      (p?[key] as num).toDouble();

  /// Move the camera on our own initiative. The flag makes the resulting idle
  /// skip gesture capture so we don't echo it back as a user interaction.
  Future<void> _moveCamera(CameraUpdate update) async {
    _programmaticCamera = true;
    await _controller?.animateCamera(update);
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

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _interactions
      ..unregister(InteractionIds.followMeTap)
      ..unregister(InteractionIds.resetOrientationTap)
      ..unregister(InteractionIds.mapTrackingDismissed)
      ..unregister(InteractionIds.mapZoom)
      ..unregister(InteractionIds.mapScroll)
      ..unregister(InteractionIds.mapRotate)
      ..unregister(InteractionIds.mapTilt);
    _controller?.removeListener(_onCameraChanged);
    MapNavigationController.instance.detach();
    _location.removeListener(_onLocationChanged);
    _location.dispose();
    _bearing.dispose();
    _oriented.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _location.attach(controller);
    // Let the console/VM-service bridge read the live camera and drive relative
    // moves (orion.camera / orion.moveBy / ...).
    MapNavigationController.instance.attach(controller);
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

  /// Classify the net camera change since the last settle and record each
  /// component the user moved. Skipped for camera moves we drive ourselves and
  /// while following (the location dot drives the camera then, not the user).
  void _onCameraIdle() {
    final pos = _controller?.cameraPosition;
    if (pos == null) return;
    final last = _lastIdleCamera;
    _lastIdleCamera = pos;

    if (_programmaticCamera) {
      _programmaticCamera = false;
      return;
    }
    if (_location.trackingMode != MyLocationTrackingMode.none) return;
    if (last == null) return;

    final t = pos.target, lt = last.target;
    if ((pos.zoom - last.zoom).abs() > 0.01) {
      _interactions.observe(InteractionIds.mapZoom, payload: {'zoom': pos.zoom});
    }
    if ((t.latitude - lt.latitude).abs() > 1e-5 ||
        (t.longitude - lt.longitude).abs() > 1e-5) {
      _interactions.observe(InteractionIds.mapScroll,
          payload: {'lat': t.latitude, 'lng': t.longitude});
    }
    if ((pos.bearing - last.bearing).abs() > 0.5) {
      _interactions
          .observe(InteractionIds.mapRotate, payload: {'bearing': pos.bearing});
    }
    if ((pos.tilt - last.tilt).abs() > 0.5) {
      _interactions.observe(InteractionIds.mapTilt, payload: {'tilt': pos.tilt});
    }
  }

  /// Tap the location FAB; show the Settings recovery SnackBar if the user has
  /// permanently denied permission (they asked for it by tapping).
  Future<void> _onLocationTap() async {
    final result = await _interactions.dispatch(InteractionIds.followMeTap);
    if (!mounted || result != LocationTapResult.permanentlyDenied) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(_kLocationDeniedMessage),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: _location.openAppSettings,
        ),
      ),
    );
  }

  /// Style is loaded and the camera is usable: let dev console automation know
  /// via `orion.ready` (no-op off web/debug).
  Future<void> _onStyleLoaded() async {
    signalMapReady();
  }

  @override
  Widget build(BuildContext context) {
    // Native: the attribution "i" lives in the platform view, outside Flutter's
    // tree, so SafeArea can't reach it — the plugin's margin param is the only
    // lever. Pin it bottom-LEFT (so the bottom-right corner is free for the FAB)
    // and inset it by the device safe-area padding so it clears the nav bar,
    // camera cutout and rounded corners. The plugin multiplies these margins by
    // display density itself (Convert.toPoint), so pass logical dp — NOT pixels.
    // (The native compass is disabled; our Flutter CompassButton replaces it.)
    //
    // Web: the plugin's attribution is uncontrollable (no compact, no-op margins,
    // re-created on every options update), so it's hidden in `web/index.html` and
    // we render our own [MapAttribution] bottom-right with the FAB lifted above.
    final pad = MediaQuery.paddingOf(context);
    final attributionMargins = kIsWeb
        ? null
        : Point(pad.left + kHudEdgeInset, pad.bottom + kHudEdgeInset);
    final attributionPosition =
        kIsWeb ? null : AttributionButtonPosition.bottomLeft;
    // Bottom-right HUD column (FAB on top, settings cog beneath). On web the
    // whole column is lifted above our bottom-right attribution so the lowest
    // control (the cog) clears it; on native (attribution is bottom-left) it's
    // already the lowest, no lift needed.
    final hudColumnBottomInset = kIsWeb ? kHudAttributionClearance : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: kMapStyleUrl,
            // No default region — open on a whole-world view (explicit zoom, not
            // a degenerate default of 0), then follow the user's location once
            // it's available (auto on native; tap-to-locate on web).
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 1,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            // User panned/zoomed while following → exit follow mode.
            onCameraTrackingDismissed: () =>
                _interactions.dispatch(InteractionIds.mapTrackingDismissed),
            // Capture the net gesture once the camera settles (one record per
            // gesture, not per frame).
            onCameraIdle: _onCameraIdle,
            // Avoid a blank flash when the native GL surface is recreated on
            // resume from background (Android lifecycle).
            translucentTextureSurface: true,
            // Native compass disabled — replaced by the Flutter CompassButton
            // below so one control handles both rotation and tilt. Track the
            // camera so we can mirror bearing/tilt into the button.
            compassEnabled: false,
            trackCameraPosition: true,
            // Native only: keep the attribution inside the safe area, bottom-left
            // (null on web — hidden there, replaced by [MapAttribution]).
            attributionButtonPosition: attributionPosition,
            attributionButtonMargins: attributionMargins,
            // All gestures enabled (PRD req. 5).
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            // "My location" blue dot + follow, owned by _location. Render mode
            // `compass` (via _location.renderMode) adds the heading cone on
            // native; web falls back to a plain dot. The accuracy ring is drawn
            // by the plugin by default (metric — visible at street zoom).
            myLocationEnabled: _location.enabled,
            myLocationRenderMode: _location.renderMode,
            myLocationTrackingMode: _location.trackingMode,
            // Use high-accuracy GPS at a 1s interval. The default `balanced`
            // priority lets Android throttle a stationary device to ~1 fix/30s,
            // which collides with MapLibre's ~30s stale timeout and leaves the
            // dot grey most of the time. GPS priority honors the interval, so
            // fixes stay frequent and the dot stays "fresh" (blue).
            locationEnginePlatforms: const LocationEnginePlatforms.android(
              enableHighAccuracy: true,
              interval: 1000,
            ),
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
                  // PointerInterceptor stops taps on HUD controls from leaking
                  // through to the MapLibre platform view underneath (a Flutter-
                  // web quirk): the leaked touch makes maplibre `map.stop()` on
                  // touchstart, which cancelled the compass reset animation.
                  // No-op off web.
                  Align(
                    alignment: Alignment.topRight,
                    child: PointerInterceptor(
                      child: CompassButton(
                        bearing: _bearing,
                        visible: _oriented,
                        onReset: () => _interactions
                            .dispatch(InteractionIds.resetOrientationTap),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: hudColumnBottomInset),
                      // One interceptor over the whole column so taps on the gap
                      // between the buttons don't leak through to the map (web).
                      child: PointerInterceptor(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LocationFab(
                              enabled: _location.enabled,
                              trackingMode: _location.trackingMode,
                              onPressed: _onLocationTap,
                            ),
                            const SizedBox(height: kHudControlGap),
                            HudButton(
                              semanticLabel: 'Settings',
                              onPressed: () => _interactions
                                  .dispatch(InteractionIds.settingsTap),
                              child: const Icon(Icons.settings),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Web only: our own attribution (the plugin's is hidden on web).
                  if (kIsWeb)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: PointerInterceptor(child: const MapAttribution()),
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
