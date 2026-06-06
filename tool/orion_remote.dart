// Call Orion's `ext.orion.*` service extensions on a running debug/profile build
// from your laptop — the native counterpart to the web console's `window.orion`.
//
// Usage:
//   dart run tool/orion_remote.dart [vm-service-uri] <cmd> [k=v ...]
//
// You normally omit the URI: `scripts/mobile/run.sh` records it to
// `.dart_tool/orion_vmservice` on every launch, and this tool reads it from
// there — so just `./scripts/mobile/orion.sh dump`. Resolution order for the URI:
//   1. a leading arg containing `://`
//   2. $ORION_VM
//   3. the file `.dart_tool/orion_vmservice`
// http(s) or ws(s) all work. Everything is localhost-forwarded, so it keeps
// working across Wi-Fi/LAN switches without re-registering anything.
//
// Examples (via the wrapper):
//   ./scripts/mobile/orion.sh dump
//   ./scripts/mobile/orion.sh logEvents on=true
//   ./scripts/mobile/orion.sh ids
//   ./scripts/mobile/orion.sh dispatch id=map.zoom.changed payload={"zoom":12}
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> argv) async {
  final args = [...argv];
  // A leading arg that looks like a URI (has a scheme) is the VM Service;
  // otherwise fall back to $ORION_VM, then to the file run.sh records.
  final uri = (args.isNotEmpty && args.first.contains('://'))
      ? args.removeAt(0)
      : (Platform.environment['ORION_VM']?.trim().isNotEmpty ?? false)
          ? Platform.environment['ORION_VM']!.trim()
          : _uriFromFile();
  final cmd = (args.isNotEmpty && !args.first.contains('=')) ? args.removeAt(0) : null;

  if (uri == null || uri.isEmpty || cmd == null) {
    stderr.writeln('usage: dart run tool/orion_remote.dart [vm-service-uri] '
        '<cmd> [k=v ...]\n'
        'No URI found — start the app with scripts/mobile/run.sh (records the URI), '
        'or pass it / set \$ORION_VM.');
    exit(64);
  }

  // Service-extension params are all strings; pass them through verbatim.
  final params = <String, String>{};
  for (final a in args) {
    final i = a.indexOf('=');
    if (i < 0) continue;
    params[a.substring(0, i)] = a.substring(i + 1);
  }

  final ws = WebSocket.connect(_wsUri(uri));
  final socket = await ws.timeout(const Duration(seconds: 10),
      onTimeout: () => throw 'could not reach VM Service at $uri');
  final rpc = _Rpc(socket);

  try {
    final vm = await rpc.call('getVM');
    final isolates = (vm['isolates'] as List).cast<Map<String, Object?>>();
    if (isolates.isEmpty) throw 'no isolates on the VM';
    final isolateId = isolates.first['id'];

    final result = await rpc.call('ext.orion.$cmd', {
      'isolateId': isolateId,
      ...params,
    });
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
  } finally {
    await socket.close();
  }
}

/// The VM Service URI `scripts/mobile/run.sh` records on each launch. Checked relative
/// to both the current dir and the repo root (this file lives in `tool/`), so it
/// resolves whether you run the wrapper or the tool directly.
String? _uriFromFile() {
  const rel = '.dart_tool/orion_vmservice';
  final root = File.fromUri(Platform.script).parent.parent.path;
  for (final path in [rel, '$root/$rel']) {
    final f = File(path);
    if (f.existsSync()) {
      final s = f.readAsStringSync().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

/// Normalize whatever `flutter run` printed into a WebSocket endpoint: http→ws,
/// and the VM Service speaks JSON-RPC on the `ws` path.
String _wsUri(String raw) {
  var u = Uri.parse(raw.trim());
  if (u.scheme == 'http') u = u.replace(scheme: 'ws');
  if (u.scheme == 'https') u = u.replace(scheme: 'wss');
  if (!u.path.endsWith('ws')) {
    final base = u.path.endsWith('/') ? u.path : '${u.path}/';
    u = u.replace(path: '${base}ws');
  }
  return u.toString();
}

/// Minimal JSON-RPC 2.0 client over the VM Service WebSocket.
class _Rpc {
  _Rpc(this._socket) {
    _socket.listen((data) {
      final msg = jsonDecode(data as String) as Map<String, Object?>;
      final id = msg['id'];
      final pending = _pending.remove(id);
      if (pending == null) return;
      final error = msg['error'];
      if (error != null) {
        pending.completeError(jsonEncode(error));
      } else {
        pending.complete(msg['result'] as Map<String, Object?>);
      }
    });
  }

  final WebSocket _socket;
  final _pending = <String, Completer<Map<String, Object?>>>{};
  var _seq = 0;

  Future<Map<String, Object?>> call(String method,
      [Map<String, Object?> params = const {}]) {
    final id = '${_seq++}';
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _socket.add(jsonEncode(
        {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
    return completer.future;
  }
}
