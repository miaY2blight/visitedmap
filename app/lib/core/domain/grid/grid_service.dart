import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 形 → セルの被覆と、塗り割合の計算(基本設計 §3.4)。
///
/// 被覆の規約: 互いに重ならない(祖先と子孫の組がない)。`(z, x, y)` の昇順に並べる。
class GridService {
  const GridService();

  /// 開始階層で数えるセルの上限。超える形は [ArgumentError]
  static const int maxStartCells = 5000;

  /// 被覆のセル数の上限(メモリを使い尽くさないための安全弁)。超える形は [ArgumentError]
  static const int maxCoverCells = 1000000;

  /// 分類のためにたどるセル数の上限(計算時間の安全弁。捨てたセルも数える)。超える形は [ArgumentError]。
  /// 周長がとても長い形(細い櫛形など)が、長時間止まらないようにする
  static const int maxVisitedCells = 2000000;

  /// 円の半径の上限(m)
  static const double maxRadiusMeters = 50000;

  static const int _circleVertices = 64;

  /// 点を含む z19 のセル1つ
  List<CellKey> coverPoint(GeoPoint p) => [CellKey.fromPoint(p, storageZoom)];

  /// 中心と半径(0 < r <= 50000)の円。結果に中心の z19 セルを必ず含める。範囲外は [ArgumentError]
  List<CellKey> coverCircle(GeoPoint center, double radiusMeters) {
    if (!radiusMeters.isFinite || radiusMeters <= 0 || radiusMeters > maxRadiusMeters) {
      throw ArgumentError.value(radiusMeters, 'radiusMeters', '0 より大きく $maxRadiusMeters 以下');
    }
    final centerCell = CellKey.fromPoint(center, storageZoom);
    final cosLat = math.cos(center.lat * math.pi / 180);
    final ring = <GeoPoint>[
      for (var i = 0; i < _circleVertices; i++)
        GeoPoint(
          center.lat + radiusMeters * math.sin(2 * math.pi * i / _circleVertices) / metersPerDegree,
          _wrapLon(center.lon +
              radiusMeters * math.cos(2 * math.pi * i / _circleVertices) / (metersPerDegree * cosLat)),
        ),
    ];
    final cover = coverPolygon(ring);
    if (cover.any((c) => c.contains(centerCell))) return cover;
    return [...cover, centerCell]..sort(_compare);
  }

