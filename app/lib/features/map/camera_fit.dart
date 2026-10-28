import 'package:flutter/widgets.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/features/map/saved_sheet.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// 180 度線をまたぐ範囲へ移動するときの拡大率(範囲の指定ができないため、中心へこの拡大率で寄せる)
const double antimeridianZoom = 2;

/// 1 点だけの範囲や、記録した場所の代表点へ寄せるときの拡大率
const double pointFocusZoom = 15;

/// 移動の依頼で寄せる範囲の、東西の幅の上限(度)。
///
/// 縦向きの画面(幅 360dp、余白 [mapFocusPadding])では、`newLatLngBounds` で見える経度の幅が範囲の約 1.2 倍になる。
/// 範囲が広すぎると、移動後の表示範囲が `GameConfig.worldScopeMeters`(13,000km)以上の世界全図になり、
/// 大陸や国のバッジから先へ進めない(N-2)。見積もり(`estimateFitWidthMeters`)で約 12,000km に収まる値【仮】
const double moveRequestMaxLonSpan = 90;

/// 地図画面で範囲へ寄せるとき(移動の依頼など)の余白(論理ピクセル)。上は検索ボックスとチップの分
const EdgeInsets mapFocusPadding = EdgeInsets.fromLTRB(32, 140, 32, 32);

/// 表示範囲 [bounds](south, west, north, east)へ地図を寄せるカメラの更新を作る。
///
/// - 西 > 東(180 度線をまたぐ)ときは、範囲の中心へ [antimeridianZoom] で寄せる。
/// - 幅も高さもゼロ(1 点)のときは、その点へ [pointFocusZoom] で寄せる。
/// - それ以外は `newLatLngBounds`。[padding] は画面の端からの余白(論理ピクセル)。
///
/// 値が非有限、南 > 北、緯度が ±90 の外、経度が -180〜180 の外のときは null(移動しない)。例外は投げない
CameraUpdate? cameraUpdateForBounds(GeoBounds bounds, {EdgeInsets padding = EdgeInsets.zero}) {
  final s = bounds.south;
  final w = bounds.west;
  final n = bounds.north;
  final e = bounds.east;
  if (!s.isFinite || !w.isFinite || !n.isFinite || !e.isFinite) return null;
  if (s > n || s < -90 || n > 90 || w < -180 || w > 180 || e < -180 || e > 180) return null;
  if (w > e) {
    final c = MapViewport(bounds: bounds, zoom: 0).center;
    return CameraUpdate.newLatLngZoom(LatLng(c.lat, c.lon), antimeridianZoom);
  }
  if (s == n && w == e) {
    return CameraUpdate.newLatLngZoom(LatLng(s, w), pointFocusZoom);
  }
  return CameraUpdate.newLatLngBounds(
    LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: padding.bottom,
  );
}

/// 地図の移動の依頼(地名・国・大陸のバッジ)の範囲 [bounds] へ寄せるカメラの更新を作る。
///
/// 国の範囲(`CountryEntry.bounds`)は、180 度線をまたぐとき経度を 0〜360 で表し、東が 180 を超える
/// (ロシア・フィジー・アラスカを含むアメリカなど)。地図には -180〜180 の範囲しか渡せないため、
/// 180 を超える経度から 360 を引いて表し直す。
///
/// 表し直したあとも 180 度線をまたぐ(西 > 東)ときは、180 度線で「西〜180」と「-180〜東」の二つに分け、
/// 東西の幅の広い方の範囲へ `newLatLngBounds` で寄せる(アメリカ=本土側、ロシア=ユーラシア側)。
/// 幅が同じなら西側(西〜180)を選ぶ。東西の幅が [moveRequestMaxLonSpan] を超える範囲(ロシア・南極など)は、
/// 中心を保ってその幅まで狭める。それ以外の範囲は [cameraUpdateForBounds] と同じ。
///
/// 値が非有限、南 > 北、東西の幅が 360 度を超える、直したあとも経度が -180〜180 に収まらないときは null
/// (移動しない)。例外は投げない
CameraUpdate? cameraUpdateForMoveRequest(GeoBounds bounds, {EdgeInsets padding = EdgeInsets.zero}) {
  final b = moveRequestTargetBounds(bounds);
  if (b == null) return null;
  return cameraUpdateForBounds(b, padding: padding);
}

/// [cameraUpdateForMoveRequest] が実際に寄せる範囲(経度を -180〜180 に直し、180 度線をまたぐときは
/// 広い側を選び、東西の幅が [moveRequestMaxLonSpan] を超えるときは中心を保って狭めたもの)。
/// 経度が非有限、東西の幅が 360 度を超えるときは null。
/// 南北など、ほかの値の検証は [cameraUpdateForBounds] に任せる(ここでは検証しない)
GeoBounds? moveRequestTargetBounds(GeoBounds bounds) {
  var w = bounds.west;
  var e = bounds.east;
  if (!w.isFinite || !e.isFinite) return null;
  if (w <= e && e - w > 360) return null;
  if (w > 180) w -= 360;
  if (e > 180) e -= 360;
  if (w > e && w >= -180 && w <= 180 && e >= -180 && e <= 180) {
    // 180 度線で二つに分け、広い方を選ぶ(同じなら西側)
    final westWidth = 180 - w;
    final eastWidth = e + 180;
    if (westWidth >= eastWidth) {
      e = 180;
    } else {
      w = -180;
    }
  }
  // 東西に広すぎる範囲は、中心を保って [moveRequestMaxLonSpan] まで狭める(縦向きでも世界全図にしない)
  if (w <= e && e - w > moveRequestMaxLonSpan && w >= -180 && e <= 180) {
    final c = (w + e) / 2;
    w = c - moveRequestMaxLonSpan / 2;
    e = c + moveRequestMaxLonSpan / 2;
  }
  // LatLng は経度 180 を -180 に折り返す(東端が西端の西になり、範囲が壊れる)ため、180 のすぐ内側にする
  if (e == 180 && w < e) e = _eastEdgeLon;
  return GeoBounds(bounds.south, w, bounds.north, e);
}

/// 東端が 180 度線ちょうどの範囲を地図に渡すときの、東端の経度(180 のすぐ内側)
const double _eastEdgeLon = 180 - 1e-9;

/// 記録した [spot] の形へ地図を寄せるカメラの更新を作る。
///
/// 形の範囲([cameraBoundsOf])が求まれば、その範囲へ [padding] つきで寄せる。求まらない(180 度線をまたぐ・
/// 極の近く)ときは、代表点へ [pointFocusZoom] で寄せる。代表点も不正なら null。例外は投げない
CameraUpdate? cameraUpdateForSpot(SavedSpot spot, {EdgeInsets padding = EdgeInsets.zero}) {
  final bounds = cameraBoundsOf(spot.shape);
  if (bounds != null) {
    final update = cameraUpdateForBounds(bounds, padding: padding);
    if (update != null) return update;
  }
  final p = spot.representative;
  if (!p.lat.isFinite || !p.lon.isFinite || p.lat.abs() > 90 || p.lon.abs() > 180) return null;
  return CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lon), pointFocusZoom);
}
