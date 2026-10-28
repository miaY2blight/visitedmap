import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:fogworld/app/message_presenter.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/data/location/geolocator_gateway.dart';
import 'package:fogworld/core/data/location/location_gateway.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/features/map/camera_fit.dart';
import 'package:fogworld/features/map/draft_overlay.dart';
import 'package:fogworld/features/map/location_mover.dart';
import 'package:fogworld/features/map/map_providers.dart';
import 'package:fogworld/features/map/map_style.dart';
import 'package:fogworld/features/map/overlay_layers.dart';
import 'package:fogworld/features/map/saved_overlay.dart';
import 'package:fogworld/features/map/saved_sheet.dart';
import 'package:fogworld/features/map/search_pill.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:fogworld/features/record_spot/application/providers.dart';
import 'package:fogworld/features/record_spot/application/record_draft.dart';
import 'package:fogworld/features/record_spot/presentation/record_panel.dart';
import 'package:fogworld/features/record_spot/presentation/widgets/shape_geojson.dart';

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

// 保存した形の薄い表示(GeoJSON のソースと、面・線のレイヤー)
const String _savedSourceId = 'saved-spots';
const String _savedFillLayerId = 'saved-spots-fill';
const String _savedLineLayerId = 'saved-spots-line';
const double _savedFillOpacity = 0.24;
const double _savedLineWidth = 2;
// 範囲へ寄せるときの余白(camera_fit.dart の mapFocusPadding。大陸の表の幅の見積もりと同じ値を使う)
const EdgeInsets _focusPadding = mapFocusPadding;
// 「記録しました」のシートが下を覆うときの余白
const EdgeInsets _focusPaddingWithSheet = EdgeInsets.fromLTRB(32, 140, 32, 260);

