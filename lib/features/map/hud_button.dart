import 'package:flutter/material.dart';

/// Shared base for all map-HUD controls: a fixed-size circular button with the
/// standard HUD drop shadow. Only [backgroundColor]/[foregroundColor] and the
/// [child] vary per instance — size, shape, shadow and tap handling are fixed
/// here so every HUD button matches.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.backgroundColor = Colors.white,
    this.foregroundColor,
  });

  final Widget child;
  final VoidCallback onPressed;

  /// Optional long-press handler. Buttons that don't pass one have no long-press
  /// behavior (the ink response just doesn't fire).
  final VoidCallback? onLongPress;

  /// Accessibility label announced by screen readers (the controls are
  /// icon-only, so without this they'd be unlabelled).
  final String? semanticLabel;
  final Color backgroundColor;
  final Color? foregroundColor;

  /// The reference HUD button size — the circle that's actually drawn.
  static const double size = 44;

  /// Hit area, kept at Material's 48 dp minimum touch target even though the
  /// visible circle is [size]; the extra ring is transparent and tappable.
  static const double tapTargetSize = 48;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(child: child);
    if (foregroundColor != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: foregroundColor),
        child: content,
      );
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: tapTargetSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The visible circle (with shadow); behind the ink layer.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: SizedBox.square(dimension: size, child: content),
            ),
            // Tap + ripple fill the 48 dp target, painted over the circle.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  onLongPress: onLongPress,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
