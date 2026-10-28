import 'dart:math' as math;

import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 検索を許可しない理由
enum SearchRejection {
  /// 表示範囲の幅が [GameConfig.searchMaxWidthMeters] を超えている
  tooWide,

  /// 値が不正(非有限、南 >= 北、緯度・経度の範囲外、幅ゼロ)
  invalid,

  /// 表示範囲が経度 180 度線をまたいでいる(西 > 東)。施設の検索は行わない
  crossesAntimeridian,
}

/// 表示範囲から求めた、検索してよいかの判定と、外部へ送る丸めた箱。
///
/// [visible] と [center] は端末の中だけで使う。**外部へ送ってよいのは [requestBox] だけ**
/// (NFR-2)。[allowed] のとき [requestBox] は null ではない
class SearchArea {
  const SearchArea._({
    required this.visible,
    required this.center,
    required this.widthMeters,
    required this.rejection,
    required this.requestBox,
  });

  /// 許可された結果
  const SearchArea.allowed({
    required GeoBounds visible,
    required GeoPoint center,
    required double widthMeters,
    required GeoBounds requestBox,
  }) : this._(
          visible: visible,
          center: center,
          widthMeters: widthMeters,
          rejection: null,
          requestBox: requestBox,
        );

  /// 許可されなかった結果。[requestBox] は null
  const SearchArea.rejected({
    required GeoBounds visible,
    required GeoPoint center,
    required double widthMeters,
    required SearchRejection rejection,
  }) : this._(
          visible: visible,
          center: center,
          widthMeters: widthMeters,
          rejection: rejection,
          requestBox: null,
        );

  /// 地図の表示範囲(端末内だけ。外部へ送らない)
  final GeoBounds visible;

  /// 表示範囲の中心(端末内だけ。外部へ送らない)。[SearchRejection.invalid] のときは値を保証しない
  final GeoPoint center;

  /// 表示範囲の東西の幅(m)。中心緯度での値。[SearchRejection.invalid] のときは 0
  final double widthMeters;

  /// 拒否の理由。許可のときは null
  final SearchRejection? rejection;

  /// 外部へ送ってよい、丸めた箱。許可でなければ null
  final GeoBounds? requestBox;

  /// 検索してよいか
  bool get allowed => rejection == null;
}

/// 表示範囲から、検索してよいかと、外部へ送る丸めた箱を求める(純 Dart)
class SearchAreaPlanner {
  const SearchAreaPlanner();

  /// 幅の比較で許す、浮動小数点の誤差(m)。ちょうど上限の幅を許可として扱うための余裕
  static const double _widthEpsilonMeters = 1e-6;

  /// 赤道での 1 周(m)。箱のタイル階層の決定に使う
  static const double _equatorMeters = 40075016.686;

  /// 箱のタイル階層の上限
  static const int _maxZoom = 16;

  /// Web メルカトルの緯度の限界(度)
  static const double _maxMercatorLat = 85.05;

  /// [visible] を判定して [SearchArea] を返す。例外は投げない。
  ///
  /// - 非有限、南 >= 北、緯度が ±90 度の外、経度が ±180 度の外、幅ゼロ: [SearchRejection.invalid]
  /// - 西 > 東(180 度線をまたぐ): [SearchRejection.crossesAntimeridian]
  /// - 幅が [GameConfig.searchMaxWidthMeters] を超える: [SearchRejection.tooWide]
  ///   (ちょうど上限は許可。浮動小数点の誤差は 1e-6m まで許す)
  ///
  /// 許可のときの箱は、表示範囲の南西・北東の角を含む階層 z のタイルの外周。箱の東西は、
  /// 表示範囲が小さくても 2km 以上になる。緯度が ±85.05 度を超える部分は、タイルの限界で
  /// 箱が表示範囲を含まない(落ちない)
  SearchArea plan(GeoBounds visible) {
    final values = [visible.south, visible.west, visible.north, visible.east];
    final center = GeoPoint(
      (visible.south + visible.north) / 2,
      (visible.west + visible.east) / 2,
    );

    if (values.any((v) => !v.isFinite) ||
        visible.south >= visible.north ||
        visible.south < -90 ||
        visible.north > 90 ||
        visible.west < -180 ||
        visible.east > 180 ||
        visible.west == visible.east) {
      return SearchArea.rejected(
        visible: visible,
        center: center,
        widthMeters: 0,
        rejection: SearchRejection.invalid,
      );
    }

    if (visible.west > visible.east) {
      // 180 度線をまたぐ表示範囲の幅は、東に 360 度足して数える
      final unwrapped = GeoBounds(visible.south, visible.west, visible.north, visible.east + 360);
      return SearchArea.rejected(
        visible: visible,
        center: center,
        widthMeters: widthMetersOf(unwrapped),
        rejection: SearchRejection.crossesAntimeridian,
      );
    }

    final width = widthMetersOf(visible);
    if (width > GameConfig.searchMaxWidthMeters + _widthEpsilonMeters) {
      return SearchArea.rejected(
        visible: visible,
        center: center,
        widthMeters: width,
        rejection: SearchRejection.tooWide,
      );
    }

    return SearchArea.allowed(
      visible: visible,
      center: center,
      widthMeters: width,
      requestBox: _tileBox(visible, width, center),
    );
  }

