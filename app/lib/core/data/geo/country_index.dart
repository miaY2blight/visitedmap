import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fogworld/core/domain/geometry/ring.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';

/// 検索の候補のバッジに使う、国の情報
class CountryEntry {
  const CountryEntry({
    required this.iso3,
    required this.nameJa,
    required this.continent,
    required this.bounds,
    required this.areaKm2Approx,
  });

  /// ISO 3166-1 alpha-3 の国コード
  final String iso3;

  /// 日本語名。資産に無い(空の)ときは英語名
  final String nameJa;

  /// 資産の `continent` の値(英語。例: `Asia`)
  final String continent;

  /// 国の本体(最大のポリゴンを核に、8 度以内の島・飛び地を連鎖的に取り込んだ「かたまり」)の外接矩形。
  /// 遠く離れた海外領土は含めない。180 度線をまたぐかたまりは、経度を 0〜360 に直した最小の範囲で、
  /// 東が 180 を超えることがある(`west > east` にはならない)
  final GeoBounds bounds;

  /// おおよその面積(km²)。穴を除く。順位付けの目安であり、正確な値ではない
  final double areaKm2Approx;

  /// 国のバッジを押したときに地図を寄せる範囲。ふつうは [bounds] と同じ。
  ///
  /// 東西に広すぎて、縦向きの画面では移動後も世界全図(13,000km 以上)になる国だけ、手で決めた本体側の
  /// 範囲【仮】にする(N-2)。東西の幅は 90 度以内(`moveRequestMaxLonSpan`)。表に無い広すぎる国
  /// (南極など)は、地図の移動の側で中心を保って狭める
  GeoBounds get moveBounds => _moveBoundsOverrides[iso3] ?? bounds;

  /// [moveBounds] の手決めの表(南, 西, 北, 東)。
  /// アメリカはアラスカ(アンカレッジ)・本土・東海岸、ロシアはモスクワからバイカル湖の手前まで
  static const Map<String, GeoBounds> _moveBoundsOverrides = {
    'USA': GeoBounds(18.9, -157, 71.4, -67),
    'RUS': GeoBounds(41.2, 28, 81.9, 118),
  };
}

/// 検索の候補のバッジに使う、大陸の情報
class ContinentEntry {
  const ContinentEntry({required this.name, required this.bounds});

  /// 日本語名(アジア / ヨーロッパ / アフリカ / 北アメリカ / 南アメリカ / オセアニア)
  final String name;

  /// 地図を移動して大陸を見せるための表示範囲(手で決めた固定値。所属する国の範囲の和ではない)
  final GeoBounds bounds;
}

/// 同梱の国境データ(`assets/data/world_countries.json`)から作る、国・大陸の索引。
///
/// 表示範囲に入る国や大陸を、検索の候補のバッジとして示すために使う。通信はしない
class CountryIndex {
  CountryIndex._(this._countries);

  /// 資産の置き場所
  static const String assetPath = 'assets/data/world_countries.json';

  /// 大陸の表示範囲(南, 西, 北, 東)の固定表。この順に [continents] へ並べる。
  ///
  /// 地図を移動して大陸を見せるための**手決めの値**で、国境データから求めたものではない。
  /// 国の範囲の和にすると、海外領土(フランス領ギアナ、ピトケアンなど)や北方の広い国
  /// (ロシアの東端が 180 度線を越える)で、世界の大半が映ってしまうため。
  /// 各大陸の主要部が収まる程度の余白をとった概数で、経度は -180〜180 の範囲に収め、
  /// 180 度線をまたがない。資産の `continent` が `Antarctica`(南極)と
  /// `Seven seas (open ocean)`(公海の島々)の国は、大陸として扱わない(国としては [countries] に残る)。
  ///
  /// 東西の幅は 90 度以内にする(`moveRequestMaxLonSpan`)。縦向きの画面では、見える経度の幅が範囲の約 1.2 倍に
  /// なるため、範囲の外側も周りに映る。アジアは西アジアの一部、北アメリカはアラスカ西部とニューファンドランドの
  /// 東端を範囲から外す(画面には、ほぼ入る)。広すぎると移動後も世界全図のままになる(N-2)
  static const List<ContinentEntry> _continentTable = [
    ContinentEntry(name: 'アジア', bounds: GeoBounds(-11, 56, 56, 146)),
    ContinentEntry(name: 'ヨーロッパ', bounds: GeoBounds(35, -25, 71, 45)),
    ContinentEntry(name: 'アフリカ', bounds: GeoBounds(-35, -18, 37, 52)),
    ContinentEntry(name: '北アメリカ', bounds: GeoBounds(7, -150, 72, -60)),
    ContinentEntry(name: '南アメリカ', bounds: GeoBounds(-56, -82, 13, -34)),
    ContinentEntry(name: 'オセアニア', bounds: GeoBounds(-48, 110, 5, 180)),
  ];

