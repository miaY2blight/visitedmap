import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/search/search_area.dart';

/// 地図の表示範囲の段階。検索の候補に付けるバッジの種類を決める
enum SearchScope {
  /// 近景。幅が [GameConfig.searchMaxWidthMeters] 以下(施設の検索ができる範囲)
  near,

  /// 広域。近景より広く、世界全図より狭い(国・大陸を示す範囲)
  region,

  /// 世界全図相当。幅が [GameConfig.worldScopeMeters] 以上
  world,
}

/// 表示範囲の幅から、[SearchScope] を決める規則(純 Dart)
class SearchScopeRule {
  const SearchScopeRule();

  /// 幅の比較で許す、浮動小数点の誤差(m)。ちょうど境界の幅を、境界の内側として扱うための余裕
  static const double _widthEpsilonMeters = 1e-6;

  /// [visible] の段階を返す。例外は投げない。
  ///
  /// - 幅 <= [GameConfig.searchMaxWidthMeters]: [SearchScope.near]
  /// - 幅 >= [GameConfig.worldScopeMeters]: [SearchScope.world]
  /// - その間: [SearchScope.region]
  ///
  /// 値が不正(非有限、南 >= 北、幅ゼロ)なときは、近景にも世界全図にもせず
  /// [SearchScope.region] を返す。西 > 東(180 度線をまたぐ)は、東に 360 度足して幅を数える
  SearchScope scopeOf(GeoBounds visible) {
    final values = [visible.south, visible.west, visible.north, visible.east];
    if (values.any((v) => !v.isFinite) ||
        visible.south >= visible.north ||
        visible.west == visible.east) {
      return SearchScope.region;
    }

    final east = visible.west > visible.east ? visible.east + 360 : visible.east;
    final width = SearchAreaPlanner.widthMetersOf(
      GeoBounds(visible.south, visible.west, visible.north, east),
    );
    if (!width.isFinite) return SearchScope.region;

    if (width <= GameConfig.searchMaxWidthMeters + _widthEpsilonMeters) {
      return SearchScope.near;
    }
    if (width >= GameConfig.worldScopeMeters - _widthEpsilonMeters) {
      return SearchScope.world;
    }
    return SearchScope.region;
  }
}
