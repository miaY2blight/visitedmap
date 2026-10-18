# Step 2: POI検索・表示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overpass APIで現在地周辺のPOI(施設)を検索し、OSMタグに基づく客観的な基準でフィルタリングした上で地図上にピン表示する。ピンタップで名称・カテゴリを表示する(記録機能はまだ無い)。

**Architecture:** `OverpassQueryBuilder`(クエリ文字列生成)→ `OverpassClient`(HTTP実行・レート制限・JSONパース)→ `PoiClassifier`(OSMタグに基づく対象/対象外の機械的判定)→ `MapScreen`(検索結果をシンボルとして描画、タップで詳細ボトムシート表示)という一方向のパイプラインにする。レート制限(1リクエスト/秒)は `OverpassClient` に閉じ込め、呼び出し側は意識しなくてよい設計にする。

**Tech Stack:** `http` ^1.6.0(Overpass APIへのPOSTリクエスト用)、Overpass API公開インスタンス `https://overpass-api.de/api/interpreter`(2026-09-04にOSM Wikiで確認済み)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(POI判定基準・Overpass利用ポリシー)、[`../../plan.md`](../../plan.md)(Step 2の位置づけ)、[`step1-map-display.md`](step1-map-display.md)(前提となる地図表示・現在地取得)

## Global Constraints

- チェックイン・スコア等、Step 3以降の機能は実装しない。本Stepは検索とピン表示・詳細表示のみ。
- Overpass公開インスタンスの利用ポリシー(1リクエスト/秒まで、重い用途禁止)を`OverpassClient`内で機械的に遵守する。バックグラウンドでの一括取得は行わない(ユーザー操作起点の検索のみ)。
- POI対象/対象外の判定は「注目度」等の主観的基準を使わず、OSMタグの有無のみで機械的に決定する(CLAUDE.md方針)。本Stepでは以下を対象タグとする: `amenity`, `shop`, `tourism`, `leisure`, `historic`, `railway`(値が`station`または`halt`の場合のみ), `public_transport`。個人邸宅(`building=house`等)や企業専用ビルは、これらのタグを持たない限り自動的に対象外となる。

---

### Task 1: `OverpassQueryBuilder` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/overpass_query_builder.dart`
- Test: `fogworld/test/services/overpass_query_builder_test.dart`

**Interfaces:**
- Consumes: なし
- Produces: クラス `OverpassQueryBuilder`。静的メソッド `String buildNearbyPoiQuery({required double lat, required double lon, required int radiusMeters})`。Task 3の `OverpassClient` がこの戻り値(Overpass QL文字列)をリクエストボディとして使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/overpass_query_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/overpass_query_builder.dart';

