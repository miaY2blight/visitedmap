import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/geometry/simplify.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// 外部(Nominatim の `geojson`)から受け取った形を検証して、[PolygonShape] にする。
/// 外部の入力は信用しない。不正な入力は、落ちずに [FormatException] にする。
///
/// GeoJSON の座標は [lon, lat] の並び(アプリ内の `GeoPoint(lat, lon)` とは逆)。
/// 座標の並びの変換は、このクラスと `ShapeCodec` の中だけで行う。
class ShapeValidator {
  const ShapeValidator();

  /// GeoJSON の geometry([Map])を読み、外周だけのポリゴンにする。
  ///
  /// - 対応は Polygon と MultiPolygon。穴は捨てる(各ポリゴンの最初のリングだけを使う)
  /// - 穴を含む生の頂点の合計が [GameConfig.shapeRawVertexLimit] を超えたら不正
  /// - 各リングは `normalizeRing` を通す(閉じ点を除き、180 度線をまたぐ形は経度を連続させる)。
  ///   MultiPolygon の中の退化したポリゴン(3 点未満・一直線など)は捨てる
  /// - 全体の頂点数が [GameConfig.shapeTargetVertices] を超えるときは簡略化する。
  ///   リングごとの頂点数に比例して配分し、それでも超える場合(小さなポリゴンが非常に多い)は、
  ///   面積の小さいリングから捨てる
  ///
  /// 座標は、保存の形式(`ShapeCodec`)と同じ小数 6 桁に丸めてから検証する。
  /// 出力の座標は丸めた値なので、符号化して復号しても変わらず、被覆も同じになる。
  /// 丸めると退化する極小・極細のリング(3 点未満・面積ゼロ)は、退化したポリゴンとして扱う。
  ///
  /// 入力の構造は決まった深さ(ポリゴン → リング → 座標 → 値)までしか読まない(再帰しない)ので、
  /// 深くネストした入力でもスタックを使い切らない。例外のメッセージには、入力の値(座標・種類)を含めない。
  ///
  /// Point・LineString・その他の種類、構造が違う、座標が数でない・非有限・範囲外
  /// (緯度は ±90、経度は ±180)、生の頂点が多すぎる、使えるリングが 1 つもない場合は [FormatException]
  PolygonShape parsePolygonGeoJson(Object? geometry) {
    if (geometry is! Map) throw const FormatException('geometry がオブジェクトではありません');
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    final List<Object?> polygons;
    final bool single;
    if (type == 'Polygon') {
      if (coordinates is! List) throw const FormatException('coordinates がリストではありません');
      polygons = [coordinates];
      single = true;
    } else if (type == 'MultiPolygon') {
      if (coordinates is! List) throw const FormatException('coordinates がリストではありません');
      polygons = coordinates;
      single = false;
    } else {
      throw const FormatException('対応していない形の種類です(Polygon・MultiPolygon のみ)');
    }

    _checkStructureAndCount(polygons);

    final rings = <List<GeoPoint>>[];
    for (final polygon in polygons) {
      final outer = (polygon as List).first as List;
      final points = [for (final p in outer) _parsePosition(p)];
      final ring = _normalizeRounded(points);
      if (ring != null) {
        rings.add(ring);
      } else if (single) {
        // 単独の Polygon なら不正。MultiPolygon の一部なら、その部分だけ捨てる
        throw const FormatException('外周のリングが不正です(頂点が 3 つ未満、面積がゼロ、または経度の幅が 180 度を超えます)');
      }
    }
    if (rings.isEmpty) throw const FormatException('使える外周のリングがありません');

    // 簡略化は、丸めた点の一部を選ぶだけなので、座標は丸めた値のまま。
    // ただし選んだ点が一直線に並ぶなど、退化することがあるので、もう一度確かめて捨てる
    final fitted = [
      for (final ring in _fitToTarget(rings))
        if (_normalizeRounded(ring) != null) ring,
    ];
    if (fitted.isEmpty) throw const FormatException('使える外周のリングがありません');
    return PolygonShape(fitted);
  }

