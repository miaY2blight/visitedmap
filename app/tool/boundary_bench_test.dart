// ignore_for_file: avoid_print
//
// 区画の内外判定の性能計測(V-10)。
// `flutter test tool/boundary_bench_test.dart` で単独に実行する。`test/` の外にあるため、通常の `flutter test` には含まれない。
// 入力: ../tools/data/out/regions_<ISO3>.json(`tools/data/build_regions.py` の出力)と ../tools/data/sample_areas.csv。
// JIT(flutter test の VM)での計測で、実機の AOT より遅めに出る。結果は `docs/handoff/step2_results.md` に記録する。
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/core/data/boundary/boundary_repository.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

const _dataDir = '../tools/data';
const _pointsPerSite = 1000;
const _spreadDegrees = 0.25; // 地点の周辺(±0.25 度 ≒ ±28km)

void main() {
  test('区画の内外判定の速さ(全国のパックを読み込んだ状態)', () {
    final outDir = Directory('$_dataDir/out');
    final packFiles = outDir.existsSync()
        ? (outDir.listSync().whereType<File>().where((f) => RegExp(r'regions_[A-Z]{3}\.json$').hasMatch(f.path)).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];
    if (packFiles.isEmpty) {
      print('BOUNDARY_BENCH スキップ: $_dataDir/out に regions_<ISO3>.json がありません');
      return;
    }

    final rssBefore = ProcessInfo.currentRss;
    final sw = Stopwatch();
    late final BoundaryRepository repo;
    var first = true;
    var totalRegions = 0;
    for (final f in packFiles) {
      sw.reset();
      sw.start();
      final json = jsonDecode(utf8.decode(f.readAsBytesSync())) as Map<String, dynamic>;
      final parseMs = sw.elapsedMilliseconds;
      sw.reset();
      if (first) {
        repo = BoundaryRepository.fromJson(json);
        first = false;
      } else {
        repo.addPack(json);
      }
      final loadMs = sw.elapsedMilliseconds;
      final n = (json['regions'] as List).length;
      totalRegions += n;
      print('BOUNDARY_BENCH load ${json['iso3']} regions=$n bytes=${f.lengthSync()} jsonDecodeMs=$parseMs buildMs=$loadMs');
    }
    final rssMb = (ProcessInfo.currentRss - rssBefore) / 1e6;
    print('BOUNDARY_BENCH loaded packs=${packFiles.length} regions=$totalRegions rssIncreaseMB=${rssMb.toStringAsFixed(0)}');

    // 検証地点(sample_areas.csv)の周辺で、ランダムな点の regionAt の平均時間
    final lines = File('$_dataDir/sample_areas.csv').readAsLinesSync().skip(1).where((l) => l.trim().isNotEmpty);
    final rnd = math.Random(42);
    var allMicros = 0, allCount = 0;
    for (final line in lines) {
      final c = line.split(',');
      final name = c[0], lat = double.parse(c[3]), lon = double.parse(c[4]);
      final points = [
        for (var i = 0; i < _pointsPerSite; i++)
          GeoPoint(
            (lat + (rnd.nextDouble() * 2 - 1) * _spreadDegrees).clamp(-85.0, 85.0),
            lon + (rnd.nextDouble() * 2 - 1) * _spreadDegrees,
          ),
      ];
      for (final p in points.take(100)) {
        repo.regionAt(p); // ウォームアップ
      }
      var hits = 0;
      sw.reset();
      sw.start();
      for (final p in points) {
        if (repo.regionAt(p) != null) hits++;
      }
      sw.stop();
      allMicros += sw.elapsedMicroseconds;
      allCount += points.length;
      print(
        'BOUNDARY_BENCH site=$name points=${points.length} hits=$hits '
        'meanMicros=${(sw.elapsedMicroseconds / points.length).toStringAsFixed(1)}',
      );
    }
    final mean = allMicros / allCount;
    print('BOUNDARY_BENCH overall meanMicros=${mean.toStringAsFixed(1)} (目標: 約 1ms = 1000µs 前後)');
    expect(mean, lessThan(20000), reason: '異常に遅い(緩い上限)');
  });
}
