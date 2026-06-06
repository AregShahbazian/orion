import 'dart:async';
import 'dart:collection';

import '../log/dev_log.dart';
import 'interaction.dart';
import 'interaction_ids.dart';

/// A registered interaction handler: receives the dispatch payload (if any) and
/// may return a value the dispatcher passes back to the caller (e.g. a result
/// enum the UI needs for follow-up).
typedef InteractionHandler = FutureOr<Object?> Function(
    Map<String, Object?>? payload);

/// Default ring-buffer size. A few hundred interactions is plenty to describe
/// "how the user got here" without unbounded growth.
const int kInteractionLogCapacity = 200;

/// App-global command bus + interaction log (Phase 3). One channel for every
/// meaningful interaction:
///
///  * features [register] a handler for each interaction id they own;
///  * the UI (or automation) [dispatch]es ids — same path either way, so a
///    programmatic dispatch produces the exact effect of the real user action;
///  * every dispatch is recorded in a bounded ring buffer ([recent]) and echoed
///    to the dev log, tagged with its [InteractionOrigin].
///
/// Hand-rolled (no flutter_bloc): Orion's state is plain [ChangeNotifier]s, so a
/// thin dispatcher layers over the existing controllers without an app-wide
/// rewrite. See `ai/phase-3/interaction-controller/design.md`.
class InteractionController {
  InteractionController({
    this.capacity = kInteractionLogCapacity,
    this.logEvents = false,
  });

  /// The app-global instance the UI dispatches through. (Ctor stays public so
  /// tests can use isolated instances.)
  static final InteractionController instance = InteractionController();

  /// Max records kept; the oldest is dropped once the buffer exceeds this.
  final int capacity;

  /// Whether each recorded interaction is echoed to [devLog]. Off by default —
  /// the ring buffer ([recent]) always captures everything; this only gates the
  /// noisy per-event console/DevTools line. Flip at runtime (e.g. from the dev
  /// console) to watch interactions live.
  bool logEvents;

  final Map<String, InteractionHandler> _handlers = {};
  final Queue<InteractionRecord> _log = Queue<InteractionRecord>();

  /// Bind [handler] to a taxonomy [id]. Called by the feature that owns the
  /// interaction, typically in `initState`.
  void register(String id, InteractionHandler handler) {
    assert(InteractionIds.all.contains(id), 'Unknown interaction id: $id');
    _handlers[id] = handler;
  }

  void unregister(String id) => _handlers.remove(id);

  /// Perform [id] as if the user did it. Records + logs first, then runs the
  /// registered handler and returns whatever it returns. Throws if [id] has no
  /// handler registered.
  Future<Object?> dispatch(
    String id, {
    Map<String, Object?>? payload,
    InteractionOrigin origin = InteractionOrigin.user,
  }) async {
    assert(InteractionIds.all.contains(id), 'Unknown interaction id: $id');
    _record(InteractionRecord(
      id: id,
      origin: origin,
      at: DateTime.now(),
      payload: payload,
    ));
    final handler = _handlers[id];
    if (handler == null) {
      throw StateError('No handler registered for interaction "$id"');
    }
    return await handler(payload);
  }

  /// Record an interaction the app *observed* but did not itself execute — the
  /// monitoring half of the bus. Used for native gestures (map zoom/pan/rotate)
  /// that MapLibre performs before we hear about them: there's nothing to run, so
  /// no handler is invoked. [dispatch] the same id (origin=programmatic) to make
  /// it happen on demand.
  void observe(
    String id, {
    Map<String, Object?>? payload,
    InteractionOrigin origin = InteractionOrigin.user,
  }) {
    assert(InteractionIds.all.contains(id), 'Unknown interaction id: $id');
    _record(InteractionRecord(
      id: id,
      origin: origin,
      at: DateTime.now(),
      payload: payload,
    ));
  }

  /// The buffered records, oldest first.
  List<InteractionRecord> recent() => List.unmodifiable(_log);

  /// Human- and machine-readable dump of the buffer (for bug reports).
  String dump() => _log.map((r) => r.line).join('\n');

  void _record(InteractionRecord r) {
    _log.addLast(r);
    while (_log.length > capacity) {
      _log.removeFirst();
    }
    if (logEvents) devLog('interaction', r.line);
  }
}
