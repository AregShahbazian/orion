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

  /// HUD compass / reset button tapped — restore north-up, flat.
  static const String resetOrientationTap = 'hud.resetOrientation.tap';

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
    resetOrientationTap,
    mapTrackingDismissed,
    mapZoom,
    mapScroll,
    mapRotate,
    mapTilt,
  };
}
