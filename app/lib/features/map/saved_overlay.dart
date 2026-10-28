import 'dart:convert';

import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/geometry/circle_polygon.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// 保存した形を、地図に薄く重ねるための GeoJSON にする(純 Dart)。
class SavedOverlay {
  const SavedOverlay._();

  /// 点+半径の円を作るときの頂点数(閉じ点を除く)
  static const int _circleSegments = 48;

  /// [spots] を 1 つの GeoJSON(`FeatureCollection`、座標は `[lon, lat]`)の文字列にする。
  ///
  /// - ポリゴンは外周を 1 つずつ `Polygon` の Feature にする(閉じた座標列。最初の点を最後に繰り返す)。
  /// - 点+半径は [circlePolygon] の円にする。極付近などで円にできないものは飛ばす。
  /// - Feature の `properties` は記録の `id` だけ(名前などは入れない)。
  /// - [spots] は**新しい順**で渡す(`SpotRepository.allSpots` の順)。頂点の合計(閉じ点を含む)が
  ///   [vertexBudget] を超える分は、新しい記録から順に採用し、超えたところで打ち切る(それより古い記録は
  ///   入れない)。1 件だけで [vertexBudget] を超える記録は、入れずに飛ばして次へ進む。
  ///   形は記録の単位で、外周の一部だけが入ることはない。
  ///
  /// 例外は投げない([vertexBudget] が 0 以下なら空の FeatureCollection)。
  /// 座標は小数 6 桁(約 0.1m)に丸める
  static String featureCollectionJson(
    List<SavedSpot> spots, {
    int vertexBudget = GameConfig.overlayVertexBudget,
  }) {
    final features = <Map<String, Object?>>[];
    var used = 0;
    for (final spot in spots) {
      final rings = _closedRings(spot.shape);
      if (rings == null) continue;
      var cost = 0;
      for (final ring in rings) {
        cost += ring.length;
      }
      // 1 件だけで予算を超える形は、いつまでも入らないので飛ばして次へ進む
      if (cost > vertexBudget) continue;
      // 累計が予算を超えたら、それより古い記録は入れない
      if (used + cost > vertexBudget) break;
      used += cost;
      for (final ring in rings) {
        features.add({
          'type': 'Feature',
          'properties': {'id': spot.id},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        });
      }
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  /// 形を、閉じた `[lon, lat]` の外周の列にする。円にできないときは null
  static List<List<List<double>>>? _closedRings(SpotShape shape) {
    switch (shape) {
      case PolygonShape():
        return [for (final ring in shape.outerRings) _close(ring)];
      case PointRadiusShape():
        try {
          return [_close(circlePolygon(shape.center, shape.radiusMeters, segments: _circleSegments))];
        } on ArgumentError {
          return null;
        }
    }
  }

  static List<List<double>> _close(List<GeoPoint> ring) {
    final coords = [for (final p in ring) _toLonLat(p)];
    coords.add(coords.first);
    return coords;
  }

  /// 小数 6 桁に丸めた `[lon, lat]`
  static List<double> _toLonLat(GeoPoint p) => [_round6(p.lon), _round6(p.lat)];

  static double _round6(double v) => (v * 1e6).round() / 1e6;
}
