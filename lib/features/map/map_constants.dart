/// OpenFreeMap `liberty` style — free, no API key, no usage limits.
const String kMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Required attribution for the OpenFreeMap `liberty` style. Shown by our own
/// web attribution widget (MapLibre's built-in one is hidden on web); on native
/// the plugin renders its own.
const String kMapAttribution =
    'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

/// Gap (logical dp) between HUD controls and the safe-area edge, so they clear
/// rounded corners. Shared by the Flutter HUD layer and the native-control
/// margins so both sit at the same inset.
const double kHudEdgeInset = 8.0;

/// Extra bottom inset (logical dp) to lift the bottom-right location FAB clear
/// of our [MapAttribution] "ⓘ" widget below it. Web only — on native the
/// attribution sits bottom-left. The collapsed "ⓘ" is a fixed-size circle, so
/// this lift is constant.
const double kHudAttributionClearance = 30.0;
