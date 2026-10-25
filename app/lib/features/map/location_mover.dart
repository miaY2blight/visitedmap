import 'package:fogworld/core/data/location/location_gateway.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const String locationUnavailableMessage = '位置情報が利用できません。設定で権限と位置情報をオンにしてください';
const String locationFailedMessage = '現在地を取得できませんでした';
const String approximateLocationMessage =
    'おおよその位置のみ許可されています。設定で位置情報の権限を「正確な位置」に変更してください';

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

  /// 位置の表示を有効にする。許可されている精度を渡す
  final void Function(LocationPrecision precision) enableLocation;
  final Future<void> Function(LatLng target) moveCamera;
  // 実行の開始時に呼ぶ(利用者の地図操作の記録をリセットする)
  final void Function()? onStart;
  // 実行開始後に利用者が地図を動かしたか。動かした後は勝手に再移動しない
  final bool Function()? userMovedCamera;

  // 拒否が固定されている状態。checkPermission では判別できないため、
  // requestPermission の結果で記録する。固定中に再要求すると権限画面が一瞬起動して地図が再描画される
  bool _blocked = false;
  // 「正確な位置」への切り替えを要求済みで、なお「おおよその位置」のままの状態。
  // 拒否が固定されているかは判別できないため、同じセッションでは再要求しない
  bool _upgradeBlocked = false;
  bool _running = false;
  // 今回の実行で権限を要求したか。利用者が今まさに精度を選んだ直後に、聞き返さないために使う
  bool _askedPermissionThisRun = false;

  /// [userInitiated] は、利用者がボタンを押した場合に true にする。
  /// 「おおよその位置」のみの許可は、利用者が押した時にだけ「正確な位置」への切り替えを要求する
  /// (起動のたびに権限ダイアログを出して煩わせないため)
  Future<void> moveToCurrentLocation({bool userInitiated = false}) async {
    if (_running) return;
    _running = true;
    _askedPermissionThisRun = false;
    onStart?.call();
    try {
      await _run(userInitiated);
    } catch (_) {
      showMessage(locationFailedMessage);
    } finally {
      _running = false;
    }
  }

  Future<void> _run(bool userInitiated) async {
    if (!await _ensureAccess()) {
      showMessage(locationUnavailableMessage);
      return;
    }

    var precision = await gateway.checkPrecision();
    if (precision == LocationPrecision.approximate &&
        userInitiated &&
        !_upgradeBlocked &&
        !_askedPermissionThisRun) {
      await gateway.requestAccess();
      precision = await gateway.checkPrecision();
      if (precision == LocationPrecision.approximate) _upgradeBlocked = true;
    }
    enableLocation(precision);
    if (precision == LocationPrecision.approximate) {
      showMessage(approximateLocationMessage);
    }

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
      _askedPermissionThisRun = true;
      access = await gateway.requestAccess();
      _blocked = access == LocationAccess.deniedForever;
    }
    // 設定アプリで許可された場合は固定状態を解除する
    if (access == LocationAccess.granted) _blocked = false;
    return access == LocationAccess.granted;
  }
}
