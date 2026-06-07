import 'package:xml/xml.dart';

import '../../core/db/app_database.dart';

/// Serialize a track + its points to a GPX 1.1 document (one `<trk>`). Round-trips
/// name, desc, color and every point — re-importing the output yields an
/// equivalent track. Color is written as Gaia's `gpx_style` `<line><color>` (hex
/// without `#`), which the parser reads back namespace-agnostically.
String buildGpx(Track track, List<TrackPoint> points) {
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element('gpx', nest: () {
    b.attribute('version', '1.1');
    b.attribute('creator', 'Orion');
    b.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');
    b.element('trk', nest: () {
      b.element('name', nest: track.name);
      final desc = track.description;
      if (desc != null && desc.isNotEmpty) b.element('desc', nest: desc);
      b.element('extensions', nest: () {
        b.element('line', nest: () {
          b.attribute('xmlns', 'http://www.topografix.com/GPX/gpx_style/0/2');
          b.element('color', nest: _hex(track.color));
        });
      });
      b.element('trkseg', nest: () {
        for (final p in points) {
          b.element('trkpt', nest: () {
            b.attribute('lat', p.lat.toString());
            b.attribute('lon', p.lon.toString());
            if (p.ele != null) b.element('ele', nest: p.ele.toString());
            b.element('time', nest: p.time.toUtc().toIso8601String());
          });
        }
      });
    });
  });
  return b.buildDocument().toXmlString(pretty: true);
}

/// A safe file name for the exported track (track name + `.gpx`, sanitized).
String gpxFileName(Track track) {
  final base = track.name.replaceAll(RegExp(r'[^\w\-. ]'), '_').trim();
  return '${base.isEmpty ? 'track' : base}.gpx';
}

String _hex(String color) => color.startsWith('#') ? color.substring(1) : color;
