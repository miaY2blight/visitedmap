// ignore_for_file: avoid_print
//
// スポット記録 1 万件の DB 性能計測(基本設計 V-04)。
// `flutter test tool/spot_db_bench_test.dart` で単独に実行する(app/ で)。`test/` の外にあるため、
// 通常の `flutter test` には含まれない。所要時間が長いときは `--timeout` を延ばす(このファイルは 20 分まで許す)。
// アサートは、合格の目安(追加 1 件が 1 秒以内、DB 容量が 100MB 以内)のみ。
// 結果は `docs/handoff/step3_results.md` の「3a: 記録 1 万件の計測」に記録する。
//
// 合成データ(固定シード。毎回同じ):
//   店 9,000 件 = 点+半径 50〜300m、公園 900 件 = 外周 50〜500 点・0.1〜3km²、
//   国立公園規模 100 件 = 外周 5,000 点・3,000〜9,000km²。位置は日本国内(北緯 31〜44、東経 130〜145)にばらける。
// 計測:
//   被覆の計算(SyncCoverService)と DB への書き込み(saveSpot)を分けて時間を取る。
//   メモリ DB とファイル DB(一時ディレクトリ。終わったら消す)の両方で、同じ 1 万件を 1 件ずつ保存する。
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/core/data/cover/cover_service.dart';
import 'package:fogworld/core/data/db/app_database.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const _shopCount = 9000;
const _parkCount = 900;
const _nationalCount = 100;

enum _Kind {
  shop('店(点+半径)'),
  park('公園(外周 50〜500 点)'),
  national('国立公園規模(外周 5,000 点)');

  const _Kind(this.label);
  final String label;
}

class _Item {
  _Item(this.kind, this.shape, this.representative, this.major, this.minor);
  final _Kind kind;
  final SpotShape shape;
  final GeoPoint representative;
  final MajorCategory major;
  final String minor;
  late List<CellKey> cover;
  int coverMicros = 0;
}

GeoPoint _offset(GeoPoint c, double north, double east) => GeoPoint(
      c.lat + north / metersPerDegree,
      c.lon + east / (metersPerDegree * math.cos(c.lat * math.pi / 180)),
    );

