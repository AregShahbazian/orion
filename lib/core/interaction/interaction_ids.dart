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

  /// Authoritative set of permitted ids.
  static const Set<String> all = {
    followMeTap,
    resetOrientationTap,
    mapTrackingDismissed,
  };
}