  /// 国の「かたまり」に取り込む、箱どうしの隙間の上限(度。緯度・経度とも)
  static const double _clusterGapDegrees = 8;

  final List<CountryEntry> _countries;

  /// [json]( `{iso3, name_en, name_ja, continent, geometry}` の配列)から索引を作る。
  ///
  /// 配列でない場合は [FormatException]。配列の要素のうち、形式が不正な国
  /// (必須項目の欠け、ジオメトリが Polygon / MultiPolygon でない、座標が数でない・範囲外など)
  /// は捨てて、他を読む。外周が重複を除いて 3 点未満または面積ゼロのポリゴンは採用せず、
  /// 採用できるポリゴンが 0 の国も捨てる。例外メッセージには座標を含めない
  factory CountryIndex.fromJson(Object? json) {
    if (json is! List) {
      throw const FormatException('国の一覧が配列ではありません');
    }
    final countries = <CountryEntry>[];
    for (final item in json) {
      final entry = _parseCountry(item);
      if (entry != null) countries.add(entry);
    }
    return CountryIndex._(List.unmodifiable(countries));
  }

  /// 同梱資産を読み込んで索引を作る。494KB の解析は Isolate(`compute`)で行う。
  ///
  /// [bundle] を省略すると `rootBundle`。資産が無い、または JSON が不正なときは例外
  /// ([FormatException] など)
  static Future<CountryIndex> load({AssetBundle? bundle}) async {
    final text = await (bundle ?? rootBundle).loadString(assetPath);
    return compute(_parseText, text);
  }

  /// 読み込めた国(資産の順)
  List<CountryEntry> get countries => _countries;

  /// 大陸(アジア / ヨーロッパ / アフリカ / 北アメリカ / 南アメリカ / オセアニアの順)。
  /// 範囲は固定の表示用の値で、読み込んだ国によらず常に 6 つ。南極は含めない
  List<ContinentEntry> get continents => _continentTable;

  /// [visible] と [CountryEntry.bounds] が重なる国を、重なりの面積が大きい順に最大 [max] 件返す。
  ///
  /// 面積は、重なりの緯度幅 × 経度幅 × cos(重なりの中心緯度)。同じ面積なら iso3 の昇順。
  /// [visible] が 180 度線をまたぐ(西 > 東)ときは、東に 360 度足して比べる。
  /// 値が不正(非有限、南 >= 北)、または [max] が 0 以下なら空。例外は投げない
  List<CountryEntry> countriesIn(GeoBounds visible, {int max = 6}) {
    if (max <= 0) return const [];
    final values = [visible.south, visible.west, visible.north, visible.east];
    if (values.any((v) => !v.isFinite) || visible.south >= visible.north) {
      return const [];
    }

    final scored = <(CountryEntry, double)>[];
    for (final c in _countries) {
      final overlap = _overlapArea(visible, c.bounds);
      if (overlap > 0) scored.add((c, overlap));
    }
    scored.sort((a, b) {
      final byArea = b.$2.compareTo(a.$2);
      return byArea != 0 ? byArea : a.$1.iso3.compareTo(b.$1.iso3);
    });
    return [for (final s in scored.take(max)) s.$1];
  }