  /// 地点(地名・広域の地点)の検索に送る、丸めた箱を返す。箱を送らない(全体から探す)ときは null。
  /// 例外は投げない。
  ///
  /// - 非有限、南 >= 北、緯度が ±90 度の外、経度が ±180 度の外、幅ゼロ: null
  /// - 西 > 東(180 度線をまたぐ): null
  /// - 幅が [GameConfig.worldScopeMeters] 以上(世界全図): null
  ///
  /// それ以外は [plan] と同じ丸め方(表示範囲の南西・北東の角を含むタイルの外周。階層は 0〜16)の箱。
  /// 施設の検索と違い、幅の上限([GameConfig.searchMaxWidthMeters])では拒否しない。
  /// 緯度が ±85.05 度を超える部分は、タイルの限界で箱が表示範囲を含まない(落ちない)
  GeoBounds? planPlaceBox(GeoBounds visible) {
    final values = [visible.south, visible.west, visible.north, visible.east];
    if (values.any((v) => !v.isFinite) ||
        visible.south >= visible.north ||
        visible.south < -90 ||
        visible.north > 90 ||
        visible.west < -180 ||
        visible.east > 180 ||
        visible.west >= visible.east) {
      return null;
    }
    final width = widthMetersOf(visible);
    if (!width.isFinite || width >= GameConfig.worldScopeMeters - _widthEpsilonMeters) return null;
    final center = GeoPoint(
      (visible.south + visible.north) / 2,
      (visible.west + visible.east) / 2,
    );
    return _tileBox(visible, width, center);
  }

  /// 表示範囲 [visible](値は検証済み、西 < 東)を含む、階層 z のタイルの外周の箱。
  /// z は、幅 max([width], [GameConfig.searchBoxMinMeters]) の半分以上のタイル幅になる最大の階層(0〜16)
  static GeoBounds _tileBox(GeoBounds visible, double width, GeoPoint center) {
    final w = math.max(width, GameConfig.searchBoxMinMeters);
    final target = w / 2;
    final lat = center.lat.clamp(-_maxMercatorLat, _maxMercatorLat).toDouble();
    final cosLat = math.cos(lat * math.pi / 180);
    final z = (math.log(_equatorMeters * cosLat / target) / math.ln2)
        .floor()
        .clamp(0, _maxZoom);

    final kSW = CellKey.fromPoint(GeoPoint(visible.south, visible.west), z);
    final kNE = CellKey.fromPoint(GeoPoint(visible.north, visible.east), z);
    return GeoBounds(
      kSW.bounds.south,
      kSW.bounds.west,
      kNE.bounds.north,
      kNE.bounds.east,
    );
  }

  /// 矩形の東西の幅(m)。`(東 - 西) × metersPerDegree × cos(中心緯度)`。
  /// 値の検証はしない(不正な入力では NaN や負の値になり得る)
  static double widthMetersOf(GeoBounds b) {
    final centerLat = (b.south + b.north) / 2;
    return (b.east - b.west) * metersPerDegree * math.cos(centerLat * math.pi / 180);
  }
}
