import 'package:flutter/foundation.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';
import 'package:fogworld/features/map/overlay_layers.dart';
import 'package:fogworld/features/record_spot/application/record_draft.dart';
import 'package:fogworld/features/record_spot/presentation/widgets/shape_geojson.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const String _shapeSource = 'draft-shape';
const String _shapeFillLayer = 'draft-shape-fill';
const String _shapeLineLayer = 'draft-shape-line';
const String _pointSource = 'draft-point';
const String _pointLayer = 'draft-point-circle';

const String _accent = '#0E7C86';

/// 記録中の形(塗り・縁)と、点を地図に重ねる層(下から: 塗り、縁、点)。
///
/// どの層も `enableInteraction: false` にする。true(maplibre_gl の既定)だと、層の上の長押しが
/// 層の操作に回り、`onMapLongClick` が呼ばれず、保存済みの形や今の円の内側に点を置けない(実機の B-1)
@visibleForTesting
List<OverlayLayerSpec> draftOverlayLayerSpecs() => const [
  OverlayLayerSpec(
    sourceId: _shapeSource,
    layerId: _shapeFillLayer,
    properties: FillLayerProperties(fillColor: _accent, fillOpacity: 0.35),
  ),
  OverlayLayerSpec(
    sourceId: _shapeSource,
    layerId: _shapeLineLayer,
    properties: LineLayerProperties(lineColor: _accent, lineWidth: 2.5),
  ),
  OverlayLayerSpec(
    sourceId: _pointSource,
    layerId: _pointLayer,
    properties: CircleLayerProperties(
      circleRadius: 7,
      circleColor: _accent,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2.5,
    ),
  ),
];

/// 地図(メイン地図 1 つ)に、記録中の形を描く。
///
/// 描いた内容を覚え、変わったときだけ地図へ送る(点+半径は半径が変わるたびに別の値になる)。
/// 地図の作り直し・スタイルの読み込みのあとは、[reset] で層を足し直す。
/// 同時には 1 つだけ実行し、実行中に来た更新は終わってから 1 回だけ行う。
/// 失敗しても落とさない(次の更新で足し直す)。座標はログに出さない(NFR-2)
class DraftOverlay {
  bool _added = false;

  /// [reset] のたびに増やす。層を足している途中で地図が替わったとき、古い処理の結果を採用しないため
  int _epoch = 0;
  bool _busy = false;
  bool _dirty = false;
  Object? _drawnShape;
  GeoPoint? _drawnPoint;

  /// 新しい地図・読み込み直したスタイルには層が無い。次の [sync] で足し直す
  void reset() {
    _epoch++;
    _added = false;
    _drawnShape = null;
    _drawnPoint = null;
  }

  /// 描く内容を [state] に合わせる。[state] が null なら消す。[controller] は更新のたびに最新を読む
  Future<void> sync(
    MapLibreMapController? Function() controller,
    RecordDraftState? Function() state,
  ) async {
    if (_busy) {
      _dirty = true;
      return;
    }
    _busy = true;
    try {
      do {
        _dirty = false;
        final c = controller();
        if (c == null) return;
        final epoch = _epoch;
        try {
          await _syncOnce(c, state(), epoch);
          // 途中で地図が替わった(reset された)。新しい地図に、もう一度描く
          if (epoch != _epoch) _dirty = true;
        } on Object {
          debugPrint('記録中の形の表示を更新できませんでした');
          if (c == controller()) reset();
        }
      } while (_dirty);
    } finally {
      _busy = false;
    }
  }

  Future<void> _syncOnce(MapLibreMapController c, RecordDraftState? s, int epoch) async {
    if (!_added) {
      for (final layer in [_pointLayer, _shapeLineLayer, _shapeFillLayer]) {
        try {
          await c.removeLayer(layer);
        } on Object {
          // 無ければ何もしない
        }
      }
      for (final source in [_pointSource, _shapeSource]) {
        try {
          await c.removeSource(source);
        } on Object {
          // 無ければ何もしない
        }
      }
      await c.addGeoJsonSource(_shapeSource, ShapeGeoJson.empty());
      await c.addGeoJsonSource(_pointSource, ShapeGeoJson.empty());
      await addOverlayLayers(c.addLayer, draftOverlayLayerSpecs());
      // 足している間に reset された(別の地図になった)なら、足し済みにしない
      if (epoch != _epoch) return;
      _added = true;
      _drawnShape = null;
      _drawnPoint = null;
    }

    final shape = s?.displayShape;
    // 点: 読み込み中は施設の代表点、点+半径は中心。形(ポリゴン)のときは出さない
    final GeoPoint? point = s == null ? null : (s.loading || s.isPointRadius ? s.center : null);

    if (!_sameShape(shape, _drawnShape)) {
      _drawnShape = shape;
      await c.setGeoJsonSource(_shapeSource, ShapeGeoJson.featureCollection(shape));
    }
    if (point != _drawnPoint) {
      _drawnPoint = point;
      await c.setGeoJsonSource(_pointSource, ShapeGeoJson.pointCollection(point));
    }
  }

  /// 点+半径は半径が変わるたびに別のインスタンスになる。中心と半径が同じなら送り直さない
  static bool _sameShape(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is PointRadiusShape && b is PointRadiusShape) {
      return a.center == b.center && a.radiusMeters == b.radiusMeters;
    }
    return false;
  }
}
