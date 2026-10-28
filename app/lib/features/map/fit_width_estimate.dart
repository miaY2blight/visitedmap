import 'dart:math' as math;

import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 地図のタイルの大きさ(論理ピクセル)。MapLibre は、ズーム 0 で世界全体を 512 × 512 に描く
const double _tileSize = 512;

/// Web メルカトルで表せる緯度の上限
const double _maxMercatorLat = 85.051128779806604;

/// `newLatLngBounds`(余白 [padding] つき)で範囲 [bounds] へ寄せたあと、画面 [screenWidth] × [screenHeight]
/// (論理ピクセル)に見える範囲の東西の幅(m)を見積もる。
///
/// MapLibre の計算(範囲の 4 隅をメルカトルに投影し、余白を除いた枠に収まる小さい方のズームを採る。
/// 範囲の中心を、余白を除いた枠の中心に置く。地図の上下が世界の外に出るときは内側へずらす)をまねる。
/// 幅は、見える範囲の中心緯度での `経度の幅 × metersPerDegree × cos(中心緯度)` で、
/// 画面の幅の判断(`SearchAreaPlanner.widthMetersOf`)と同じ数え方。経度の幅は 360 度で頭打ちにする。
///
/// [bounds] は西 <= 東(180 度線をまたがない)で、南 < 北を前提にする。前提を外れたり、余白で枠が
/// なくなったりするときは NaN を返す。例外は投げない
double estimateFitWidthMeters(
  GeoBounds bounds, {
  required double screenWidth,
  required double screenHeight,
  double padLeft = 0,
  double padTop = 0,
  double padRight = 0,
  double padBottom = 0,
}) {
  final values = [bounds.south, bounds.west, bounds.north, bounds.east, screenWidth, screenHeight];
  if (values.any((v) => !v.isFinite)) return double.nan;
  if (bounds.west > bounds.east || bounds.south >= bounds.north) return double.nan;
  final frameW = screenWidth - padLeft - padRight;
  final frameH = screenHeight - padTop - padBottom;
  if (frameW <= 0 || frameH <= 0) return double.nan;

  // ズーム 0 の世界(0〜1)での範囲の大きさ
  final dx = (bounds.east - bounds.west) / 360;
  final yNorth = _mercatorY(bounds.north);
  final ySouth = _mercatorY(bounds.south);
  final dy = ySouth - yNorth;
  final scaleX = dx > 0 ? frameW / (dx * _tileSize) : double.infinity;
  final scaleY = dy > 0 ? frameH / (dy * _tileSize) : double.infinity;
  final scale = math.min(scaleX, scaleY);
  if (!scale.isFinite || scale <= 0) return double.nan;
  final worldPx = _tileSize * scale;

  // 範囲の中心(メルカトル)を、余白を除いた枠の中心に置いたときの、画面の上端と下端の y(世界 0〜1)
  final centerY = (yNorth + ySouth) / 2;
  final frameCenterFromTop = padTop + frameH / 2;
  var topY = centerY - frameCenterFromTop / worldPx;
  var bottomY = topY + screenHeight / worldPx;
  // 世界の外(極の向こう)が見えないよう、内側へずらす(世界より画面が高いときは中央に置く)
  final viewH = bottomY - topY;
  if (viewH >= 1) {
    topY = 0.5 - viewH / 2;
    bottomY = 0.5 + viewH / 2;
  } else if (topY < 0) {
    topY = 0;
    bottomY = viewH;
  } else if (bottomY > 1) {
    bottomY = 1;
    topY = 1 - viewH;
  }
  final northLat = _latOfY(topY.clamp(0, 1).toDouble());
  final southLat = _latOfY(bottomY.clamp(0, 1).toDouble());
  final centerLat = (northLat + southLat) / 2;

  final lonSpan = math.min(360.0, screenWidth / worldPx * 360);
  return lonSpan * metersPerDegree * math.cos(centerLat * math.pi / 180);
}

/// 緯度を、ズーム 0 の世界の y(北端 0、南端 1)にする
double _mercatorY(double lat) {
  final l = lat.clamp(-_maxMercatorLat, _maxMercatorLat) * math.pi / 180;
  return 0.5 - math.log(math.tan(math.pi / 4 + l / 2)) / (2 * math.pi);
}

/// ズーム 0 の世界の y を緯度にする
double _latOfY(double y) {
  final n = math.pi * (1 - 2 * y);
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}
