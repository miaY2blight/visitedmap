import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 区画の階層(`regionAt` の `level` に指定できる値)
const List<String> regionLevels = ['country', 'admin1', 'admin2'];

/// 区画 1 つ(国・州・郡など)。`tools/data` が作る `regions_<ISO3>.json` の 1 件に対応する
class Region {
  const Region({
    required this.id,
    required this.externalCode,
    required this.level,
    required this.name,
    required this.parentId,
    required this.recordUnit,
    required this.gridLevel,
    required this.reachableAreaKm2,
  });

  /// geoBoundaries の `shapeID`(全国共通の区画 ID)
  final String id;

  /// 日本の全国地方公共団体コード(5 桁)。ない国・区画は null
  final String? externalCode;

  /// `country` / `admin1` / `admin2`
  final String level;

  /// 現地語の名前(空のこともある)
  final String name;
  final String? parentId;

  /// チェックインの単位: `grid`(日本と主要都市。判定マスの格子を使う)、`country`、`admin1`、`admin2`
  final String recordUnit;

  /// 判定マスの階層(11〜17)。`recordUnit` が `grid` のときだけ値を持つ
  final int? gridLevel;

  /// 到達できる面積(km²)。`recordUnit` が `grid` のときだけ値を持つ
  final double? reachableAreaKm2;
}

class _Polygon {
  _Polygon(this.outer, this.holes);

  final List<GeoPoint> outer;
  final List<List<GeoPoint>> holes;
}

class _Entry {
  _Entry(this.region, this.areaKm2, this.polygons)
      : south = polygons.expand((p) => p.outer).map((p) => p.lat).reduce((a, b) => a < b ? a : b),
        north = polygons.expand((p) => p.outer).map((p) => p.lat).reduce((a, b) => a > b ? a : b),
        west = polygons.expand((p) => p.outer).map((p) => p.lon).reduce((a, b) => a < b ? a : b),
        east = polygons.expand((p) => p.outer).map((p) => p.lon).reduce((a, b) => a > b ? a : b);

  final Region region;
  final double areaKm2;
  final List<_Polygon> polygons;
  final double south, north, west, east;

  /// 経度ちょうど +180 は、-180 と同じ子午線。180 度線で分割された区画の東側の部分は、右辺が 180 にあり、
  /// 偶奇規則では辺の上の点が外側になるため、-180(西側の部分の左辺。内側)でも調べる
  bool contains(GeoPoint p) => _containsAt(p) || (p.lon == 180 && _containsAt(GeoPoint(p.lat, -180)));

  bool _containsAt(GeoPoint p) {
    if (p.lat < south || p.lat > north || p.lon < west || p.lon > east) return false;
    for (final poly in polygons) {
      if (!pointInRing(p, poly.outer)) continue;
      // 穴の内側は、この区画の外側として扱う(穴を埋める別の区画が返る)
      if (poly.holes.any((h) => pointInRing(p, h))) continue;
      return true;
    }
    return false;
  }
}

/// 区画データ(国ごとのパック)の読み込みと、点がどの区画に入るかの内外判定。
///
/// 複数の国のパックを読み込める([addPack])。判定は、区画の外接矩形で絞ってから、外周と穴で行う。
/// 複数の区画に当たる場合は、面積の小さい方を返す(入れ子の誤判定を避ける)。
/// 180 度線で分割された区画(MultiPolygon の複数の部分)は、どちらの側の点でも同じ区画を返す。
class BoundaryRepository {
  BoundaryRepository.fromJson(Map<String, dynamic> regionsJson) {
    addPack(regionsJson);
  }

  final Map<String, _Entry> _byId = {};
  final Map<String, Map<String, _Entry>> _byLevel = {for (final l in regionLevels) l: {}};

  /// 国ごとのパックを足す。同じ区画 ID は置き換える。
  /// `regions` がない、形が不正などは [FormatException](1 件でも不正なら、何も足さない)
  void addPack(Map<String, dynamic> regionsJson) {
    final regions = regionsJson['regions'];
    if (regions is! List) {
      throw const FormatException('パックに regions がありません');
    }
    final List<_Entry> entries;
    try {
      final defaultUnit = _optionalUnit(regionsJson, 'record_unit') ?? 'country';
      entries = [
        for (final r in regions)
          _parseRegion(r is Map<String, dynamic> ? r : throw const FormatException('regions の要素が不正です'), defaultUnit),
      ];
    } on FormatException {
      rethrow;
    } catch (e) {
      // 想定外の形(型違い・欠落)でも、例外の種類を FormatException にそろえる。何も足さない。
      // メモリ不足などの致命的なエラーは、そのまま投げる
      if (e is! TypeError && e is! RangeError && e is! StateError && e is! NoSuchMethodError) rethrow;
      throw FormatException('パックの形式が不正です: $e');
    }
    for (final e in entries) {
      final old = _byId[e.region.id];
      if (old != null) _byLevel[old.region.level]?.remove(old.region.id);
      _byId[e.region.id] = e;
      _byLevel[e.region.level]?[e.region.id] = e;
    }
  }

