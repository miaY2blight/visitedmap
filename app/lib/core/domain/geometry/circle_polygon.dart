import 'dart:math' as math;

import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 中心 [center]・半径 [radiusMeters] の円に近い多角形を、反時計回りの [segments] 個の頂点で返す
/// (閉じ点なし)。確認用の表示とテスト用。緯度経度を等距円筒の近似で換算する。
///
/// 180 度線の近くでは、経度を 180 度の外へ連続させた値(180 超または -180 未満)になる。
///
/// 中心が非有限・範囲外・極付近(緯度の絶対値 89 度以上)、半径が 0 以下、
/// [segments] が 3 未満なら [ArgumentError]
List<GeoPoint> circlePolygon(GeoPoint center, int radiusMeters, {int segments = 48}) {
  if (!center.lat.isFinite ||
      !center.lon.isFinite ||
      center.lat.abs() >= 89 ||
      center.lon.abs() > 180) {
    throw ArgumentError('中心の座標が不正です: $center');
  }
  if (radiusMeters <= 0) throw ArgumentError('半径は 1m 以上が必要です: $radiusMeters');
  if (segments < 3) throw ArgumentError('頂点数は 3 以上が必要です: $segments');
  final metersPerLon = metersPerDegree * math.cos(center.lat * math.pi / 180);
  return [
    for (var i = 0; i < segments; i++)
      GeoPoint(
        center.lat + radiusMeters * math.sin(2 * math.pi * i / segments) / metersPerDegree,
        center.lon + radiusMeters * math.cos(2 * math.pi * i / segments) / metersPerLon,
      ),
  ];
}