  /// 重なりの面積(度² を緯度で補正した値)。重ならなければ 0
  static double _overlapArea(GeoBounds visible, GeoBounds country) {
    final latLow = math.max(visible.south, country.south);
    final latHigh = math.min(visible.north, country.north);
    if (latHigh <= latLow) return 0;

    final east = visible.west > visible.east ? visible.east + 360 : visible.east;
    var lonOverlap = 0.0;
    // 国の範囲を 360 度ずらして比べる(180 度線をまたぐ表示範囲・国の両方に対応)
    for (final shift in const [-360.0, 0.0, 360.0]) {
      final low = math.max(visible.west, country.west + shift);
      final high = math.min(east, country.east + shift);
      lonOverlap = math.max(lonOverlap, high - low);
    }
    if (lonOverlap <= 0) return 0;

    final midLat = (latLow + latHigh) / 2;
    return (latHigh - latLow) * lonOverlap * math.cos(midLat * math.pi / 180);
  }
}

/// Isolate で動かす入口。JSON の文字列を解析して索引を作る
CountryIndex _parseText(String text) => CountryIndex.fromJson(jsonDecode(text));

/// 1 件の国を読む。形式が不正なら null
CountryEntry? _parseCountry(Object? item) {
  if (item is! Map) return null;
  final iso3 = item['iso3'];
  final continent = item['continent'];
  if (iso3 is! String || iso3.isEmpty) return null;
  if (continent is! String || continent.isEmpty) return null;

  final nameEn = item['name_en'];
  final nameJa = item['name_ja'];
  final String name;
  if (nameJa is String && nameJa.isNotEmpty) {
    name = nameJa;
  } else if (nameEn is String && nameEn.isNotEmpty) {
    name = nameEn;
  } else {
    name = iso3;
  }

  final geometry = item['geometry'];
  if (geometry is! Map) return null;
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) return null;
  final List<dynamic> polygons;
  switch (geometry['type']) {
    case 'Polygon':
      polygons = [coordinates];
    case 'MultiPolygon':
      polygons = coordinates;
    default:
      return null;
  }

  final polygonBoxes = <_PolygonBox>[];
  var areaM2 = 0.0;

  for (final polygon in polygons) {
    if (polygon is! List) return null;
    _PolygonBox? box;
    for (var ringIndex = 0; ringIndex < polygon.length; ringIndex++) {
      final ring = polygon[ringIndex];
      if (ring is! List) return null;
      final points = <GeoPoint>[];
      for (final raw in ring) {
        final p = _parsePoint(raw);
        if (p == null) return null;
        points.add(p);
      }
      // 外周が不正(重複を除いて 3 点未満、または面積ゼロ)なら、このポリゴンは採用しない
      if (ringIndex == 0 && !_isUsableOuterRing(points)) break;
      // 外周は足し、穴(2 つ目以降のリング)は引く
      final ringArea = ringAreaSquareMeters(points);
      areaM2 += ringIndex == 0 ? ringArea : -ringArea;
      // ポリゴンの箱は外周(1 つ目のリング)だけから作る。穴は外周の内側にある
      if (ringIndex == 0) box = _PolygonBox.of(points);
    }
    if (box != null) polygonBoxes.add(box);
  }
  if (polygonBoxes.isEmpty) return null;

  return CountryEntry(
    iso3: iso3,
    nameJa: name,
    continent: continent,
    bounds: _mainlandBounds(polygonBoxes),
    areaKm2Approx: math.max(0, areaM2) / 1e6,
  );
}

/// 外周として使えるか。重複を除いて 3 点以上あり、面積がゼロ(一直線)でないとき true。
///
/// 一直線上の点は浮動小数点の誤差で面積が極小の正になるため、外接矩形の面積との比で判定する
/// (`normalizeRing` と同じ考え方。経度の幅の制限は、国境データの 180 度線をまたぐ外周を通すため設けない)
bool _isUsableOuterRing(List<GeoPoint> points) {
  if (points.toSet().length < 3) return false;
  final b = ringBounds(points);
  final boxArea = (b.north - b.south) *
      (b.east - b.west) *
      metersPerDegree *
      metersPerDegree *
      math.cos((b.south + b.north) / 2 * math.pi / 180);
  if (boxArea <= 0) return false;
  return ringAreaSquareMeters(points) > boxArea * 1e-9;
}

/// 1 つのポリゴン(外周)の外接箱
class _PolygonBox {
  const _PolygonBox({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.mappedWest,
    required this.mappedEast,
  });

