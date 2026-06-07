import 'package:flutter/material.dart';

import 'map_constants.dart';

/// Web-only map attribution: a compact "ⓘ" that expands on tap to the required
/// OpenFreeMap / OpenMapTiles / OpenStreetMap credit.
///
/// We render this ourselves (and hide MapLibre's built-in web attribution in
/// `web/index.html`) because the `maplibre_gl_web` plugin gives no control over
/// the attribution: it can't be made compact, its margins are a no-op on web,
/// and it's destroyed/re-created on every partial map-options update — which made
/// it collide with the HUD. Owning it here makes position and collapse fully ours
/// and independent of the plugin / MapLibre internals.
class MapAttribution extends StatefulWidget {
  const MapAttribution({super.key});

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded)
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                kMapAttribution,
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: const SizedBox(
              width: 22,
              height: 22,
              child: Icon(Icons.info_outline, size: 15, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}
