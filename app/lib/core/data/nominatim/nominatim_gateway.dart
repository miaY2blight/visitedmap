import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/result.dart';

/// Nominatim(場所の検索)への窓口。実機では HTTP で通信し、テストでは差し替える。
/// 失敗は例外ではなく [NominatimFailure] で返す。
abstract class NominatimGateway {
  /// 施設を名前で検索する。[requestBox] の内側だけを対象にする。
  /// 該当が無いときは `Err(notFound)` ではなく、空のリストの `Ok` を返す
  Future<Result<List<FacilityHit>, NominatimFailure>> searchFacilities(
    String query,
    GeoBounds requestBox,
  );

  /// 場所(地名・広域の地点)を名前で検索する。[requestBox] があればその内側だけを対象にし、
  /// null なら範囲を限定しない。外部へ送ってよい位置は [requestBox] の 4 値だけ
  Future<Result<List<PlaceHit>, NominatimFailure>> searchPlaces(
    String query, {
    GeoBounds? requestBox,
  });

  /// [osmRef](`N123` / `W123` / `R123`)の形を取得する。
  /// 成功値は Nominatim の `geojson`(デコード済みの `Map`)。検証は `ShapeValidator` が行う。
  /// 形が無い場合は `Err(notFound)`
  Future<Result<Object, NominatimFailure>> lookupGeometry(String osmRef);
}
