import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/search/place_kind.dart';

/// Nominatim への問い合わせが失敗した理由
enum NominatimFailure {
  /// 通信できない(機内モード、圏外など)
  offline,

  /// 応答が時間内に返らない
  timeout,

  /// 混雑(429 / 503)またはクールダウン中。自動では再試行しない
  busy,

  /// 応答が壊れている(JSON でない、必須項目が無い、など)
  badResponse,

  /// 該当する場所が無い
  notFound,

  /// 停止スイッチ(配布前に、規約・負荷の都合で検索を止めるための口)が有効で、通信しなかった
  disabled,
}

/// 施設の検索結果 1 件
class FacilityHit {
  const FacilityHit({
    required this.osmRef,
    required this.name,
    required this.address,
    required this.typeLabel,
    required this.point,
    required this.tags,
    this.geometry,
  });

  /// OSM の参照。`N123`(点)/ `W123`(線・面)/ `R123`(関係)
  final String osmRef;
  final String name;
  final String address;

  /// 種別の表示名(例: 博物館・美術館)
  final String typeLabel;
  final GeoPoint point;
  final FacilityTags tags;

  /// Nominatim の `geojson`(デコード済み。無ければ null)。
  /// 候補のまとめの判定にだけ使い、保存する形には使わない
  /// (保存の形は `lookupGeometry` の結果を `ShapeValidator` に通す)
  final Object? geometry;
}

/// 場所(地名)の検索結果 1 件
class PlaceHit {
  const PlaceHit({
    required this.osmRef,
    required this.name,
    required this.address,
    required this.bounds,
    required this.center,
    required this.kind,
    this.landmarkLabel,
    this.importance,
  });

  final String osmRef;
  final String name;
  final String address;
  final GeoBounds bounds;
  final GeoPoint center;
  final PlaceKind kind;

  /// 広域の地点の種類の表示ラベル(「湖」「山」「国立公園・保護区」など)。地名(行政区など)では null
  final String? landmarkLabel;

  /// Nominatim の重要度(`importance`)。応答に無い・数でないときは null
  final double? importance;
}
