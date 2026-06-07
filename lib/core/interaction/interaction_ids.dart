/// The closed, enumerated taxonomy of interactions Orion permits. Hierarchical
/// `domain.subject.action` ids, stable over time so recorded logs stay
/// interpretable across versions. Registering or dispatching an id that isn't in
/// [all] is a programming error.
///
/// Adding a new user interaction = add its const here (and to [all]).
class InteractionIds {
  InteractionIds._();

  /// HUD location FAB tapped — enable / cycle follow mode.
  static const String followMeTap = 'hud.followMe.tap';

  /// HUD location FAB long-pressed — center on the user and zoom to the default
  /// follow zoom. In Follow+Heading it's a plain toggle to Off (no zoom).
  static const String followMeLongPress = 'hud.followMe.longPress';

  /// HUD compass / reset button tapped — restore north-up, flat.
  static const String resetOrientationTap = 'hud.resetOrientation.tap';

  /// HUD settings cog tapped — open the settings screen.
  static const String settingsTap = 'hud.settings.tap';

  // Settings toggles. Payload `{enabled: bool}`; dispatched by the settings
  // screen's switches and re-dispatchable to flip a setting programmatically.

  /// Long-press-to-zoom setting changed (gates the follow FAB long-press).
  static const String settingsLongPressZoomSet = 'settings.longPressZoom.set';

  /// Interaction-event logging setting changed (echoes each interaction to the
  /// dev log). Replaces the old runtime-only `orion.logEvents(...)` toggle.
  static const String settingsLogEventsSet = 'settings.logEvents.set';

  /// HUD tracks button tapped — open the imported-tracks screen.
  static const String hudTracksTap = 'hud.tracks.tap';

  // Track import / export (Phase 6). The screen and its actions route through the
  // bus both ways, so they're drivable from the dev bridges.

  /// Open the file picker and import the selected GPX file(s). No payload.
  static const String tracksImportStart = 'tracks.import.start';

  /// Open a track's detail page. Payload `{id: int}`.
  static const String tracksOpen = 'tracks.open';

  /// Export a single track as GPX (share sheet / download). Payload `{id: int}`.
  static const String tracksExport = 'tracks.export';

  /// Delete ALL stored tracks (dev/data action). No payload. Destructive.
  static const String dataTracksClear = 'data.tracks.clear';

  // App-screen navigation. Screens are child routes of the map route, so the map
  // stays mounted/alive beneath them; these open/close screens over it. See
  // `ai/phase-5/navigation/design.md`.

  /// Open a named app screen. Payload `{screen: String}` (e.g. `'settings'`).
  static const String navScreenOpen = 'nav.screen.open';

  /// Close the current screen — pop back to whatever's beneath (the live map).
  static const String navScreenClose = 'nav.screen.close';

  /// Camera follow dropped because the user panned/zoomed by hand.
  static const String mapTrackingDismissed = 'map.follow.dismissed';

  // Map camera gestures. Captured (origin=user) when the user settles a gesture;
  // dispatchable (origin=programmatic) to drive the camera to a target value.
  // Only the net effect is modelled — MapLibre exposes no raw gesture stream.

  /// Map zoom level settled at a new value. Payload `{zoom: double}`.
  static const String mapZoom = 'map.zoom.changed';

  /// Map center panned to a new target. Payload `{lat: double, lng: double}`.
  static const String mapScroll = 'map.scroll.changed';

  /// Map bearing rotated to a new value. Payload `{bearing: double}`.
  static const String mapRotate = 'map.rotate.changed';

  /// Map tilt (pitch) changed to a new value. Payload `{tilt: double}`.
  static const String mapTilt = 'map.tilt.changed';

  /// Authoritative set of permitted ids.
  static const Set<String> all = {
    followMeTap,
    followMeLongPress,
    resetOrientationTap,
    settingsTap,
    settingsLongPressZoomSet,
    settingsLogEventsSet,
    hudTracksTap,
    tracksImportStart,
    tracksOpen,
    tracksExport,
    dataTracksClear,
    navScreenOpen,
    navScreenClose,
    mapTrackingDismissed,
    mapZoom,
    mapScroll,
    mapRotate,
    mapTilt,
  };
}
