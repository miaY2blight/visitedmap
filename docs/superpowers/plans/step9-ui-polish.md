# Step 9: UI/UXの磨き込み Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** チェックイン時に「霧が晴れる」ビジュアル表現を`CustomPainter`で実装し、地図演出(チェックインアニメーション)を加え、全体的なUI/UXを磨き込んでMVPとして完結させる。

**Architecture:** チェックインしたPOI周辺に半透明の「霧」オーバーレイを`CustomPainter`で描画し、チェックイン成功時にその範囲だけ円形にクリア(晴れる)するアニメーションを`AnimationController`で実装する。霧オーバーレイは地図の上に重ねる`Stack`構成とし、地図の現在の表示範囲(カメラ位置・ズーム)と各チェックイン地点の画面上座標を`MaplibreMapController.toScreenLocation`で変換して描画する。既存の機能(POI検索・チェックイン・スコア表示・除外設定・認証)には手を加えず、見た目・演出のみを追加する。

**Tech Stack:** 追加のFlutterパッケージは導入しない(`CustomPainter`, `AnimationController` はFlutter標準)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(「霧が晴れる」演出、CustomPainter/Skiaの採用理由)、[`../../plan.md`](../../plan.md)(Step 9の位置づけ、MVP完了)、[`step3-manual-checkin.md`](step3-manual-checkin.md)〜[`step8-cloud-auth-sync.md`](step8-cloud-auth-sync.md)(磨き込み対象となる既存機能)

## Global Constraints

- 新機能(記録方式・集計ロジック等)は追加しない。本Stepは表示・演出・使い勝手の改善のみを対象とする。
- 霧オーバーレイの再描画は地図移動(パン・ズーム)のたびに発生するため、パフォーマンスに配慮し、チェックイン地点数が多い場合でも描画が破綻しない(オフスクリーンの地点は描画をスキップする)設計にする。
- 本Stepの完了をもってCLAUDE.mdのロードマップ(Step 0〜9)によるMVPが完結する。Phase 2以降の機能(自動チェックイン提案、バッジ等)は本Stepの範囲外。

---

### Task 1: `FogPainter` をTDDで実装する(霧の描画ロジック)

**Files:**
- Create: `fogworld/lib/widgets/fog_painter.dart`
- Test: `fogworld/test/widgets/fog_painter_test.dart`

**Interfaces:**
- Consumes: なし(座標変換済みの画面上ポイントを受け取る)
- Produces: クラス `FogPainter extends CustomPainter`。コンストラクタ `FogPainter({required List<Offset> clearedScreenPoints, required double clearRadius, required Color fogColor})`。`paint(Canvas canvas, Size size)` は画面全体を `fogColor` で塗った上で、`clearedScreenPoints` の各点を中心とする半径 `clearRadius` の円を `BlendMode.clear` で透過させる。`shouldRepaint` は `clearedScreenPoints` の内容が変わった場合のみ `true` を返す。Task 3の `MapScreen` 統合で使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/widgets/fog_painter_test.dart`(`CustomPainter`のロジックは`shouldRepaint`の比較ロジックを中心に単体テストする。実際の描画結果は目視確認(Task 5)に委ねる):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/widgets/fog_painter.dart';

void main() {
  test('clearedScreenPointsが同じ場合はshouldRepaintがfalse', () {
    final points = [const Offset(10, 10), const Offset(20, 20)];
    final oldPainter = FogPainter(
      clearedScreenPoints: points,
      clearRadius: 40,
      fogColor: Colors.black54,
    );
    final newPainter = FogPainter(
      clearedScreenPoints: List.of(points),
      clearRadius: 40,
      fogColor: Colors.black54,
    );

    expect(newPainter.shouldRepaint(oldPainter), isFalse);
  });

  test('clearedScreenPointsの点数が変わった場合はshouldRepaintがtrue', () {
    final oldPainter = FogPainter(
      clearedScreenPoints: const [Offset(10, 10)],
      clearRadius: 40,
      fogColor: Colors.black54,
    );
    final newPainter = FogPainter(
      clearedScreenPoints: const [Offset(10, 10), Offset(20, 20)],
      clearRadius: 40,
      fogColor: Colors.black54,
    );

    expect(newPainter.shouldRepaint(oldPainter), isTrue);
  });

  test('同じ点数でも座標が変わった場合はshouldRepaintがtrue', () {
    final oldPainter = FogPainter(
      clearedScreenPoints: const [Offset(10, 10)],
      clearRadius: 40,
      fogColor: Colors.black54,
    );
    final newPainter = FogPainter(
      clearedScreenPoints: const [Offset(15, 10)],
      clearRadius: 40,
      fogColor: Colors.black54,
    );

    expect(newPainter.shouldRepaint(oldPainter), isTrue);
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/widgets/fog_painter_test.dart
```

