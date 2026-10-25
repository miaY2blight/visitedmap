import 'package:flutter/material.dart';

import 'package:fogworld/features/map/map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: '地識録', home: MapPage());
  }
}
