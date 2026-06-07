import 'package:flutter/material.dart';

/// App-global messenger key so any transient message uses the same `SnackBar`
/// host — including ones raised from controllers that have no `BuildContext`
/// (e.g. the import controller). Wired into `MaterialApp.router`.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Show a transient app message. The **one** path for every user-facing
/// transient message (import status/errors, location-permission, …) so they all
/// share styling. Replaces the previous one shown immediately.
void showAppMessage(
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
}) {
  appMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      duration: duration,
    ));
}
