import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';

/// 保存したスポットの一覧(新しい順。削除済みは含まない)。地図の薄い表示と、保存件数のチップに使う。
///
/// DB の読み出しに失敗したときは `AsyncError`(地図は、前の表示のまま使える)。
/// 記録が保存されたら、[SavedSheetNotifier.show] がこれを無効化して読み直させる
final savedSpotsProvider = FutureProvider<List<SavedSpot>>(
  (ref) => ref.watch(spotRepositoryProvider).allSpots(),
);

/// [savedSheetProvider] の状態。記録の画面が保存に成功したら [show] を呼ぶ
class SavedSheetNotifier extends Notifier<SavedSpot?> {
  @override
  SavedSpot? build() => null;

  /// 記録した [spot] を地図に知らせる(地図が「記録しました」のシートを出し、形へ寄る)。
  ///
  /// あわせて [savedSpotsProvider] を無効化し、保存件数と保存した形の表示を読み直させる。例外は投げない
  void show(SavedSpot spot) {
    ref.invalidate(savedSpotsProvider);
    state = spot;
  }

  /// 知らせを消す(地図が受け取ったあとに呼ぶ)
  void clear() => state = null;
}

/// 最後に記録したスポット(地図がまだ受け取っていなければ値がある。受け取ったら null)
final savedSheetProvider = NotifierProvider<SavedSheetNotifier, SavedSpot?>(SavedSheetNotifier.new);