void main() {
  test('緯度経度と半径からOverpass QLクエリを生成する', () {
    final query = OverpassQueryBuilder.buildNearbyPoiQuery(
      lat: 35.681236,
      lon: 139.767125,
      radiusMeters: 500,
    );

    expect(query, contains('[out:json][timeout:25];'));
    expect(query, contains('around:500,35.681236,139.767125'));
    expect(query, contains('amenity'));
    expect(query, contains('shop'));
    expect(query, contains('tourism'));
    expect(query, contains('leisure'));
    expect(query, contains('historic'));
    expect(query, contains('out center;'));
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_query_builder_test.dart
```

Expected: `overpass_query_builder.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/overpass_query_builder.dart`:

```dart
class OverpassQueryBuilder {
  static String buildNearbyPoiQuery({
    required double lat,
    required double lon,
    required int radiusMeters,
  }) {
    final around = 'around:$radiusMeters,$lat,$lon';
    final filters = [
      'node[amenity]($around);',
      'way[amenity]($around);',
      'node[shop]($around);',
      'way[shop]($around);',
      'node[tourism]($around);',
      'way[tourism]($around);',
      'node[leisure]($around);',
      'way[leisure]($around);',
      'node[historic]($around);',
      'way[historic]($around);',
      'node[railway~"^(station|halt)\$"]($around);',
      'way[railway~"^(station|halt)\$"]($around);',
      'node[public_transport]($around);',
      'way[public_transport]($around);',
    ].join('\n  ');

    return '[out:json][timeout:25];\n(\n  $filters\n);\nout center;';
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_query_builder_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/overpass_query_builder.dart fogworld/test/services/overpass_query_builder_test.dart
git commit -m "feat: Overpassクエリビルダーをテスト駆動で実装"
```

---

### Task 2: `Poi` モデルと `PoiClassifier` をTDDで実装する

**Files:**
- Create: `fogworld/lib/models/poi.dart`
- Create: `fogworld/lib/services/poi_classifier.dart`
- Test: `fogworld/test/services/poi_classifier_test.dart`

**Interfaces:**
- Consumes: Overpass APIレスポンスの要素(`Map<String, dynamic>` — `type`, `id`, `lat`/`lon` または `center.lat`/`center.lon`, `tags`)
- Produces: クラス `Poi`(フィールド: `String id`, `double lat`, `double lon`, `String? name`, `Map<String, String> tags`)。クラス `PoiClassifier`。静的メソッド `bool isTargetPoi(Map<String, String> tags)` と `Poi? fromOverpassElement(Map<String, dynamic> element)`(対象外なら`null`を返す)。Task 3の `OverpassClient` がこれを使って生要素を`List<Poi>`に変換する。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/poi_classifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/poi_classifier.dart';

void main() {
  group('isTargetPoi', () {
    test('amenityタグを持つ要素は対象', () {
      expect(PoiClassifier.isTargetPoi({'amenity': 'cafe'}), isTrue);
    });

    test('shopタグを持つ要素は対象', () {
      expect(PoiClassifier.isTargetPoi({'shop': 'supermarket'}), isTrue);
    });

    test('railwayタグがstationの場合は対象', () {
      expect(PoiClassifier.isTargetPoi({'railway': 'station'}), isTrue);
    });

    test('railwayタグがrailの場合(線路そのもの)は対象外', () {
      expect(PoiClassifier.isTargetPoi({'railway': 'rail'}), isFalse);
    });

    test('buildingタグのみ(個人邸宅相当)は対象外', () {
      expect(PoiClassifier.isTargetPoi({'building': 'house'}), isFalse);
    });

    test('タグが空の場合は対象外', () {
      expect(PoiClassifier.isTargetPoi({}), isFalse);
    });
  });

  group('fromOverpassElement', () {
    test('nodeタイプで対象タグを持つ要素をPoiに変換する', () {
      final poi = PoiClassifier.fromOverpassElement({
        'type': 'node',
        'id': 123,
        'lat': 35.68,
        'lon': 139.76,
        'tags': {'amenity': 'cafe', 'name': 'Sample Cafe'},
      });

      expect(poi, isNotNull);
      expect(poi!.id, '123');
      expect(poi.lat, 35.68);
      expect(poi.lon, 139.76);
      expect(poi.name, 'Sample Cafe');
    });

    test('wayタイプはcenterフィールドの座標を使う', () {
      final poi = PoiClassifier.fromOverpassElement({
        'type': 'way',
        'id': 456,
        'center': {'lat': 35.69, 'lon': 139.77},
        'tags': {'shop': 'mall', 'name': 'Sample Mall'},
      });

      expect(poi, isNotNull);
      expect(poi!.lat, 35.69);
      expect(poi.lon, 139.77);
    });

    test('対象外タグの要素はnullを返す', () {
      final poi = PoiClassifier.fromOverpassElement({
        'type': 'way',
        'id': 789,
        'center': {'lat': 35.0, 'lon': 139.0},
        'tags': {'building': 'residential'},
      });

      expect(poi, isNull);
    });

    test('nameタグが無い場合はnameがnullになる', () {
      final poi = PoiClassifier.fromOverpassElement({
        'type': 'node',
        'id': 999,
        'lat': 35.0,
        'lon': 139.0,
        'tags': {'amenity': 'toilets'},
      });

      expect(poi, isNotNull);
      expect(poi!.name, isNull);
    });
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/poi_classifier_test.dart
```

Expected: `poi.dart` / `poi_classifier.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 3: `Poi` モデルを実装する**

`fogworld/lib/models/poi.dart`:

```dart
class Poi {
  final String id;
  final double lat;
  final double lon;
  final String? name;
  final Map<String, String> tags;

  const Poi({
    required this.id,
    required this.lat,
    required this.lon,
    required this.name,
    required this.tags,
  });
}
```

- [ ] **Step 4: `PoiClassifier` を実装する**

`fogworld/lib/services/poi_classifier.dart`:

```dart
import '../models/poi.dart';

class PoiClassifier {
  static const _targetKeys = [
    'amenity',
    'shop',
    'tourism',
    'leisure',
    'historic',
    'public_transport',
  ];

  static const _railwayTargetValues = ['station', 'halt'];

  static bool isTargetPoi(Map<String, String> tags) {
    for (final key in _targetKeys) {
      if (tags.containsKey(key)) return true;
    }
    final railway = tags['railway'];
    if (railway != null && _railwayTargetValues.contains(railway)) {
      return true;
    }
    return false;
  }

  static Poi? fromOverpassElement(Map<String, dynamic> element) {
    final rawTags = element['tags'] as Map<String, dynamic>? ?? {};
    final tags = rawTags.map((k, v) => MapEntry(k, v.toString()));

    if (!isTargetPoi(tags)) return null;

    final double lat;
    final double lon;
    if (element['type'] == 'node') {
      lat = (element['lat'] as num).toDouble();
      lon = (element['lon'] as num).toDouble();
    } else {
      final center = element['center'] as Map<String, dynamic>;
      lat = (center['lat'] as num).toDouble();
      lon = (center['lon'] as num).toDouble();
    }

    return Poi(
      id: element['id'].toString(),
      lat: lat,
      lon: lon,
      name: tags['name'],
      tags: tags,
    );
  }
}
```

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/poi_classifier_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/models/poi.dart fogworld/lib/services/poi_classifier.dart fogworld/test/services/poi_classifier_test.dart
git commit -m "feat: OSMタグに基づく客観的なPOI判定ロジックをTDDで実装"
```

---

### Task 3: `OverpassClient`(レート制限付きHTTP実行)をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/overpass_client.dart`
- Test: `fogworld/test/services/overpass_client_test.dart`
- Modify: `fogworld/pubspec.yaml`(`http` パッケージ追加)

**Interfaces:**
- Consumes: `http.Client`(テストでは `MockClient` に差し替え)、Task 1の `OverpassQueryBuilder`、Task 2の `PoiClassifier`
- Produces: クラス `OverpassClient`。コンストラクタ `OverpassClient({http.Client? httpClient})`。メソッド `Future<List<Poi>> searchNearbyPois({required double lat, required double lon, required int radiusMeters})`。連続呼び出し時は前回リクエストから1秒未満なら1秒経過まで待機してから送信する(内部に最終リクエスト時刻を保持)。Task 4の `MapScreen` がこれを呼び出す。

- [ ] **Step 1: `pubspec.yaml` に `http` を追加する**

`fogworld/pubspec.yaml` の `dependencies:` に追加:

```yaml
  http: ^1.6.0
```

```powershell
cd fogworld
flutter pub get
```

- [ ] **Step 2: 失敗するテストを書く**

`fogworld/test/services/overpass_client_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fogworld/services/overpass_client.dart';

void main() {
  test('Overpassレスポンスを対象POIのみのリストに変換する', () async {
    final mockClient = MockClient((request) async {
      final body = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 35.68,
            'lon': 139.76,
            'tags': {'amenity': 'cafe', 'name': 'Cafe A'},
          },
          {
            'type': 'way',
            'id': 2,
            'center': {'lat': 35.0, 'lon': 139.0},
            'tags': {'building': 'residential'},
          },
        ],
      });
      return http.Response(body, 200);
    });

    final client = OverpassClient(httpClient: mockClient);
    final pois = await client.searchNearbyPois(
      lat: 35.681236,
      lon: 139.767125,
      radiusMeters: 500,
    );

    expect(pois.length, 1);
    expect(pois.first.name, 'Cafe A');
  });

  test('HTTPエラー時は例外を投げる', () async {
    final mockClient = MockClient((request) async {
      return http.Response('Server Error', 504);
    });

    final client = OverpassClient(httpClient: mockClient);

    expect(
      () => client.searchNearbyPois(lat: 0, lon: 0, radiusMeters: 500),
      throwsA(isA<OverpassException>()),
    );
  });
}
```

`fogworld/pubspec.yaml` の `dev_dependencies:` に `http` のテストユーティリティが含まれる(同一パッケージの `http/testing.dart` を使うため追加の依存追加は不要)。

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_client_test.dart
```

Expected: `overpass_client.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 4: 最小実装を書く**

`fogworld/lib/services/overpass_client.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/poi.dart';
import 'overpass_query_builder.dart';
import 'poi_classifier.dart';

class OverpassException implements Exception {
  final String message;
  OverpassException(this.message);

  @override
  String toString() => 'OverpassException: $message';
}

class OverpassClient {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';
  static const _minInterval = Duration(seconds: 1);

  final http.Client _httpClient;
  DateTime? _lastRequestAt;

  OverpassClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<List<Poi>> searchNearbyPois({
    required double lat,
    required double lon,
    required int radiusMeters,
  }) async {
    await _waitForRateLimit();

    final query = OverpassQueryBuilder.buildNearbyPoiQuery(
      lat: lat,
      lon: lon,
      radiusMeters: radiusMeters,
    );

    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      body: {'data': query},
    );

    _lastRequestAt = DateTime.now();

    if (response.statusCode != 200) {
      throw OverpassException(
        'Overpass API returned ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>;

    return elements
        .cast<Map<String, dynamic>>()
        .map(PoiClassifier.fromOverpassElement)
        .whereType<Poi>()
        .toList();
  }

  Future<void> _waitForRateLimit() async {
    final lastRequestAt = _lastRequestAt;
    if (lastRequestAt == null) return;

    final elapsed = DateTime.now().difference(lastRequestAt);
    if (elapsed < _minInterval) {
      await Future.delayed(_minInterval - elapsed);
    }
  }
}
```

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_client_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: レート制限の動作を検証するテストを追加する**

`fogworld/test/services/overpass_client_test.dart` に追記:

```dart
  test('連続呼び出し時は1秒未満の間隔をあけて送信する', () async {
    var callCount = 0;
    final mockClient = MockClient((request) async {
      callCount++;
      return http.Response(jsonEncode({'elements': []}), 200);
    });

    final client = OverpassClient(httpClient: mockClient);
    final stopwatch = Stopwatch()..start();

    await client.searchNearbyPois(lat: 0, lon: 0, radiusMeters: 500);
    await client.searchNearbyPois(lat: 0, lon: 0, radiusMeters: 500);

    stopwatch.stop();

    expect(callCount, 2);
    expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(1000));
  });
```

```powershell
cd fogworld
flutter test test/services/overpass_client_test.dart
```

Expected: `All tests passed!`(このテストは実時間で1秒以上かかる想定)

- [ ] **Step 7: コミット**

```bash
git add fogworld/lib/services/overpass_client.dart fogworld/test/services/overpass_client_test.dart fogworld/pubspec.yaml fogworld/pubspec.lock
git commit -m "feat: レート制限付きOverpassClientをTDDで実装"
```

---

### Task 4: `MapScreen` にPOI検索結果をピン表示する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 3の `OverpassClient`、Task 2の `Poi` モデル
- Produces: 現在地取得後にその周辺500m以内のPOIを検索し、地図上にシンボルとして表示する。各シンボルには `Poi.id` を紐づけたデータを保持し、Task 5のタップ判定で使う。

- [ ] **Step 1: `MapScreen` にPOI検索・シンボル描画を追加する**

`fogworld/lib/screens/map_screen.dart` の `_moveToCurrentLocation` 呼び出し後にPOI検索を行うよう変更する:

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/poi.dart';
import '../services/location_provider.dart';
import '../services/location_service.dart';
import '../services/overpass_client.dart';

const _openFreeMapLibertyStyle = 'https://tiles.openfreemap.org/styles/liberty';
const _poiSearchRadiusMeters = 500;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService(GeolocatorLocationProvider());
  final _overpassClient = OverpassClient();
  MaplibreMapController? _mapController;
  final Map<String, Poi> _poiBySymbolId = {};

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _mapController = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
    await _moveToCurrentLocationAndSearchPois();
  }

  Future<void> _moveToCurrentLocationAndSearchPois() async {
    try {
      final position = await _locationService.determinePosition();
      final latLng = LatLng(position.latitude, position.longitude);

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );

      final pois = await _overpassClient.searchNearbyPois(
        lat: position.latitude,
        lon: position.longitude,
        radiusMeters: _poiSearchRadiusMeters,
      );

      for (final poi in pois) {
        final symbol = await _mapController?.addSymbol(
          SymbolOptions(
            geometry: LatLng(poi.lat, poi.lon),
            iconImage: 'marker-15',
          ),
        );
        if (symbol != null) {
          _poiBySymbolId[symbol.id] = poi;
        }
      }
    } on LocationServiceException catch (e) {
      _showMessage(e.message);
    } on OverpassException catch (e) {
      _showMessage(e.message);
    }
  }

  void _onSymbolTapped(Symbol symbol) {
    final poi = _poiBySymbolId[symbol.id];
    if (poi == null) return;
    _showPoiDetail(poi);
  }

  void _showPoiDetail(Poi poi) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poi.name ?? '名称不明',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(poi.tags.entries.map((e) => '${e.key}=${e.value}').join(', ')),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

- [ ] **Step 2: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 5: エミュレータ/実機でPOI検索・タップ詳細表示を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜4の全成果物
- Produces: 実機/エミュレータ上でPOI検索結果がピン表示され、タップで詳細ボトムシートが開く状態

- [ ] **Step 1: アプリを起動する**

```powershell
cd fogworld
flutter run
```

Expected: Step 1同様に地図・現在地マーカーが表示された後、数秒以内に周辺のPOI(カフェ・コンビニ・駅等)を示す追加のピンが表示される。

- [ ] **Step 2: ピンをタップする**

Expected: 画面下部にボトムシートが表示され、POIの名称(または「名称不明」)とOSMタグの一覧が表示される。

- [ ] **Step 3: 建物のみ(住宅等)がピン表示されていないことを確認する**

地図を住宅街にパンし、`amenity`/`shop`/`tourism`等のタグを持たない一般住宅にピンが表示されていないことを目視確認する。

- [ ] **Step 4: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 6: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 4〜5の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/map_screen.dart
git commit -m "feat: POI検索結果の地図ピン表示とタップ詳細表示を追加"
```

---

## Step 2 完了条件(再掲)

- `flutter test` がパス(クエリビルダー・POI判定・Overpassクライアントの単体テスト)
- `flutter analyze` がクリーン
- エミュレータ/実機で現在地周辺のPOIがピン表示される
- ピンタップで名称・カテゴリの詳細が表示される
- OSMタグに基づく機械的フィルタリングにより個人邸宅等が表示されない

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 3(手動チェックイン)に進む。
