import 'package:xml/xml.dart';

import 'track_model.dart';

/// Default track color when a file carries none. Matches the import contract:
/// color is preserved when present, this fills the gap otherwise.
const String kDefaultTrackColor = '#4CAF50';

/// Parse a GPX 1.1 string into its tracks. Namespace-agnostic and tolerant: a
/// file may hold many `<trk>` (Gaia bundles a whole trip; MyTracks is one per
/// file) — each becomes one [ParsedTrack]. `<wpt>`/`<rte>` are ignored.
///
/// Returns an empty list on malformed XML (the caller validates/surfaces it).
List<ParsedTrack> parseGpx(String xmlString) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xmlString);
  } catch (_) {
    return const [];
  }

  final tracks = <ParsedTrack>[];
  for (final trk in _children(doc.rootElement, 'trk')) {
    // Name verbatim (CDATA already unwrapped by innerText); trim only the
    // pretty-print whitespace around it.
    final name = _child(trk, 'name')?.innerText.trim() ?? 'Imported Track';
    final descText = _child(trk, 'desc')?.innerText.trim();
    final description = (descText == null || descText.isEmpty) ? null : descText;
    final color = _extractColor(trk);

    final raw = <_RawPoint>[];
    for (final seg in _children(trk, 'trkseg')) {
      for (final pt in _children(seg, 'trkpt')) {
        final lat = double.tryParse(pt.getAttribute('lat') ?? '');
        final lon = double.tryParse(pt.getAttribute('lon') ?? '');
        if (lat == null || lon == null) continue;
        final ele = double.tryParse(_child(pt, 'ele')?.innerText.trim() ?? '');
        final time = DateTime.tryParse(_child(pt, 'time')?.innerText.trim() ?? '');
        raw.add(_RawPoint(lat, lon, ele, time));
      }
    }
    if (raw.isEmpty) continue;

    tracks.add(ParsedTrack(
      name: name,
      description: description,
      color: color,
      points: _withTimes(raw),
    ));
  }
  return tracks;
}

/// Web has no isolates (so `compute` runs inline and would freeze the UI). Parse
/// one `<trk>` block at a time, reusing [parseGpx] per block and yielding to the
/// event loop between them, so the page stays responsive. Each block is wrapped
/// back in the file's original `<gpx …>` open tag to keep its namespace
/// declarations (e.g. MyTracks' `topografix:` prefix). Correctness is identical
/// to [parseGpx] — it's the same parser, just fed per track.
Future<List<ParsedTrack>> parseGpxYielding(String xmlString) async {
  final rootOpen =
      RegExp(r'<gpx\b[^>]*>').firstMatch(xmlString)?.group(0) ?? '<gpx>';
  final out = <ParsedTrack>[];
  for (final m in RegExp(r'<trk\b[^>]*>[\s\S]*?</trk>').allMatches(xmlString)) {
    out.addAll(parseGpx('$rootOpen${m.group(0)}</gpx>'));
    await Future<void>.delayed(Duration.zero);
  }
  return out;
}

/// A trkpt before time-fill — `<time>` may be missing.
class _RawPoint {
  _RawPoint(this.lat, this.lon, this.ele, this.time);
  final double lat;
  final double lon;
  final double? ele;
  final DateTime? time;
}

/// Stats and ordering rely on monotonic times. Fill any missing `<time>`: if the
/// track has none, synthesize 1s steps from the epoch; otherwise carry the last
/// seen time forward (+1s) so gaps don't break the sequence.
List<ParsedPoint> _withTimes(List<_RawPoint> raw) {
  final hasAny = raw.any((p) => p.time != null);
  if (!hasAny) {
    final epoch = DateTime.utc(1970, 1, 1);
    return [
      for (var i = 0; i < raw.length; i++)
        ParsedPoint(
            lat: raw[i].lat,
            lon: raw[i].lon,
            ele: raw[i].ele,
            time: epoch.add(Duration(seconds: i))),
    ];
  }
  var last = raw.firstWhere((p) => p.time != null).time!;
  return [
    for (final p in raw)
      ParsedPoint(
          lat: p.lat,
          lon: p.lon,
          ele: p.ele,
          time: last = p.time ?? last.add(const Duration(seconds: 1))),
  ];
}

Iterable<XmlElement> _children(XmlElement parent, String localName) =>
    parent.childElements.where((e) => e.name.local == localName);

XmlElement? _child(XmlElement parent, String localName) {
  for (final e in parent.childElements) {
    if (e.name.local == localName) return e;
  }
  return null;
}

/// Track color from `<extensions>`: Gaia uses a `gpx_style` `<line><color>`,
/// MyTracks a `<topografix:color>` — both surface as a descendant `color`
/// element (namespace-agnostic). Normalized to `#RRGGBB`.
String _extractColor(XmlElement trk) {
  final ext = _child(trk, 'extensions');
  if (ext == null) return kDefaultTrackColor;
  for (final el in ext.descendants.whereType<XmlElement>()) {
    if (el.name.local != 'color') continue;
    final text = el.innerText.trim();
    if (text.isEmpty) continue;
    final color = text.startsWith('#') ? text : '#$text';
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) return color;
  }
  return kDefaultTrackColor;
}
