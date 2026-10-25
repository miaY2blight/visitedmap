import 'dart:math' as math;

import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/grid/grid_service.dart';

/// 穴の作り方。[perCell] はセル1つ = 穴1つ、[rowMerged] は同じ階層・同じ行で隣り合うセルを横に結合する
enum HoleMode { perCell, rowMerged }

// 東京の範囲
const double _latMin = 35.55, _latMax = 35.85;
const double _lonMin = 139.55, _lonMax = 139.95;

/// 霧の穴(長方形。閉じていない4点のリング)の合成データ。使い捨ての検証用。
///
/// 東京の範囲に、半径 150〜600m の円の被覆(z17〜z19 が中心)を足していき、
/// 穴の数がちょうど [targetHoles] になったところで止める([rowMerged] は結合後なので、それより少ない)。
/// 穴同士は重ならない。同じ [seed] なら同じ結果
List<List<GeoPoint>> buildHoles({
  required int targetHoles,
  required int seed,
  HoleMode mode = HoleMode.perCell,
}) {
  if (targetHoles <= 0) {
    throw ArgumentError.value(targetHoles, 'targetHoles', '1 以上');
  }
  const grid = GridService();
  final random = math.Random(seed);
  final accepted = <CellKey>[];
  final acceptedSet = <CellKey>{};
  // 採用したセルの祖先(自分を含まない)。新しいセルがこれに入っていれば、子孫を採用済みで重なる
  final ancestorsOfAccepted = <CellKey>{};

  bool overlaps(CellKey c) {
    if (ancestorsOfAccepted.contains(c)) return true;
    for (var z = c.z; z >= 0; z--) {
      if (acceptedSet.contains(c.ancestorAt(z))) return true;
    }
    return false;
  }

  // 円が重なると採用できるセルが減るため、無限に回らないよう上限を置く
  final maxCircles = targetHoles * 2 + 100;
  for (var i = 0; i < maxCircles && accepted.length < targetHoles; i++) {
    final center = GeoPoint(
      _latMin + random.nextDouble() * (_latMax - _latMin),
      _lonMin + random.nextDouble() * (_lonMax - _lonMin),
    );
    final radius = 150 + random.nextDouble() * 450;
    for (final cell in grid.coverCircle(center, radius)) {
      if (accepted.length >= targetHoles) break;
      if (overlaps(cell)) continue;
      accepted.add(cell);
      acceptedSet.add(cell);
      for (var z = cell.z - 1; z >= 0; z--) {
        ancestorsOfAccepted.add(cell.ancestorAt(z));
      }
    }
  }
  if (accepted.length < targetHoles) {
    throw StateError('穴を $targetHoles 個まで作れませんでした(${accepted.length} 個)');
  }

  if (mode == HoleMode.perCell) {
    return [for (final c in accepted) _rect(c.bounds)];
  }

  // 同じ階層・同じ行で、列が連続するセルを1つの長方形にする
  final byRow = <(int, int), List<int>>{};
  for (final c in accepted) {
    byRow.putIfAbsent((c.z, c.y), () => []).add(c.x);
  }
  final keys = byRow.keys.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final merged = <List<GeoPoint>>[];
  for (final key in keys) {
    final xs = byRow[key]!..sort();
    var start = xs.first, prev = xs.first;
    void flush() {
      final west = CellKey(key.$1, start, key.$2).bounds;
      final east = CellKey(key.$1, prev, key.$2).bounds;
      merged.add(_rect(GeoBounds(west.south, west.west, west.north, east.east)));
    }

    for (final x in xs.skip(1)) {
      if (x == prev + 1) {
        prev = x;
      } else {
        flush();
        start = prev = x;
      }
    }
    flush();
  }
  return merged;
}

// 大きな形の格子(経緯度 14 度間隔)。緯度 ±63、経度 ±161 までの中心を、符号対称に並べる
const double _gridStep = 14;
final List<GeoPoint> _regionGrid = [
  for (var i = 0; i < 10; i++)
    for (var j = 0; j < 24; j++)
      GeoPoint(-63 + i * _gridStep, -161 + j * _gridStep),
];
const int _minRegionVertices = 8;
const double _radiusMinDeg = 1, _radiusMaxDeg = 6, _wobble = 0.35;
const int _maxHarmonics = 48;

