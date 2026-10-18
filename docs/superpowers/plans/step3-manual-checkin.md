# Step 3: 手動チェックイン(ローカル保存) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** POI詳細ボトムシートからチェックインでき、履歴をsqfliteによるローカルDBに保存する。チェックイン済みPOIは地図上で見た目を変えてハイライト表示する。クラウド同期は行わない。

**Architecture:** `CheckinRepository` がsqfliteへの読み書きを担う唯一の窓口とし、`MapScreen` は `CheckinRepository` のメソッドのみを呼び出す(SQLを直接書かない)。テスト容易性のため `CheckinRepository.open()` は `DatabaseFactory` と DBパスを差し替え可能にし、単体テストでは `sqflite_common_ffi` のインメモリDBを使う。チェックイン済みPOIのハイライトは、シンボル追加時に `_poiBySymbolId` と合わせて `checkedInPoiIds`(`Set<String>`)を保持し、`iconImage` を出し分けることで実現する。

**Tech Stack:** `sqflite` ^2.4.3(本番DB)、`sqflite_common_ffi` ^2.4.2+1(テスト用、dev_dependency)、`path` ^1.9.1(DBパス結合)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(記録方式・スコア設計の前提)、[`../../plan.md`](../../plan.md)(Step 3の位置づけ)、[`step2-poi-search.md`](step2-poi-search.md)(前提となるPOI検索・地図ピン表示)

## Global Constraints

- スコア計算・レベル表示はStep 4以降で実装する。本Stepはチェックインの記録とハイライト表示のみ。
- クラウド同期(Firebase)はStep 8で実装する。本Stepのデータはデバイスローカルのsqfliteのみに保存する。
- 再訪問(同一POIへの複数回チェックイン)は履歴として複数行保存してよい(将来の「連続訪問日数」指標のため)。ただしハイライト表示の判定は「1回以上チェックインしたPOI」の集合(`DISTINCT poi_id`)で行う。

---

### Task 1: `CheckinRepository` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/checkin_repository.dart`
- Test: `fogworld/test/services/checkin_repository_test.dart`
- Modify: `fogworld/pubspec.yaml`(`sqflite`, `path` を dependencies に、`sqflite_common_ffi` を dev_dependencies に追加)

**Interfaces:**
- Consumes: Task 2(Step 2)で定義済みの `Poi` モデル(`fogworld/lib/models/poi.dart`)
- Produces: クラス `CheckinRepository`。静的メソッド `Future<CheckinRepository> open({DatabaseFactory? factory, String? path})`。インスタンスメソッド `Future<void> checkIn(Poi poi, {DateTime? checkedInAt})`、`Future<bool> isCheckedIn(String poiId)`、`Future<Set<String>> getCheckedInPoiIds()`、`Future<void> close()`。Task 3の `MapScreen` がこれらを呼び出す。

- [ ] **Step 1: `pubspec.yaml` に依存関係を追加する**

`fogworld/pubspec.yaml` の `dependencies:` に追加:

```yaml
  sqflite: ^2.4.3
  path: ^1.9.1
```

`dev_dependencies:` に追加:

```yaml
  sqflite_common_ffi: ^2.4.2+1
```

```powershell
cd fogworld
flutter pub get
```

- [ ] **Step 2: 失敗するテストを書く**

`fogworld/test/services/checkin_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/models/poi.dart';
import 'package:fogworld/services/checkin_repository.dart';

void main() {
  sqfliteFfiInit();

  late CheckinRepository repository;

  setUp(() async {
    repository = await CheckinRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await repository.close();
  });

  const poi = Poi(
    id: 'node/1',
    lat: 35.68,
    lon: 139.76,
    name: 'Sample Cafe',
    tags: {'amenity': 'cafe', 'name': 'Sample Cafe'},
  );

  test('チェックイン前はisCheckedInがfalseを返す', () async {
    expect(await repository.isCheckedIn(poi.id), isFalse);
  });

  test('チェックイン後はisCheckedInがtrueを返す', () async {
    await repository.checkIn(poi);
    expect(await repository.isCheckedIn(poi.id), isTrue);
  });

  test('チェックイン済みPOI IDの集合を取得できる', () async {
    await repository.checkIn(poi);
    final ids = await repository.getCheckedInPoiIds();
    expect(ids, {'node/1'});
  });

  test('同一POIへの複数回チェックインは履歴として保存されるが集合には1件のみ含まれる', () async {
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 1, 1));
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 2, 1));

    final ids = await repository.getCheckedInPoiIds();
    expect(ids, {'node/1'});
  });
}
```

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_repository_test.dart
```

Expected: `checkin_repository.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 4: 最小実装を書く**

