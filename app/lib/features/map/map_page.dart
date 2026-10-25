import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fogworld/app/message_presenter.dart';
import 'package:fogworld/core/data/location/geolocator_gateway.dart';
import 'package:fogworld/core/data/location/location_gateway.dart';
import 'package:fogworld/features/map/location_mover.dart';

/// 現在地が取れない場合の初期表示位置(東京駅)
const LatLng tokyoStation = LatLng(35.681236, 139.767125);

const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
// 東京駅フォールバック時は広域、現在地へ移動する時は街区が見えるズーム
const double _fallbackZoom = 11;
const double _currentLocationZoom = 15;
// この時間内にスタイルが読み込めなければ通信エラーとして案内する
const Duration _styleLoadTimeout = Duration(seconds: 15);
const Duration _ownMoveGrace = Duration(milliseconds: 300);
const String _mapLoadFailedMessage = '地図を読み込めません。通信環境を確認してください';
const String _reloadLabel = '再読み込み';
const String _reloadMapLabel = '地図を再読み込み';
// 帰属表示(OpenFreeMap / OpenStreetMap の利用条件)
const String _attribution = '© OpenStreetMap contributors';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  bool _locationEnabled = false;
  // 位置表示を有効にした時点の、許可されていた精度
  LocationPrecision? _displayPrecision;
  bool _restartingDisplay = false;
  late final MessagePresenter _messages = MessagePresenter(
    () => mounted ? ScaffoldMessenger.of(context) : null,
  );
  // 地図の準備前に来た移動先。準備後に実行する(準備前に呼ばれても失われないように)
  LatLng? _pendingTarget;
  Timer? _styleLoadTimer;
  // アプリ自身のカメラ移動中の件数(完了後も少し猶予を持たせて数える)。
  // これが0の間に来たカメラ移動は、利用者が地図を動かしたものとみなす
  int _ownMoves = 0;
  bool _userMoved = false;
  // 地図の初期化中に出るカメラ移動を、利用者の操作と誤認しないための目印
  bool _styleLoaded = false;
  bool _mapLoadFailed = false;
  late final LocationMover _mover;

  // 地図の再読み込み回数。MapLibreMap の Key に使う
  int _mapGeneration = 0;
  // 直近のカメラ位置。再読み込み後の初期位置に使う
  CameraPosition _camera = const CameraPosition(
    target: tokyoStation,
    zoom: _fallbackZoom,
  );

  @override
  void initState() {
    super.initState();
    _mover = LocationMover(
      gateway: const GeolocatorGateway(),
      showMessage: _messages.show,
      enableLocation: _enableLocation,
      moveCamera: _moveCamera,
      onStart: () => _userMoved = false,
      userMovedCamera: () => _userMoved,
    );
    _startStyleLoadTimer();
    _mover.moveToCurrentLocation();
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }

  void _startStyleLoadTimer() {
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(_styleLoadTimeout, () {
      if (!mounted) return;
      setState(() => _mapLoadFailed = true);
      // 表示中の別メッセージに握りつぶされないよう、置き換えて出す。
      // 自動では復帰しないため、利用者が再読み込みできるよう消えない通知にする
      _messages.show(
        _mapLoadFailedMessage,
        replaceCurrent: true,
        actionLabel: _reloadLabel,
        onAction: _reloadMap,
        persistent: true,
      );
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    final pending = _pendingTarget;
    if (pending != null) {
      _pendingTarget = null;
      _moveCamera(pending);
    }
  }

  void _onStyleLoaded() {
    if (!mounted) return;
    _styleLoadTimer?.cancel();
    // 遅れて読み込めた場合、消えない失敗の通知が残らないようにする
    if (_mapLoadFailed) _messages.dismiss();
    setState(() {
      _styleLoaded = true;
      _mapLoadFailed = false;
    });
  }

  void _enableLocation(LocationPrecision precision) {
    if (!mounted) return;
    final previous = _displayPrecision;
    _displayPrecision = precision;
    if (!_locationEnabled) {
      setState(() => _locationEnabled = true);
    } else if (previous == LocationPrecision.approximate &&
        precision == LocationPrecision.precise) {
      _restartLocationDisplay();
    }
  }

  // 位置表示は一度有効にすると、権限が「おおよそ」から「正確」に変わっても作り直されず、
  // 点が出ないままになる。いったん無効にしてから有効に戻して作り直す
  Future<void> _restartLocationDisplay() async {
    if (_restartingDisplay) return;
    _restartingDisplay = true;
    try {
      setState(() => _locationEnabled = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      setState(() => _locationEnabled = true);
    } finally {
      _restartingDisplay = false;
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) {
      _pendingTarget = target;
      return;
    }
    // アプリ自身の移動を基準に、その後の利用者の操作だけを数える
    _userMoved = false;
    _ownMoves++;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, _currentLocationZoom),
      );
    } finally {
      // 完了通知の後に遅れて届くカメラ移動を、利用者の操作と誤認しないための猶予
      Future<void>.delayed(_ownMoveGrace, () => _ownMoves--);
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (_styleLoaded && _ownMoves == 0) _userMoved = true;
    _camera = position;
  }

  void _reloadMap() {
    if (!mounted) return;
    setState(() {
      _mapGeneration++;
      _controller = null;
      _styleLoaded = false;
      _mapLoadFailed = false;
    });
    _startStyleLoadTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            key: ValueKey(_mapGeneration),
            styleString: _styleUrl,
            initialCameraPosition: _camera,
            myLocationEnabled: _locationEnabled,
            onMapCreated: _onMapCreated,
            // onCameraMove を受け取るには、カメラ位置の追跡を有効にする必要がある
            trackCameraPosition: true,
            onCameraMove: _onCameraMove,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
          // 地図が読み込めない間は、再読み込みの入口を常に見える形で出す
          // (通知はスワイプや時間経過で見えなくなり得るため)
          if (_mapLoadFailed)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: _reloadMap,
                    icon: const Icon(Icons.refresh),
                    label: const Text(_reloadMapLabel),
                  ),
                ),
              ),
            ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 8, bottom: 4),
              child: _AttributionLabel(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '現在地へ移動',
        onPressed: () => _mover.moveToCurrentLocation(userInitiated: true),
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _AttributionLabel extends StatelessWidget {
  const _AttributionLabel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          _attribution,
          style: TextStyle(fontSize: 10, color: Colors.black87),
        ),
      ),
    );
  }
}
