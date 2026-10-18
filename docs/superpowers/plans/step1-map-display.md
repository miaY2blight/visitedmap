# Step 1: 地図表示のみ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `maplibre_gl` + OpenFreeMapベクタータイルで地図を表示し、`geolocator` で取得した現在地を地図上にマーカー表示する。　

**Architecture:** `LocationProvider` インターフェースで位置情報取得を抽象化し、`GeolocatorLocationProvider`(実装)と `LocationService`(権限確認〜取得のフロー制御)に分離する。`LocationService` はモックで単体テストし、`GeolocatorLocationProvider` 自体と地図描画は実機/エミュレータでの目視確認とする(プラットフォームネイティブビューはウィジェットテストで検証できないため)。`MapScreen` は `MapLibreMap` ウィジェットを配置し、`onMapCreated` 後に現在地を取得してカメラ移動・シンボル追加を行う。

**Tech Stack:** `maplibre_gl` ^0.27.0、`geolocator` ^14.0.3、`mocktail`(テスト用、コード生成不要のモックライブラリ)。スタイルは OpenFreeMap の `https://tiles.openfreemap.org/styles/liberty`(2026-09-04時点でWebFetch確認済み。`bright`・`positron` も同一パターンで提供されているが本Stepでは `liberty` を採用)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)、[`../../plan.md`](../../plan.md)(Step 1の位置づけ)、[`step0-env-setup.md`](step0-env-setup.md)(前提となる `fogworld/` プロジェクト作成)

## Global Constraints

- POI検索・チェックイン等、Step 2以降の機能は実装しない。本Stepは「地図表示+現在地表示」のみ。
- 実機/エミュレータでの確認はAndroidを対象とする(Step 0と同様、iOS確認はmacOS環境が別途必要なため対象外)。
- 地図スタイルは `https://tiles.openfreemap.org/styles/liberty` を使用する(2026-09-04にWebFetchで存在確認済み)。
- `maplibre_gl` 0.27.0 は Flutter 3.29以上・Dart 3.7以上が必要(2026-09-04にpub.devで確認済み)。Step 0で導入したFlutter SDKがこの要件を満たすことをTask 1で確認する。

---

### Task 1: パッケージ追加とバージョン要件確認

**Files:**
- Modify: `fogworld/pubspec.yaml`

**Interfaces:**
- Consumes: なし
- Produces: `maplibre_gl`, `geolocator` の依存関係、`mocktail` のdev依存関係が解決された状態

- [ ] **Step 1: Flutter/Dartのバージョンが要件を満たすか確認する**

```powershell
flutter --version
```

Expected: Flutter 3.29以上、Dart 3.7以上と表示される。満たさない場合は `flutter upgrade` を実行する。

- [ ] **Step 2: `pubspec.yaml` に依存関係を追加する**

`fogworld/pubspec.yaml` の `dependencies:` セクションに追加:

```yaml
dependencies:
  flutter:
    sdk: flutter
  maplibre_gl: ^0.27.0
  geolocator: ^14.0.3
```

`dev_dependencies:` セクションに追加:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

- [ ] **Step 3: 依存関係を解決する**

```powershell
cd fogworld
flutter pub get
```

Expected: エラーなく完了し、`pubspec.lock` が更新される。

---

### Task 2: Android側の権限・設定を追加する

**Files:**
- Modify: `fogworld/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: なし
- Produces: アプリがインターネット通信・位置情報取得を行うための権限が付与された状態

- [ ] **Step 1: `AndroidManifest.xml` を開き、`<manifest>` タグ直下(`<application>` タグより前)に権限を追加する**

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 2: ファイル全体の構造が壊れていないことを確認する**

```powershell
Get-Content fogworld\android\app\src\main\AndroidManifest.xml
```

Expected: `<manifest ...>` 直下に上記3つの `<uses-permission>` が存在し、その下に既存の `<application ...>` ブロックが続く。

---

### Task 3: `LocationProvider` インターフェースと `GeolocatorLocationProvider` を作成する

**Files:**
- Create: `fogworld/lib/services/location_provider.dart`

**Interfaces:**
- Consumes: `geolocator` パッケージの `Geolocator` 静的API
- Produces: 抽象クラス `LocationProvider`(メソッド: `Future<bool> isLocationServiceEnabled()`, `Future<LocationPermission> checkPermission()`, `Future<LocationPermission> requestPermission()`, `Future<Position> getCurrentPosition()` — いずれも `geolocator` パッケージの `LocationPermission`, `Position` 型をそのまま使う)。具象クラス `GeolocatorLocationProvider implements LocationProvider`。Task 4の `LocationService` がこれをコンストラクタで受け取って利用する。

- [ ] **Step 1: `location_provider.dart` を作成する**

```dart
import 'package:geolocator/geolocator.dart';

