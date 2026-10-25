import 'package:flutter/material.dart';

import 'package:fogworld/prototype/fog_bench_page.dart';

/// 霧の描画方式の測定アプリ(使い捨て)の入口。
/// `flutter run --profile -t lib/prototype/prototype_main.dart -d <端末>` で起動する。製品の main.dart とは別
void main() {
  runApp(
    MaterialApp(
      title: 'FogBench',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: const FogBenchPage(),
    ),
  );
}