  /// 外周リングの内側を、大小のセルで覆う。穴は扱わない。
  ///
  /// 開始階層 [startZoom] のセルを、外側は捨て、内側はそのセルのまま採用し、
  /// 外周と交わる(境界の)セルは4分割して、[boundaryZoom] まで繰り返す。
  /// [boundaryZoom] に達したセルは、中心が内側なら採用する。結果が空なら、頂点の平均点の z19 セルを1つ返す。
  /// 不正なリング、開始階層のセルが [maxStartCells] を超える形、階層の指定ミス、
  /// 被覆のセル数が [maxCoverCells] を超える形、たどるセル数が [maxVisitedCells] を超える形は [ArgumentError]
  /// (2つの上限は、テストで確かめやすいよう引数で変えられる)
  List<CellKey> coverPolygon(
    List<GeoPoint> outerRing, {
    int startZoom = 10,
    int boundaryZoom = storageZoom,
    int maxCoverCells = GridService.maxCoverCells,
    int maxVisitedCells = GridService.maxVisitedCells,
  }) {
    if (startZoom < 0 || boundaryZoom > storageZoom || startZoom > boundaryZoom) {
      throw ArgumentError('階層の指定が不正です: startZoom=$startZoom, boundaryZoom=$boundaryZoom');
    }
    // 180 度線をまたぐ形は、経度が 180 を超える値に連続させて返ってくる。
    // 計算は連続させた座標で行い、セルは列番号を折り返して(x mod 2^z)返す
    final ring = normalizeRing(outerRing);
    final b = ringBounds(ring);
    final n = 1 << startZoom;
    final yTop = CellKey.fromPoint(GeoPoint(b.north, 0), startZoom).y;
    final yBottom = CellKey.fromPoint(GeoPoint(b.south, 0), startZoom).y;
    final xMin = math.min(((b.west + 180) / 360 * n).floor(), n - 1);
    var xMax = ((b.east + 180) / 360 * n).floor();
    if (b.east <= 180) xMax = math.min(xMax, n - 1); // 東端が 180 ちょうどの形は、最東のセルまで
    if (xMax - xMin + 1 > n) {
      throw ArgumentError('180 度線をまたぐ形には、startZoom が小さすぎます(z$startZoom)');
    }
    final rootCount = (xMax - xMin + 1) * (yBottom - yTop + 1);
    if (rootCount > maxStartCells) {
      throw ArgumentError('開始階層(z$startZoom)のセルが $rootCount 個あり、上限 $maxStartCells を超えます。startZoom を下げてください');
    }

    final edges = _Edges(ring);
    final index = _RingIndex(ring);
    final allEdges = List<int>.generate(ring.length, (i) => i);
    final result = <CellKey>[];
    // (セル, 連続させた座標での周回数, 交わる辺の候補)。周回数は、子に引き継ぐ
    final stack = <(CellKey, int, List<int>)>[];
    for (var xv = xMin; xv <= xMax; xv++) {
      final turns = xv ~/ n;
      for (var y = yTop; y <= yBottom; y++) {
        stack.add((CellKey(startZoom, xv - turns * n, y), turns, allEdges));
      }
    }

    var visited = 0;
    while (stack.isNotEmpty) {
      if (++visited > maxVisitedCells) {
        throw ArgumentError('形が複雑すぎます(分類するセルが上限 $maxVisitedCells を超えました)。周長が長い形は扱えません');
      }
      final (cell, turns, candidates) = stack.removeLast();
      final shift = 360.0 * turns;
      final raw = cell.bounds;
      final cb = GeoBounds(raw.south, raw.west + shift, raw.north, raw.east + shift);
      final hit = edges.intersecting(candidates, cb);
      if (hit.isEmpty || cell.z >= boundaryZoom) {
        // 外周が通らないセルは全体が同じ側。境界の最小セルは、中心で決める
        final c = cell.center;
        if (index.contains(GeoPoint(c.lat, c.lon + shift))) {
          result.add(cell);
          if (result.length > maxCoverCells) {
            throw ArgumentError('被覆のセルが上限 $maxCoverCells を超えます。形が大きすぎるか、boundaryZoom が深すぎます');
          }
        }
        continue;
      }
      for (final child in cell.children) {
        stack.add((child, turns, hit));
      }
    }

    if (result.isEmpty) {
      var lat = 0.0, lon = 0.0;
      for (final p in ring) {
        lat += p.lat;
        lon += p.lon;
      }
      return coverPoint(GeoPoint(lat / ring.length, _wrapLon(lon / ring.length)));
    }
    result.sort(_compare);
    return result;
  }

  /// 重なりを除いた z19 換算のセル数
  int countZ19(Iterable<CellKey> cover) {
    final set = cover.toSet();
    var total = 0;
    for (final c in set) {
      if (!_hasAncestorIn(c, set, 0)) total += c.z19Count;
    }
    return total;
  }

  /// 判定マス [judgeCell] のうち、[cover] が覆う z19 セルの割合(0.0〜1.0)。
  /// [cover] に [judgeCell] の祖先(または自身)が含まれれば 1.0。重なりは1回と数える
  double paintedFraction(CellKey judgeCell, Iterable<CellKey> cover) {
    final inside = <CellKey>{};
    for (final c in cover) {
      if (c.contains(judgeCell)) return 1.0;
      if (judgeCell.contains(c)) inside.add(c);
    }
    var total = 0;
    for (final c in inside) {
      if (!_hasAncestorIn(c, inside, judgeCell.z)) total += c.z19Count;
    }
    return math.min(1.0, total / judgeCell.z19Count);
  }

  /// 経度を -180〜180 に折り返す(180 は 180 のまま)。範囲外の入力はそのまま返し、後段で拒否させる
  static double _wrapLon(double lon) {
    if (!lon.isFinite || lon.abs() > 540) return lon;
    if (lon > 180) return lon - 360;
    if (lon < -180) return lon + 360;
    return lon;
  }

  /// [c] の真の祖先(階層 [minZoom] 以上)が [set] にあれば true
  static bool _hasAncestorIn(CellKey c, Set<CellKey> set, int minZoom) {
    for (var z = c.z - 1; z >= minZoom; z--) {
      if (set.contains(c.ancestorAt(z))) return true;
    }
    return false;
  }

