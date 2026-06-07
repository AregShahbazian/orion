import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';

/// Draw under the status/navigation bars and make them transparent, so the map
/// fills the screen and HUD insets come from SafeArea. Re-applied on resume:
/// some Android OEMs reset the overlay style when the app returns to foreground.
void applyEdgeToEdgeSystemUi() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
}

class OrionApp extends StatefulWidget {
  const OrionApp({super.key});

  @override
  State<OrionApp> createState() => _OrionAppState();
}

class _OrionAppState extends State<OrionApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) applyEdgeToEdgeSystemUi();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Orion',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
