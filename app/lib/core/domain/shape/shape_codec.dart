import 'dart:convert';

import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// [SpotShape] と、DB に保存する JSON 文字列との変換。
///
/// 形式(座標は [lon, lat] の並び。アプリ内の `GeoPoint(lat, lon)` とは逆)
/// - `{"type":"polygon","rings":[[[lon,lat],...]]}`(リングは閉じ点なし)
/// - `{"type":"point_radius","center":[lon,lat],"radius_m":300}`
///
/// 座標は小数 6 桁(約 0.1m)に丸めて保存する。
/// 座標の並びの変換は、このクラスと `ShapeValidator` の中だけで行う。
class ShapeCodec {
  const ShapeCodec();

  /// [shape] を JSON 文字列にする
  String encode(SpotShape shape) {
    return switch (shape) {
      PolygonShape() => jsonEncode({
          'type': 'polygon',
          'rings': [
            for (final ring in shape.outerRings) [for (final p in ring) _toLonLat(p)],
          ],
        }),
      PointRadiusShape() => jsonEncode({
          'type': 'point_radius',
          'center': _toLonLat(shape.center),
          'radius_m': shape.radiusMeters,
        }),
    };
  }

  /// [json] から形を復元する。
  ///
  /// JSON として読めない、形式が違う、座標が数でない・範囲外、リングが 3 点未満、
  /// 半径が整数でない・範囲外のときは [FormatException]。
  /// 構造は決まった深さまでしか読まない(再帰しない)。例外のメッセージには、入力の値(座標・種類・半径)を含めない
  SpotShape decode(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException {
      // jsonDecode の例外は、入力の文字列(座標を含む)を source に持つので、置き換える
      throw const FormatException('形の JSON として読めません');
    }
    if (root is! Map) throw const FormatException('形の JSON がオブジェクトではありません');
    final type = root['type'];
    try {
      if (type == 'polygon') return _decodePolygon(root['rings']);
      if (type == 'point_radius') return _decodePointRadius(root['center'], root['radius_m']);
      throw const FormatException('形の種類が不明です(polygon・point_radius のみ)');
    } on ArgumentError catch (e) {
      // 形の型が持つ検証(範囲外の座標、3 点未満、半径の範囲)に引っかかったもの。
      // 形の型のメッセージは、入力の値を含まない
      throw FormatException('形の値が不正です: ${e.message}');
    }
  }

  PolygonShape _decodePolygon(Object? rings) {
    if (rings is! List || rings.isEmpty) {
      throw const FormatException('rings が空、またはリストではありません');
    }
    return PolygonShape([
      for (final ring in rings)
        if (ring is List)
          [for (final p in ring) _fromLonLat(p)]
        else
          throw const FormatException('リングがリストではありません'),
    ]);
  }

  PointRadiusShape _decodePointRadius(Object? center, Object? radius) {
    if (radius is! num || !radius.isFinite || radius != radius.truncate()) {
      throw const FormatException('radius_m が整数ではありません');
    }
    return PointRadiusShape(_fromLonLat(center), radius.toInt());
  }

  /// 小数 6 桁に丸めた [lon, lat]
  List<double> _toLonLat(GeoPoint p) => [_round6(p.lon), _round6(p.lat)];

  GeoPoint _fromLonLat(Object? value) {
    if (value is! List || value.length != 2) {
      throw const FormatException('座標が [lon, lat] ではありません');
    }
    final lon = value[0];
    final lat = value[1];
    if (lon is! num || lat is! num || !lon.isFinite || !lat.isFinite) {
      throw const FormatException('座標が有限の数ではありません');
    }
    if (lat.abs() > 90 || lon < -180 || lon > 360) {
      throw const FormatException('座標が範囲外です');
    }
    return GeoPoint(lat.toDouble(), lon.toDouble());
  }

  double _round6(double v) => (v * 1e6).round() / 1e6;
}
