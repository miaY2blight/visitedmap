import 'package:fogworld/core/domain/category/spot_category.dart';

/// ゲーム全体の設定値(仮の値を含む)。後から調整しやすいよう、ここに集める
class GameConfig {
  const GameConfig();

  /// 施設の検索ができる、表示範囲の幅の上限(m)。ちょうどこの幅は許可する。
  /// 公開 Nominatim は重要度順の上位 40 件しか返さず、広い範囲では目的の施設が上位に入らないため、
  /// 2km に狭めた(2026-10-27。実機の確認による)
  static const double searchMaxWidthMeters = 2000;

  /// 「場所を置く」操作(地図をタップして点を置く)ができる、表示範囲の幅の上限(m)。ちょうどこの幅は許可する。
  /// 大きな半径の山などを置くとき 2km まで拡大させないよう、施設の検索([searchMaxWidthMeters])とは別にする
  static const double placeMaxWidthMeters = 20000;

  /// 場所を置く操作の上限を、半径に連動させるときの倍率。上限は max([placeMaxWidthMeters], 半径 × この値)。
  /// 半径の大きな山などを置いた後に縮んだ地図でも、置き直せるようにする(半径 100km なら 2,000km)
  static const double placeWidthPerRadius = 20;

  /// 半径 [radiusMeters] で場所を置くときの、表示範囲の幅の上限(m)。
  /// 小さい半径では [placeMaxWidthMeters] のまま(タップの位置の精度のため)
  static double placeMaxWidthFor(int radiusMeters) {
    final byRadius = radiusMeters * placeWidthPerRadius;
    return byRadius > placeMaxWidthMeters ? byRadius : placeMaxWidthMeters;
  }

  /// 検索に送る範囲の箱の、最小の幅(m)
  static const double searchBoxMinMeters = 4000;

  /// 表示範囲の幅がこの値(m)以上なら、世界全図相当の段階として扱う(検索の候補のバッジ)。
  /// 縦向きの端末では最小ズームでも幅 約 16,000km までしか出ないため、13,000km とする
  /// (アジア規模の 約 11,000km は広域のまま)
  static const double worldScopeMeters = 13000000;

  /// 広域の地点の検索で、数が多く小さいものも多い種類(湖・池、公園、森など)を残す、
  /// Nominatim の重要度(`importance`)の下限【仮】。ちょうどこの値は残す。
  /// どの種類に掛けるかは `PlaceClassifier` の表で決める
  static const double landmarkMinImportance = 0.30;

  /// 点で登録された地形(山・火山・峠など)を選んだときの、地図の移動先の幅(m)。
  /// 移動後そのまま施設の検索ができるよう、[searchMaxWidthMeters] より小さくする
  static const double landmarkPointViewMeters = 1500;

  /// 地形の地点の `bounds` の幅・高さがこの値(m)未満なら、点とみなして
  /// [landmarkPointViewMeters] の移動先にする
  static const double landmarkPointMaxMeters = 1000;

  /// 点+半径で記録するときの、半径の下限(m)
  static const int radiusMinMeters = 20;

  /// 点+半径の半径の、全体の上限(m)。大分類ごとの上限([radiusMaxFor])の最大。
  /// 形の型の検証と、保存データの復元に使う(被覆の計算の円の上限 `GridService.maxRadiusMeters` 以下)
  static const int radiusMaxMeters = 100000;

  /// 大分類ごとの、半径の上限(m)【仮】。巨大な円で制覇を簡単に進めさせないための値
  static const int radiusMaxNatureMeters = 100000;
  static const int radiusMaxSightseeingMeters = 10000;
  static const int radiusMaxOtherMeters = 5000;
  static const int radiusMaxDiningMeters = 1000;

  /// 小分類ごとの標準の半径(m)【仮】。大分類「公園・自然」の、この小分類だけ大分類の標準より広くする
  static const Map<String, int> natureMinorStandardRadiusMeters = {
    '山・高原': 3000,
    '湖・海岸': 2000,
  };

  /// [major] の、点+半径の半径の上限(m)
  static int radiusMaxFor(MajorCategory major) => switch (major) {
        MajorCategory.nature => radiusMaxNatureMeters,
        MajorCategory.sightseeing => radiusMaxSightseeingMeters,
        MajorCategory.other => radiusMaxOtherMeters,
        MajorCategory.dining => radiusMaxDiningMeters,
      };

  /// [major]・[minor] の、点+半径の標準の半径(m)。
  /// 公園・自然の「山・高原」「湖・海岸」は [natureMinorStandardRadiusMeters]、それ以外は大分類の標準
  static int standardRadiusFor(MajorCategory major, String minor) {
    if (major == MajorCategory.nature) {
      final byMinor = natureMinorStandardRadiusMeters[minor];
      if (byMinor != null) return byMinor;
    }
    // コンビニは敷地が小さいので、半径の下限(ほぼ点)を標準にする
    if (major == MajorCategory.other && minor == convenienceMinor) return radiusMinMeters;
    return major.standardRadiusMeters;
  }

  /// 標準の半径を下限にする、小分類「コンビニ」の名前
  static const String convenienceMinor = 'コンビニ';

  /// 場所の名前の最大文字数
  static const int nameMaxLength = 100;

  /// 外部から受け取る形の、頂点数の上限(これを超えると不正として扱う)
  static const int shapeRawVertexLimit = 20000;

  /// 簡略化後の形の、目標の頂点数
  static const int shapeTargetVertices = 5000;

  /// 地図に重ねる形の、頂点数の予算(合計)
  static const int overlayVertexBudget = 100000;

  /// 半径 [m] を [radiusMinMeters]〜上限に収めた値を返す。上限は [major] があれば [radiusMaxFor]、
  /// 省略時は全体の上限 [radiusMaxMeters]
  static int clampRadius(int m, {MajorCategory? major}) {
    final max = major == null ? radiusMaxMeters : radiusMaxFor(major);
    if (m < radiusMinMeters) return radiusMinMeters;
    if (m > max) return max;
    return m;
  }
}
