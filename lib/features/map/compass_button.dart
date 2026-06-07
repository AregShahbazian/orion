import 'dart:math' show pi;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'hud_button.dart';

/// Reset-orientation control: a compass needle that rotates to the current map
/// bearing and, on tap, restores the default orientation (bearing 0, tilt 0).
///
/// Replaces the native MapLibre compass so a single button covers both rotation
/// and tilt — [visible] is driven by `bearing != 0 || tilt != 0` in [MapScreen].
class CompassButton extends StatelessWidget {
  const CompassButton({
    super.key,
    required this.bearing,
    required this.visible,
    required this.onReset,
  });

  final ValueListenable<double> bearing;
  final ValueListenable<bool> visible;
  final VoidCallback onReset;

  static const double _size = HudButton.size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, isVisible, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: !isVisible
              ? const SizedBox.shrink()
              : HudButton(
                  onPressed: onReset,
                  child: ValueListenableBuilder<double>(
                    valueListenable: bearing,
                    builder: (context, deg, child) => Transform.rotate(
                      angle: -deg * (pi / 180),
                      child: child,
                    ),
                    child: const CustomPaint(
                      size: Size(_size, _size),
                      painter: _CompassNeedlePainter(),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  const _CompassNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final needleLen = size.height * 0.32;
    const halfWidth = 5.0;

    // North — red
    final north = Path()
      ..moveTo(center.dx, center.dy - needleLen)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..close();
    canvas.drawPath(north, Paint()..color = const Color(0xFFD32F2F));

    // South — light grey
    final south = Path()
      ..moveTo(center.dx, center.dy + needleLen)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..close();
    canvas.drawPath(south, Paint()..color = const Color(0xFFBDBDBD));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
