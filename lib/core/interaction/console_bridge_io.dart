import 'interaction_controller.dart';

/// Native: no browser console, so there's nothing to install.
void installInteractionConsoleBridge(InteractionController bus) {}

/// Native: no console bridge to notify, so readiness signalling is a no-op.
void signalMapReady() {}
