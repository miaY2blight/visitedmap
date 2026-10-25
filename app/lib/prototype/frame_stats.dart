import 'dart:math' as math;

/// コマ時間の集計結果
class FrameStats {
  const FrameStats({
    required this.frames,
    required this.avgFps,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.jankFrames,
  });

  final int frames;
  final double avgFps;
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;

  /// 33.3ms を超えたコマの数(30 コマ/秒を下回るコマ)
  final int jankFrames;
}

/// 地図のコマ間隔の目安(カメラ移動通知の時刻の間隔)の集計結果
class MapFrameStats {
  const MapFrameStats({
    required this.events,
    required this.motionFps,
    required this.dt50Ms,
    required this.dt95Ms,
    required this.dt99Ms,
    required this.jankIntervals,
    required this.idleGaps,
  });

  final int events;

  /// 動いている間のコマ/秒(間隔の平均の逆数。止まっている間は含めない)
  final double motionFps;
  final double dt50Ms;
  final double dt95Ms;
  final double dt99Ms;

  /// 33.3ms を超えた間隔の数
  final int jankIntervals;

  /// [idleGap] を超えた間隔の数(カメラが止まっていた区間とみなす)
  final int idleGaps;
}

/// 時刻(昇順)の列から、隣り合う間隔を集計する。[idleGap] を超える間隔は、止まっていた区間として数えない。
/// パーセンタイルは最近傍順位法。時刻が 2 個未満なら全て 0
MapFrameStats summarizeTimestamps(
  List<Duration> stamps, {
  Duration idleGap = const Duration(milliseconds: 250),
}) {
  final dts = <double>[];
  var idle = 0;
  for (var i = 1; i < stamps.length; i++) {
    final d = stamps[i] - stamps[i - 1];
    if (d > idleGap) {
      idle++;
    } else {
      dts.add(d.inMicroseconds / 1000);
    }
  }
  if (dts.isEmpty) {
    return MapFrameStats(
      events: stamps.length,
      motionFps: 0,
      dt50Ms: 0,
      dt95Ms: 0,
      dt99Ms: 0,
      jankIntervals: 0,
      idleGaps: idle,
    );
  }
  final sorted = List<double>.of(dts)..sort();
  double percentile(double p) => sorted[math.max(0, (p * sorted.length).ceil() - 1)];
  final mean = dts.reduce((a, b) => a + b) / dts.length;
  return MapFrameStats(
    events: stamps.length,
    motionFps: mean > 0 ? 1000 / mean : 0,
    dt50Ms: percentile(0.50),
    dt95Ms: percentile(0.95),
    dt99Ms: percentile(0.99),
    jankIntervals: dts.where((v) => v > 1000 / 30).length,
    idleGaps: idle,
  );
}

/// コマ時間 [frameTimes] を、測定時間 [elapsed] の中で集計する。
/// パーセンタイルは、昇順に並べた `ceil(p·n) − 1` 番目(最近傍順位法)。空なら全て 0。
/// [elapsed] が 0 以下は [ArgumentError]
FrameStats summarizeFrames(List<Duration> frameTimes, {required Duration elapsed}) {
  if (elapsed <= Duration.zero) {
    throw ArgumentError.value(elapsed, 'elapsed', '0 より大きい時間が必要です');
  }
  if (frameTimes.isEmpty) {
    return const FrameStats(frames: 0, avgFps: 0, p50Ms: 0, p95Ms: 0, p99Ms: 0, jankFrames: 0);
  }
  final ms = [for (final d in frameTimes) d.inMicroseconds / 1000]..sort();
  double percentile(double p) => ms[math.max(0, (p * ms.length).ceil() - 1)];
  return FrameStats(
    frames: ms.length,
    avgFps: ms.length / (elapsed.inMicroseconds / Duration.microsecondsPerSecond),
    p50Ms: percentile(0.50),
    p95Ms: percentile(0.95),
    p99Ms: percentile(0.99),
    jankFrames: ms.where((v) => v > 1000 / 30).length,
  );
}
