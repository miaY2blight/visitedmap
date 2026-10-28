import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/features/map/map_page.dart';
import 'package:fogworld/features/record_spot/presentation/search_page.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------- 画面の差し替え口
// 各画面は Provider 経由で作る。テストでは `overrideWithValue` でスタブに差し替える。

/// 地図の画面(`/`)。既定は [MapPage]
final mapPageBuilderProvider = Provider<WidgetBuilder>((ref) => (context) => const MapPage());

/// 検索画面(`/search`)。既定は [SearchPage]
final searchPageBuilderProvider = Provider<WidgetBuilder>((ref) => (context) => const SearchPage());

/// アプリのルーター。破棄時にルーターも破棄する
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

/// 画面遷移を組み立てる。
///
/// - `/` = 地図(場所を置く・形の確認・記録は、この地図の上の固定パネルで行う)、`/search` = 検索
///   (`/search` は `/` の下に置く。どこから開いても、戻ると地図に着く)
/// - 存在しない場所は、案内の画面を出す
///
/// 画面間の値は `extra` ではなく Provider で渡す
GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const _NotFoundPage(),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ref.read(mapPageBuilderProvider)(context),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => ref.read(searchPageBuilderProvider)(context),
          ),
        ],
      ),
    ],
  );
}

/// 存在しない場所を開いたときの案内
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ページが見つかりません'),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go('/'), child: const Text('地図へ戻る')),
          ],
        ),
      ),
    );
  }
}
