import 'dart:async';
import 'dart:math' show Point;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/interaction/interaction_controller.dart';
import '../../core/interaction/interaction_ids.dart';
import 'compass_button.dart';
import 'location_controller.dart';
import 'location_fab.dart';
import 'map_constants.dart';
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
          (_) => _location.onCameraTrackingDismissed());
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
      ..unregister(InteractionIds.mapTrackingDismissed);
    _controller?.removeListener(_onCameraChanged);
    _location.removeListener(_onLocationChanged);
    _location.dispose();
    _bearing.dispose();
    _oriented.dispose();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _location.attach(controller);
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
    // EXCEPT on web: maplibre_gl_web resets the attribution to bottom-right on
    // every partial option update (e.g. when location turns on) — its
    // interpretMapLibreMapOptions forces bottomRight whenever the position key
    // is absent from the diff. Fighting it makes the label visibly jump, so on
    // web we let it live bottom-right and move the FAB to bottom-left instead.
    final pad = MediaQuery.paddingOf(context);
    final attributionMargins =
        Point(pad.left + kHudEdgeInset, pad.bottom + kHudEdgeInset);
    final attributionPosition = kIsWeb
        ? AttributionButtonPosition.bottomRight
        : AttributionButtonPosition.bottomLeft;
    final fabAlignment = kIsWeb ? Alignment.bottomLeft : Alignment.bottomRight;

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
            onCameraTrackingDismissed: () =>
                _interactions.dispatch(InteractionIds.mapTrackingDismissed),
            // Avoid a blank flash when the native GL surface is recreated on
            // resume from background (Android lifecycle).
            translucentTextureSurface: true,
            // Native compass disabled — replaced by the Flutter CompassButton
            // below so one control handles both rotation and tilt. Track the
            // camera so we can mirror bearing/tilt into the button.
            compassEnabled: false,
            trackCameraPosition: true,
            // Keep the native attribution inside the safe area (bottom-left on
            // native, bottom-right on web — see attributionPosition above).
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
                  Align(
                    alignment: Alignment.topRight,
                    child: CompassButton(
                      bearing: _bearing,
                      visible: _oriented,
                      onReset: () =>
                          _interactions.dispatch(InteractionIds.resetOrientationTap),
                    ),
                  ),
                  Align(
                    alignment: fabAlignment,
                    child: LocationFab(
                      enabled: _location.enabled,
                      trackingMode: _location.trackingMode,
                      onPressed: _onLocationTap,
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
