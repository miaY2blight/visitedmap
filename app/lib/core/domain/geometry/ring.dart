import 'dart:math' as math;

import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 緯度 1 度あたりのメートル(平面近似用)
const double metersPerDegree = 111320;

/// 点 [p] がリングの内側なら true(偶奇規則。経度を x、緯度を y とした平面で判定する)。
/// リングは閉じていても、いなくてもよい。境界上の点は、どちらになるか決めていない
bool pointInRing(GeoPoint p, List<GeoPoint> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.lat > p.lat) != (b.lat > p.lat) &&
        p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon) {
      inside = !inside;
    }
  }
  return inside;
}

/// リングの面積(m²、符号なし)。緯度の中央で経度方向を補正する等距円筒の近似
double ringAreaSquareMeters(List<GeoPoint> ring) {
  if (ring.length < 3) return 0;
  final bounds = ringBounds(ring);
  final scaleX = metersPerDegree * math.cos((bounds.south + bounds.north) / 2 * math.pi / 180);
  var twiceArea = 0.0;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[j];
    final b = ring[i];
    twiceArea += (a.lon * scaleX) * (b.lat * metersPerDegree) -
        (b.lon * scaleX) * (a.lat * metersPerDegree);
  }
  return twiceArea.abs() / 2;
}

/// リングの外接矩形。空なら [ArgumentError]
GeoBounds ringBounds(List<GeoPoint> ring) {
  if (ring.isEmpty) throw ArgumentError('リングが空です');
  var south = ring.first.lat, north = ring.first.lat;
  var west = ring.first.lon, east = ring.first.lon;
  for (final p in ring) {
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
    west = math.min(west, p.lon);
    east = math.max(east, p.lon);
  }
  return GeoBounds(south, west, north, east);
}

/// 外周リングを検証し、末尾が先頭と同じ点なら取り除いて返す。
///
/// 経度が 180 度線をまたぐ形(例: 179.99 と -179.99 の頂点が混ざる形)は、
/// 負の経度に 360 を足して連続させた形で返す(経度が 180 を超える値になる)。
/// 連続させた幅が 180 度以内のときだけ、この形として扱う。
///
/// 頂点が3未満、NaN・無限大・範囲外の座標、面積ゼロ(一直線)、
/// 経度の幅が、連続させても180度を超える形は [ArgumentError]
List<GeoPoint> normalizeRing(List<GeoPoint> ring) {
  var points = List<GeoPoint>.of(ring);
  if (points.length > 1 && points.first == points.last) points.removeLast();
  if (points.length < 3) {
    throw ArgumentError('リングの頂点は3つ以上が必要です(${points.length}個)');
  }
  for (final p in points) {
    if (!p.lat.isFinite || !p.lon.isFinite || p.lat.abs() > 90 || p.lon.abs() > 180) {
      throw ArgumentError('リングに不正な座標があります: $p');
    }
  }
  var b = ringBounds(points);
  if (b.east - b.west > 180) {
    // 180 度線をまたぐ形かもしれない。負の経度に 360 を足して、幅が 180 度以内なら、その形とみなす
    final unwrapped = [for (final p in points) p.lon < 0 ? GeoPoint(p.lat, p.lon + 360) : p];
    final ub = ringBounds(unwrapped);
    if (ub.east - ub.west > 180) {
      throw ArgumentError('経度の幅が180度を超える形は扱えません');
    }
    points = unwrapped;
    b = ub;
  }
  // 一直線上の点は、浮動小数点の誤差で面積が極小の正になるため、外接矩形に対する比で判定する
  final boxArea = (b.north - b.south) *
      (b.east - b.west) *
      metersPerDegree *
      metersPerDegree *
      math.cos((b.south + b.north) / 2 * math.pi / 180);
  final area = ringAreaSquareMeters(points);
  if (boxArea <= 0 || area <= boxArea * 1e-9) {
    throw ArgumentError('面積がゼロの形は扱えません');
  }
  return points;
}