  static int _compare(CellKey a, CellKey b) {
    if (a.z != b.z) return a.z.compareTo(b.z);
    if (a.x != b.x) return a.x.compareTo(b.x);
    return a.y.compareTo(b.y);
  }
}

/// リングの辺(i 番目は、頂点 i から i+1。最後は先頭へ戻る)と、セルの矩形との交差判定
class _Edges {
  _Edges(List<GeoPoint> ring)
      : _lat = Float64List(ring.length),
        _lon = Float64List(ring.length) {
    for (var i = 0; i < ring.length; i++) {
      _lat[i] = ring[i].lat;
      _lon[i] = ring[i].lon;
    }
  }

  final Float64List _lat;
  final Float64List _lon;

  /// [candidates] のうち、矩形 [r](境界を含む)と交わる辺
  List<int> intersecting(List<int> candidates, GeoBounds r) {
    final n = _lat.length;
    final hit = <int>[];
    for (final i in candidates) {
      final j = i + 1 == n ? 0 : i + 1;
      if (_segmentIntersectsRect(_lon[i], _lat[i], _lon[j], _lat[j], r.west, r.south, r.east, r.north)) {
        hit.add(i);
      }
    }
    return hit;
  }

  /// 線分と矩形(閉じた範囲)が交わるか。スラブ法
  static bool _segmentIntersectsRect(
    double x0,
    double y0,
    double x1,
    double y1,
    double xmin,
    double ymin,
    double xmax,
    double ymax,
  ) {
    var t0 = 0.0, t1 = 1.0;
    final dx = x1 - x0, dy = y1 - y0;
    if (dx == 0) {
      if (x0 < xmin || x0 > xmax) return false;
    } else {
      var ta = (xmin - x0) / dx, tb = (xmax - x0) / dx;
      if (ta > tb) {
        final t = ta;
        ta = tb;
        tb = t;
      }
      t0 = math.max(t0, ta);
      t1 = math.min(t1, tb);
      if (t0 > t1) return false;
    }
    if (dy == 0) {
      if (y0 < ymin || y0 > ymax) return false;
    } else {
      var ta = (ymin - y0) / dy, tb = (ymax - y0) / dy;
      if (ta > tb) {
        final t = ta;
        ta = tb;
        tb = t;
      }
      t0 = math.max(t0, ta);
      t1 = math.min(t1, tb);
      if (t0 > t1) return false;
    }
    return true;
  }
}

/// 緯度の帯ごとに辺を分けた、内外判定の索引。`pointInRing` と同じ偶奇規則で、
/// 点の緯度をまたぐ辺だけを調べる(頂点の多いリングでも 1 回の判定が軽い)
class _RingIndex {
  _RingIndex(List<GeoPoint> ring) {
    final n = ring.length;
    _lat = Float64List(n);
    _lon = Float64List(n);
    var south = double.infinity, north = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      _lat[i] = ring[i].lat;
      _lon[i] = ring[i].lon;
      south = math.min(south, _lat[i]);
      north = math.max(north, _lat[i]);
    }
    _south = south;
    _north = north;
    _bandCount = math.max(1, math.min(1024, n ~/ 4));
    _bands = List.generate(_bandCount, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      final j = i + 1 == n ? 0 : i + 1;
      if (_lat[i] == _lat[j]) continue; // 水平な辺は、交差の判定に関わらない
      final lo = _bandOf(math.min(_lat[i], _lat[j]));
      final hi = _bandOf(math.max(_lat[i], _lat[j]));
      for (var k = lo; k <= hi; k++) {
        _bands[k].add(i);
      }
    }
  }

  late final Float64List _lat;
  late final Float64List _lon;
  late final double _south;
  late final double _north;
  late final int _bandCount;
  late final List<List<int>> _bands;

  int _bandOf(double lat) =>
      ((lat - _south) / (_north - _south) * _bandCount).floor().clamp(0, _bandCount - 1);

  bool contains(GeoPoint p) {
    if (p.lat < _south || p.lat > _north) return false;
    final n = _lat.length;
    var inside = false;
    for (final i in _bands[_bandOf(p.lat)]) {
      final j = i + 1 == n ? 0 : i + 1;
      final aLat = _lat[i], bLat = _lat[j];
      if ((aLat > p.lat) != (bLat > p.lat) &&
          p.lon < (_lon[j] - _lon[i]) * (p.lat - aLat) / (bLat - aLat) + _lon[i]) {
        inside = !inside;
      }
    }
    return inside;
  }
}
