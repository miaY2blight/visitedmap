import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/features/map/map_style.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:fogworld/features/record_spot/application/search_controller.dart';
import 'package:go_router/go_router.dart';

/// 地図の上の検索ボックス。押すと検索画面(`/search`)へ進む(ここでは入力しない)。
/// 前回の検索の結果と検索語を消してから進む(検索は毎回、空から始める)
class SearchPill extends ConsumerWidget {
  const SearchPill({super.key});

  /// 表示する文言
  static const String label = '場所を名前で検索';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: MapPalette.card,
      elevation: 3,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          clearSpotSearch(ref);
          context.go('/search');
        },
        child: const SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: MapPalette.muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14, color: MapPalette.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 地図の右上の、現在地へ移動するボタン(ゴールモックの 44px の丸)。押すと [onPressed] を呼ぶ
class LocateButton extends StatelessWidget {
  const LocateButton({super.key, required this.onPressed});

  /// 押したときの処理(現在地の取得と移動は呼び出し側が行う)
  final VoidCallback onPressed;

  /// ボタンの直径
  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: MapPalette.card,
        elevation: 3,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: '現在地へ移動',
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: const Icon(Icons.my_location, size: 22, color: MapPalette.accent),
        ),
      ),
    );
  }
}

/// 地図の上のチップ(表示範囲、広域の警告、保存件数)を縦に並べる。
///
/// - [viewport] が null(地図がまだ読み込まれていない)のときは、表示範囲と警告のチップを出さない。
/// - 警告は、[MapViewport.searchAllowed] が false のときだけ出す(施設の検索の上限。幅 2km ちょうどは出さない)。
/// - [savedCount] が null(件数をまだ読めていない、または読めなかった)のときは、件数のチップを出さない
class MapChips extends StatelessWidget {
  const MapChips({super.key, required this.viewport, required this.savedCount});

  /// 地図の今の表示範囲
  final MapViewport? viewport;

  /// 保存した記録の件数
  final int? savedCount;

  /// 広域のときの警告の文言
  static const String wideWarning = '広域: 施設の検索は拡大してから';

  @override
  Widget build(BuildContext context) {
    final v = viewport;
    final count = savedCount;
    final chips = <Widget>[
      if (v != null) _MapChip(child: Text('表示範囲 ${v.widthLabel}')),
      if (v != null && !v.searchAllowed) const _MapChip(warn: true, child: Text(wideWarning)),
      if (count != null)
        _MapChip(
          // 狭い幅・大きい文字では「確認用の表示」を次の行へ折り返す(はみ出さない)
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text('記録 $count 件'),
              const Text(
                '確認用の表示',
                style: TextStyle(fontWeight: FontWeight.w400, color: MapPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          chips[i],
        ],
      ],
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.child, this.warn = false});

  final Widget child;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warn ? MapPalette.warnSoft : MapPalette.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: warn ? MapPalette.warn : MapPalette.text,
          ),
          child: child,
        ),
      ),
    );
  }
}