/// 海外のチェックインで塗る、国・州規模の形を模した穴(閉じたリング)。使い捨ての検証用。
///
/// 経緯度 14 度間隔の格子点(最大 240。種から [regions] 個を選ぶ)ごとに、中心から見て半径が角度の関数になる
/// 星型の不規則な形を1つずつ置く。半径(ゆらぎを含む最大の広がり)は 1〜6 度で、ゆらぎは ±35%。
/// 頂点は [totalVertices] を均等に配る(1個あたり 8 以上)。星型なので自己交差せず、
/// 格子の間隔(14 度)が広がりの2倍(12 度)より大きいので、形どうしは重ならない。同じ [seed] なら同じ結果
List<List<GeoPoint>> buildRegionHoles({
  required int regions,
  required int totalVertices,
  required int seed,
}) {
  if (regions <= 0 || regions > _regionGrid.length) {
    throw ArgumentError.value(regions, 'regions', '1〜${_regionGrid.length}');
  }
  if (totalVertices < regions * _minRegionVertices) {
    throw ArgumentError.value(
      totalVertices,
      'totalVertices',
      'regions×$_minRegionVertices(${regions * _minRegionVertices})以上',
    );
  }
  final random = math.Random(seed);
  final centers = List<GeoPoint>.of(_regionGrid)..shuffle(random);
  final base = totalVertices ~/ regions;
  final extra = totalVertices - base * regions;
  final rings = <List<GeoPoint>>[];
  for (var i = 0; i < regions; i++) {
    final n = base + (i < extra ? 1 : 0);
    final reach = _radiusMinDeg + random.nextDouble() * (_radiusMaxDeg - _radiusMinDeg);
    final baseRadius = reach / (1 + _wobble);
    // 角度の関数: 低い次数から高い次数の正弦波を、振幅を減らしながら足す
    final harmonics = math.min(_maxHarmonics, n ~/ 4);
    final amp = [for (var k = 1; k <= harmonics; k++) random.nextDouble() / math.pow(k, 1.2)];
    final phase = [for (var k = 1; k <= harmonics; k++) random.nextDouble() * 2 * math.pi];
    final f = List<double>.filled(n, 0);
    var maxAbs = 1e-9;
    for (var v = 0; v < n; v++) {
      final theta = 2 * math.pi * v / n;
      var s = 0.0;
      for (var k = 1; k <= harmonics; k++) {
        s += amp[k - 1] * math.sin(k * theta + phase[k - 1]);
      }
      f[v] = s;
      maxAbs = math.max(maxAbs, s.abs());
    }
    final c = centers[i];
    final ring = <GeoPoint>[
      for (var v = 0; v < n; v++)
        () {
          final theta = 2 * math.pi * v / n;
          final r = baseRadius * (1 + _wobble * f[v] / maxAbs);
          return GeoPoint(c.lat + r * math.sin(theta), c.lon + r * math.cos(theta));
        }(),
    ];
    ring.add(ring.first);
    rings.add(ring);
  }
  return rings;
}

/// 除外地域の斜線を載せる GeoJSON(地域ごとに Polygon の Feature を1つ)。リングは閉じた形に揃える
Map<String, dynamic> exclusionGeoJson(List<List<GeoPoint>> rings) {
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final ring in rings)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                for (final p in ring) [p.lon, p.lat],
                if (ring.first != ring.last) [ring.first.lon, ring.first.lat],
              ],
            ],
          },
        },
    ],
  };
}

List<GeoPoint> _rect(GeoBounds b) => [
      GeoPoint(b.south, b.west),
      GeoPoint(b.south, b.east),
      GeoPoint(b.north, b.east),
      GeoPoint(b.north, b.west),
    ];

/// 世界全体を覆う霧に [holes] の穴を開けた GeoJSON(FeatureCollection、Polygon 1つ。RFC 7946)。
/// 外側は反時計回り、穴は時計回りに揃え、すべて閉じたリングにする
Map<String, dynamic> fogGeoJson(List<List<GeoPoint>> holes) {
  List<List<double>> toCoords(List<GeoPoint> ring, {required bool counterClockwise}) {
    var points = ring;
    if (points.length > 1 && points.first == points.last) {
      points = points.sublist(0, points.length - 1);
    }
    var twice = 0.0;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      twice += points[j].lon * points[i].lat - points[i].lon * points[j].lat;
    }
    if ((twice > 0) != counterClockwise) points = points.reversed.toList();
    return [
      for (final p in points) [p.lon, p.lat],
      [points.first.lon, points.first.lat],
    ];
  }

  const outer = [
    GeoPoint(-85, -180),
    GeoPoint(-85, 180),
    GeoPoint(85, 180),
    GeoPoint(85, -180),
  ];
  return {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            toCoords(outer, counterClockwise: true),
            for (final h in holes) toCoords(h, counterClockwise: false),
          ],
        },
      },
    ],
  };
}