/// 星型(中心から見て半径が角度の関数)の単純な多角形。面積はおよそ [areaM2]
List<GeoPoint> _blob(GeoPoint center, double areaM2, int vertices, math.Random rnd) {
  final phase = List.generate(4, (_) => rnd.nextDouble() * 2 * math.pi);
  final unit = List<double>.generate(vertices, (i) {
    final a = 2 * math.pi * i / vertices;
    final w = math.sin(2 * a + phase[0]) * 0.5 +
        math.sin(3 * a + phase[1]) * 0.3 +
        math.sin(5 * a + phase[2]) * 0.2 +
        math.sin(9 * a + phase[3]) * 0.1;
    return 1 + 0.3 * w + 0.001 * (rnd.nextDouble() * 2 - 1);
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

/// 合成データを作る。並びは種類を混ぜた順(実際の記録の順に近づける)
List<_Item> _generate() {
  final rnd = math.Random(20261026);
  GeoPoint place() => GeoPoint(31 + rnd.nextDouble() * 13, 130 + rnd.nextDouble() * 15);
  final items = <_Item>[];
  for (var i = 0; i < _shopCount; i++) {
    final c = place();
    final radius = 50 + rnd.nextInt(251);
    items.add(_Item(_Kind.shop, PointRadiusShape(c, radius), c, MajorCategory.dining, 'カフェ'));
  }
  for (var i = 0; i < _parkCount; i++) {
    final c = place();
    final vertices = 50 + rnd.nextInt(451);
    final area = (0.1 + rnd.nextDouble() * 2.9) * 1e6;
    items.add(_Item(_Kind.park, PolygonShape([_blob(c, area, vertices, rnd)]), c, MajorCategory.nature, '公園'));
  }
  for (var i = 0; i < _nationalCount; i++) {
    final c = place();
    final area = (3000 + rnd.nextDouble() * 6000) * 1e6;
    items.add(_Item(_Kind.national, PolygonShape([_blob(c, area, 5000, rnd)]), c, MajorCategory.nature, '山・高原'));
  }
  items.shuffle(rnd);
  return items;
}

class _Stats {
  final List<int> micros = [];
  void add(int us) => micros.add(us);
  double get avgMs => micros.isEmpty ? 0 : micros.reduce((a, b) => a + b) / micros.length / 1000;
  double get maxMs => micros.isEmpty ? 0 : micros.reduce(math.max) / 1000;
  double get p95Ms {
    if (micros.isEmpty) return 0;
    final s = [...micros]..sort();
    return s[(s.length * 0.95).floor().clamp(0, s.length - 1)] / 1000;
  }

  double get totalMs => micros.fold<int>(0, (a, b) => a + b) / 1000;
}

String _f(double v) => v.toStringAsFixed(2);

class _RunResult {
  final all = _Stats();
  final byKind = {for (final k in _Kind.values) k: _Stats()};
  final firstThousand = _Stats();
  final lastThousand = _Stats();
  int allSpotsMsBest = 0;
  int allSpotsMsFirst = 0;
  int allSpotsCount = 0;
  int coverRows = 0;
  int recordRows = 0;
  Map<String, int> files = {};
  int bytes = 0;

  /// 表・索引ごとの容量(dbstat。使えない環境では空)
  Map<String, int> objects = {};
}

/// [items] を 1 件ずつ保存して計測する。[file] が null ならメモリ DB
Future<_RunResult> _run(List<_Item> items, {File? file}) async {
  final db = AppDatabase(file == null ? NativeDatabase.memory() : NativeDatabase(file));
  var seq = 0;
  final repo = SpotRepository(
    db,
    now: () => DateTime.utc(2026, 1, 1).add(Duration(seconds: seq)),
    newId: () {
      seq++;
      return _uuid.v4(); // 本番と同じ 36 文字の UUID(容量を実際に近づける)
    },
  );
  final res = _RunResult();
  try {
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final spot = NewSpot(
        name: '合成スポット $i',
        shape: it.shape,
        source: it.shape is PolygonShape ? ShapeSource.nominatim : ShapeSource.manual,
        representative: it.representative,
        major: it.major,
        minor: it.minor,
        scoring: SpotScoring.target,
        visitedOn: '2026-01-01',
      );
      final sw = Stopwatch()..start();
      await repo.saveSpot(spot, it.cover);
      sw.stop();
      final us = sw.elapsedMicroseconds;
      res.all.add(us);
      res.byKind[it.kind]!.add(us);
      if (i < 1000) res.firstThousand.add(us);
      if (i >= items.length - 1000) res.lastThousand.add(us);
    }

    // 1 万件後の allSpots(3 回測り、初回と最良を出す)
    for (var n = 0; n < 3; n++) {
      final sw = Stopwatch()..start();
      final spots = await repo.allSpots();
      sw.stop();
      res.allSpotsCount = spots.length;
      if (n == 0) res.allSpotsMsFirst = sw.elapsedMilliseconds;
      if (n == 0 || sw.elapsedMilliseconds < res.allSpotsMsBest) res.allSpotsMsBest = sw.elapsedMilliseconds;
    }

    res.coverRows = (await db.customSelect('SELECT COUNT(*) AS c FROM cover_cells').getSingle()).read<int>('c');
    res.recordRows = (await db.customSelect('SELECT COUNT(*) AS c FROM records').getSingle()).read<int>('c');

    // DB 内の使用ページ数からの容量(メモリ DB でも出せる)
    final pages = (await db.customSelect('PRAGMA page_count').getSingle()).read<int>('page_count');
    final pageSize = (await db.customSelect('PRAGMA page_size').getSingle()).read<int>('page_size');
    res.bytes = pages * pageSize;
    final journal = (await db.customSelect('PRAGMA journal_mode').getSingle()).data.values.first;
    print('  (journal_mode = $journal, page_size = $pageSize, page_count = $pages)');

    try {
      final rows = await db
          .customSelect('SELECT name, SUM(pgsize) AS s FROM dbstat GROUP BY name ORDER BY s DESC')
          .get();
      res.objects = {for (final r in rows) r.read<String>('name'): r.read<int>('s')};
    } catch (_) {
      // dbstat が無い SQLite では、表ごとの内訳は出さない
    }

    if (file != null) {
      // 開いたまま(閉じる前)のファイルサイズ。WAL があればそれも含める
      res.files = _fileSizes(file);
    }
  } finally {
    await db.close();
  }
  return res;
}

/// DB ファイルと、あれば WAL・SHM・ジャーナルのサイズ(バイト)
Map<String, int> _fileSizes(File file) {
  final sizes = <String, int>{};
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${file.path}$suffix');
    if (f.existsSync()) sizes[suffix.isEmpty ? 'db' : suffix] = f.lengthSync();
  }
  return sizes;
}

String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);

