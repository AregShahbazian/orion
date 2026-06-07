import 'package:maplibre_gl/maplibre_gl.dart';

/// OpenFreeMap `liberty` style — free, no API key, no usage limits.
const String kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Gap (logical dp) between HUD controls and the safe-area edge, so they clear
/// rounded corners. Shared by the Flutter HUD layer and the native-control
/// margins so both sit at the same inset.
const double kHudEdgeInset = 8.0;

/// Extra bottom inset (logical dp) to lift a bottom-right HUD control clear of
/// the collapsed "ⓘ" attribution control below it (forced compact in
/// `web/index.html`). Web only — on native the label sits bottom-left. The
/// collapsed control is a fixed ~28 dp circle, so this lift is constant.
const double kHudAttributionClearance = 36.0;

/// Rough center of the Philippines for the initial camera.
/// Phase 1 / T4 will refine this to a fit over [kPhBounds].
const LatLng kPhCenter = LatLng(12.8, 122.0);
const double kPhInitialZoom = 5.0;

/// Philippines bounding box (southwest / northeast corners).
/// Used to frame the whole country (fit-to-bounds added in T4).
final LatLngBounds kPhBounds = LatLngBounds(
  southwest: const LatLng(4.5, 116.0),
  northeast: const LatLng(21.0, 127.0),
);
