import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/prototype/fog_image_renderer.dart';
import 'package:fogworld/prototype/frame_stats.dart';
import 'package:fogworld/prototype/synthetic_holes.dart';

// 使い捨ての測定用。結果の行は `adb logcat -s flutter` で読める(接頭辞 FOGBENCH)
const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
const LatLng _tokyoStation = LatLng(35.681236, 139.767125);
const double _initialZoom = 14;

const Duration _measureDuration = Duration(seconds: 15);
const Duration _legDuration = Duration(milliseconds: 1500);
const Duration _legPause = Duration(milliseconds: 1000);
const Duration _regenIdle = Duration(milliseconds: 750);
const double _lonSwing = 0.02;
const double _zoomNear = 16;
const double _zoomFar = 13;
// 大きな形(世界)の台本: 欧州・アフリカ・アジアを順に巡り、ズーム 2 ↔ 8 を繰り返す
const List<LatLng> _worldStops = [
  LatLng(50, 10),
  LatLng(0, 20),
  LatLng(35, 100),
];
const double _worldZoomFar = 2;
const double _worldZoomNear = 8;

const int _regionCount = 60;
const int _exclusionRegions = 20;
const int _exclusionVertices = 4000;

const String _fogSource = 'fog';
const String _fogFill = 'fog-fill';
const String _fogEdge = 'fog-edge';
const String _imgSource = 'fog-img';
const String _imgLayer = 'fog-img-layer';
const String _exclSource = 'excl';
const String _exclFill = 'excl-fill';
const String _hatchImage = 'excl-hatch';
const ui.Size _imageSize = ui.Size(1024, 1024);

enum _Variant { a, b }

/// 穴の種類: 東京の小さなマス / 世界の大きな形(国・州規模)
enum _Kind { cells, regions }

enum _Status { ok, aborted, failed }

class FogBenchPage extends StatefulWidget {
  const FogBenchPage({super.key});

  @override
  State<FogBenchPage> createState() => _FogBenchPageState();
}

