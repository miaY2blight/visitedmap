# Step 5: 階層レベルの全展開 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 世界/大陸/国/都道府県/市区町村の全階層でレベルを表示する。天井を持つのは都道府県・市区町村のみとし、国・大陸・世界は天井を持たず「訪問した場所の数」「制覇した下位地域の数」で表示する。一度表示したレベルは下げない(単調非減少)。

**Architecture:** Step 4の `MunicipalityResolver` を一般化した `RegionResolver` に置き換え、geoBoundariesのADM0(国)・ADM1(都道府県)・ADM2(市区町村)の3階層を同時に解決できるようにする。大陸・世界は行政境界データを使わず、国コード(ISO)から静的なマッピングテーブルで大陸を導出し、世界は常に単一の集計単位とする。`HierarchyScoreAggregator` が5階層それぞれの `RegionLevel`(名称・スコアまたは訪問数・天井の有無・レベル)を算出する。天井を持つ階層(都道府県・市区町村)は Step 4の `CeilingService` を再利用し、天井を持たない階層(国・大陸・世界)は「訪問済みPOI数」または「制覇済み下位地域数」をそのままレベル計算の入力にする。単調非減少の保証は `LevelHistoryRepository`(sqflite)が「階層種別+リージョンID」ごとに「これまでに表示した最大レベル」を保存し、新しい計算結果より大きければ更新、小さければ保存済みの値を返すことで実現する。

**Tech Stack:** geoBoundaries ADM0・ADM1(追加ダウンロード、Task 1)。大陸マッピングは静的JSONアセット(ISO 3166-1 alpha-3国コード → 大陸名)としてバンドルする。新規Flutterパッケージの追加は無い。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(階層設計・天井の有無・単調非減少の方針)、[`../../plan.md`](../../plan.md)(Step 5の位置づけ)、[`step4-score-municipality.md`](step4-score-municipality.md)(前提となる市区町村スコア・天井キャッシュの仕組み)

## Global Constraints

- 除外地域(紛争地域等)の実装はStep 7で行う。本Stepでは全地域を集計対象とする。
- 天井を持つ階層は都道府県・市区町村のみ。国・大陸・世界は天井を持たない(CLAUDE.md方針)。
- 一度画面に表示したレベルは、後から天井やデータが変動しても下げない(単調非減少)。この保証は `LevelHistoryRepository` に閉じ込め、他のコードは意識しなくてよい設計にする。
- 本Stepの対象国は日本のみとする(CLAUDE.mdの「世界規模のPOI総数は取得不可能」という制約は天井の話であり、階層構造自体は世界共通だが、バンドルする行政境界データを全世界分用意するのは本Stepの範囲外。日本国内のチェックインのみを正しく階層分解できればよく、日本国外のチェックインが発生した場合の扱いはTask 5で最小限のフォールバック(国名不明として扱う)を実装する)。

---

### Task 1: geoBoundariesのADM0(国)・ADM1(都道府県)データを追加する

**Files:**
- Create: `fogworld/assets/geo/jpn_adm1.geojson`
- Create: `fogworld/assets/geo/world_adm0.geojson`
- Create: `fogworld/assets/geo/country_continent.json`
- Modify: `fogworld/pubspec.yaml`(`flutter.assets` に追加)

**Interfaces:**
- Consumes: geoBoundaries API
- Produces: 都道府県判定用・国判定用のGeoJSONアセット、国コード→大陸名の静的マッピングJSON。Task 2の `RegionResolver` が読み込む。

- [ ] **Step 1: 日本の都道府県(ADM1)データを取得する**

```powershell
$adm1Info = Invoke-RestMethod -Uri "https://www.geoboundaries.org/api/current/gbOpen/JPN/ADM1/"
Invoke-WebRequest -Uri $adm1Info.gjDownloadURL -OutFile fogworld\assets\geo\jpn_adm1.geojson
```

- [ ] **Step 2: 世界のADM0(国境)データを取得する**

geoBoundariesは国ごとのAPIのため、世界全体のADM0は `https://www.geoboundaries.org/api/current/gbOpen/ALL/ADM0/` で一括取得を試みる。データ量が大きい場合は、CLAUDE.mdの「Step 1: 地図表示」で導入済みの `geolocator` から得られる現在地の国名判定に、より軽量な代替手段(例: 主要国のみの簡略化ポリゴンセット)を使うことを検討し、実装時にファイルサイズを見て判断する。

