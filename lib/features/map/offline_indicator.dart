import 'package:flutter/material.dart';

/// Small, non-intrusive banner shown while the device is offline.
/// Explains blank tiles (uncached areas); never blocks the map.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
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
        ),
      ),
    );
  }
}