abstract class LocationProvider {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
}

class GeolocatorLocationProvider implements LocationProvider {
  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition();
  }
}
```

このファイルには単体テストを書かない(`geolocator` パッケージ自体・プラットフォームチャネルへの薄いラッパーのため。Task 7の実機確認で動作を検証する)。

- [ ] **Step 2: コンパイルが通ることを確認する**

```powershell
cd fogworld
flutter analyze lib/services/location_provider.dart
```

Expected: `No issues found!`

---

### Task 4: `LocationService` をTDDで実装する(権限フロー制御)

**Files:**
- Create: `fogworld/lib/services/location_service.dart`
- Test: `fogworld/test/services/location_service_test.dart`

**Interfaces:**
- Consumes: Task 3で定義した `LocationProvider` インターフェース
- Produces: クラス `LocationService`。コンストラクタ `LocationService(LocationProvider provider)`。メソッド `Future<Position> determinePosition()` — サービス無効時・権限拒否時は `LocationServiceException`(本タスクで定義する例外クラス)を投げ、権限OK時は `provider.getCurrentPosition()` の結果を返す。Task 5の `MapScreen` がこの `determinePosition()` を呼び出す。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/location_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fogworld/services/location_provider.dart';
import 'package:fogworld/services/location_service.dart';

class MockLocationProvider extends Mock implements LocationProvider {}

class FakePosition extends Fake implements Position {}

void main() {
  late MockLocationProvider mockProvider;
  late LocationService service;

  setUp(() {
    mockProvider = MockLocationProvider();
    service = LocationService(mockProvider);
  });

  test('位置情報サービスが無効な場合、LocationServiceExceptionを投げる', () async {
    when(() => mockProvider.isLocationServiceEnabled())
        .thenAnswer((_) async => false);

    expect(
      () => service.determinePosition(),
      throwsA(isA<LocationServiceException>()),
    );
  });

  test('権限がdeniedのままの場合、LocationServiceExceptionを投げる', () async {
    when(() => mockProvider.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(() => mockProvider.checkPermission())
        .thenAnswer((_) async => LocationPermission.denied);
    when(() => mockProvider.requestPermission())
        .thenAnswer((_) async => LocationPermission.denied);

    expect(
      () => service.determinePosition(),
      throwsA(isA<LocationServiceException>()),
    );
  });

  test('権限がwhileInUseの場合、現在地を返す', () async {
    final fakePosition = FakePosition();
    when(() => mockProvider.isLocationServiceEnabled())
        .thenAnswer((_) async => true);
    when(() => mockProvider.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => mockProvider.getCurrentPosition())
        .thenAnswer((_) async => fakePosition);

    final result = await service.determinePosition();

    expect(result, same(fakePosition));
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/location_service_test.dart
```

Expected: `location_service.dart` が存在しないためコンパイルエラーで失敗する。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/location_service.dart`:

```dart
import 'package:geolocator/geolocator.dart';
import 'location_provider.dart';

class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}

class LocationService {
  final LocationProvider _provider;

  LocationService(this._provider);

  Future<Position> determinePosition() async {
    final serviceEnabled = await _provider.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException('Location services are disabled.');
    }

    var permission = await _provider.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _provider.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permissions are permanently denied.',
      );
    }

    return _provider.getCurrentPosition();
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/location_service_test.dart
```

Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/ fogworld/test/services/ fogworld/pubspec.yaml fogworld/pubspec.lock fogworld/android/app/src/main/AndroidManifest.xml
git commit -m "feat: 位置情報取得のLocationService/LocationProviderをTDDで実装"
```

---

### Task 5: `MapScreen` に地図を表示する

**Files:**
- Create: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: `maplibre_gl` の `MapLibreMap` ウィジェット
- Produces: ウィジェット `MapScreen extends StatefulWidget`。Task 6で `main.dart` から呼び出す。

- [ ] **Step 1: `map_screen.dart` を作成する**

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const _openFreeMapLibertyStyle = 'https://tiles.openfreemap.org/styles/liberty';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MaplibreMapController? _mapController;

  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FogWorld')),
      body: MapLibreMap(
        styleString: _openFreeMapLibertyStyle,
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.681236, 139.767125),
          zoom: 12,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
