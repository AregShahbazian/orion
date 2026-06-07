import 'package:flutter/material.dart';

/// Parse a `#RRGGBB` (or `RRGGBB`) hex string to a [Color], opaque. Falls back to
/// grey on anything unparseable.
Color parseTrackColor(String hex) {
  var s = hex.startsWith('#') ? hex.substring(1) : hex;
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return Colors.grey;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `23 Dec 2022` — a plain, locale-agnostic date (i18n arrives in Phase 9).
String formatDate(DateTime dt) {
  final d = dt.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// `23 Dec 2022, 17:09` — date + 24h time.
String formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  return '${formatDate(dt)}, ${_two(d.hour)}:${_two(d.minute)}';
}