```powershell
$adm0Info = Invoke-RestMethod -Uri "https://www.geoboundaries.org/api/current/gbOpen/ALL/ADM0/"
Invoke-WebRequest -Uri $adm0Info.gjDownloadURL -OutFile fogworld\assets\geo\world_adm0.geojson
(Get-Item fogworld\assets\geo\world_adm0.geojson).Length / 1MB
```

数十MBを超える場合は、Task 2の実装時に座標の間引き(簡略化)処理を別途追加するか、Natural Earthの110m解像度(国境判定のみが目的で高精度不要なため)等の軽量な代替データセットへの切り替えを検討する。判断はファイルサイズ確認後に行う。

- [ ] **Step 3: 国コード→大陸名マッピングを作成する**

`fogworld/assets/geo/country_continent.json`(ISO 3166-1 alpha-3コードをキーとする。ここでは主要国の一部を例示。実装時に全世界分(200件程度)を作成する):

```json
{
  "JPN": "Asia",
  "USA": "North America",
  "GBR": "Europe",
  "AUS": "Oceania",
  "BRA": "South America",
  "EGY": "Africa"
}
```

- [ ] **Step 4: `pubspec.yaml` にアセットを追加する**

```yaml
  assets:
    - assets/geo/jpn_adm2.geojson
    - assets/geo/jpn_adm1.geojson
    - assets/geo/world_adm0.geojson
    - assets/geo/country_continent.json
```

- [ ] **Step 5: コミット**

```bash
git add fogworld/assets/geo/ fogworld/pubspec.yaml
git commit -m "feat: 都道府県・国境界データと大陸マッピングをアセットに追加"
```

---

### Task 2: `RegionResolver` をTDDで実装する(市区町村・都道府県・国の3階層解決)

**Files:**
- Create: `fogworld/lib/services/region_resolver.dart`
- Test: `fogworld/test/services/region_resolver_test.dart`
- Test fixture: `fogworld/test/fixtures/sample_regions.geojson`(市区町村・都道府県・国それぞれ用に3ファイル、または1ファイルを階層別に用意する。ここでは階層ごとに個別フィクスチャとする)

**Interfaces:**
- Consumes: Task 3(Step 4)の `PointInPolygon`
- Produces: クラス `Region`(フィールド: `String id`, `String name`, `List<List<List<double>>> outerRings`)。クラス `RegionResolver`。ファクトリ `RegionResolver.fromGeoJson(String geoJsonString, {required String idField, required String nameField})`(汎用化。市区町村=`shapeID`/`shapeName`、都道府県=同様、国=`shapeISO`(国コード)/`shapeName`)。インスタンスメソッド `Region? resolve(double lat, double lon)`。Step 4の `MunicipalityResolver` はこのクラスの薄いラッパーとして書き換える(下記Step 5参照)。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/region_resolver_test.dart`(Step 4の `municipality_resolver_test.dart` と同型のフィクスチャ・テストケースを、汎用化された `idField`/`nameField` パラメータ付きで書く):

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/region_resolver.dart';

void main() {
  late RegionResolver resolver;

  setUp(() async {
    final geoJson =
        await File('test/fixtures/sample_regions.geojson').readAsString();
    resolver = RegionResolver.fromGeoJson(
      geoJson,
      idField: 'shapeID',
      nameField: 'shapeName',
    );
  });

  test('領域内の点は対応するRegionを返す', () {
    final result = resolver.resolve(5.0, 5.0);
    expect(result, isNotNull);
    expect(result!.id, 'REGION-001');
    expect(result.name, 'サンプル地域');
  });

  test('どの領域にも属さない点はnullを返す', () {
    final result = resolver.resolve(100.0, 100.0);
    expect(result, isNull);
  });
}
```