  /// 点 [p] を含む区画。階層 [level](`country` / `admin1` / `admin2`)で探し、なければ null。
  /// 不正な [level] は [ArgumentError]。NaN・無限大の点は null
  Region? regionAt(GeoPoint p, {String level = 'admin2'}) {
    final entries = _byLevel[level];
    if (entries == null) {
      throw ArgumentError.value(level, 'level', '$regionLevels のいずれか');
    }
    if (!p.lat.isFinite || !p.lon.isFinite) return null;
    _Entry? best;
    for (final e in entries.values) {
      if (!e.contains(p)) continue;
      if (best == null || e.areaKm2 < best.areaKm2) best = e;
    }
    return best?.region;
  }

  /// 親をたどった一覧(admin2 → admin1 → country の順。自分は含まない)。親が見つからない所で止まる
  List<Region> ancestorsOf(Region r) {
    final result = <Region>[];
    final seen = <String>{r.id};
    var parentId = r.parentId;
    while (parentId != null && seen.add(parentId)) {
      final parent = _byId[parentId]?.region;
      if (parent == null) break;
      result.add(parent);
      parentId = parent.parentId;
    }
    return result;
  }

  static const _units = ['grid', 'country', 'admin1', 'admin2'];

  /// [json] の [key] を、型 [T] の任意の値として読む。null は null。型が違えば [FormatException]
  static T? _optional<T>(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! T) throw FormatException('$key の型が不正です: $v');
    return v;
  }

  /// 必須の文字列
  static String _requiredString(Map<String, dynamic> json, String key) {
    final v = _optional<String>(json, key);
    if (v == null) throw FormatException('$key がありません');
    return v;
  }

  /// `record_unit`(省略・null・空文字は null)。不明な値は [FormatException]
  static String? _optionalUnit(Map<String, dynamic> json, String key) {
    final v = _optional<String>(json, key);
    if (v == null || v.isEmpty) return null;
    if (!_units.contains(v)) throw FormatException('$key が不正です: $v');
    return v;
  }

  static _Entry _parseRegion(Map<String, dynamic> json, String defaultUnit) {
    final level = _requiredString(json, 'level');
    if (!regionLevels.contains(level)) {
      throw FormatException('区画の level が不正です: $level');
    }
    final code = _optional<String>(json, 'external_code');
    final area = _optional<num>(json, 'area_km2')?.toDouble();
    if (area != null && (area.isNaN || area < 0)) {
      throw FormatException('area_km2 が不正です: $area');
    }
    final region = Region(
      id: _requiredString(json, 'region_id'),
      externalCode: (code == null || code.isEmpty) ? null : code,
      level: level,
      name: _optional<String>(json, 'name') ?? '',
      parentId: _optional<String>(json, 'parent_id'),
      recordUnit: _optionalUnit(json, 'record_unit') ?? defaultUnit,
      gridLevel: _optional<num>(json, 'grid_level')?.toInt(),
      reachableAreaKm2: _optional<num>(json, 'reachable_area_km2')?.toDouble(),
    );
    final polygons = _parseGeometry(json['geometry']);
    return _Entry(region, area ?? double.infinity, polygons);
  }

  static List<_Polygon> _parseGeometry(Object? geometry) {
    if (geometry is! Map<String, dynamic>) {
      throw const FormatException('区画に geometry がありません');
    }
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) {
      throw const FormatException('geometry に coordinates がありません');
    }
    switch (geometry['type']) {
      case 'Polygon':
        return [_parsePolygon(coordinates)];
      case 'MultiPolygon':
        if (coordinates.isEmpty) throw const FormatException('MultiPolygon が空です');
        return [
          for (final poly in coordinates)
            _parsePolygon(poly is List ? poly : throw const FormatException('MultiPolygon の要素が不正です')),
        ];
      default:
        throw FormatException('対応していない geometry です: ${geometry['type']}');
    }
  }

  static _Polygon _parsePolygon(List rings) {
    if (rings.isEmpty) throw const FormatException('ポリゴンにリングがありません');
    final parsed = [
      for (final ring in rings) _parseRing(ring is List ? ring : throw const FormatException('リングが不正です')),
    ];
    return _Polygon(parsed.first, parsed.sublist(1));
  }

  static List<GeoPoint> _parseRing(List points) {
    if (points.length < 3) throw const FormatException('リングの頂点が 3 未満です');
    return [for (final p in points) _parsePoint(p)];
  }

  /// GeoJSON の [経度, 緯度](第 3 要素以降は無視)。数値でない・有限でない・範囲外は [FormatException]
  static GeoPoint _parsePoint(Object? p) {
    if (p is! List || p.length < 2) throw FormatException('頂点が不正です: $p');
    final lon = p[0], lat = p[1];
    if (lon is! num || lat is! num || !lon.isFinite || !lat.isFinite) {
      throw FormatException('頂点の座標が不正です: $p');
    }
    if (lat.abs() > 90 || lon.abs() > 180) {
      throw FormatException('頂点の座標が範囲外です: $p');
    }
    return GeoPoint(lat.toDouble(), lon.toDouble());
  }
}