`fogworld/lib/services/checkin_repository.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';
import '../models/poi.dart';

class CheckinRepository {
  final Database _db;

  CheckinRepository._(this._db);

  static Future<CheckinRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? sqflite.databaseFactory;
    final dbPath =
        path ?? p.join(await sqflite.getDatabasesPath(), 'fogworld_checkins.db');

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE checkins (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              poi_id TEXT NOT NULL,
              name TEXT,
              lat REAL NOT NULL,
              lon REAL NOT NULL,
              checked_in_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    return CheckinRepository._(db);
  }

  Future<void> checkIn(Poi poi, {DateTime? checkedInAt}) async {
    await _db.insert('checkins', {
      'poi_id': poi.id,
      'name': poi.name,
      'lat': poi.lat,
      'lon': poi.lon,
      'checked_in_at': (checkedInAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<bool> isCheckedIn(String poiId) async {
    final rows = await _db.query(
      'checkins',
      where: 'poi_id = ?',
      whereArgs: [poiId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getCheckedInPoiIds() async {
    final rows = await _db.query('checkins', distinct: true, columns: ['poi_id']);
    return rows.map((row) => row['poi_id'] as String).toSet();
  }

  Future<void> close() => _db.close();
}
```

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/services/checkin_repository.dart fogworld/test/services/checkin_repository_test.dart fogworld/pubspec.yaml fogworld/pubspec.lock
git commit -m "feat: sqfliteによるCheckinRepositoryをTDDで実装"
```

---

### Task 2: `MapScreen` にチェックインボタンとハイライト表示を追加する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 1の `CheckinRepository`
- Produces: POI詳細ボトムシートに「チェックインする」ボタンを表示し、押下すると `CheckinRepository.checkIn()` を呼びシンボルの `iconImage` をハイライト用アイコンに切り替える。すでにチェックイン済みの場合はボタンの代わりに「チェックイン済み」の表示にする。

- [ ] **Step 1: `MapScreen` の state に `CheckinRepository` とハイライト管理を追加する**

`fogworld/lib/screens/map_screen.dart` を以下の差分で変更する(既存の `_MapScreenState` に追記・変更):

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/poi.dart';
import '../services/checkin_repository.dart';
import '../services/location_provider.dart';
import '../services/location_service.dart';
import '../services/overpass_client.dart';

const _openFreeMapLibertyStyle = 'https://tiles.openfreemap.org/styles/liberty';
const _poiSearchRadiusMeters = 500;
const _defaultIcon = 'marker-15';
const _checkedInIcon = 'marker-stroked-15';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService(GeolocatorLocationProvider());
  final _overpassClient = OverpassClient();
  MaplibreMapController? _mapController;
  CheckinRepository? _checkinRepository;
  final Map<String, Poi> _poiBySymbolId = {};
  final Map<String, Symbol> _symbolByPoiId = {};
  Set<String> _checkedInPoiIds = {};

  @override
  void initState() {
    super.initState();
    _initCheckinRepository();
  }

  Future<void> _initCheckinRepository() async {
    _checkinRepository = await CheckinRepository.open();
    _checkedInPoiIds = await _checkinRepository!.getCheckedInPoiIds();
  }

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
        final isCheckedIn = _checkedInPoiIds.contains(poi.id);
        final symbol = await _mapController?.addSymbol(
          SymbolOptions(
            geometry: LatLng(poi.lat, poi.lon),
            iconImage: isCheckedIn ? _checkedInIcon : _defaultIcon,
          ),
        );
        if (symbol != null) {
          _poiBySymbolId[symbol.id] = poi;
          _symbolByPoiId[poi.id] = symbol;
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

  Future<void> _checkIn(Poi poi) async {
    final repository = _checkinRepository;
    if (repository == null) return;

    await repository.checkIn(poi);
    _checkedInPoiIds = {..._checkedInPoiIds, poi.id};

    final symbol = _symbolByPoiId[poi.id];
    final controller = _mapController;
    if (symbol != null && controller != null) {
      await controller.updateSymbol(
        symbol,
        const SymbolOptions(iconImage: _checkedInIcon),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _showPoiDetail(Poi poi) {
    final isCheckedIn = _checkedInPoiIds.contains(poi.id);

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
            const SizedBox(height: 16),
            if (isCheckedIn)
              const Text('チェックイン済み')
            else
              FilledButton(
                onPressed: () => _checkIn(poi),
                child: const Text('チェックインする'),
              ),
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
  void dispose() {
    _checkinRepository?.close();
    super.dispose();
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

`marker-stroked-15` はliberty系スタイルのスプライトに含まれる標準アイコンID(Task 7で実機確認し、見分けが付きにくい場合は色付きの別アイコンIDに調整する)。

- [ ] **Step 2: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 3: エミュレータ/実機でチェックイン・ハイライト・永続化を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜2の全成果物
- Produces: 実機/エミュレータ上でチェックインが機能し、アプリ再起動後も履歴が保持される状態

- [ ] **Step 1: アプリを起動しPOI詳細からチェックインする**

```powershell
cd fogworld
flutter run
```

任意のPOIピンをタップし、「チェックインする」ボタンを押す。

Expected: ボトムシートが閉じ、該当ピンのアイコンが変化する(ハイライト状態になる)。

- [ ] **Step 2: 同じPOIを再度タップする**

Expected: 「チェックイン済み」と表示され、チェックインボタンは表示されない。

- [ ] **Step 3: アプリを再起動し、ハイライトが保持されていることを確認する**

ターミナルで `R`(大文字、ホットリスタート)ではなく、`q` で一度終了してから再度 `flutter run` する(sqfliteはアプリプロセスをまたいだ永続化なのでホットリスタートではなく完全再起動で検証する)。

Expected: 起動直後のPOI検索結果で、前回チェックインしたPOIのピンが最初からハイライト状態で表示される。

- [ ] **Step 4: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 4: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 2〜3の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/map_screen.dart
git commit -m "feat: 手動チェックインとチェックイン済みPOIのハイライト表示を追加"
```

---

## Step 3 完了条件(再掲)

- `flutter test` がパス(`CheckinRepository` の単体テスト)
- `flutter analyze` がクリーン
- POIをチェックインでき、チェックイン済みのPOIが地図上で視覚的に区別される
- アプリ再起動後もチェックイン履歴(ハイライト状態)が保持される

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 4(スコア表示・市区町村1階層)に進む。
