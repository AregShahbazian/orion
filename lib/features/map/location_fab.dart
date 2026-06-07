import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'hud_button.dart';

/// The my-location / follow-me FAB (ported from `track`'s location FAB). A pure
/// view of [enabled] + [trackingMode]; its parent rebuilds it when those change.
/// Icon reflects the state; tint goes primary while following.
class LocationFab extends StatelessWidget {
  const LocationFab({
    super.key,
    required this.enabled,
    required this.trackingMode,
    required this.onPressed,
    this.onLongPress,
  });

  final bool enabled;
  final MyLocationTrackingMode trackingMode;
  final VoidCallback onPressed;

  /// Long-press: center on the user and zoom to the default follow zoom.
  final VoidCallback? onLongPress;

  IconData get _icon {
    if (!enabled) return Icons.location_disabled;
    switch (trackingMode) {
      case MyLocationTrackingMode.trackingCompass:
        return Icons.explore;
      case MyLocationTrackingMode.tracking:
        return Icons.my_location;
      default:
        return Icons.location_searching;
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = trackingMode != MyLocationTrackingMode.none;
    return HudButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      semanticLabel: 'My location',
      foregroundColor:
          following ? Theme.of(context).colorScheme.primary : null,
      child: Icon(_icon),
    );
  }
}
