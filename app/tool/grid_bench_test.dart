// ignore_for_file: avoid_print
//
// グリッド計算の性能計測(V-03、V-04 の簡易版)。
// `flutter test tool/grid_bench_test.dart` で単独に実行する。`test/` の外にあるため、通常の `flutter test` には含まれない。
// アサートは、異常値を検知するための緩い上限のみ。結果は `docs/handoff/step2_results.md` に記録する。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/grid/grid_service.dart';

const _tokyo = GeoPoint(35.681236, 139.767125);
const _grid = GridService();

GeoPoint _offset(GeoPoint c, double north, double east) => GeoPoint(
      c.lat + north / metersPerDegree,
      c.lon + east / (metersPerDegree * math.cos(c.lat * math.pi / 180)),
    );

List<GeoPoint> _square(GeoPoint c, double side) {
  final h = side / 2;
  return [_offset(c, -h, -h), _offset(c, -h, h), _offset(c, h, h), _offset(c, h, -h)];
}

/// 星型(中心から見て、半径が角度の関数)の不規則な形。単純な多角形になる。
/// 面積はおよそ [areaM2]。[wobble] は半径のゆらぎの大きさ(0〜1)、[jitter] は頂点ごとの細かいゆらぎ
List<GeoPoint> _blob(
  GeoPoint center,
  double areaM2,
  int vertices,
  math.Random rnd, {
  double wobble = 0.3,
  double jitter = 0.001,
}) {
  final phase = List.generate(4, (_) => rnd.nextDouble() * 2 * math.pi);
  final unit = List<double>.generate(vertices, (i) {
    final a = 2 * math.pi * i / vertices;
    final w = math.sin(2 * a + phase[0]) * 0.5 +
        math.sin(3 * a + phase[1]) * 0.3 +
        math.sin(5 * a + phase[2]) * 0.2 +
        math.sin(9 * a + phase[3]) * 0.1;
    return 1 + wobble * w + jitter * (rnd.nextDouble() * 2 - 1);
  });
  final meanSq = unit.map((u) => u * u).reduce((a, b) => a + b) / vertices;
  final scale = math.sqrt(areaM2 / (math.pi * meanSq));
  return [
    for (var i = 0; i < vertices; i++)
      _offset(
        center,
        unit[i] * scale * math.sin(2 * math.pi * i / vertices),
        unit[i] * scale * math.cos(2 * math.pi * i / vertices),
      ),
  ];
}

class _Row {
  _Row(this.name, this.vertices, this.areaKm2);
  final String name;
  final int vertices;
  final double areaKm2;
  int ms19 = 0, cells19 = 0, z19Count = 0, ms17 = 0, cells17 = 0;
}

_Row _measure(String name, List<GeoPoint> ring) {
  final row = _Row(name, ring.length, ringAreaSquareMeters(ring) / 1e6);
  var sw = Stopwatch()..start();
  final cover19 = _grid.coverPolygon(ring);
  sw.stop();
  row.ms19 = sw.elapsedMilliseconds;
  row.cells19 = cover19.length;
  row.z19Count = _grid.countZ19(cover19);
  sw = Stopwatch()..start();
  final cover17 = _grid.coverPolygon(ring, boundaryZoom: 17);
  sw.stop();
  row.ms17 = sw.elapsedMilliseconds;
  row.cells17 = cover17.length;
  return row;
}

