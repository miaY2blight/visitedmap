import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/core/data/cover/cover_service.dart';
import 'package:fogworld/core/data/db/app_database.dart';
import 'package:fogworld/core/data/db/geo_cache_store.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/data/geo/country_index.dart';
import 'package:fogworld/core/data/nominatim/nominatim_client.dart';
import 'package:fogworld/core/data/nominatim/nominatim_gateway.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// アプリ全体で共有する Provider。テストでは、どれも `overrideWith` / `overrideWithValue` で差し替えられる。

/// アプリの DB。アプリ全体で 1 つだけ開き、Provider の破棄時に閉じる。
///
/// 本番は `AppDatabase.open()`(端末内の SQLite)。単体テストでは `AppDatabase.memory()` に差し替える
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// 現在時刻を返す関数。テストでは固定の時刻を返す関数に差し替える
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 記録・形の ID(UUID v4)を作る関数。テストでは連番などに差し替える
final newIdProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});

/// 通信に使う HTTP クライアント。Provider の破棄時に閉じる
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// 外部サービスの応答のキャッシュ(DB の `geo_cache` 表)
final geoCacheStoreProvider = Provider<GeoCacheStore>(
  (ref) => GeoCacheStore(ref.watch(databaseProvider), now: ref.watch(nowProvider)),
);

/// Nominatim へのゲートウェイ。待ち行列と同時検索の共有がインスタンスの中だけで効くため、
/// アプリ全体で 1 つにする
final nominatimGatewayProvider = Provider<NominatimGateway>(
  (ref) => NominatimClient(
    http: ref.watch(httpClientProvider),
    cache: ref.watch(geoCacheStoreProvider),
    now: ref.watch(nowProvider),
  ),
);

/// 形 → 被覆(セルの一覧)の計算。本番は別の Isolate で計算する
final coverServiceProvider = Provider<CoverService>((ref) => const IsolateCoverService());

/// スポットの記録の保存と読み出し
final spotRepositoryProvider = Provider<SpotRepository>(
  (ref) => SpotRepository(
    ref.watch(databaseProvider),
    now: ref.watch(nowProvider),
    newId: ref.watch(newIdProvider),
  ),
);

/// 国・大陸の索引(同梱の `world_countries.json` を端末内で読む。通信しない)。
///
/// 資産が無い・不正なときは、`AsyncError`
final countryIndexProvider = FutureProvider<CountryIndex>((ref) => CountryIndex.load());

/// 起動時に 1 回だけ行う処理。期限切れの検索キャッシュを消す(検索した範囲の履歴を残し続けない。NFR-2)。
///
/// 失敗しても例外にしない(起動を止めない)
final startupTasksProvider = FutureProvider<void>((ref) async {
  try {
    await ref.read(geoCacheStoreProvider).purgeExpired();
  } on Object {
    // キャッシュを消せなくても、アプリは使える。次回の起動、または get / put のときに消える
  }
});

// ---------------------------------------------------------------- 画面間の受け渡し

/// 地図の移動の要求。検索画面で地名を選んだときなど、地図に表示範囲 [bounds] への移動を頼む。
///
/// 同じ範囲を続けて頼んでも別の要求として届くよう、値の比較は同一性(インスタンスごと)で行う
class MapMoveRequest {
  const MapMoveRequest({required this.bounds});

  /// 移動先の表示範囲
  final GeoBounds bounds;
}

/// [mapMoveRequestProvider] の状態。受け取った側(地図)は、処理したら [clear] で消す
class MapMoveRequestNotifier extends Notifier<MapMoveRequest?> {
  @override
  MapMoveRequest? build() => null;

  /// [bounds] への移動を頼む(毎回、新しい要求になる)
  void request(GeoBounds bounds) => state = MapMoveRequest(bounds: bounds);

  /// 要求を消す
  void clear() => state = null;
}

/// 地図への移動の要求(なければ null)
final mapMoveRequestProvider = NotifierProvider<MapMoveRequestNotifier, MapMoveRequest?>(
  MapMoveRequestNotifier.new,
);