void _printRun(String title, _RunResult r) {
  print('\n=== V-04 $title: saveSpot(DB への書き込みのみ) ===');
  print('| 区分 | 件数 | 平均(ms) | p95(ms) | 最大(ms) | 合計(s) |');
  print('|---|---|---|---|---|---|');
  print('| 全体 | ${r.all.micros.length} | ${_f(r.all.avgMs)} | ${_f(r.all.p95Ms)} | ${_f(r.all.maxMs)} | '
      '${_f(r.all.totalMs / 1000)} |');
  for (final k in _Kind.values) {
    final s = r.byKind[k]!;
    print('| ${k.label} | ${s.micros.length} | ${_f(s.avgMs)} | ${_f(s.p95Ms)} | ${_f(s.maxMs)} | '
        '${_f(s.totalMs / 1000)} |');
  }
  print('| 最初の 1,000 件 | ${r.firstThousand.micros.length} | ${_f(r.firstThousand.avgMs)} | '
      '${_f(r.firstThousand.p95Ms)} | ${_f(r.firstThousand.maxMs)} | ${_f(r.firstThousand.totalMs / 1000)} |');
  print('| 最後の 1,000 件 | ${r.lastThousand.micros.length} | ${_f(r.lastThousand.avgMs)} | '
      '${_f(r.lastThousand.p95Ms)} | ${_f(r.lastThousand.maxMs)} | ${_f(r.lastThousand.totalMs / 1000)} |');
  print('allSpots: ${r.allSpotsCount} 件、初回 ${r.allSpotsMsFirst}ms、3 回のうち最良 ${r.allSpotsMsBest}ms');
  print('records ${r.recordRows} 行、cover_cells ${r.coverRows} 行');
  print('DB の使用ページ容量: ${_mb(r.bytes)}MB');
  if (r.objects.isNotEmpty) {
    print('表・索引ごとの容量(dbstat): '
        '${r.objects.entries.where((e) => e.value > 100 * 1024).map((e) => '${e.key}=${_mb(e.value)}MB').join('、')}');
  }
  if (r.files.isNotEmpty) {
    final total = r.files.values.fold<int>(0, (a, b) => a + b);
    print('ファイル: ${r.files.entries.map((e) => '${e.key}=${_mb(e.value)}MB').join('、')}(合計 ${_mb(total)}MB)');
  }
}

