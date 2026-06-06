import 'package:flutter/foundation.dart';

/// Where a dispatched interaction came from: a real user, or a programmatic
/// dispatch (automation / diagnostics replay) through the same funnel.
enum InteractionOrigin { user, programmatic }

/// One recorded interaction: what happened, with what data, from where, when.
@immutable
class InteractionRecord {
  const InteractionRecord({
    required this.id,
    required this.origin,
    required this.at,
    this.payload,
  });

  final String id;
  final InteractionOrigin origin;
  final DateTime at;
  final Map<String, Object?>? payload;

  /// One-line, human-readable form — written to the dev log and to [dump].
  /// `14:22:07.913 [user] hud.followMe.tap {zoom: 14}`
  String get line {
    final t = at.toIso8601String().split('T').last;
    final tag = origin == InteractionOrigin.programmatic ? 'prog' : 'user';
    final body = (payload == null || payload!.isEmpty) ? '' : ' $payload';
    return '$t [$tag] $id$body';
  }

  @override
  String toString() => line;
}
