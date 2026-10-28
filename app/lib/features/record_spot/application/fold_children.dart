import 'package:fogworld/core/data/nominatim/nominatim_models.dart' show FacilityHit;
import 'package:fogworld/core/domain/category/category_classifier.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';

/// 検索結果から、親の場所(城・公園など)の内側にある付属物を除く。
///
/// 「親」は、`geometry` が Polygon / MultiPolygon で、大分類が 観光地 または 公園・自然 の結果。
/// 次の条件をすべて満たす結果を除く(親であっても除く)。
/// - 代表点 `hit.point` が、別の親の外周の内側にある(穴は無視する)
/// - その親より小さい(親の外周の外接箱の面積が、自分より厳密に大きい。
///   `geometry` が無い・Point のものは常に小さい扱い。
///   Polygon / MultiPolygon なら、自分の外接箱の面積と比べる。面積が等しければ除かない)
/// - チェーン店ではない(`classify` の `chain` が false。チェーン店は別に記録できるため残す)
///
/// 除くのは常に面積の大きい親が小さいものを隠す一方向なので、
/// 外側に自分を含む大きな親がない最も大きい親は必ず残る
/// (観光地同士の入れ子は、最も外側だけが残る)。入力の順序は保つ。入力のリストは変更しない。
///
/// 180 度線をまたぐ形、壊れた形(型違い、座標が数でない、外周の点が 3 未満、範囲外の座標)は、
/// 無視してまとめない。壊れた形の結果は親にならず、子としても除かない。
/// 例外は投げない(内外の判定は平面上の単純な計算で、180 度線をまたぐ形は対象外)。
List<FacilityHit> foldChildren(List<FacilityHit> hits, CategoryClassifier classifier) {
  final classes = [for (final h in hits) classifier.classify(h.tags)];

  // 親の候補(形を解釈できたものだけ)
  final parents = <_Shape>[];
  for (var i = 0; i < hits.length; i++) {
    final major = classes[i].major;
    if (major != MajorCategory.sightseeing && major != MajorCategory.nature) continue;
    final shape = _parseAreaShape(hits[i].geometry);
    if (shape != null) parents.add(shape);
  }
  if (parents.isEmpty) return List<FacilityHit>.of(hits);

  final result = <FacilityHit>[];
  for (var i = 0; i < hits.length; i++) {
    final hit = hits[i];
    if (classes[i].chain) {
      result.add(hit);
      continue;
    }
    final area = _ownArea(hit.geometry);
    if (area == null) {
      // 形を解釈できない(壊れている・線など): まとめない
      result.add(hit);
      continue;
    }
    final lat = hit.point.lat;
    final lon = hit.point.lon;
    // 自分自身は面積が厳密に大きくないので、自分で自分を隠すことはない
    final hidden = parents.any(
      (p) => p.area > area && p.contains(lon, lat),
    );
    if (!hidden) result.add(hit);
  }
  return result;
}

/// 子の側の「自分の大きさ」(外接箱の面積。度²)。
/// 形が無い・Point は 0(常に小さい扱い)。解釈できない形は null
double? _ownArea(Object? geometry) {
  if (geometry == null) return 0;
  if (geometry is Map && geometry['type'] == 'Point') return 0;
  return _parseAreaShape(geometry)?.area;
}

/// Polygon / MultiPolygon の外周と外接箱。外周は経度・緯度の順の組
class _Shape {
  _Shape(this.rings, this.minLon, this.minLat, this.maxLon, this.maxLat);

  final List<List<double>> rings; // 各外周を [lon0, lat0, lon1, lat1, ...] で持つ
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  /// 外接箱の面積(度²。大小の比較だけに使う)
  double get area => (maxLon - minLon) * (maxLat - minLat);

  /// 点が、いずれかの外周の内側にあるか(レイキャスティング)。
  /// 点が有限でない・範囲外なら false
  bool contains(double lon, double lat) {
    if (!lon.isFinite || !lat.isFinite) return false;
    if (lon < minLon || lon > maxLon || lat < minLat || lat > maxLat) return false;
    for (final ring in rings) {
      if (_ringContains(ring, lon, lat)) return true;
    }
    return false;
  }
}

bool _ringContains(List<double> ring, double x, double y) {
  final n = ring.length ~/ 2;
  var inside = false;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = ring[2 * i];
    final yi = ring[2 * i + 1];
    final xj = ring[2 * j];
    final yj = ring[2 * j + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// GeoJSON(デコード済み)の Polygon / MultiPolygon から、外周だけを取り出す。
/// 型違い・座標が数でない・外周の点が 3 未満・範囲外の座標・
/// 180 度線をまたぐ(隣り合う点の経度差が 180 度超、または全体の経度幅が 180 度超)ときは null
_Shape? _parseAreaShape(Object? geometry) {
  if (geometry is! Map) return null;
  final type = geometry['type'];
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.isEmpty) return null;

  final List<Object?> polygons;
  if (type == 'Polygon') {
    polygons = [coordinates];
  } else if (type == 'MultiPolygon') {
    polygons = coordinates;
  } else {
    return null;
  }

  final rings = <List<double>>[];
  var minLon = double.infinity;
  var minLat = double.infinity;
  var maxLon = double.negativeInfinity;
  var maxLat = double.negativeInfinity;
  for (final polygon in polygons) {
    if (polygon is! List || polygon.isEmpty) return null;
    final ring = _parseRing(polygon.first); // 先頭が外周。穴(2 つ目以降)は無視する
    if (ring == null) return null;
    rings.add(ring);
    for (var k = 0; k < ring.length; k += 2) {
      final lon = ring[k];
      final lat = ring[k + 1];
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }
  }
  if (maxLon - minLon > 180) return null;
  return _Shape(rings, minLon, minLat, maxLon, maxLat);
}

List<double>? _parseRing(Object? raw) {
  if (raw is! List || raw.length < 3) return null;
  final ring = <double>[];
  for (final p in raw) {
    if (p is! List || p.length < 2) return null;
    final lon = p[0];
    final lat = p[1];
    if (lon is! num || lat is! num) return null;
    final x = lon.toDouble();
    final y = lat.toDouble();
    if (!x.isFinite || !y.isFinite || x < -180 || x > 180 || y < -90 || y > 90) {
      return null;
    }
    ring
      ..add(x)
      ..add(y);
  }
  // 隣り合う点(終点から始点も)の経度差が 180 度を超えるなら、180 度線をまたぐ
  final n = ring.length ~/ 2;
  for (var i = 0; i < n; i++) {
    final next = (i + 1) % n;
    if ((ring[2 * i] - ring[2 * next]).abs() > 180) return null;
  }
  return ring;
}
