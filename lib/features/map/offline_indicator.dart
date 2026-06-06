import 'package:flutter/material.dart';

/// Small, non-intrusive banner shown while the device is offline.
/// Explains blank tiles (uncached areas); never blocks the map.
///
/// Safe-area insets are owned by the HUD layer in [MapScreen] (a single
/// `SafeArea`), so this widget only positions itself — no inset math here.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Offline — showing cached map',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
