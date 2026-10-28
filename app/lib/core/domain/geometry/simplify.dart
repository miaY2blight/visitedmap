import 'dart:math' as math;

import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 閉じていないリング [ring] を、Douglas-Peucker 法で簡略化する。
/// 距離は、経度を x、緯度を y とした平面での距離(度)で測る。
///
/// 結果は 3 点以上になる(元が 3 点未満ならそのまま返す)。
/// 3 点以上のリングが、許容値が大きくても退化しないよう、最も離れた 2 点と、
/// その線から最も離れた点は必ず残す。
///
/// [toleranceDegrees] が負または非有限なら [ArgumentError]
List<GeoPoint> simplifyRing(List<GeoPoint> ring, double toleranceDegrees) {
  if (!toleranceDegrees.isFinite || toleranceDegrees < 0) {
    throw ArgumentError('許容値は 0 以上の有限の数である必要があります: $toleranceDegrees');
  }
  final n = ring.length;
  if (n <= 3) return List<GeoPoint>.of(ring);

  // 先頭の点から最も遠い点 f で、リングを 2 本の線(0..f と f..n-1,0)に分ける
  var f = 1;
  var farthest = -1.0;
  for (var i = 1; i < n; i++) {
    final d = _distanceSquared(ring[0], ring[i]);
    if (d > farthest) {
      farthest = d;
      f = i;
    }
  }
  if (farthest <= 0) return ring.sublist(0, 3); // すべて同じ点

  final keep = List<bool>.filled(n, false);
  keep[0] = true;
  keep[f] = true;
  _markChain(ring, [for (var i = 0; i <= f; i++) i], toleranceDegrees, keep);
  _markChain(ring, [for (var i = f; i < n; i++) i, 0], toleranceDegrees, keep);

  // 3 点未満なら、線 0-f から最も離れた点を足す
  if (keep.where((k) => k).length < 3) {
    var best = -1;
    var bestDistance = -1.0;
    for (var i = 1; i < n; i++) {
      if (keep[i]) continue;
      final d = _distanceToSegment(ring[i], ring[0], ring[f]);
      if (d > bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    keep[best] = true;
  }
  return [for (var i = 0; i < n; i++) if (keep[i]) ring[i]];
}

/// 閉じていないリング [ring] を、頂点数が [maxVertices] 以下になるまで簡略化する。
/// 許容値を小さい値から倍々にして、上限以下になる最初の結果を返す。
/// すでに上限以下ならそのまま返す。
///
/// [maxVertices] が 3 未満なら [ArgumentError]
List<GeoPoint> simplifyToLimit(List<GeoPoint> ring, int maxVertices) {
  if (maxVertices < 3) {
    throw ArgumentError('頂点数の上限は 3 以上が必要です: $maxVertices');
  }
  if (ring.length <= maxVertices) return ring;
  final b = ringBounds(ring);
  final extent = math.max(b.north - b.south, b.east - b.west);
  if (extent <= 0) return ring.sublist(0, 3);

  // 外接矩形の大きさの 100 万分の 1 から始める。倍々にして、矩形の大きさの 2 倍に達すれば、
  // 必ず 3 点まで減るので、そこで必ず終わる
  var tolerance = extent * 1e-6;
  var result = ring;
  while (result.length > maxVertices && tolerance <= extent * 2) {
    result = simplifyRing(ring, tolerance);
    tolerance *= 2;
  }
  return result;
}

/// [order] の順に並べた [ring] の添字を 1 本の線とみなし、Douglas-Peucker 法で残す点に印を付ける。
/// 線の両端は、呼び出し側が印を付ける。再帰を使わない(頂点が多くても深くならない)
void _markChain(List<GeoPoint> ring, List<int> order, double tolerance, List<bool> keep) {
  final stack = <(int, int)>[(0, order.length - 1)];
  while (stack.isNotEmpty) {
    final (lo, hi) = stack.removeLast();
    if (hi - lo < 2) continue;
    final a = ring[order[lo]];
    final b = ring[order[hi]];
    var maxDistance = -1.0;
    var maxAt = -1;
    for (var i = lo + 1; i < hi; i++) {
      final d = _distanceToSegment(ring[order[i]], a, b);
      if (d > maxDistance) {
        maxDistance = d;
        maxAt = i;
      }
    }
    if (maxDistance > tolerance) {
      keep[order[maxAt]] = true;
      stack.add((lo, maxAt));
      stack.add((maxAt, hi));
    }
  }
}

double _distanceSquared(GeoPoint a, GeoPoint b) {
  final dx = a.lon - b.lon;
  final dy = a.lat - b.lat;
  return dx * dx + dy * dy;
}

/// 点 [p] から線分 a-b までの距離(度)
double _distanceToSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
  final dx = b.lon - a.lon;
  final dy = b.lat - a.lat;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return math.sqrt(_distanceSquared(p, a));
  final t = (((p.lon - a.lon) * dx + (p.lat - a.lat) * dy) / lengthSquared).clamp(0.0, 1.0);
  final cx = a.lon + t * dx;
  final cy = a.lat + t * dy;
  final ex = p.lon - cx;
  final ey = p.lat - cy;
  return math.sqrt(ex * ex + ey * ey);
}
