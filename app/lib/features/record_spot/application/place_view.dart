import 'dart:math' as math;

import 'package:fogworld/core/data/nominatim/nominatim_models.dart' show PlaceHit;
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/geometry/ring.dart' show metersPerDegree;
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/search/place_kind.dart';

/// 地図の移動先の緯度の限界(度)
const double _latLimit = 85;

/// 地図の移動先の経度の限界(度)
const double _lonLimit = 180;

/// 地名の種類ごとの、移動先の最小の幅(度。南北・東西とも)
double _minSpanDegrees(PlaceKind kind) => switch (kind) {
      PlaceKind.country => 5,
      PlaceKind.natural => 3,
      PlaceKind.region => 1,
      PlaceKind.city => 0.06,
      PlaceKind.district => 0.015,
    };

/// 点で登録されることの多い地形の種類ラベル。`bounds` が小さければ、施設の検索ができる幅へ移動する
const Set<String> _pointTerrainLabels = {'山', '火山', '峠', '尾根', '断崖', '谷'};

/// 種類([PlaceKind])ごとの最小幅をそのまま使う、地点の種類ラベル(点で来る砂漠・海・島など、
/// 広い範囲を見せたいもの)
const Set<String> _wideNaturalLabels = {'砂漠', '海', '島', '湾', '海峡', '岬', '半島'};

/// 形のある広域の地点(湖・公園・国立公園など)の、移動先の最小の幅(度)。
/// `bounds` がこれ以上なら、`bounds` のまま移動する
const double _shapedLandmarkMinSpan = 0.015;

/// 地名・地点 [hit] を選んだときの、地図の移動先の範囲。
///
/// - 種類ラベルが 山・火山・峠・尾根・断崖・谷 で、`bounds` の幅・高さがともに
///   [GameConfig.landmarkPointMaxMeters] 未満(点で登録されたもの)なら、`hit.center` を中心に
///   幅・高さ [GameConfig.landmarkPointViewMeters](施設の検索ができる幅)にする
/// - その他の種類ラベル(湖・公園・国立公園など。砂漠・海・島・湾・海峡・岬・半島を除く)は、
///   最小幅 0.015 度
/// - 種類ラベルが無い地名と、砂漠・海・島・湾・海峡・岬・半島は、種類ごとの最小幅
///   (国 5 度、自然 3 度、地方 1 度、市 0.06 度、地区 0.015 度)
///
/// `bounds` の南北・東西の幅が最小幅より小さいときは、`hit.center` を中心に最小幅まで広げる
/// (点で登録された砂漠などで、極端に拡大されないように)。それ以上なら `hit.bounds` のまま。
///
/// 結果は、緯度 ±85 度・経度 ±180 度に収める。最小幅まで広げた側が限界をはみ出すときは、
/// 幅を保ったまま内側へずらす。`hit.bounds` のまま使う側は、限界で切る(切って最小幅を下回れば、
/// 限界の内側で最小幅まで広げる)。例外は投げない(値が非有限なら中心 0 度で最小幅にする)
GeoBounds viewBoundsFor(PlaceHit hit) {
  final label = hit.landmarkLabel;
  if (label != null && _pointTerrainLabels.contains(label) && _isPointLike(hit.bounds)) {
    final latSpan = GameConfig.landmarkPointViewMeters / metersPerDegree;
    final lat = hit.center.lat.isFinite ? hit.center.lat.clamp(-_latLimit, _latLimit).toDouble() : 0.0;
    final cosLat = math.cos(lat * math.pi / 180);
    final lonSpan = math.min(latSpan / math.max(cosLat, 1e-6), 2 * _lonLimit);
    // 中心の 1 点から広げる(bounds は使わない)
    final (south, north) =
        _fitAxis(hit.center.lat, hit.center.lat, hit.center.lat, latSpan, _latLimit);
    final (west, east) =
        _fitAxis(hit.center.lon, hit.center.lon, hit.center.lon, lonSpan, _lonLimit);
    return GeoBounds(south, west, north, east);
  }

  final span = label != null && !_wideNaturalLabels.contains(label)
      ? _shapedLandmarkMinSpan
      : _minSpanDegrees(hit.kind);
  final (south, north) =
      _fitAxis(hit.bounds.south, hit.bounds.north, hit.center.lat, span, _latLimit);
  final (west, east) =
      _fitAxis(hit.bounds.west, hit.bounds.east, hit.center.lon, span, _lonLimit);
  return GeoBounds(south, west, north, east);
}

/// [b] の幅・高さ(m)がともに [GameConfig.landmarkPointMaxMeters] 未満か。非有限なら true(点とみなす)
bool _isPointLike(GeoBounds b) {
  final height = (b.north - b.south) * metersPerDegree;
  final width = (b.east - b.west) *
      metersPerDegree *
      math.cos((b.south + b.north) / 2 * math.pi / 180);
  return !(height >= GameConfig.landmarkPointMaxMeters || width >= GameConfig.landmarkPointMaxMeters);
}

/// 1 つの軸の範囲 [lo]〜[hi] を、最小幅 [span] と限界 ±[limit] に合わせる
(double, double) _fitAxis(double lo, double hi, double center, double span, double limit) {
  var a = math.max(lo, -limit);
  var b = math.min(hi, limit);
  // NaN を含む比較は false になるので、「十分な幅がある」と言えないときは広げる
  if (!(b - a >= span)) {
    final c = center.isFinite ? center.clamp(-limit, limit).toDouble() : 0.0;
    a = c - span / 2;
    b = c + span / 2;
    if (a < -limit) {
      b += -limit - a;
      a = -limit;
    }
    if (b > limit) {
      a -= b - limit;
      b = limit;
    }
    a = math.max(a, -limit);
  }
  return (a, b);
}