`fogworld/test/fixtures/sample_regions.geojson` はStep 4の `sample_municipalities.geojson` を1フィーチャに簡略化したものを用意する:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"shapeID": "REGION-001", "shapeName": "サンプル地域"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0], [0.0, 0.0]]]
      }
    }
  ]
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/region_resolver_test.dart
```

Expected: `region_resolver.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/region_resolver.dart`(Step 4の `MunicipalityResolver` を `idField`/`nameField` パラメータ化した汎用版):

```dart
import 'dart:convert';
import 'point_in_polygon.dart';

class Region {
  final String id;
  final String name;
  final List<List<List<double>>> outerRings;

  const Region({
    required this.id,
    required this.name,
    required this.outerRings,
  });
}

class RegionResolver {
  final List<Region> _regions;

  RegionResolver._(this._regions);

  factory RegionResolver.fromGeoJson(
    String geoJsonString, {
    required String idField,
    required String nameField,
  }) {
    final decoded = jsonDecode(geoJsonString) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>;

    final regions = features.map((f) {
      final feature = f as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      final outerRings = <List<List<double>>>[];
      if (geometry['type'] == 'Polygon') {
        final coordinates = geometry['coordinates'] as List<dynamic>;
        outerRings.add(_parseRing(coordinates.first as List<dynamic>));
      } else if (geometry['type'] == 'MultiPolygon') {
        final polygons = geometry['coordinates'] as List<dynamic>;
        for (final polygon in polygons) {
          final rings = polygon as List<dynamic>;
          outerRings.add(_parseRing(rings.first as List<dynamic>));
        }
      }

      return Region(
        id: properties[idField].toString(),
        name: properties[nameField].toString(),
        outerRings: outerRings,
      );
    }).toList();

    return RegionResolver._(regions);
  }

  static List<List<double>> _parseRing(List<dynamic> ring) {
    return ring
        .map((point) => (point as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList())
        .toList();
  }

  Region? resolve(double lat, double lon) {
    for (final region in _regions) {
      for (final ring in region.outerRings) {
        if (PointInPolygon.contains(ring, lat, lon)) {
          return region;
        }
      }
    }
    return null;
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/region_resolver_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/region_resolver.dart fogworld/test/services/region_resolver_test.dart fogworld/test/fixtures/sample_regions.geojson
git commit -m "feat: 市区町村/都道府県/国を汎用的に解決するRegionResolverをTDDで実装"
```

---

### Task 3: 既存コードを `RegionResolver` ベースに置き換える

**Files:**
- Modify: `fogworld/lib/services/ceiling_service.dart`(型を `Municipality` → `Region` に変更)
- Modify: `fogworld/lib/screens/map_screen.dart`(`MunicipalityResolver` → `RegionResolver` に置き換え)
- Delete: `fogworld/lib/services/municipality_resolver.dart`
- Delete: `fogworld/test/services/municipality_resolver_test.dart`
- Delete: `fogworld/test/fixtures/sample_municipalities.geojson`

**Interfaces:**
- Consumes: Task 2の `Region`/`RegionResolver`
- Produces: `CeilingService.getCeiling(Region region)` に変更。`MapScreen` は市区町村用の `RegionResolver`(`idField: 'shapeID', nameField: 'shapeName'`、`assets/geo/jpn_adm2.geojson` から生成)を使い続ける。Task 4以降で都道府県・国用のリゾルバーも同様に追加する。

- [ ] **Step 1: `CeilingService` のシグネチャを `Region` に変更する**

`fogworld/lib/services/ceiling_service.dart` の `import 'municipality_resolver.dart';` を `import 'region_resolver.dart';` に変更し、`Future<int> getCeiling(Municipality municipality)` を `Future<int> getCeiling(Region region)` に変更(内部の `municipality.shapeId`/`municipality.outerRings` を `region.id`/`region.outerRings` に置換)。

- [ ] **Step 2: `fogworld/test/services/ceiling_service_test.dart` を `Region` ベースに書き換える**

`Municipality(...)` の生成箇所を `Region(...)`(`shapeId:` → `id:`)に置き換える。`import 'package:fogworld/services/municipality_resolver.dart';` を `import 'package:fogworld/services/region_resolver.dart';` に変更。

- [ ] **Step 3: `map_screen.dart` を `RegionResolver` ベースに書き換える**

`import '../services/municipality_resolver.dart';` を `import '../services/region_resolver.dart';` に変更し、`MunicipalityResolver` → `RegionResolver`、`Municipality` → `Region`、`resolver.resolve(...)?.shapeId` → `resolver.resolve(...)?.id` に置換する。`RegionResolver.fromGeoJson` 呼び出しに `idField: 'shapeID', nameField: 'shapeName'` を渡す。

- [ ] **Step 4: 旧ファイルを削除する**

```powershell
Remove-Item fogworld\lib\services\municipality_resolver.dart
Remove-Item fogworld\test\services\municipality_resolver_test.dart
Remove-Item fogworld\test\fixtures\sample_municipalities.geojson
```

- [ ] **Step 5: テストと静的解析を実行する**

```powershell
cd fogworld
flutter test
flutter analyze
```

Expected: 全テストパス、`No issues found!`

- [ ] **Step 6: コミット**

```bash
git add -A fogworld/
git commit -m "refactor: MunicipalityResolverを汎用RegionResolverに置き換え"
```

---

### Task 4: `LevelHistoryRepository`(単調非減少レベル)をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/level_history_repository.dart`
- Test: `fogworld/test/services/level_history_repository_test.dart`

**Interfaces:**
- Consumes: なし(sqfliteのみ)
- Produces: クラス `LevelHistoryRepository`。静的メソッド `Future<LevelHistoryRepository> open({DatabaseFactory? factory, String? path})`。メソッド `Future<int> recordAndGetDisplayLevel({required String tier, required String regionId, required int computedLevel})` — `tier`(例: `municipality`, `prefecture`, `country`, `continent`, `world`)と`regionId`の組で過去最大レベルを保存し、`computedLevel` との `max` を返して保存し直す。Task 5の `HierarchyScoreAggregator` がこれを使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/level_history_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/services/level_history_repository.dart';

void main() {
  sqfliteFfiInit();

  late LevelHistoryRepository repository;

  setUp(() async {
    repository = await LevelHistoryRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await repository.close();
  });

  test('初回はcomputedLevelがそのまま返り保存される', () async {
    final level = await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-ADM2-001',
      computedLevel: 3,
    );
    expect(level, 3);
  });

  test('computedLevelが過去の最大値を下回る場合は過去の最大値を返す', () async {
    await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-ADM2-001',
      computedLevel: 5,
    );

    final level = await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-ADM2-001',
      computedLevel: 2,
    );

    expect(level, 5);
  });