void main() {
  test('V-04: 記録 1 万件の DB 性能(メモリ DB・ファイル DB)', () async {
    final items = _generate();
    expect(items.length, _shopCount + _parkCount + _nationalCount);

    // 被覆の計算(DB を含まない)。種類ごとに時間を出す
    final cover = SyncCoverService();
    final coverStats = {for (final k in _Kind.values) k: _Stats()};
    final cellCounts = {for (final k in _Kind.values) k: <int>[]};
    final coverWatch = Stopwatch()..start();
    for (final it in items) {
      final sw = Stopwatch()..start();
      it.cover = await cover.coverOf(it.shape);
      sw.stop();
      it.coverMicros = sw.elapsedMicroseconds;
      coverStats[it.kind]!.add(it.coverMicros);
      cellCounts[it.kind]!.add(it.cover.length);
    }
    coverWatch.stop();
    print('\n=== V-04 被覆の計算(SyncCoverService。DB を含まない) ===');
    print('| 区分 | 件数 | 平均(ms) | p95(ms) | 最大(ms) | セル数 平均 | セル数 最大 | セル数 合計 |');
    print('|---|---|---|---|---|---|---|---|');
    var totalCells = 0;
    for (final k in _Kind.values) {
      final s = coverStats[k]!;
      final c = cellCounts[k]!;
      final sum = c.fold<int>(0, (a, b) => a + b);
      totalCells += sum;
      print('| ${k.label} | ${c.length} | ${_f(s.avgMs)} | ${_f(s.p95Ms)} | ${_f(s.maxMs)} | '
          '${(sum / c.length).toStringAsFixed(1)} | ${c.reduce(math.max)} | $sum |');
    }
    print('被覆セル数の合計(= 挿入される cover_cells の行数): $totalCells、計算の合計 ${_f(coverWatch.elapsedMilliseconds / 1000)}s');

    // メモリ DB
    final mem = await _run(items);
    _printRun('メモリ DB', mem);

    // ファイル DB(一時ディレクトリ。終わったら消す)
    final dir = await Directory.systemTemp.createTemp('fogworld_bench_');
    _RunResult? fileRes;
    Map<String, int> afterClose = {};
    try {
      final file = File('${dir.path}/bench.sqlite');
      fileRes = await _run(items, file: file);
      afterClose = _fileSizes(file);
    } finally {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    _printRun('ファイル DB', fileRes);
    final totalAfter = afterClose.values.fold<int>(0, (a, b) => a + b);
    print('閉じた後のファイル: ${afterClose.entries.map((e) => '${e.key}=${_mb(e.value)}MB').join('、')}'
        '(合計 ${_mb(totalAfter)}MB)');
    print('一時ディレクトリの削除: ${dir.existsSync() ? "失敗" : "済み"}');

    // 参考: 国立公園規模を除いた場合(店 9,000 + 公園 900。実利用に近い値を見る)。ファイル DB のみ
    final subset = [for (final it in items) if (it.kind != _Kind.national) it];
    final dir2 = await Directory.systemTemp.createTemp('fogworld_bench_sub_');
    _RunResult subRes;
    try {
      subRes = await _run(subset, file: File('${dir2.path}/bench.sqlite'));
    } finally {
      if (dir2.existsSync()) await dir2.delete(recursive: true);
    }
    _printRun('ファイル DB(国立公園規模を除く ${subset.length} 件)', subRes);

    // 合格の目安(V-04)
    final worstOne = math.max(mem.all.maxMs, fileRes.all.maxMs);
    final fileTotal = math.max(
      fileRes.files.values.fold<int>(0, (a, b) => a + b),
      totalAfter,
    );
    print('\n判定: 追加 1 件の最大 ${_f(worstOne)}ms(目安 1,000ms 以内)、'
        'ファイル DB の容量 ${_mb(fileTotal)}MB(目安 100MB 以内)');
    expect(worstOne, lessThan(1000), reason: '追加 1 件が 1 秒以内(V-04)');
    expect(fileTotal, lessThan(100 * 1024 * 1024), reason: 'DB 容量が 100MB 以内(NFR-8)');
    expect(dir.existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
