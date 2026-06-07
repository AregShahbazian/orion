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
    this.backgroundColor = Colors.white,
    this.foregroundColor,
  });

  final Widget child;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color? foregroundColor;

  /// The reference HUD button size (the original compass circle).
  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(child: child);
    if (foregroundColor != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: foregroundColor),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: size, height: size, child: content),
        ),
      ),
    );
  }
}
