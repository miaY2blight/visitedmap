import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fogworld/core/domain/grid/geo_point.dart';

double _mercatorY(double lat) {
  final r = lat * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + r / 2));
}

/// 点 [p] を、表示範囲 [view] を写した画像([imageSize])の座標に写す(左上が北西)。
/// 横は経度で線形、縦は Web メルカトルの y で線形。範囲外の点は、はみ出した座標を返す
ui.Offset projectToImage(GeoPoint p, GeoBounds view, ui.Size imageSize) {
  final yNorth = _mercatorY(view.north);
  final ySouth = _mercatorY(view.south);
  return ui.Offset(
    (p.lon - view.west) / (view.east - view.west) * imageSize.width,
    (yNorth - _mercatorY(p.lat)) / (yNorth - ySouth) * imageSize.height,
  );
}

/// 除外地域の斜線の、1 タイル分の PNG([size]×[size]、透明な地に斜めの赤い線)
Future<Uint8List> renderHatchPng({int size = 16}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..color = const ui.Color(0xFFD32F2F).withValues(alpha: 0.7)
    ..strokeWidth = 2
    ..style = ui.PaintingStyle.stroke;
  final s = size.toDouble();
  // タイルを並べても線がつながるよう、対角線と、その上下の角を描く
  canvas.drawLine(ui.Offset(0, s), ui.Offset(s, 0), paint);
  canvas.drawLine(ui.Offset(-s / 2, s / 2), ui.Offset(s / 2, -s / 2), paint);
  canvas.drawLine(ui.Offset(s / 2, s * 1.5), ui.Offset(s * 1.5, s / 2), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG への変換に失敗しました');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// 霧の PNG(方式 B)。画像全体を霧の色で塗り、穴を `BlendMode.clear` で抜き、縁をぼかす。
/// 表示範囲の外の穴は描かない
Future<Uint8List> renderFogPng({
  required List<List<GeoPoint>> holes,
  required GeoBounds view,
  required ui.Size imageSize,
  double blurSigma = 4,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rect = ui.Offset.zero & imageSize;
  canvas.saveLayer(rect, ui.Paint());
  canvas.drawRect(
    rect,
    ui.Paint()..color = const ui.Color(0xFF1D2A3A).withValues(alpha: 0.75),
  );
  final holePaint = ui.Paint()
    ..blendMode = ui.BlendMode.clear
    ..maskFilter = blurSigma > 0 ? ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma) : null;
  for (final hole in holes) {
    var south = double.infinity, north = double.negativeInfinity;
    var west = double.infinity, east = double.negativeInfinity;
    for (final p in hole) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lon);
      east = math.max(east, p.lon);
    }
    if (north < view.south || south > view.north || east < view.west || west > view.east) continue;
    final path = ui.Path();
    for (var i = 0; i < hole.length; i++) {
      final o = projectToImage(hole[i], view, imageSize);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    canvas.drawPath(path, holePaint);
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(imageSize.width.round(), imageSize.height.round());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG への変換に失敗しました');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
