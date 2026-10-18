import 'package:maplibre_gl/maplibre_gl.dart';

/// 位置情報の権限状態(geolocator に依存しない形)
enum LocationAccess { granted, denied, deniedForever }

/// 位置情報へのアクセス。実機では geolocator を使い、テストでは差し替える
abstract class LocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationAccess> checkAccess();
  Future<LocationAccess> requestAccess();
  Future<LatLng?> lastKnown();
  Future<LatLng> current();
  double distanceMeters(LatLng a, LatLng b);
}

const String locationUnavailableMessage = '位置情報が利用できません。設定で権限と位置情報をオンにしてください';
const String locationFailedMessage = '現在地を取得できませんでした';

/// 直近位置と新規測位がこの距離(m)以上ずれた時だけ再移動する
const double refineThresholdMeters = 50;

/// 「現在地へ移動する」処理。連打しても同時に1つしか走らない
class LocationMover {
  LocationMover({
    required this.gateway,
    required this.showMessage,
    required this.enableLocation,
    required this.moveCamera,
    this.onStart,
    this.userMovedCamera,
  });

  final LocationGateway gateway;
  final void Function(String message) showMessage;
  final void Function() enableLocation;
  final Future<void> Function(LatLng target) moveCamera;
  // 実行の開始時に呼ぶ(利用者の地図操作の記録をリセットする)
  final void Function()? onStart;
  // 実行開始後に利用者が地図を動かしたか。動かした後は勝手に再移動しない
  final bool Function()? userMovedCamera;

  // 拒否が固定されている状態。checkPermission では判別できないため、
  // requestPermission の結果で記録する。固定中に再要求すると権限画面が一瞬起動して地図が再描画される
  bool _blocked = false;
  bool _running = false;

  Future<void> moveToCurrentLocation() async {
    if (_running) return;
    _running = true;
    onStart?.call();
    try {
      await _run();
    } catch (_) {
      showMessage(locationFailedMessage);
    } finally {
      _running = false;
    }
  }

  Future<void> _run() async {
    if (!await _ensureAccess()) {
      showMessage(locationUnavailableMessage);
      return;
    }
    enableLocation();

    // 新規測位は数秒かかるため、端末が保持する直近の位置へ先に移動して即応させる
    final lastKnown = await gateway.lastKnown();
    if (lastKnown != null) await moveCamera(lastKnown);

    try {
      final current = await gateway.current();
      // 直近位置へ移動済みで、その後に利用者が地図を動かしたなら、補正で引き戻さない
      final userTookOver = lastKnown != null && (userMovedCamera?.call() ?? false);
      final moved = lastKnown == null ||
          (!userTookOver &&
              gateway.distanceMeters(lastKnown, current) > refineThresholdMeters);
      if (moved) await moveCamera(current);
    } catch (_) {
      // 直近位置へ移動済みなら、測位失敗は利用者に見せない
      if (lastKnown == null) showMessage(locationFailedMessage);
    }
  }

  Future<bool> _ensureAccess() async {
    if (!await gateway.isServiceEnabled()) return false;
    var access = await gateway.checkAccess();
    if (access == LocationAccess.denied && !_blocked) {
      access = await gateway.requestAccess();
      _blocked = access == LocationAccess.deniedForever;
    }
    // 設定アプリで許可された場合は固定状態を解除する
    if (access == LocationAccess.granted) _blocked = false;
    return access == LocationAccess.granted;
  }
}