  test('computedLevelが過去の最大値を上回る場合は更新される', () async {
    await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-ADM2-001',
      computedLevel: 3,
    );

    final level = await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-ADM2-001',
      computedLevel: 7,
    );

    expect(level, 7);
  });

  test('tierが異なれば同じregionIdでも独立して扱う', () async {
    await repository.recordAndGetDisplayLevel(
      tier: 'municipality',
      regionId: 'JPN-001',
      computedLevel: 5,
    );

    final level = await repository.recordAndGetDisplayLevel(
      tier: 'prefecture',
      regionId: 'JPN-001',
      computedLevel: 1,
    );

    expect(level, 1);
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/level_history_repository_test.dart
```

Expected: `level_history_repository.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/level_history_repository.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

class LevelHistoryRepository {
  final Database _db;

  LevelHistoryRepository._(this._db);

  static Future<LevelHistoryRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? sqflite.databaseFactory;
    final dbPath =
        path ?? p.join(await sqflite.getDatabasesPath(), 'fogworld_levels.db');

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE level_history (
              tier TEXT NOT NULL,
              region_id TEXT NOT NULL,
              max_level INTEGER NOT NULL,
              PRIMARY KEY (tier, region_id)
            )
          ''');
        },
      ),
    );

    return LevelHistoryRepository._(db);
  }

  Future<int> recordAndGetDisplayLevel({
    required String tier,
    required String regionId,
    required int computedLevel,
  }) async {
    final rows = await _db.query(
      'level_history',
      where: 'tier = ? AND region_id = ?',
      whereArgs: [tier, regionId],
      limit: 1,
    );

    final previousMax = rows.isEmpty ? 0 : rows.first['max_level'] as int;
    final displayLevel =
        computedLevel > previousMax ? computedLevel : previousMax;

    if (displayLevel != previousMax) {
      await _db.insert(
        'level_history',
        {'tier': tier, 'region_id': regionId, 'max_level': displayLevel},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return displayLevel;
  }

  Future<void> close() => _db.close();
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/level_history_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/level_history_repository.dart fogworld/test/services/level_history_repository_test.dart
git commit -m "feat: レベルの単調非減少を保証するLevelHistoryRepositoryをTDDで実装"
```

---

### Task 5: `HierarchyScoreAggregator` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/hierarchy_score_aggregator.dart`
- Test: `fogworld/test/services/hierarchy_score_aggregator_test.dart`

**Interfaces:**
- Consumes: Task 2の `RegionResolver`/`Region`、Task 3(Step 4)の `CeilingService`、Task 4の `LevelHistoryRepository`、Task 1(Step 3)の `CheckinRepository.getAllCheckins()`
- Produces: クラス `RegionLevelInfo`(フィールド: `String tier`, `String name`, `int score`, `int? ceiling`, `int level`)。クラス `HierarchyScoreAggregator`。コンストラクタで市区町村用/都道府県用/国用の3つの `RegionResolver`、大陸マッピング(`Map<String, String>` 国コード→大陸名)、`CeilingService`、`LevelHistoryRepository`、`CheckinRepository` を受け取る。メソッド `Future<List<RegionLevelInfo>> aggregateForCheckins(List<({String poiId, double lat, double lon})> checkins, {required double currentLat, required double currentLon})` — 現在地が属する5階層それぞれについて `RegionLevelInfo` を算出して返す(市区町村→都道府県→国→大陸→世界の順)。Task 6の `MapScreen` がこれを呼び出す。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/hierarchy_score_aggregator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fogworld/services/ceiling_service.dart';
import 'package:fogworld/services/hierarchy_score_aggregator.dart';
import 'package:fogworld/services/level_history_repository.dart';
import 'package:fogworld/services/region_resolver.dart';

class MockCeilingService extends Mock implements CeilingService {}

class MockLevelHistoryRepository extends Mock implements LevelHistoryRepository {}

void main() {
  late RegionResolver municipalityResolver;
  late RegionResolver prefectureResolver;
  late RegionResolver countryResolver;
  late MockCeilingService mockCeilingService;
  late MockLevelHistoryRepository mockLevelHistory;
  late HierarchyScoreAggregator aggregator;

  const square = [
    [0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0], [0.0, 0.0],
  ];

  setUp(() {
    municipalityResolver = RegionResolver.fromGeoJson(
      _sampleGeoJson('MUNI-001', 'サンプル市', square),
      idField: 'shapeID',
      nameField: 'shapeName',
    );
    prefectureResolver = RegionResolver.fromGeoJson(
      _sampleGeoJson('PREF-001', 'サンプル県', square),
      idField: 'shapeID',
      nameField: 'shapeName',
    );
    countryResolver = RegionResolver.fromGeoJson(
      _sampleGeoJson('JPN', '日本', square),
      idField: 'shapeISO',
      nameField: 'shapeName',
    );

    mockCeilingService = MockCeilingService();
    mockLevelHistory = MockLevelHistoryRepository();

    when(() => mockCeilingService.getCeiling(any()))
        .thenAnswer((_) async => 100);
    when(() => mockLevelHistory.recordAndGetDisplayLevel(
          tier: any(named: 'tier'),
          regionId: any(named: 'regionId'),
          computedLevel: any(named: 'computedLevel'),
        )).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#computedLevel] as int,
    );

    aggregator = HierarchyScoreAggregator(
      municipalityResolver: municipalityResolver,
      prefectureResolver: prefectureResolver,
      countryResolver: countryResolver,
      countryToContinent: const {'JPN': 'Asia'},
      ceilingService: mockCeilingService,
      levelHistoryRepository: mockLevelHistory,
    );
  });

  test('5階層すべての情報を返す', () async {
    final checkins = [
      (poiId: 'p1', lat: 5.0, lon: 5.0),
      (poiId: 'p2', lat: 5.0, lon: 6.0),
    ];

    final result = await aggregator.aggregateForCheckins(
      checkins,
      currentLat: 5.0,
      currentLon: 5.0,
    );

    expect(result.map((r) => r.tier), [
      'municipality',
      'prefecture',
      'country',
      'continent',
      'world',
    ]);

    final municipality = result.firstWhere((r) => r.tier == 'municipality');
    expect(municipality.name, 'サンプル市');
    expect(municipality.score, 2);
    expect(municipality.ceiling, 100);

    final country = result.firstWhere((r) => r.tier == 'country');
    expect(country.ceiling, isNull);

    final continent = result.firstWhere((r) => r.tier == 'continent');
    expect(continent.name, 'Asia');
    expect(continent.ceiling, isNull);

    final world = result.firstWhere((r) => r.tier == 'world');
    expect(world.ceiling, isNull);
    expect(world.score, 2);
  });
}

String _sampleGeoJson(String id, String name, List<List<double>> ring) {
  return '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"shapeID": "$id", "shapeISO": "$id", "shapeName": "$name"},
      "geometry": {"type": "Polygon", "coordinates": [${_ringToJson(ring)}]}
    }
  ]
}
''';
}

String _ringToJson(List<List<double>> ring) {
  final points = ring.map((p) => '[${p[0]}, ${p[1]}]').join(', ');
  return '[$points]';
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/hierarchy_score_aggregator_test.dart
```

Expected: `hierarchy_score_aggregator.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/hierarchy_score_aggregator.dart`:

```dart
import 'ceiling_service.dart';
import 'level_history_repository.dart';
import 'region_resolver.dart';
import 'score_calculator.dart';

class RegionLevelInfo {
  final String tier;
  final String name;
  final int score;
  final int? ceiling;
  final int level;

  const RegionLevelInfo({
    required this.tier,
    required this.name,
    required this.score,
    required this.ceiling,
    required this.level,
  });
}

class HierarchyScoreAggregator {
  final RegionResolver municipalityResolver;
  final RegionResolver prefectureResolver;
  final RegionResolver countryResolver;
  final Map<String, String> countryToContinent;
  final CeilingService ceilingService;
  final LevelHistoryRepository levelHistoryRepository;

  HierarchyScoreAggregator({
    required this.municipalityResolver,
    required this.prefectureResolver,
    required this.countryResolver,
    required this.countryToContinent,
    required this.ceilingService,
    required this.levelHistoryRepository,
  });

  Future<List<({String poiId, double lat, double lon})>> _filterByRegion(
    List<({String poiId, double lat, double lon})> checkins,
    RegionResolver resolver,
    String regionId,
  ) async {
    return checkins
        .where((c) => resolver.resolve(c.lat, c.lon)?.id == regionId)
        .toList();
  }

  Future<RegionLevelInfo> _tierWithCeiling({
    required String tier,
    required Region region,
    required int score,
  }) async {
    final ceiling = await ceilingService.getCeiling(region);
    final computedLevel = ScoreCalculator.level(score);
    final displayLevel = await levelHistoryRepository.recordAndGetDisplayLevel(
      tier: tier,
      regionId: region.id,
      computedLevel: computedLevel,
    );
    return RegionLevelInfo(
      tier: tier,
      name: region.name,
      score: score,
      ceiling: ceiling,
      level: displayLevel,
    );
  }

  Future<RegionLevelInfo> _tierWithoutCeiling({
    required String tier,
    required String regionId,
    required String name,
    required int score,
  }) async {
    final computedLevel = ScoreCalculator.level(score);
    final displayLevel = await levelHistoryRepository.recordAndGetDisplayLevel(
      tier: tier,
      regionId: regionId,
      computedLevel: computedLevel,
    );
    return RegionLevelInfo(
      tier: tier,
      name: name,
      score: score,
      ceiling: null,
      level: displayLevel,
    );
  }

  Future<List<RegionLevelInfo>> aggregateForCheckins(
    List<({String poiId, double lat, double lon})> checkins, {
    required double currentLat,
    required double currentLon,
  }) async {
    final results = <RegionLevelInfo>[];

    final municipality = municipalityResolver.resolve(currentLat, currentLon);
    if (municipality != null) {
      final scoped =
          await _filterByRegion(checkins, municipalityResolver, municipality.id);
      results.add(await _tierWithCeiling(
        tier: 'municipality',
        region: municipality,
        score: scoped.length,
      ));
    }

    final prefecture = prefectureResolver.resolve(currentLat, currentLon);
    if (prefecture != null) {
      final scoped =
          await _filterByRegion(checkins, prefectureResolver, prefecture.id);
      results.add(await _tierWithCeiling(
        tier: 'prefecture',
        region: prefecture,
        score: scoped.length,
      ));
    }

    final country = countryResolver.resolve(currentLat, currentLon);
    if (country != null) {
      final scoped = await _filterByRegion(checkins, countryResolver, country.id);
      results.add(await _tierWithoutCeiling(
        tier: 'country',
        regionId: country.id,
        name: country.name,
        score: scoped.length,
      ));

      final continentName = countryToContinent[country.id] ?? 'Unknown';
      results.add(await _tierWithoutCeiling(
        tier: 'continent',
        regionId: continentName,
        name: continentName,
        score: scoped.length,
      ));
    }

    results.add(await _tierWithoutCeiling(
      tier: 'world',
      regionId: 'world',
      name: 'World',
      score: checkins.length,
    ));

    return results;
  }
}
```

大陸・世界の「訪問した場所の数」は、本実装では暫定的に国のスコアと同数(大陸)・全チェックイン数(世界)としている。CLAUDE.mdが言う「制覇した下位地域の数」(例: 都道府県を何県制覇したか)は、制覇の定義(天井到達をもって制覇とみなす等)が本プランの前提資料に明記されていないため、本Stepでは実装しない。Phase 2以降のバッジ/実績システム設計時に定義し、別途実装する。

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/hierarchy_score_aggregator_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/hierarchy_score_aggregator.dart fogworld/test/services/hierarchy_score_aggregator_test.dart
git commit -m "feat: 5階層のレベル集計を行うHierarchyScoreAggregatorをTDDで実装"
```

---

### Task 6: `MapScreen` を5階層表示に統合する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 1〜5の全成果物
- Produces: チェックイン成功時、Step 4の単一バナー表示を5階層分のリスト表示に置き換える。

- [ ] **Step 1: `MapScreen` の初期化処理を拡張する**

`_initServices` に都道府県・国用の `RegionResolver`、大陸マッピング、`LevelHistoryRepository`、`HierarchyScoreAggregator` の初期化を追加する:

```dart
  Future<void> _initServices() async {
    _checkinRepository = await CheckinRepository.open();
    _checkedInPoiIds = await _checkinRepository!.getCheckedInPoiIds();

    final municipalityGeoJson =
        await rootBundle.loadString('assets/geo/jpn_adm2.geojson');
    final prefectureGeoJson =
        await rootBundle.loadString('assets/geo/jpn_adm1.geojson');
    final countryGeoJson =
        await rootBundle.loadString('assets/geo/world_adm0.geojson');
    final continentJson =
        await rootBundle.loadString('assets/geo/country_continent.json');

    final municipalityResolver = RegionResolver.fromGeoJson(
      municipalityGeoJson,
      idField: 'shapeID',
      nameField: 'shapeName',
    );
    final prefectureResolver = RegionResolver.fromGeoJson(
      prefectureGeoJson,
      idField: 'shapeID',
      nameField: 'shapeName',
    );
    final countryResolver = RegionResolver.fromGeoJson(
      countryGeoJson,
      idField: 'shapeISO',
      nameField: 'shapeName',
    );
    final countryToContinent =
        (jsonDecode(continentJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));

    _ceilingRepository = await CeilingRepository.open();
    _ceilingService = CeilingService(_ceilingRepository!, _overpassClient);

    _levelHistoryRepository = await LevelHistoryRepository.open();

    _hierarchyAggregator = HierarchyScoreAggregator(
      municipalityResolver: municipalityResolver,
      prefectureResolver: prefectureResolver,
      countryResolver: countryResolver,
      countryToContinent: countryToContinent,
      ceilingService: _ceilingService!,
      levelHistoryRepository: _levelHistoryRepository!,
    );
  }
```

(`import 'dart:convert';` を追加する。state フィールドに `LevelHistoryRepository? _levelHistoryRepository;`, `HierarchyScoreAggregator? _hierarchyAggregator;`, `List<RegionLevelInfo> _regionLevels = [];` を追加する)

- [ ] **Step 2: `_updateScoreForMunicipalityContaining` を階層集計呼び出しに置き換える**

メソッド名を `_updateHierarchyLevels(Poi poi)` に変更し、内部で `HierarchyScoreAggregator.aggregateForCheckins` を呼び出す:

```dart
  Future<void> _updateHierarchyLevels(Poi poi) async {
    final aggregator = _hierarchyAggregator;
    final checkinRepository = _checkinRepository;
    if (aggregator == null || checkinRepository == null) return;

    final allCheckins = await checkinRepository.getAllCheckins();
    final levels = await aggregator.aggregateForCheckins(
      allCheckins,
      currentLat: poi.lat,
      currentLon: poi.lon,
    );

    if (!mounted) return;
    setState(() {
      _regionLevels = levels;
    });
  }
```

`_checkIn` メソッド内の `await _updateScoreForMunicipalityContaining(poi);` 呼び出しを `await _updateHierarchyLevels(poi);` に変更する。既存の `_currentMunicipalityName`/`_currentScore`/`_currentLevel`/`_currentCeiling` フィールドと `_updateScoreForMunicipalityContaining` メソッドは削除する。

- [ ] **Step 3: バナー表示を5階層リスト表示に置き換える**

`build` メソッドのバナー部分を置き換える:

```dart
          if (_regionLevels.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _regionLevels.map((r) {
                  final ceilingText =
                      r.ceiling != null ? ' / 天井 ${r.ceiling}' : '';
                  return Text(
                    '${r.tier}: ${r.name} Lv.${r.level}(スコア ${r.score}$ceilingText)',
                  );
                }).toList(),
              ),
            ),
```

- [ ] **Step 4: `dispose` で `LevelHistoryRepository` もクローズする**

```dart
  @override
  void dispose() {
    _checkinRepository?.close();
    _ceilingRepository?.close();
    _levelHistoryRepository?.close();
    super.dispose();
  }
```

- [ ] **Step 5: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 7: エミュレータ/実機で5階層表示を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜6の全成果物
- Produces: 実機/エミュレータ上でチェックイン後に5階層すべてのレベルが表示される状態

- [ ] **Step 1: アプリを起動しPOIにチェックインする**

```powershell
cd fogworld
flutter run
```

Expected: チェックイン後、バナーに `municipality`, `prefecture`, `country`, `continent`, `world` の5行が表示され、市区町村・都道府県には「天井」の値が、国・大陸・世界には天井が表示されない(または「天井なし」相当の表記になる)ことを確認する。

- [ ] **Step 2: アプリを再起動し、レベルが下がらないことを確認する**

一度表示されたレベルが、再起動後の再計算で低くなっていないことを確認する(単調非減少の確認)。

- [ ] **Step 3: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 8: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 6〜7の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/map_screen.dart
git commit -m "feat: 5階層(世界/大陸/国/都道府県/市区町村)のレベル表示を統合"
```

---

## Step 5 完了条件(再掲)

- `flutter test` がパス(`RegionResolver`, `LevelHistoryRepository`, `HierarchyScoreAggregator` の単体テスト)
- `flutter analyze` がクリーン
- チェックイン後、5階層すべてのレベルが表示される
- 都道府県・市区町村には天井が表示され、国・大陸・世界には表示されない
- 一度表示されたレベルが再起動後も下がらない

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 6(バックデート記録機能)に進む。

## 既知の制約・積み残し(Phase 2以降で対応)

- 大陸・世界の「制覇した下位地域の数」表示は未実装(制覇の定義がCLAUDE.mdに明記されていないため)。バッジ/実績システムの設計時に定義する。
- 世界ADM0データのファイルサイズによっては簡略化データセットへの切り替えが必要(Task 1参照)。
- 日本国外でのチェックインは、Task 1で世界ADM0データが正しく用意されていれば国・大陸判定は機能するが、都道府県・市区町村相当の階層(ADM1/ADM2)は日本のみバンドルしているため解決できない(nullとして扱われ、該当階層はリストに含まれない)。他国のADM1/ADM2データ追加は別Stepとする。