class _FogBenchPageState extends State<FogBenchPage>
    with WidgetsBindingObserver {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _running = false;

  _Kind _kind = _Kind.cells;
  int _holeCount = 10000;
  int _vertices = 100000;
  bool _exclusion = false;
  bool _hatchAdded = false;
  String _exclPattern = '';
  HoleMode _merge = HoleMode.perCell;
  bool _blur = false;
  _Variant _variant = _Variant.a;

  // 実行中の状態
  bool _abort = false;
  ui.Size? _startSize;
  bool _measuring = false;
  Timer? _regenTimer;
  List<List<GeoPoint>>? _currentHoles;
  bool _imageSourceAdded = false;
  bool _regenerating = false;
  final List<double> _regenMs = [];
  Object? _regenError;

  // 地図のコマ間隔の目安: 測定中のカメラ移動通知の時刻。FrameTiming は Flutter 側のコマしか測れず、
  // 地図(別スレッドの SurfaceView)の描画の遅れが出ないため、こちらも集める
  final List<Duration> _moveStamps = [];
  final Stopwatch _moveClock = Stopwatch();

  // 地図の見た目を確かめるため、操作パネルを隠せるようにする
  bool _panelVisible = true;

  final List<String> _results = [];
  Uint8List? _snapshot;
  String _snapshotInfo = '';
  bool _snapshotBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _regenTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_running && state != AppLifecycleState.resumed) _abort = true;
  }

  @override
  void didChangeMetrics() {
    final start = _startSize;
    if (!_running || start == null) return;
    if (_currentSize() != start) _abort = true;
  }

  ui.Size _currentSize() =>
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;

  void _log(String line) {
    debugPrint(line);
    if (!mounted) return;
    setState(() {
      _results.insert(0, line);
      if (_results.length > 2) _results.removeLast();
    });
  }

  Future<void> _removeFog() async {
    final c = _controller!;
    // 無いものを消そうとして例外になっても構わない(最初の実行)
    for (final layer in [_exclFill, _fogFill, _fogEdge, _imgLayer]) {
      try {
        await c.removeLayer(layer);
      } catch (_) {}
    }
    for (final source in [_exclSource, _fogSource, _imgSource]) {
      try {
        await c.removeSource(source);
      } catch (_) {}
    }
    _imageSourceAdded = false;
  }

  Future<void> _run() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded || _running) return;
    final variant = _variant, kind = _kind, merge = _merge, blur = _blur;
    final exclusion = _exclusion;
    setState(() => _running = true);
    _abort = false;
    _startSize = _currentSize();
    _regenMs.clear();
    _regenError = null;
    _exclPattern = '';
    var status = _Status.ok;
    var buildMs = 0;
    var holeCount = 0, vertexCount = 0;
    FrameStats? stats;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await _removeFog();
      final holes = kind == _Kind.cells
          ? buildHoles(targetHoles: _holeCount, seed: 1, mode: merge)
          : buildRegionHoles(
              regions: _regionCount,
              totalVertices: _vertices,
              seed: 1,
            );
      _currentHoles = holes;
      holeCount = holes.length;
      vertexCount = holes.fold(0, (s, h) => s + h.length);
      await WidgetsBinding.instance.endOfFrame;

      // buildMs: 穴ができてから、地図へ設定し終えるまで(穴の生成は含めない)
      final sw = Stopwatch()..start();
      if (variant == _Variant.a) {
        await controller.addGeoJsonSource(_fogSource, fogGeoJson(holes));
        await controller.addFillLayer(
          _fogSource,
          _fogFill,
          const FillLayerProperties(fillColor: '#1d2a3a', fillOpacity: 0.75),
        );
        if (blur) {
          await controller.addLineLayer(
            _fogSource,
            _fogEdge,
            const LineLayerProperties(
              lineColor: '#ffffff',
              lineWidth: 6.0,
              lineBlur: 6.0,
              lineOpacity: 0.5,
            ),
          );
        }
      } else {
        await _regenerateImage();
        if (_regenError != null) throw _regenError!;
        _regenMs.clear(); // 最初の1回は buildMs に入れ、再生成の統計には入れない
      }
      if (exclusion) await _addExclusion(controller);
      sw.stop();
      buildMs = sw.elapsedMilliseconds;

      // 台本の開始位置へ移し、描画が落ち着くのを待つ
      await _moveToLeg(controller, kind, 0, const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_abort) {
        status = _Status.aborted;
      } else {
        final frames = <Duration>[];
        void onTimings(List<ui.FrameTiming> timings) {
          for (final t in timings) {
            frames.add(t.totalSpan);
          }
        }

        SchedulerBinding.instance.addTimingsCallback(onTimings);
        final clock = Stopwatch()..start();
        _moveStamps.clear();
        _moveClock
          ..reset()
          ..start();
        _measuring = true;
        try {
          var leg = 1;
          while (clock.elapsed < _measureDuration && !_abort) {
            await _moveToLeg(controller, kind, leg++, _legDuration);
            await Future<void>.delayed(_legPause);
          }
        } finally {
          _measuring = false;
          clock.stop();
          SchedulerBinding.instance.removeTimingsCallback(onTimings);
          _regenTimer?.cancel();
        }
        if (_abort) {
          status = _Status.aborted;
        } else {
          stats = summarizeFrames(frames, elapsed: clock.elapsed);
        }
      }
    } catch (e) {
      status = _Status.failed;
      debugPrint('FOGBENCH error: $e');
    } finally {
      _measuring = false;
      _currentHoles = null;
    }

    final s = stats;
    final m = summarizeTimestamps(List.of(_moveStamps));
    final buf = StringBuffer(
      'FOGBENCH variant=${variant.name.toUpperCase()} kind=${kind.name} holes=$holeCount '
      'vertices=$vertexCount merge=${kind == _Kind.cells ? merge.name : '-'} '
      'blur=${blur ? 'on' : 'off'} excl=${exclusion ? _exclusionRegions : 0}'
      '${exclusion ? ' exclPattern=$_exclPattern' : ''} '
      'frames=${s?.frames ?? 0} avgFps=${(s?.avgFps ?? 0).toStringAsFixed(1)} '
      'p50=${(s?.p50Ms ?? 0).toStringAsFixed(1)} p95=${(s?.p95Ms ?? 0).toStringAsFixed(1)} '
      'p99=${(s?.p99Ms ?? 0).toStringAsFixed(1)} jank=${s?.jankFrames ?? 0} buildMs=$buildMs '
      'mapEvents=${m.events} mapFps=${m.motionFps.toStringAsFixed(1)} mapDt50=${m.dt50Ms.toStringAsFixed(1)} '
      'mapDt95=${m.dt95Ms.toStringAsFixed(1)} mapDt99=${m.dt99Ms.toStringAsFixed(1)} '
      'mapJank=${m.jankIntervals} mapIdleGaps=${m.idleGaps}',
    );
    if (variant == _Variant.b) {
      final n = _regenMs.length;
      final avg = n == 0 ? 0.0 : _regenMs.reduce((a, b) => a + b) / n;
      final max = n == 0 ? 0.0 : _regenMs.reduce((a, b) => a > b ? a : b);
      buf.write(
        ' regenCount=$n regenAvgMs=${avg.toStringAsFixed(0)} regenMaxMs=${max.toStringAsFixed(0)}',
      );
    }
    buf.write(' status=${status.name}');
    _log(buf.toString());
    if (mounted) setState(() => _running = false);
  }

  /// カメラの台本の [leg] 番目(0 が開始位置)へ動く。
  /// マス: 東京駅の周囲を東西に ±0.02 度往復しながら、ズーム 13 ↔ 16。
  /// 大きな形: 欧州・アフリカ・アジアを順に巡りながら、ズーム 2 ↔ 8
  Future<void> _moveToLeg(
    MapLibreMapController c,
    _Kind kind,
    int leg,
    Duration d,
  ) async {
    final LatLng target;
    final double zoom;
    if (kind == _Kind.cells) {
      final even = leg.isEven;
      target = LatLng(
        _tokyoStation.latitude,
        _tokyoStation.longitude + (even ? -_lonSwing : _lonSwing),
      );
      zoom = even ? _zoomFar : _zoomNear;
    } else {
      target = _worldStops[leg % _worldStops.length];
      zoom = leg.isEven ? _worldZoomFar : _worldZoomNear;
    }
    try {
      // 完了通知が来ない場合(背面など)に止まらないよう、時間で打ち切る
      await c
          .animateCamera(CameraUpdate.newLatLngZoom(target, zoom), duration: d)
          .timeout(d + const Duration(seconds: 3));
    } on TimeoutException {
      _abort = true;
    }
  }

  /// 除外地域の斜線を、霧の上に載せる。斜線の画像が使えなければ、半透明の赤で代用する
  Future<void> _addExclusion(MapLibreMapController c) async {
    final rings = buildRegionHoles(
      regions: _exclusionRegions,
      totalVertices: _exclusionVertices,
      seed: 99,
    );
    await c.addGeoJsonSource(_exclSource, exclusionGeoJson(rings));
    var pattern = 'hatch';
    try {
      if (!_hatchAdded) {
        await c.addImage(_hatchImage, await renderHatchPng());
        _hatchAdded = true;
      }
      await c.addFillLayer(
        _exclSource,
        _exclFill,
        const FillLayerProperties(fillPattern: _hatchImage),
      );
    } catch (e) {
      debugPrint('FOGBENCH hatch unavailable: $e');
      pattern = 'fallback';
      try {
        await c.removeLayer(_exclFill);
      } catch (_) {}
      await c.addFillLayer(
        _exclSource,
        _exclFill,
        const FillLayerProperties(fillColor: '#d32f2f', fillOpacity: 0.25),
      );
    }
    _exclPattern = pattern;
  }

  void _onCameraIdle() {
    if (!_measuring || _variant != _Variant.b) return;
    _regenTimer?.cancel();
    _regenTimer = Timer(_regenIdle, () async {
      if (!_measuring || _regenerating) return;
      await _regenerateImage();
    });
  }

  /// 方式 B: 表示範囲に合わせて霧の画像を作り直して、地図へ反映する。所要時間を [_regenMs] に足す
  Future<void> _regenerateImage() async {
    final controller = _controller;
    final holes = _currentHoles;
    if (controller == null || holes == null) return;
    _regenerating = true;
    final sw = Stopwatch()..start();
    try {
      final region = await controller.getVisibleRegion();
      final view = GeoBounds(
        region.southwest.latitude,
        region.southwest.longitude,
        region.northeast.latitude,
        region.northeast.longitude,
      );
      final png = await renderFogPng(
        holes: holes,
        view: view,
        imageSize: _imageSize,
        blurSigma: _blur ? 4 : 0,
      );
      final quad = LatLngQuad(
        topLeft: LatLng(view.north, view.west),
        topRight: LatLng(view.north, view.east),
        bottomRight: LatLng(view.south, view.east),
        bottomLeft: LatLng(view.south, view.west),
      );
      if (!_imageSourceAdded) {
        await controller.addImageSource(_imgSource, png, quad);
        await controller.addRasterLayer(
          _imgSource,
          _imgLayer,
          const RasterLayerProperties(),
        );
        _imageSourceAdded = true;
      } else {
        await controller.updateImageSource(_imgSource, png, quad);
      }
      _regenMs.add(sw.elapsedMicroseconds / 1000);
    } catch (e) {
      _regenError = e;
      debugPrint('FOGBENCH regen error: $e');
    } finally {
      _regenerating = false;
    }
  }

  Future<void> _snapshotTest() async {
    final c = _controller;
    if (c == null || !_styleLoaded || _snapshotBusy) return;
    setState(() => _snapshotBusy = true);
    final sw = Stopwatch()..start();
    try {
      final bytes = await c.takeSnapshot(width: 300, height: 300);
      sw.stop();
      final fog = (await _fogLayerPresent()) ? 'あり' : 'なし';
      final info =
          'snapshot ok ${sw.elapsedMilliseconds}ms ${bytes.length}B 霧(${_variant.name.toUpperCase()}):$fog';
      debugPrint('FOGBENCH $info');
      if (mounted) {
        setState(() {
          _snapshot = bytes;
          _snapshotInfo = info;
        });
      }
    } catch (e) {
      final info = 'snapshot failed: $e';
      debugPrint('FOGBENCH $info');
      if (mounted) {
        setState(() {
          _snapshot = null;
          _snapshotInfo = info;
        });
      }
    } finally {
      if (mounted) setState(() => _snapshotBusy = false);
    }
  }

  // 霧のレイヤーが地図に載っているか(実行済みかの目安)
  Future<bool> _fogLayerPresent() async {
    final c = _controller;
    if (c == null) return false;
    try {
      final ids = (await c.getLayerIds()).cast<String>();
      return ids.contains(_fogFill) || ids.contains(_imgLayer);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _styleLoaded && !_running;
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _styleUrl,
            initialCameraPosition: const CameraPosition(
              target: _tokyoStation,
              zoom: _initialZoom,
            ),
            onMapCreated: (c) => _controller = c,
            onStyleLoadedCallback: () {
              if (mounted) setState(() => _styleLoaded = true);
            },
            onCameraIdle: _onCameraIdle,
            trackCameraPosition: true,
            onCameraMove: (_) {
              if (_measuring) _moveStamps.add(_moveClock.elapsed);
            },
          ),
          if (_snapshot != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(_snapshot!, width: 120, height: 120),
                ),
              ),
            ),
          if (!_panelVisible)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton.tonal(
                    onPressed: () => setState(() => _panelVisible = true),
                    child: Text(_running ? '測定中…(パネルを出す)' : 'パネルを出す'),
                  ),
                ),
              ),
            ),
          if (_panelVisible)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _panelVisible = false),
                            child: const Text('パネルを隠す(地図を見る)'),
                          ),
                        ),
                        _chips<_Kind>(
                          '種類',
                          _Kind.values,
                          _kind,
                          (v) => v == _Kind.cells ? 'マス(東京)' : '大きな形(世界)',
                          (v) => _kind = v,
                        ),
                        if (_kind == _Kind.cells) ...[
                          _chips<int>(
                            '穴',
                            [1000, 10000, 50000],
                            _holeCount,
                            (v) => '$v',
                            (v) => _holeCount = v,
                          ),
                          _chips<HoleMode>(
                            '結合',
                            HoleMode.values,
                            _merge,
                            (v) => v.name,
                            (v) => _merge = v,
                          ),
                        ] else
                          _chips<int>(
                            '頂点',
                            [100000, 500000],
                            _vertices,
                            (v) => '$v',
                            (v) => _vertices = v,
                          ),
                        _chips<bool>(
                          '除外斜線',
                          [false, true],
                          _exclusion,
                          (v) => v ? '$_exclusionRegions 地域' : 'なし',
                          (v) => _exclusion = v,
                        ),
                        _chips<bool>(
                          'ぼかし',
                          [false, true],
                          _blur,
                          (v) => v ? 'あり' : 'なし',
                          (v) => _blur = v,
                        ),
                        _chips<_Variant>(
                          '方式',
                          _Variant.values,
                          _variant,
                          (v) => v.name.toUpperCase(),
                          (v) => _variant = v,
                        ),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: canRun ? _run : null,
                              child: Text(_running ? '測定中…' : '実行(15 秒)'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed:
                                  _styleLoaded && !_running && !_snapshotBusy
                                  ? _snapshotTest
                                  : null,
                              child: const Text('スナップショット'),
                            ),
                          ],
                        ),
                        if (_snapshotInfo.isNotEmpty)
                          Text(
                            _snapshotInfo,
                            style: const TextStyle(fontSize: 11),
                          ),
                        for (final line in _results)
                          Text(
                            line,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chips<T>(
    String label,
    List<T> values,
    T current,
    String Function(T) name,
    void Function(T) set,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        for (final v in values)
          ChoiceChip(
            label: Text(name(v)),
            selected: v == current,
            visualDensity: VisualDensity.compact,
            onSelected: _running ? null : (_) => setState(() => set(v)),
          ),
      ],
    );
  }
}
