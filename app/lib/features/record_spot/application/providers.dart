import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/domain/category/category_classifier.dart';
import 'package:fogworld/core/domain/search/search_area.dart';
import 'package:fogworld/core/domain/shape/shape_validator.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:fogworld/features/record_spot/application/record_spot_service.dart';

/// スポットの記録のユースケース(検索、形の取得、記録)。画面はこれだけを使う
final recordSpotServiceProvider = Provider<RecordSpotService>(
  (ref) => RecordSpotService(
    gateway: ref.watch(nominatimGatewayProvider),
    planner: const SearchAreaPlanner(),
    classifier: const CategoryClassifier(),
    validator: const ShapeValidator(),
    cover: ref.watch(coverServiceProvider),
    repository: ref.watch(spotRepositoryProvider),
    now: ref.watch(nowProvider),
  ),
);

/// [mapViewportProvider] の状態
class MapViewportNotifier extends Notifier<MapViewport?> {
  @override
  MapViewport? build() => null;

  /// 最新の表示範囲を入れる。端末の中だけで使い、保存も外部への送信もしない(NFR-2)
  void set(MapViewport viewport) => state = viewport;

  /// 表示範囲を消す
  void clear() => state = null;
}

/// 地図の今の表示範囲と縮尺(地図がまだ読み込まれていなければ null)
final mapViewportProvider = NotifierProvider<MapViewportNotifier, MapViewport?>(MapViewportNotifier.new);

/// [searchQueryProvider] の状態
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// 入力した検索語を入れる
  void set(String query) => state = query;
}

/// 検索画面で入力した検索語。「場所を置く」画面で、名前の初期値に使う。
/// 検索語は保存せず、メモリの中だけで持つ(NFR-2)
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);