void main() {
  test('V-03: 形 → セル変換', () {
    final rnd = math.Random(1);
    final rows = [
      _measure('店(30m 四方)', _square(_tokyo, 30)),
      _measure('公園(1km²・100頂点・凹み)', _blob(_tokyo, 1e6, 100, rnd, wobble: 0.4)),
      _measure('市区町村(300km²・1,500頂点)', _blob(_tokyo, 300e6, 1500, rnd)),
      _measure('国立公園(9,000km²・2,800頂点)', _blob(_tokyo, 9000e6, 2800, rnd)),
    ];
    print('\n=== V-03 形 → セル変換 ===');
    print('| 形 | 頂点 | 面積km² | z19まで(ms) | セル数 | z19換算 | z17まで(ms) | セル数 |');
    print('|---|---|---|---|---|---|---|---|');
    for (final r in rows) {
      print('| ${r.name} | ${r.vertices} | ${r.areaKm2.toStringAsFixed(1)} | ${r.ms19} | ${r.cells19} | '
          '${r.z19Count} | ${r.ms17} | ${r.cells17} |');
    }
    final park = rows.last;
    expect(park.ms19, lessThan(60000), reason: '国立公園規模が 60 秒以内(異常値の検知)');
    expect(park.cells19, lessThan(500000), reason: 'セル数が 50 万以内(異常値の検知)');
  });

  test('V-04 簡易版: 記録 1万件の導出データ(メモリ上)', () {
    final rnd = math.Random(2);
    const records = 10000;
    GeoPoint randomPlace() =>
        _offset(_tokyo, (rnd.nextDouble() * 2 - 1) * 30000, (rnd.nextDouble() * 2 - 1) * 30000);

    final covers = <List<CellKey>>[];
    final genWatch = Stopwatch()..start();
    for (var i = 0; i < records; i++) {
      final place = randomPlace();
      final r = rnd.nextDouble();
      final ring = r < 0.80
          ? _square(place, 30)
          : r < 0.95
              ? _blob(place, 1e6, 8, rnd)
              : _blob(place, 5e6, 20, rnd);
      covers.add(_grid.coverPolygon(ring));
    }
    genWatch.stop();

    final totalCells = covers.fold<int>(0, (s, c) => s + c.length);

    // 判定マス(z15)ごとに、覆うセルを集める。z15 より粗いセルは、子孫の判定マスすべてに加える
    Map<CellKey, List<CellKey>> buildIndex(Iterable<List<CellKey>> all) {
      final index = <CellKey, List<CellKey>>{};
      void add(CellKey judge, CellKey cell) => (index[judge] ??= []).add(cell);
      for (final cover in all) {
        for (final c in cover) {
          if (c.z >= 15) {
            add(c.ancestorAt(15), c);
          } else {
            var level = [c];
            for (var z = c.z; z < 15; z++) {
              level = [for (final k in level) ...k.children];
            }
            for (final judge in level) {
              add(judge, c);
            }
          }
        }
      }
      return index;
    }

    final rebuildWatch = Stopwatch()..start();
    final index = buildIndex(covers);
    final painted = <CellKey, int>{};
    for (final e in index.entries) {
      painted[e.key] = (_grid.paintedFraction(e.key, e.value) * e.key.z19Count).round();
    }
    rebuildWatch.stop();

    // 1件を追加して、影響を受けた判定マスだけを数え直す
    final newRing = _blob(randomPlace(), 5e6, 20, rnd);
    final addWatch = Stopwatch()..start();
    final newCover = _grid.coverPolygon(newRing);
    final touched = buildIndex([newCover]);
    for (final judge in touched.keys) {
      final cells = [...?index[judge], ...touched[judge]!];
      painted[judge] = (_grid.paintedFraction(judge, cells) * judge.z19Count).round();
    }
    addWatch.stop();

    final estimatedMb = totalCells * 12 / (1024 * 1024);
    print('\n=== V-04 簡易版: 記録 $records 件(店80%・公園15%・大きな施設5%) ===');
    print('| 項目 | 値 |');
    print('|---|---|');
    print('| 被覆の生成(参考。DB 保存は含まない) | ${genWatch.elapsedMilliseconds} ms |');
    print('| 被覆のセルの合計数 | $totalCells |');
    print('| セルの推定サイズ(×12バイト) | ${estimatedMb.toStringAsFixed(2)} MB |');
    print('| 判定マス(z15)の数 | ${index.length} |');
    print('| 全再構築(判定マスごとの塗った数) | ${rebuildWatch.elapsedMilliseconds} ms |');
    print('| 1件追加(大きな施設・影響を受けた判定マス ${touched.length} 個) | ${addWatch.elapsedMilliseconds} ms |');

    expect(rebuildWatch.elapsedMilliseconds, lessThan(60000), reason: '全再構築が 60 秒以内(異常値の検知)');
    expect(addWatch.elapsedMilliseconds, lessThan(5000), reason: '1件の追加が 5 秒以内(異常値の検知)');
    expect(estimatedMb, lessThan(100), reason: '推定サイズが 100MB 以内(NFR-8)');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
