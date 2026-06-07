import 'package:flutter_test/flutter_test.dart';
import 'package:orion/core/interaction/interaction.dart';
import 'package:orion/core/interaction/interaction_controller.dart';
import 'package:orion/core/interaction/interaction_ids.dart';

void main() {
  late InteractionController bus;

  setUp(() => bus = InteractionController(capacity: 3));

  test('dispatch runs the registered handler and returns its value', () async {
    bus.register(InteractionIds.followMeTap, (_) => 'ran');
    final result = await bus.dispatch(InteractionIds.followMeTap);
    expect(result, 'ran');
  });

  test('handler receives the dispatch payload', () async {
    Map<String, Object?>? seen;
    bus.register(InteractionIds.followMeTap, (p) {
      seen = p;
      return null;
    });
    await bus.dispatch(InteractionIds.followMeTap, payload: {'zoom': 14});
    expect(seen, {'zoom': 14});
  });

  test('origin is recorded; programmatic == same path as user', () async {
    bus.register(InteractionIds.followMeTap, (_) => null);
    await bus.dispatch(InteractionIds.followMeTap); // defaults to user
    await bus.dispatch(InteractionIds.followMeTap,
        origin: InteractionOrigin.programmatic);

    final log = bus.recent();
    expect(log.map((r) => r.origin),
        [InteractionOrigin.user, InteractionOrigin.programmatic]);
  });

  test('ring buffer drops the oldest past capacity', () async {
    bus.register(InteractionIds.followMeTap, (_) => null);
    for (var i = 0; i < 5; i++) {
      await bus.dispatch(InteractionIds.followMeTap, payload: {'n': i});
    }
    final log = bus.recent();
    expect(log.length, 3); // capacity
    expect(log.first.payload, {'n': 2}); // 0 and 1 dropped
    expect(log.last.payload, {'n': 4});
  });

  test('dispatching a known id with no handler throws', () {
    expect(
      () => bus.dispatch(InteractionIds.resetOrientationTap),
      throwsStateError,
    );
  });

  test('observe records without a handler (monitoring-only path)', () {
    // No handler registered for mapZoom — observe must not throw, just record.
    bus.observe(InteractionIds.mapZoom, payload: {'zoom': 12.0});
    final log = bus.recent();
    expect(log.single.id, InteractionIds.mapZoom);
    expect(log.single.origin, InteractionOrigin.user);
    expect(log.single.payload, {'zoom': 12.0});
  });

  test('record:false runs the handler but does not log (observer is the '
      'single recorder)', () async {
    var ran = false;
    bus.register(InteractionIds.navScreenOpen, (_) {
      ran = true;
      return null;
    }, record: false);
    await bus.dispatch(InteractionIds.navScreenOpen, payload: {'screen': 'x'});
    expect(ran, isTrue); // handler executed
    expect(bus.recent(), isEmpty); // but nothing logged by dispatch

    // Re-registering with record:true restores logging.
    bus.register(InteractionIds.navScreenOpen, (_) => null);
    await bus.dispatch(InteractionIds.navScreenOpen);
    expect(bus.recent().single.id, InteractionIds.navScreenOpen);
  });
}
