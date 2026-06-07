/// OpenFreeMap `liberty` style — free, no API key, no usage limits.
const String kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Street/neighborhood zoom the long-press "center on me" lands at. The app
/// opens whole-world (zoom 1) and plain follow keeps the current zoom, so this
/// is the one place the camera is taken to a usable street level. Parity with
/// the `track` POC's center-me zoom.
const double kDefaultFollowZoom = 15.0;

/// How long the long-press zoom-to-[kDefaultFollowZoom] glide takes. The SDK
/// default snaps in fast; this slows it to a smoother, more legible motion.
const Duration kDefaultFollowZoomDuration = Duration(milliseconds: 1200);

/// Required attribution for the OpenFreeMap `liberty` style. Shown by our own
/// web attribution widget (MapLibre's built-in one is hidden on web); on native
/// the plugin renders its own.
const String kMapAttribution =
    'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

/// Gap (logical dp) between HUD controls and the safe-area edge, so they clear
/// rounded corners. Shared by the Flutter HUD layer and the native-control
/// margins so both sit at the same inset.
const double kHudEdgeInset = 8.0;

/// Vertical gap (logical dp) between stacked HUD controls in a column (e.g. the
/// bottom-right location FAB and the settings cog beneath it).
const double kHudControlGap = 8.0;

/// Extra bottom inset (logical dp) to lift the bottom-right HUD column clear of
/// our [MapAttribution] "ⓘ" widget below it, so the lowest control (the settings
/// cog) doesn't collide with it. Web only — on native the attribution sits
/// bottom-left. The collapsed "ⓘ" is a fixed-size circle, so this lift is
/// constant.
const double kHudAttributionClearance = 30.0;