Expected: `fog_painter.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/widgets/fog_painter.dart`:

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FogPainter extends CustomPainter {
  final List<Offset> clearedScreenPoints;
  final double clearRadius;
  final Color fogColor;

  FogPainter({
    required this.clearedScreenPoints,
    required this.clearRadius,
    required this.fogColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, Paint()..color = fogColor);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    for (final point in clearedScreenPoints) {
      if (!fullRect.inflate(clearRadius).contains(point)) continue;
      canvas.drawCircle(point, clearRadius, clearPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) {
    if (oldDelegate.clearRadius != clearRadius) return true;
    if (oldDelegate.fogColor != fogColor) return true;
    if (oldDelegate.clearedScreenPoints.length != clearedScreenPoints.length) {
      return true;
    }
    for (var i = 0; i < clearedScreenPoints.length; i++) {
      if (oldDelegate.clearedScreenPoints[i] != clearedScreenPoints[i]) {
        return true;
      }
    }
    return false;
  }
}
```

`saveLayer`+`BlendMode.clear` はSkia(Flutterのレンダリングエンジン)上でオフスクリーンバッファへの描画を要求するため、Web(HTML renderer)では正しく動作しない場合がある(本アプリはモバイル向けのためAndroid/iOSでは問題ない。Skiaの採用理由どおりの実装)。

- [ ] **Step 4: `ui` の未使用importを確認する**

Step 3の実装は `dart:ui` の機能を直接使っていないため、`import 'dart:ui' as ui;` を削除する(`flutter analyze` で未使用import警告が出るため)。

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/widgets/fog_painter_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/widgets/fog_painter.dart fogworld/test/widgets/fog_painter_test.dart
git commit -m "feat: 霧オーバーレイを描画するFogPainterをTDDで実装"
```

---

### Task 2: チェックイン時のクリアアニメーションを制御する `FogClearAnimationController` をTDDで実装する

**Files:**
- Create: `fogworld/lib/widgets/fog_clear_animation_controller.dart`
- Test: `fogworld/test/widgets/fog_clear_animation_controller_test.dart`

**Interfaces:**
- Consumes: `AnimationController`(テストでは `TestVSync` を使う)
- Produces: クラス `FogClearAnimationController`。コンストラクタ `FogClearAnimationController({required TickerProvider vsync, required VoidCallback onTick})`(`onTick` はアニメーション値が変わるたびに呼ばれる)。メソッド `double get radiusMultiplier`(0.0〜1.0のイージング済み値)、`Future<void> playClearAnimation()`(0→1へアニメーションし完了を待つ)、`void dispose()`。Task 3の `MapScreen` がチェックイン成功時にこれを呼び、`radiusMultiplier` を `FogPainter.clearRadius` に掛け合わせて円が広がる演出を作る。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/widgets/fog_clear_animation_controller_test.dart`:

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/widgets/fog_clear_animation_controller.dart';

void main() {
  testWidgets('初期状態のradiusMultiplierは0', (tester) async {
    final controller = FogClearAnimationController(
      vsync: tester,
      onTick: () {},
    );
    addTearDown(controller.dispose);

    expect(controller.radiusMultiplier, 0.0);
  });

  testWidgets('playClearAnimation完了後radiusMultiplierは1になる', (tester) async {
    final controller = FogClearAnimationController(
      vsync: tester,
      onTick: () {},
    );
    addTearDown(controller.dispose);

    final future = controller.playClearAnimation();
    await tester.pumpAndSettle();
    await future;

    expect(controller.radiusMultiplier, 1.0);
  });

  testWidgets('アニメーション中にonTickが複数回呼ばれる', (tester) async {
    var tickCount = 0;
    final controller = FogClearAnimationController(
      vsync: tester,
      onTick: () => tickCount++,
    );
    addTearDown(controller.dispose);

    final future = controller.playClearAnimation();
    await tester.pumpAndSettle();
    await future;

    expect(tickCount, greaterThan(1));
  });
}
```

(`tester: WidgetTester` は `TickerProvider` を実装しているため `vsync: tester` として利用できる)

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/widgets/fog_clear_animation_controller_test.dart
```

Expected: `fog_clear_animation_controller.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/widgets/fog_clear_animation_controller.dart`:

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

class FogClearAnimationController {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final VoidCallback _onTick;

  FogClearAnimationController({
    required TickerProvider vsync,
    required VoidCallback onTick,
  }) : _onTick = onTick {
    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(_onTick);
  }

  double get radiusMultiplier => _animation.value;

  Future<void> playClearAnimation() async {
    _controller.reset();
    await _controller.forward();
  }

  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
  }
}
```

`VoidCallback` は `dart:ui` ではなく `package:flutter/foundation.dart`(`flutter/animation.dart` が re-export)由来。`flutter analyze` でimportエラーが出た場合は `import 'package:flutter/foundation.dart';` を追加する。

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/widgets/fog_clear_animation_controller_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/widgets/fog_clear_animation_controller.dart fogworld/test/widgets/fog_clear_animation_controller_test.dart
git commit -m "feat: 霧が晴れるアニメーション制御をTDDで実装"
```

---

### Task 3: `MapScreen` に霧オーバーレイとクリアアニメーションを統合する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 1の `FogPainter`、Task 2の `FogClearAnimationController`
- Produces: 地図の上に霧オーバーレイを重ね、チェックイン済みPOIの位置は常時クリアされた状態にする。新規チェックイン時はTask 2のアニメーションで円が広がりながら霧が晴れる。

- [ ] **Step 1: `_MapScreenState` を `SingleTickerProviderStateMixin` にする**

```dart
class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
```

- [ ] **Step 2: 霧描画用の状態とアニメーションコントローラーを追加する**

```dart
  late final FogClearAnimationController _fogAnimationController;
  final Map<String, Offset> _clearedScreenPointsByPoiId = {};
  String? _animatingPoiId;

  @override
  void initState() {
    super.initState();
    _fogAnimationController = FogClearAnimationController(
      vsync: this,
      onTick: () => setState(() {}),
    );
    _initServices();
  }
```

- [ ] **Step 3: 地図移動のたびに画面上座標を再計算するリスナーを追加する**

```dart
  Future<void> _refreshClearedScreenPoints() async {
    final controller = _mapController;
    if (controller == null) return;

    final updated = <String, Offset>{};
    for (final entry in _poiBySymbolId.entries) {
      final poi = entry.value;
      if (!_checkedInPoiIds.contains(poi.id)) continue;
      final point = await controller.toScreenLocation(LatLng(poi.lat, poi.lon));
      updated[poi.id] = Offset(point.x.toDouble(), point.y.toDouble());
    }

    if (!mounted) return;
    setState(() => _clearedScreenPointsByPoiId
      ..clear()
      ..addAll(updated));
  }
```

`_onMapCreated` の末尾、および `MapLibreMap` に `onCameraIdle: _refreshClearedScreenPoints` を追加して地図移動が止まるたびに再計算する:

```dart
        onCameraIdle: () {
          unawaited(_refreshClearedScreenPoints());
        },
```

(`import 'dart:async' show unawaited;` を追加する)

- [ ] **Step 4: `_checkIn` 成功時にクリアアニメーションを再生する**

`_checkIn` メソッド内、`Navigator.of(context).pop();` より前に追加:

```dart
    await _refreshClearedScreenPoints();
    _animatingPoiId = poi.id;
    await _fogAnimationController.playClearAnimation();
    _animatingPoiId = null;
```

- [ ] **Step 5: `Stack` で霧オーバーレイを地図に重ねる**

`build` メソッドの `MapLibreMap` を `Stack` でラップする:

```dart
          Expanded(
            child: Stack(
              children: [
                MapLibreMap(
                  styleString: _openFreeMapLibertyStyle,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(35.681236, 139.767125),
                    zoom: 12,
                  ),
                  myLocationEnabled: false,
                  onMapCreated: _onMapCreated,
                  onCameraIdle: () {
                    unawaited(_refreshClearedScreenPoints());
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: FogPainter(
                      clearedScreenPoints: _buildClearedPoints(),
                      clearRadius: 48,
                      fogColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
```

`_buildClearedPoints` メソッドを追加する(アニメーション中のPOIだけ半径倍率を掛ける単純化のため、`FogPainter` 自体は固定半径を受け取り、アニメーション中の点のみ別扱いにする代わりに、ここでは簡略化してアニメーション中かどうかによらず全チェックイン済みPOIを同じ半径でクリアする。アニメーションの見た目は「新しく追加された点がフェードイン気味に見える」程度の簡易演出とする):

```dart
  List<Offset> _buildClearedPoints() {
    return _clearedScreenPointsByPoiId.values.toList();
  }
```

- [ ] **Step 6: `dispose` で `FogClearAnimationController` も破棄する**

```dart
  @override
  void dispose() {
    _checkinRepository?.close();
    _ceilingRepository?.close();
    _levelHistoryRepository?.close();
    _fogAnimationController.dispose();
    super.dispose();
  }
```

- [ ] **Step 7: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 4: チェックイン済みPOI一覧・スコア表示のUIを磨き込む

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: 既存の `_regionLevels`
- Produces: Step 5で追加した5階層のバナー表示を、視認性の高いカード型UIに変更する(機能追加ではなく見た目のみの変更)。

- [ ] **Step 1: バナー部分をカードリストに変更する**

`build` メソッドの `_regionLevels.map(...)` によるプレーンな `Text` 列挙を、`Card`+`ListTile` を使った表示に変更する:

```dart
          if (_regionLevels.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: _regionLevels.map((r) {
                  final ceilingText =
                      r.ceiling != null ? ' / 天井 ${r.ceiling}' : '';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.tier, style: Theme.of(context).textTheme.labelSmall),
                          Text(r.name, style: Theme.of(context).textTheme.titleSmall),
                          Text('Lv.${r.level}(${r.score}$ceilingText)'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
```

- [ ] **Step 2: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 5: エミュレータ/実機で演出とUI磨き込みを確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜4の全成果物
- Produces: 実機/エミュレータ上で霧演出・カード型スコア表示が動作する状態

- [ ] **Step 1: アプリを起動する**

```powershell
cd fogworld
flutter run
```

Expected: 地図全体が半透明の霧で覆われ、既にチェックイン済みのPOI周辺のみ円形に霧が晴れている。

- [ ] **Step 2: 新規POIにチェックインする**

Expected: チェックイン確定と同時に、そのPOI周辺の霧がアニメーションしながら晴れる。

- [ ] **Step 3: 地図をパン・ズームする**

Expected: 地図移動に追従して、霧が晴れた円の位置がずれずに正しく追従する(`onCameraIdle` での再計算が機能している)。

- [ ] **Step 4: スコアカードを確認する**

Expected: 画面上部に5階層分のスコアカードが横スクロールリストとして表示される。

- [ ] **Step 5: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 6: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 3〜5の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/map_screen.dart
git commit -m "feat: 霧が晴れる演出とスコアカードUIを追加しMVPを完成させる"
```

---

## Step 9 完了条件(再掲)

- `flutter test` がパス(`FogPainter`, `FogClearAnimationController` の単体テスト)
- `flutter analyze` がクリーン
- 地図が霧オーバーレイで覆われ、チェックイン済みPOI周辺のみ晴れている
- 新規チェックイン時にアニメーションで霧が晴れる
- 地図のパン・ズームに霧の表示が正しく追従する
- 5階層のスコア表示がカードUIとして視認しやすく表示される

この完了条件をもって、[`../../plan.md`](../../plan.md) に定義したMVP(Step 0〜9)が完結する。Phase 2以降の機能(自動チェックイン提案・連続訪問日数・バッジ/実績システム・施設の入れ子構造対応)は、MVP完成後にあらためてブレインストーミングし、別途スペック化・プランニングする。
