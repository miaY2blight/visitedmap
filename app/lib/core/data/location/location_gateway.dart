import 'package:maplibre_gl/maplibre_gl.dart';

/// 位置情報の権限状態(geolocator に依存しない形)
enum LocationAccess { granted, denied, deniedForever }

/// 許可されている位置の精度。おおよその位置のみだと、施設単位の検索やチェックインに使えない
enum LocationPrecision { precise, approximate }

/// 位置情報へのアクセス。実機では geolocator を使い、テストでは差し替える
abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationAccess> checkAccess();
  Future<LocationAccess> requestAccess();

  /// 位置情報が許可されている場合の精度
  Future<LocationPrecision> checkPrecision();
  Future<LatLng?> lastKnown();
  Future<LatLng> current();
  double distanceMeters(LatLng a, LatLng b);
}
