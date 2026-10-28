import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fogworld/app/providers.dart';
import 'package:fogworld/app/router.dart';
import 'package:fogworld/features/map/map_style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 縦向きに固定する(横向きは対応しない)
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 画面の遷移で地図が一瞬真っ黒になるのを防ぐため、Android の地図を TextureView で描く。
  // 地図を作る前に設定する必要がある。性能が下がる場合は map_style.dart の mapUseTextureView を false に戻す
  configureMapPlatformView();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // 起動時に 1 回だけ行う処理(期限切れの検索キャッシュの削除)。失敗しても起動は続く
    ref.read(startupTasksProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '地識録',
      routerConfig: ref.watch(routerProvider),
      // 日付選択などの標準部品を日本語で表示する(端末の言語によらず日本語)
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
