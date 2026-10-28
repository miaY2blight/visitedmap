import 'dart:math' as math;

import 'package:fogworld/core/domain/geometry/circle_polygon.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// 確認用の地図に描く形を、GeoJSON と表示範囲にする(純 Dart)。
class ShapeGeoJson {
  const ShapeGeoJson._();

  /// 点+半径の円を作るときの頂点数(閉じ点を除く)
  static const int circleSegments = 64;

  /// 表示範囲の最小の半幅(度。約 80m)。小さな形で地図を寄せすぎないため
  static const double minHalfSpanDegrees = 0.0007;

  /// 空の `FeatureCollection`
  static Map<String, dynamic> empty() => {'type': 'FeatureCollection', 'features': <Object?>[]};

  /// [shape] の塗る範囲の `FeatureCollection`(座標は `[lon, lat]`)。
  ///
  /// ポリゴンは外周ごとに 1 つの `Polygon`、点+半径は円(多角形)にする。
  /// [shape] が null、または円にできない(極付近など)ときは空にする。例外は投げない
  static Map<String, dynamic> featureCollection(SpotShape? shape) {
    final rings = _rings(shape);
    return {
      'type': 'FeatureCollection',
      'features': [
        for (final ring in rings)
          {
            'type': 'Feature',
            'properties': <String, Object?>{},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [_closed(ring)],
            },
          },
      ],
    };
  }

  /// 点 [point] の `FeatureCollection`。null なら空
  static Map<String, dynamic> pointCollection(GeoPoint? point) {
    if (point == null || !point.lat.isFinite || !point.lon.isFinite) return empty();
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object?>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [point.lon, point.lat],
          },
        },
      ],
    };
  }

  /// 地図を合わせる範囲。[shape] の外接の箱(小さすぎれば [minHalfSpanDegrees] まで広げる)。
  /// [shape] が無ければ [marker] の周り。どちらも無ければ null。例外は投げない。
  ///
  /// 180 度線をまたぐ形は、経度が 180 を超える連続した値のまま返す
  static GeoBounds? fitBounds(SpotShape? shape, GeoPoint? marker) {
    final points = <GeoPoint>[];
    for (final ring in _rings(shape)) {
      points.addAll(ring);
    }
    if (points.isEmpty) {
      if (shape is PointRadiusShape) {
        points.add(shape.center);
      } else if (marker != null) {
        points.add(marker);
      }
    }
    if (points.isEmpty) return null;
    var south = double.infinity, north = -double.infinity;
    var west = double.infinity, east = -double.infinity;
    for (final p in points) {
      if (!p.lat.isFinite || !p.lon.isFinite) continue;
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lon);
      east = math.max(east, p.lon);
    }
    if (!south.isFinite) return null;
    final latHalf = math.max((north - south) / 2, minHalfSpanDegrees);
    final lonHalf = math.max((east - west) / 2, minHalfSpanDegrees);
    final latMid = (north + south) / 2;
    final lonMid = (east + west) / 2;
    return GeoBounds(
      math.max(latMid - latHalf, -85),
      lonMid - lonHalf,
      math.min(latMid + latHalf, 85),
      lonMid + lonHalf,
    );
  }

  /// 形の外周(閉じ点なし)。円にできないときは空
  static List<List<GeoPoint>> _rings(SpotShape? shape) {
    switch (shape) {
      case null:
        return const [];
      case PolygonShape():
        return shape.outerRings;
      case PointRadiusShape():
        try {
          return [circlePolygon(shape.center, shape.radiusMeters, segments: circleSegments)];
        } on ArgumentError {
          return const [];
        }
    }
  }

  /// 閉じた `[lon, lat]` の列にする
  static List<List<double>> _closed(List<GeoPoint> ring) {
    final coords = [
      for (final p in ring) [p.lon, p.lat],
    ];
    coords.add(coords.first);
    return coords;
  }
}