  factory _PolygonBox.of(List<GeoPoint> ring) {
    var south = double.infinity, north = double.negativeInfinity;
    var west = double.infinity, east = double.negativeInfinity;
    var mappedWest = double.infinity, mappedEast = double.negativeInfinity;
    for (final p in ring) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lon);
      east = math.max(east, p.lon);
      // 経度を 0〜360 に直した値(180 度線をまたぐ形の範囲を小さく取るため)
      final mapped = p.lon < 0 ? p.lon + 360 : p.lon;
      mappedWest = math.min(mappedWest, mapped);
      mappedEast = math.max(mappedEast, mapped);
    }
    return _PolygonBox(
      south: south,
      north: north,
      west: west,
      east: east,
      mappedWest: mappedWest,
      mappedEast: mappedEast,
    );
  }

  final double south;
  final double north;

  /// 経度(-180〜180 のまま)
  final double west;
  final double east;

  /// 経度を 0〜360 に直したとき
  final double mappedWest;
  final double mappedEast;

  /// 箱の面積(度²)。核を選ぶための大小比較に使う
  double get areaDeg2 => (north - south) * (east - west);

  /// [other] との隙間が、緯度・経度とも [gap] 度以内か。経度は 180 度線をまたいだ近さも見る
  bool isNear(_PolygonBox other, double gap) {
    final latGap = math.max(0.0, math.max(south, other.south) - math.min(north, other.north));
    if (latGap > gap) return false;
    var lonGap = double.infinity;
    for (final shift in const [-360.0, 0.0, 360.0]) {
      final g = math.max(0.0, math.max(west, other.west + shift) - math.min(east, other.east + shift));
      lonGap = math.min(lonGap, g);
    }
    return lonGap <= gap;
  }
}

/// 国の本体の範囲。面積が最大のポリゴンを核に、隙間が [CountryIndex._clusterGapDegrees] 度以内の
/// ポリゴンを連鎖的に取り込んだ「かたまり」の外接矩形。遠い海外領土は含めない。
///
/// 経度は、-180〜180 のままの幅と、0〜360 に直した幅を比べて狭い方(同じなら前者)。
/// 後者のとき東が 180 を超えることがあるが、`west > east` にはならない
GeoBounds _mainlandBounds(List<_PolygonBox> boxes) {
  var core = 0;
  for (var i = 1; i < boxes.length; i++) {
    if (boxes[i].areaDeg2 > boxes[core].areaDeg2) core = i;
  }

  final inCluster = List<bool>.filled(boxes.length, false);
  inCluster[core] = true;
  final pending = [core];
  while (pending.isNotEmpty) {
    final current = boxes[pending.removeLast()];
    for (var j = 0; j < boxes.length; j++) {
      if (!inCluster[j] && current.isNear(boxes[j], CountryIndex._clusterGapDegrees)) {
        inCluster[j] = true;
        pending.add(j);
      }
    }
  }

  var south = double.infinity, north = double.negativeInfinity;
  var west = double.infinity, east = double.negativeInfinity;
  var mappedWest = double.infinity, mappedEast = double.negativeInfinity;
  for (var i = 0; i < boxes.length; i++) {
    if (!inCluster[i]) continue;
    final b = boxes[i];
    south = math.min(south, b.south);
    north = math.max(north, b.north);
    west = math.min(west, b.west);
    east = math.max(east, b.east);
    mappedWest = math.min(mappedWest, b.mappedWest);
    mappedEast = math.max(mappedEast, b.mappedEast);
  }
  // 幅が同じ(浮動小数点の誤差を除く)ときは、-180〜180 のままにする
  return (mappedEast - mappedWest) < (east - west) - 1e-9
      ? GeoBounds(south, mappedWest, north, mappedEast)
      : GeoBounds(south, west, north, east);
}

/// `[lon, lat]` の 1 点を読む。数でない・非有限・範囲外なら null
GeoPoint? _parsePoint(Object? raw) {
  if (raw is! List || raw.length < 2) return null;
  final lon = raw[0];
  final lat = raw[1];
  if (lon is! num || lat is! num) return null;
  final lonD = lon.toDouble();
  final latD = lat.toDouble();
  if (!lonD.isFinite || !latD.isFinite) return null;
  if (lonD < -180 || lonD > 180 || latD < -90 || latD > 90) return null;
  return GeoPoint(latD, lonD);
}