  /// [points](丸めた座標)を `normalizeRing` で検証し、丸めた座標のリングを返す。退化していれば null。
  ///
  /// 180 度線をまたぐ形は、`normalizeRing` が経度に 360 を足すので、もう一度丸めて
  /// 保存の丸めで変わらない値にする。経度が 180 を超えるリングは、折り返してから検証する
  /// (`CoverService` が `GridService` に渡すときと同じ表現)
  static List<GeoPoint>? _normalizeRounded(List<GeoPoint> points) {
    try {
      final wrapped = [for (final p in points) p.lon > 180 ? GeoPoint(p.lat, p.lon - 360) : p];
      final normalized = [for (final p in normalizeRing(wrapped)) GeoPoint(_round6(p.lat), _round6(p.lon))];
      // 丸め直した値でも退化しないことを確かめる(被覆の計算で、同じ検証を通るように)
      normalizeRing([for (final p in normalized) p.lon > 180 ? GeoPoint(p.lat, p.lon - 360) : p]);
      return normalized;
    } on ArgumentError {
      return null;
    }
  }

  /// 保存の形式(`ShapeCodec`)と同じ、小数 6 桁の丸め
  static double _round6(double v) => (v * 1e6).round() / 1e6;

  /// 構造(ポリゴン → リング → 座標のリスト)を確かめ、生の頂点の合計が上限を超えたら不正にする。
  /// 座標の中身は、ここでは読まない(巨大な入力で重い処理に入る前に弾く)
  void _checkStructureAndCount(List<Object?> polygons) {
    var count = 0;
    for (final polygon in polygons) {
      if (polygon is! List || polygon.isEmpty) {
        throw const FormatException('ポリゴンにリングがありません');
      }
      for (final ring in polygon) {
        if (ring is! List) throw const FormatException('リングがリストではありません');
        count += ring.length;
        if (count > GameConfig.shapeRawVertexLimit) {
          throw const FormatException('頂点が多すぎます(${GameConfig.shapeRawVertexLimit}個まで)');
        }
      }
    }
  }

  /// GeoJSON の座標 [lon, lat](標高があれば無視する)を読み、小数 6 桁に丸める
  GeoPoint _parsePosition(Object? position) {
    if (position is! List || position.length < 2) {
      throw const FormatException('座標が [lon, lat] ではありません');
    }
    final lon = position[0];
    final lat = position[1];
    if (lon is! num || lat is! num || !lon.isFinite || !lat.isFinite) {
      throw const FormatException('座標が有限の数ではありません');
    }
    if (lon.abs() > 180 || lat.abs() > 90) {
      throw const FormatException('座標が範囲外です(緯度経度の取り違えの可能性)');
    }
    return GeoPoint(_round6(lat.toDouble()), _round6(lon.toDouble()));
  }

  /// 全体の頂点数を [GameConfig.shapeTargetVertices] 以下にする
  List<List<GeoPoint>> _fitToTarget(List<List<GeoPoint>> rings) {
    const target = GameConfig.shapeTargetVertices;
    final total = rings.fold<int>(0, (s, r) => s + r.length);
    if (total <= target) return rings;

    final simplified = [
      for (final ring in rings)
        simplifyToLimit(ring, (target * ring.length / total).floor().clamp(3, target)),
    ];
    final simplifiedTotal = simplified.fold<int>(0, (s, r) => s + r.length);
    if (simplifiedTotal <= target) return simplified;

    // 3 点未満にできないリングが多すぎる。面積の大きいリングから順に、収まるものだけを残す
    final areas = [for (final ring in simplified) ringAreaSquareMeters(ring)];
    final order = [for (var i = 0; i < simplified.length; i++) i]
      ..sort((a, b) => areas[b].compareTo(areas[a]));
    final kept = <int>{};
    var used = 0;
    for (final i in order) {
      if (used + simplified[i].length <= target) {
        kept.add(i);
        used += simplified[i].length;
      }
    }
    return [for (var i = 0; i < simplified.length; i++) if (kept.contains(i)) simplified[i]];
  }
}