/// 地図画面に重ねる保存した形の層(下から: 面、線)。
/// 地図のタップをふさがないよう、どちらも `enableInteraction: false` にする
@visibleForTesting
List<OverlayLayerSpec> savedOverlayLayerSpecs() => const [
  OverlayLayerSpec(
    sourceId: _savedSourceId,
    layerId: _savedFillLayerId,
    properties: FillLayerProperties(
      fillColor: MapPalette.accentHex,
      fillOpacity: _savedFillOpacity,
    ),
  ),
  OverlayLayerSpec(
    sourceId: _savedSourceId,
    layerId: _savedLineLayerId,
    properties: LineLayerProperties(lineColor: MapPalette.accentHex, lineWidth: _savedLineWidth),
  ),
];

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
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
  CameraPosition _camera = const CameraPosition(target: tokyoStation, zoom: _fallbackZoom);

  // 今の地図(controller)に、保存した形のソースとレイヤーを足し終えたか。
  // 地図の作り直し・スタイルの読み込みのたびに false に戻し、足し直す
  bool _overlayAdded = false;
  bool _overlaySyncing = false;
  // 更新中に、さらに更新の依頼が来たか(終わったあとにもう一度行う)
  bool _overlayDirty = false;
  // 地図の準備前に来た、範囲への移動(地名の移動・記録した形へ寄せる)。準備後に行う
  CameraUpdate? _pendingFocus;
  // 表示中の「記録しました」のシートの記録(なければ null)
  SavedSpot? _sheetSpot;
  // 記録中の形(塗り・縁・点)を、この地図に描く
  final DraftOverlay _draft = DraftOverlay();

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
    // 地図を開く前に出ていた依頼(地名の移動・記録の知らせ)も受け取る。
    // build 中は Provider を変えられないため、最初のフレームのあとに行う
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onMoveRequest(ref.read(mapMoveRequestProvider));
      _onSavedSpot(ref.read(savedSheetProvider));
    });
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }

  /// 地図の長押し。記録中でなければ、その位置に点を置いて記録を始める(広すぎる地図では始めず、通知する)。
  /// 点+半径で記録中なら、中心をその位置へ動かす。座標は渡すだけで、保存しない(NFR-2)
  void _onMapLongPress(GeoPoint point) {
    final before = ref.read(recordDraftProvider);
    ref.read(recordDraftProvider.notifier).longPress(point, ref.read(mapViewportProvider));
    final after = ref.read(recordDraftProvider);
    if (after != null && (before == null || before.center != after.center)) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  // ---------------------------------------------------------------- 記録中の形

  /// 記録中の形を、地図に合わせる(描く内容が変わったとき)
  void _syncDraft() {
    unawaited(
      _draft.sync(() => _styleLoaded ? _controller : null, () => ref.read(recordDraftProvider)),
    );
  }

  /// 記録中の状態の変化を受ける: 形を描き直す。形・円に地図を合わせる頼みと、通知があれば行う
  void _onDraft(RecordDraftState? previous, RecordDraftState? next) {
    if (!mounted) return;
    _syncDraft();
    if (next == null) return;
    if (previous == null) {
      // 記録を始めたら、前の「記録しました」のシートは閉じる(パネルと重ならないように)
      if (_sheetSpot != null) setState(() => _sheetSpot = null);
    }
    final newDraft = previous == null || previous.id != next.id;
    if (next.fitSeq > 0 && (newDraft || previous.fitSeq != next.fitSeq)) _fitDraft(next);
    final message = next.message;
    if (message != null && (newDraft || previous.messageSeq != next.messageSeq)) {
      _showAbovePanel(message);
    }
  }

  /// 記録の通知を出す。パネルが出ているときは、パネルの上に浮かせる(「記録する」を覆わないため)
  void _showAbovePanel(String message) {
    final recording = ref.read(recordDraftProvider) != null;
    final bottom = recording
        ? MediaQuery.viewInsetsOf(context).bottom + MediaQuery.sizeOf(context).height / 3 + 8
        : null;
    _messages.show(message, replaceCurrent: true, bottomMargin: bottom);
  }

  /// 形・円に地図を合わせる。下はパネルの高さの分を空ける。長押しで始めたとき・点を動かしたときは呼ばない
  void _fitDraft(RecordDraftState s) {
    final bounds = ShapeGeoJson.fitBounds(s.displayShape, s.center);
    if (bounds == null) return;
    final panelHeight = MediaQuery.sizeOf(context).height / 3;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final update = cameraUpdateForBounds(
      bounds,
      padding: EdgeInsets.fromLTRB(32, 140, 32, keyboard + panelHeight + 24),
    );
    if (update != null) unawaited(_focus(update));
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
    // 新しい地図には、保存した形・記録中の形のレイヤーがまだ無い
    _overlayAdded = false;
    _draft.reset();
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
    // スタイルを読み込むと、足したソースとレイヤーは消える。足し直す
    _overlayAdded = false;
    _draft.reset();
    unawaited(_syncOverlay());
    _syncDraft();
    unawaited(_updateViewport());
    final focus = _pendingFocus;
    if (focus != null) {
      _pendingFocus = null;
      unawaited(_focus(focus));
    }
  }

  // ---------------------------------------------------------------- 表示範囲

  /// 地図の今の表示範囲と拡大率を [mapViewportProvider] に入れる。読めなければ前の値のまま
  Future<void> _updateViewport() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) return;
    try {
      final region = await controller.getVisibleRegion();
      if (!mounted || controller != _controller) return;
      final zoom = controller.cameraPosition?.zoom ?? _camera.zoom;
      ref
          .read(mapViewportProvider.notifier)
          .set(MapViewport(bounds: boundsFromLatLng(region), zoom: zoom));
    } on Object {
      // 地図の作り直しの途中などで読めないことがある。次のカメラの停止で読み直す
    }
  }

  // ---------------------------------------------------------------- 保存した形の薄い表示

  /// 保存した形のソースを、今の一覧に合わせる。まだ足していなければ、ソースとレイヤーを足す。
  ///
  /// 失敗しても落とさない(次の更新・スタイルの読み込みで足し直す)。同時には 1 つだけ実行する
  Future<void> _syncOverlay() async {
    if (_overlaySyncing) {
      _overlayDirty = true;
      return;
    }
    _overlaySyncing = true;
    try {
      do {
        _overlayDirty = false;
        final controller = _controller;
        final spots = ref.read(savedSpotsProvider).value;
        if (!mounted || controller == null || !_styleLoaded || spots == null) return;
        // 頂点の予算は SavedOverlay が守る(大きすぎる GeoJSON は地図が落ちる)
        final geojson =
            jsonDecode(SavedOverlay.featureCollectionJson(spots)) as Map<String, dynamic>;
        try {
          if (_overlayAdded) {
            await controller.setGeoJsonSource(_savedSourceId, geojson);
          } else {
            await _addOverlay(controller, geojson);
            if (controller == _controller) _overlayAdded = true;
          }
        } on Object {
          // 内容(座標)を含み得るため、エラーの中身はログに出さない(NFR-2)
          debugPrint('保存した形の表示を更新できませんでした');
          if (controller == _controller) _overlayAdded = false;
        }
      } while (_overlayDirty && mounted);
    } finally {
      _overlaySyncing = false;
    }
  }

  /// 保存した形のソースとレイヤーを足す。同じ ID が残っていれば、先に消す(重複の追加はエラーになる)
  Future<void> _addOverlay(MapLibreMapController controller, Map<String, dynamic> geojson) async {
    for (final layer in [_savedLineLayerId, _savedFillLayerId]) {
      try {
        await controller.removeLayer(layer);
      } on Object {
        // 無ければ何もしない
      }
    }
    try {
      await controller.removeSource(_savedSourceId);
    } on Object {
      // 無ければ何もしない
    }
    await controller.addGeoJsonSource(_savedSourceId, geojson);
    await addOverlayLayers(controller.addLayer, savedOverlayLayerSpecs());
  }

  // ---------------------------------------------------------------- 範囲への移動・記録の知らせ

  /// 地名の移動の依頼を受け取り、その範囲へ地図を寄せる。受け取ったら依頼を消す
  void _onMoveRequest(MapMoveRequest? request) {
    if (request == null || !mounted) return;
    ref.read(mapMoveRequestProvider.notifier).clear();
    // 国の範囲は、180 度線をまたぐと東が 180 を超える。地図に渡せる経度に直してから寄せる
    final update = cameraUpdateForMoveRequest(request.bounds, padding: _focusPadding);
    if (update != null) unawaited(_focus(update));
  }

  /// 記録の知らせを受け取り、「記録しました」のシートを出して、記録した形へ寄せる。受け取ったら知らせを消す
  void _onSavedSpot(SavedSpot? spot) {
    if (spot == null || !mounted) return;
    ref.read(savedSheetProvider.notifier).clear();
    setState(() => _sheetSpot = spot);
    final update = cameraUpdateForSpot(spot, padding: _focusPaddingWithSheet);
    if (update != null) unawaited(_focus(update));
  }

  /// 地図を [update] で動かす。地図の準備前なら、準備後に行う。失敗しても落とさない
  Future<void> _focus(CameraUpdate update) async {
    if (!mounted) return;
    // 利用者が選んだ場所への移動なので、遅れて届いた現在地で上書きしない
    _userMoved = true;
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      _pendingFocus = update;
      return;
    }
    try {
      await controller.animateCamera(update);
    } on Object {
      // 地図の作り直しの途中などで動かせないことがある。利用者が自分で動かせる
    }
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
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, _currentLocationZoom));
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
    // 保存した形の一覧が読み直されたら(記録の保存のあと)、地図のソースを更新する
    ref.listen(savedSpotsProvider, (previous, next) {
      if (next.hasValue) unawaited(_syncOverlay());
    });
    ref.listen(mapMoveRequestProvider, (previous, next) => _onMoveRequest(next));
    ref.listen(savedSheetProvider, (previous, next) => _onSavedSpot(next));
    ref.listen<RecordDraftState?>(recordDraftProvider, _onDraft);
    // 記録中でないときの通知(広すぎる地図での長押し)
    ref.listen(draftNoticeProvider, (previous, next) {
      final text = next.text;
      if (text != null && next.seq != previous?.seq) _showAbovePanel(text);
    });
    final recording = ref.watch(recordDraftProvider.select((s) => s != null));
    final viewport = ref.watch(mapViewportProvider);
    final savedCount = ref.watch(savedSpotsProvider).value?.length;
    final sheetSpot = _sheetSpot;

    return PopScope(
      // 記録中の戻る操作は、記録をやめる(アプリを閉じない)
      canPop: !recording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 保存中は閉じない(結果の通知や、保存後のシートが宙に浮かないように)
        if (ref.read(recordDraftProvider)?.saving ?? false) return;
        ref.read(recordDraftProvider.notifier).close();
      },
      child: Scaffold(
        // キーボードが出ても、地図の大きさを変えない(カメラが跳ねないように)。パネルは自分で持ち上げる
        resizeToAvoidBottomInset: false,
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
              onCameraIdle: () => unawaited(_updateViewport()),
              onStyleLoadedCallback: _onStyleLoaded,
              // 長押しで、その位置に点を置いて記録を始める
              onMapLongClick: (_, latLng) =>
                  _onMapLongPress(GeoPoint(latLng.latitude, latLng.longitude)),
            ),
            // 上端: 検索ボックス(右は現在地ボタンのための余白)、その下に再読み込みの入口とチップ
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 60, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: double.infinity, child: SearchPill()),
                    // 地図が読み込めない間は、再読み込みの入口を常に見える形で出す
                    // (通知はスワイプや時間経過で見えなくなり得るため)
                    if (_mapLoadFailed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: FilledButton.icon(
                            onPressed: _reloadMap,
                            icon: const Icon(Icons.refresh),
                            label: const Text(_reloadMapLabel),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    MapChips(viewport: viewport, savedCount: savedCount),
                  ],
                ),
              ),
            ),
            // 右上: 現在地ボタン(ゴールモックの位置。検索ボックスの右の余白 60 に置く)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 10),
                  child: LocateButton(
                    onPressed: () => _mover.moveToCurrentLocation(userInitiated: true),
                  ),
                ),
              ),
            ),
            // 出典の表示(NFR-6)。記録の固定パネルが出ている間は、その上に出す
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  bottom: 4 + (recording ? MediaQuery.sizeOf(context).height / 3 : 0),
                ),
                child: const _AttributionLabel(),
              ),
            ),
            // 記録の固定パネル(画面の約 1/3。キーボードが出たら、その上に持ち上げる)
            if (recording)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.viewInsetsOf(context).bottom,
                height: MediaQuery.sizeOf(context).height / 3,
                child: const RecordPanel(),
              ),
          ],
        ),
        // 記録のあとのシート(地図の上に重ね、操作を止めない)
        bottomSheet: sheetSpot == null
            ? null
            : SavedSheet(
                key: ObjectKey(sheetSpot),
                spot: sheetSpot,
                onClose: () => setState(() => _sheetSpot = null),
              ),
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
        child: Text(_attribution, style: TextStyle(fontSize: 10, color: Colors.black87)),
      ),
    );
  }
}
