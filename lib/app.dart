import 'package:flutter/material.dart';

import 'features/map/map_screen.dart';

class OrionApp extends StatelessWidget {
  const OrionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Orion',
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}
