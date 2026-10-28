import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// スポットの形。外部の地図データから得たポリゴン、または点+半径のどちらか
sealed class SpotShape {
  const SpotShape();
}

/// ポリゴンの形。外周のリングだけを持つ(穴は持たない = FR-1.4)。
///
/// 各リングは、閉じ点を持たない 3 点以上の列。ふつうは `normalizeRing` を通した値を渡す
/// (180 度線をまたぐ形は、経度が 180 を超える連続した値になっている)。
final class PolygonShape extends SpotShape {
  /// [outerRings] が空、リングが 3 点未満、非有限または範囲外(緯度は ±90、経度は -180〜360)の
  /// 座標を含むときは [ArgumentError]
  PolygonShape(List<List<GeoPoint>> outerRings)
      : outerRings = List.unmodifiable([
          for (final ring in outerRings) List<GeoPoint>.unmodifiable(ring),
        ]) {
    if (this.outerRings.isEmpty) throw ArgumentError('外周のリングがありません');
    for (final ring in this.outerRings) {
      if (ring.length < 3) {
        throw ArgumentError('リングの頂点は 3 つ以上が必要です(${ring.length}個)');
      }
      for (final p in ring) {
        if (!p.lat.isFinite || !p.lon.isFinite || p.lat.abs() > 90 || p.lon < -180 || p.lon > 360) {
          // メッセージに座標を含めない(NFR-2)
          throw ArgumentError('リングに不正な座標があります(非有限、または範囲外)');
        }
      }
    }
  }

  /// 外周のリング(閉じ点なし)
  final List<List<GeoPoint>> outerRings;
}

/// 点+半径の形(形が見つからないときの、地図に置いた場所)
final class PointRadiusShape extends SpotShape {
  /// 半径が [GameConfig.radiusMinMeters]〜[GameConfig.radiusMaxMeters](全体の上限)の外、
  /// または中心が非有限・範囲外なら [ArgumentError]。
  /// 大分類ごとの上限(`GameConfig.radiusMaxFor`)は、ここでは見ない(記録のときに確かめる)
  PointRadiusShape(this.center, this.radiusMeters) {
    if (!center.lat.isFinite || !center.lon.isFinite || center.lat.abs() > 90 || center.lon.abs() > 180) {
      // メッセージに座標を含めない(NFR-2)
      throw ArgumentError('中心の座標が不正です(非有限、または範囲外)');
    }
    if (radiusMeters < GameConfig.radiusMinMeters || radiusMeters > GameConfig.radiusMaxMeters) {
      throw ArgumentError(
        '半径は ${GameConfig.radiusMinMeters}〜${GameConfig.radiusMaxMeters}m の範囲が必要です',
      );
    }
  }

  final GeoPoint center;
  final int radiusMeters;
}