```

初期カメラ位置は東京駅周辺の座標を仮値として置く(Task 6で現在地取得後にカメラを移動するため、起動直後のみ表示される)。

- [ ] **Step 2: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze lib/screens/map_screen.dart
```

Expected: `No issues found!`

---

### Task 6: 現在地を取得してカメラ移動・マーカー表示する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`
- Modify: `fogworld/lib/main.dart`

**Interfaces:**
- Consumes: Task 4の `LocationService`(`GeolocatorLocationProvider` を注入)、Task 5の `MapScreen`
- Produces: アプリ起動時に `MapScreen` が表示され、現在地取得後にカメラが移動しシンボルが表示される状態

- [ ] **Step 1: `MapScreen` に現在地取得ロジックを追加する**

`fogworld/lib/screens/map_screen.dart` を以下のように書き換える:

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../services/location_provider.dart';
import '../services/location_service.dart';

const _openFreeMapLibertyStyle = 'https://tiles.openfreemap.org/styles/liberty';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService(GeolocatorLocationProvider());
  MaplibreMapController? _mapController;

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _mapController = controller;
    await _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await _locationService.determinePosition();
      final latLng = LatLng(position.latitude, position.longitude);

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
      await _mapController?.addSymbol(
        SymbolOptions(
          geometry: latLng,
          iconImage: 'marker-15',
        ),
      );
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FogWorld')),
      body: MapLibreMap(
        styleString: _openFreeMapLibertyStyle,
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.681236, 139.767125),
          zoom: 12,
        ),
        myLocationEnabled: false,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
```

`marker-15` はMapLibreスタイルスプライトに含まれる標準アイコンID(liberty/bright/positronスタイル共通のOpenMapTiles系スプライトセットに含まれる)。表示されない場合はTask 7の実機確認で `iconImage` を調整する。

- [ ] **Step 2: `main.dart` を `MapScreen` を表示するように書き換える**

`fogworld/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const FogWorldApp());
}

class FogWorldApp extends StatelessWidget {
  const FogWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FogWorld',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const MapScreen(),
    );
  }
}
```

- [ ] **Step 3: 旧デフォルトのカウンターテストを削除する**

`fogworld/test/widget_test.dart` は `MyApp`/カウンターUIを前提にしており本Stepの構成と合わなくなるため削除する:

```powershell
Remove-Item fogworld\test\widget_test.dart
```

- [ ] **Step 4: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 7: エミュレータ/実機で地図表示と現在地取得を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜6の全成果物
- Produces: 実機/エミュレータ上でOpenFreeMap地図が表示され、位置情報権限ダイアログが出て許可すると現在地にカメラが移動・マーカーが表示される状態

- [ ] **Step 1: エミュレータの位置情報をモック設定する(実機を使わない場合)**

Android Studio Device Managerのエミュレータ拡張コントロール(`...` メニュー → Location)で任意の緯度経度(例: 35.681236, 139.767125)を設定する。

- [ ] **Step 2: アプリを起動する**

```powershell
cd fogworld
flutter run
```

Expected: OpenFreeMapのベクタータイル地図(道路・建物等が描画されたLibertyスタイル)が表示される。

- [ ] **Step 3: 位置情報権限ダイアログを許可する**

起動後に表示される権限ダイアログで「アプリの使用中のみ許可」を選択する。

Expected: 数秒以内にカメラがエミュレータで設定した座標(またはデバイスの実際の現在地)にズームインし、マーカーが表示される。

- [ ] **Step 4: 権限拒否時の挙動を確認する**

アプリを一度アンインストールし再起動、または端末設定から位置情報権限を「許可しない」に変更して再起動する。

Expected: 画面下部に `LocationServiceException` のメッセージ(SnackBar)が表示され、アプリはクラッシュしない。

- [ ] **Step 5: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 8: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 5〜7の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/ fogworld/test/
git commit -m "feat: OpenFreeMap地図表示と現在地取得・マーカー表示を追加"
```

---

## Step 1 完了条件(再掲)

- `flutter test` がパス(`LocationService` の単体テスト)
- `flutter analyze` がクリーン
- エミュレータ/実機でOpenFreeMap地図が表示される
- 位置情報許可後、現在地にカメラが移動しマーカーが表示される
- 位置情報拒否時にアプリがクラッシュせずエラーメッセージを表示する

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 2(POI検索・表示)に進む。
