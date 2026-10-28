import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/search/search_area.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// 地図の表示範囲と縮尺。検索を許可するかや、画面に出す幅のラベルの判断をここに置く(純 Dart)。
///
/// 座標は端末の中だけで使う。保存も、外部への送信もしない(NFR-2)。
class MapViewport {
  const MapViewport({required this.bounds, required this.zoom});

  /// 表示範囲。180 度線をまたぐときは、西 > 東
  final GeoBounds bounds;

  /// 地図のズームレベル
  final double zoom;

  static const SearchAreaPlanner _planner = SearchAreaPlanner();

  /// 表示範囲の中心。180 度線をまたぐときは、またいだ側の中点(経度は -180〜180 に収める)。
  /// 値が非有限のときは NaN を含む(例外は投げない)
  GeoPoint get center {
    final lat = (bounds.south + bounds.north) / 2;
    if (bounds.west > bounds.east) {
      var lon = (bounds.west + bounds.east + 360) / 2;
      if (lon > 180) lon -= 360;
      return GeoPoint(lat, lon);
    }
    return GeoPoint(lat, (bounds.west + bounds.east) / 2);
  }

  /// 表示範囲の東西の幅(m)。中心緯度での値。
  ///
  /// 180 度線をまたぐときは、東に 360 度足して数える。値が非有限のときは NaN や無限大になる(例外は投げない)
  double get widthMeters {
    if (bounds.west > bounds.east) {
      return SearchAreaPlanner.widthMetersOf(
        GeoBounds(bounds.south, bounds.west, bounds.north, bounds.east + 360),
      );
    }
    return SearchAreaPlanner.widthMetersOf(bounds);
  }

  /// 幅の比較で許す、浮動小数点の誤差(m)。[SearchAreaPlanner] と同じ
  static const double _widthEpsilonMeters = 1e-6;

  /// 施設の検索をしてよいか。
  ///
  /// 幅が [GameConfig.searchMaxWidthMeters] 以内(ちょうどは許可。浮動小数点の誤差は許す)のときだけ true。
  /// 180 度線をまたぐ、値が不正(非有限、南 >= 北、幅ゼロなど)のときは false。例外は投げない
  bool get searchAllowed => _planner.plan(bounds).allowed;

  /// 場所を置く操作(地図をタップして点を置く)をしてよいか。
  ///
  /// 幅が [GameConfig.placeMaxWidthMeters] 以内(ちょうどは許可。浮動小数点の誤差は許す)のときだけ true。
  /// 180 度線をまたぐ、値が不正(非有限、南 >= 北、幅ゼロなど)のときは、[searchAllowed] と同じく false。
  /// 例外は投げない
  bool get placeAllowed => placeAllowedFor(0);

  /// 半径 [radiusMeters] のとき、場所を置く操作(地図の長押し)をしてよいか。
  ///
  /// 上限は [GameConfig.placeMaxWidthFor](半径が小さければ 20km、大きければ半径に比例)。
  /// それ以外の条件は [placeAllowed] と同じ。例外は投げない
  bool placeAllowedFor(int radiusMeters) {
    // 値の検証と 180 度線の判定は、施設の検索と同じ([SearchAreaPlanner])。幅の上限だけを替える
    final area = _planner.plan(bounds);
    switch (area.rejection) {
      case SearchRejection.invalid || SearchRejection.crossesAntimeridian:
        return false;
      case null || SearchRejection.tooWide:
        final w = area.widthMeters;
        return w.isFinite && w <= GameConfig.placeMaxWidthFor(radiusMeters) + _widthEpsilonMeters;
    }
  }

  /// 表示範囲の幅の表示用ラベル。
  ///
  /// 0.5km 未満は m(「約400m」)、それ以上は km に切り上げ(「約1km」「約18km」)。
  /// 切り上げるのは、検索や場所を置く操作の上限(2km・20km)を超えているのに、
  /// 四捨五入で「約2km」と出て上限以内に見えるのを避けるため。上限ちょうど(誤差を含む)は上限の値のまま
  /// 幅が非有限のときは「幅不明」。例外は投げない
  String get widthLabel {
    final w = widthMeters;
    if (!w.isFinite) return '幅不明';
    if (w < 500) return '約${w.round()}m';
    return '約${((w - _widthEpsilonMeters) / 1000).ceil()}km';
  }
}

/// maplibre_gl の [LatLngBounds] を [GeoBounds] に変換する。
///
/// 南西の角から south・west を、北東の角から north・east を取る。
/// 座標の並びを取り違えやすいので、変換はここだけで行う
GeoBounds boundsFromLatLng(LatLngBounds b) {
  return GeoBounds(
    b.southwest.latitude,
    b.southwest.longitude,
    b.northeast.latitude,
    b.northeast.longitude,
  );
}
