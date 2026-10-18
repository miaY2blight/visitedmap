# Step 4: スコア表示(市区町村1階層・ローカル) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** チェックイン地点が属する市区町村(日本国内、geoBoundaries ADM2)を判定し、その市区町村内での初回チェックインPOI数をスコアとして表示する。天井(その市区町村のPOI総数)はOverpass `out count` で初回到達時に遅延取得し、永続キャッシュする。

**Architecture:** `MunicipalityResolver`(bundledされたgeoBoundaries GeoJSONを読み込み、点がどの市区町村ポリゴンに属するかをレイキャスティング法で判定)→ `CeilingRepository`(市区町村ごとの天井値をsqfliteに永続キャッシュ。一度取得した値は再取得しない)→ `CeilingService`(キャッシュが無ければOverpass `out count` + `poly` フィルタで取得)→ `ScoreCalculator`(チェックイン済みPOIのうち当該市区町村に属するものの数からスコア・レベルを算出)という一方向パイプラインにする。`MapScreen` はチェックイン成功時にこのパイプラインを呼び出し、結果をUIに表示する。

**Tech Stack:** geoBoundaries ADM2(日本)GeoJSON(CC-BY 4.0、`https://www.geoboundaries.org/api/current/gbOpen/JPN/ADM2/` から取得したURLよりダウンロードしアプリにアセットとしてバンドル)。追加のFlutterパッケージは導入しない(GeoJSON解析は`dart:convert`、点内判定は自前実装)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(階層レベル設計・天井の遅延取得とキャッシュ方針)、[`../../plan.md`](../../plan.md)(Step 4の位置づけ)、[`step3-manual-checkin.md`](step3-manual-checkin.md)(前提となるチェックイン機能)

## Global Constraints

- 本Stepは市区町村階層のみを対象とする。都道府県・国・大陸・世界階層はStep 5で追加する。
- 天井は「一度取得したら再取得しない」(単調非減少の原則)。CLAUDE.mdの方針どおり、キャッシュに値があれば必ずそれを使う。
- Overpass公開インスタンスへのリクエストは、市区町村ごとに初回到達時の1回のみ(Task 2(Step 2)で実装済みの `OverpassClient` のレート制限機構を再利用する)。
- geoBoundariesのGeoJSONプロパティのフィールド名(`shapeName`/`shapeID`等)および `out count` のJSONレスポンス構造は、本プラン作成時点(2026-09-04)でWebFetchによる直接確認ができなかった(ファイルサイズ超過・ドキュメント未記載)。Task 1・Task 4の冒頭で実データを取得して構造を確認してから実装するステップを含む。

---

### Task 1: geoBoundariesの日本ADM2データをアセットとして用意する

**Files:**
- Create: `fogworld/assets/geo/jpn_adm2.geojson`
- Modify: `fogworld/pubspec.yaml`(`flutter.assets` にアセット登録)

**Interfaces:**
- Consumes: geoBoundaries API
- Produces: アプリにバンドルされたGeoJSONファイル。Task 2の `MunicipalityResolver` が `rootBundle` 経由で読み込む。

- [ ] **Step 1: geoBoundaries APIからダウンロードURLを取得する**

```powershell
Invoke-RestMethod -Uri "https://www.geoboundaries.org/api/current/gbOpen/JPN/ADM2/" | ConvertTo-Json -Depth 5
```

レスポンスJSON内の `gjDownloadURL`(フル解像度)、および簡略化版がある場合はそのフィールド(`simplifiedGeometryGeoJSON` 等、レスポンスのキー名を実際に確認する)を控える。ファイルサイズ(アプリバンドルサイズへの影響)を優先し、簡略化版が提供されていればそちらを使う。

- [ ] **Step 2: GeoJSONファイルをダウンロードする**

```powershell
New-Item -ItemType Directory -Force fogworld\assets\geo
Invoke-WebRequest -Uri "<Step 1で取得したダウンロードURL>" -OutFile fogworld\assets\geo\jpn_adm2.geojson
```

- [ ] **Step 3: ファイルサイズと構造を確認する**

```powershell
(Get-Item fogworld\assets\geo\jpn_adm2.geojson).Length / 1MB
Get-Content fogworld\assets\geo\jpn_adm2.geojson -TotalCount 1
```

ファイルサイズが数十MBを超える場合、Task 1をやり直して簡略化版(`gbHumanitarian`など、より粗い解像度のリリース)を使うか、後続タスクで自前の簡略化処理を検討する(本プランでは詳細化しない。数MB程度に収まることを前提に進める)。

先頭の内容を目視し、`"type": "FeatureCollection"` であること、および最初の `feature.properties` に含まれるフィールド名(`shapeName`, `shapeID`, `shapeISO`, `shapeGroup` 等)を確認し、Task 2の実装時にこのフィールド名を使う。

- [ ] **Step 4: `pubspec.yaml` にアセットを登録する**

`fogworld/pubspec.yaml` の `flutter:` セクションに追加:

```yaml
  assets:
    - assets/geo/jpn_adm2.geojson
```

- [ ] **Step 5: コミット**

```bash
git add fogworld/assets/geo/jpn_adm2.geojson fogworld/pubspec.yaml
git commit -m "feat: geoBoundaries日本ADM2境界データをアセットとして追加"
```

---

### Task 2: `PointInPolygon` ユーティリティをTDDで実装する

**Files:**
- Create: `fogworld/lib/services/point_in_polygon.dart`
- Test: `fogworld/test/services/point_in_polygon_test.dart`

**Interfaces:**
- Consumes: なし
- Produces: クラス `PointInPolygon`。静的メソッド `bool contains(List<List<double>> ring, double lat, double lon)` — `ring` は `[lon, lat]` の座標配列(GeoJSON座標順)。レイキャスティング法で判定する。Task 3の `MunicipalityResolver` がこれを使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/point_in_polygon_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/point_in_polygon.dart';

void main() {
  // lon=0..10, lat=0..10 の正方形
  final square = [
    [0.0, 0.0],
    [10.0, 0.0],
    [10.0, 10.0],
    [0.0, 10.0],
    [0.0, 0.0],
  ];

  test('正方形の内部の点はtrue', () {
    expect(PointInPolygon.contains(square, 5.0, 5.0), isTrue);
  });

  test('正方形の外部の点はfalse', () {
    expect(PointInPolygon.contains(square, 5.0, 20.0), isFalse);
  });

  test('複雑な形状(L字型)でも正しく判定する', () {
    final lShape = [
      [0.0, 0.0],
      [10.0, 0.0],
      [10.0, 5.0],
      [5.0, 5.0],
      [5.0, 10.0],
      [0.0, 10.0],
      [0.0, 0.0],
    ];

    // L字の凹んだ部分(欠けている角)は外部
    expect(PointInPolygon.contains(lShape, 8.0, 8.0), isFalse);
    // L字の実体部分は内部
    expect(PointInPolygon.contains(lShape, 2.0, 8.0), isTrue);
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/point_in_polygon_test.dart
```

Expected: `point_in_polygon.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/point_in_polygon.dart`:

```dart
class PointInPolygon {
  /// [ring] は [lon, lat] の座標配列(GeoJSON座標順)。
  /// lat/lonの点がポリゴンの内部にあるかをレイキャスティング法で判定する。
  static bool contains(List<List<double>> ring, double lat, double lon) {
    var inside = false;
    final n = ring.length;

    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i][0];
      final yi = ring[i][1];
      final xj = ring[j][0];
      final yj = ring[j][1];

      final intersects = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);

      if (intersects) inside = !inside;
    }

    return inside;
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/point_in_polygon_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/point_in_polygon.dart fogworld/test/services/point_in_polygon_test.dart
git commit -m "feat: レイキャスティング法によるPointInPolygonをTDDで実装"
```

---

### Task 3: `MunicipalityResolver` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/municipality_resolver.dart`
- Test: `fogworld/test/services/municipality_resolver_test.dart`
- Test fixture: `fogworld/test/fixtures/sample_municipalities.geojson`

**Interfaces:**
- Consumes: Task 2の `PointInPolygon`、GeoJSON文字列(本番では `rootBundle.loadString('assets/geo/jpn_adm2.geojson')`、テストではフィクスチャファイル)
- Produces: クラス `Municipality`(フィールド: `String shapeId`, `String name`, `List<List<List<double>>> outerRings` — Polygon/MultiPolygonそれぞれの外周リングをまとめたもの)。クラス `MunicipalityResolver`。静的メソッド `MunicipalityResolver fromGeoJson(String geoJsonString)`。インスタンスメソッド `Municipality? resolve(double lat, double lon)`。Task 5・7が使う。

- [ ] **Step 1: テスト用の小さなGeoJSONフィクスチャを作成する**

`fogworld/test/fixtures/sample_municipalities.geojson`(Task 1の実データのフィールド名を模した最小構成。Task 1で確認した実際のプロパティ名に合わせて調整する):

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "shapeID": "JPN-ADM2-001",
        "shapeName": "サンプル市"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0], [0.0, 0.0]]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "shapeID": "JPN-ADM2-002",
        "shapeName": "サンプル町(離島、MultiPolygon)"
      },
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [[[20.0, 20.0], [30.0, 20.0], [30.0, 30.0], [20.0, 30.0], [20.0, 20.0]]],
          [[[40.0, 40.0], [45.0, 40.0], [45.0, 45.0], [40.0, 45.0], [40.0, 40.0]]]
        ]
      }
    }
  ]
}
```

- [ ] **Step 2: 失敗するテストを書く**

`fogworld/test/services/municipality_resolver_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/municipality_resolver.dart';

void main() {
  late MunicipalityResolver resolver;

  setUp(() async {
    final geoJson =
        await File('test/fixtures/sample_municipalities.geojson').readAsString();
    resolver = MunicipalityResolver.fromGeoJson(geoJson);
  });

  test('Polygon領域内の点は対応する市区町村を返す', () {
    final result = resolver.resolve(5.0, 5.0);
    expect(result, isNotNull);
    expect(result!.shapeId, 'JPN-ADM2-001');
    expect(result.name, 'サンプル市');
  });

  test('MultiPolygonの2つ目のポリゴン内の点も正しく解決する', () {
    final result = resolver.resolve(42.0, 42.0);
    expect(result, isNotNull);
    expect(result!.shapeId, 'JPN-ADM2-002');
  });

  test('どの市区町村にも属さない点はnullを返す', () {
    final result = resolver.resolve(100.0, 100.0);
    expect(result, isNull);
  });
}
```

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/municipality_resolver_test.dart
```

Expected: `municipality_resolver.dart` が存在せずコンパイルエラーで失敗する。

- [ ] **Step 4: 最小実装を書く**

`fogworld/lib/services/municipality_resolver.dart`:

```dart
import 'dart:convert';
import 'point_in_polygon.dart';

class Municipality {
  final String shapeId;
  final String name;
  final List<List<List<double>>> outerRings;

  const Municipality({
    required this.shapeId,
    required this.name,
    required this.outerRings,
  });
}

class MunicipalityResolver {
  final List<Municipality> _municipalities;

  MunicipalityResolver._(this._municipalities);

  factory MunicipalityResolver.fromGeoJson(String geoJsonString) {
    final decoded = jsonDecode(geoJsonString) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>;

    final municipalities = features.map((f) {
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

      return Municipality(
        shapeId: properties['shapeID'].toString(),
        name: properties['shapeName'].toString(),
        outerRings: outerRings,
      );
    }).toList();

    return MunicipalityResolver._(municipalities);
  }

  static List<List<double>> _parseRing(List<dynamic> ring) {
    return ring
        .map((point) => (point as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList())
        .toList();
  }

  Municipality? resolve(double lat, double lon) {
    for (final municipality in _municipalities) {
      for (final ring in municipality.outerRings) {
        if (PointInPolygon.contains(ring, lat, lon)) {
          return municipality;
        }
      }
    }
    return null;
  }
}
```

穴(内側の輪、内海など)の除外はここでは実装しない(外周リングのみで判定する簡略化。MVPとして許容する)。

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/municipality_resolver_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/services/municipality_resolver.dart fogworld/test/services/municipality_resolver_test.dart fogworld/test/fixtures/sample_municipalities.geojson
git commit -m "feat: geoBoundaries GeoJSONから市区町村を解決するMunicipalityResolverをTDDで実装"
```

---

### Task 4: Overpassの `poly` カウントクエリと `CeilingRepository` をTDDで実装する

**Files:**
- Modify: `fogworld/lib/services/overpass_query_builder.dart`
- Modify: `fogworld/lib/services/overpass_client.dart`
- Create: `fogworld/lib/services/ceiling_repository.dart`
- Test: `fogworld/test/services/overpass_query_builder_test.dart`(追記)
- Test: `fogworld/test/services/overpass_client_test.dart`(追記)
- Test: `fogworld/test/services/ceiling_repository_test.dart`

**Interfaces:**
- Consumes: Task 2(Step 2)の `OverpassQueryBuilder`/`OverpassClient`、Task 3の `Municipality.outerRings`
- Produces: `OverpassQueryBuilder.buildPolygonCountQuery(List<List<double>> outerRingLonLat)`(GeoJSON順`[lon,lat]`のリングを受け取り、Overpassの`poly:"lat lon lat lon..."`構文に変換する)。`OverpassClient.countPoisInPolygon(List<List<double>> outerRingLonLat)` → `Future<int>`。クラス `CeilingRepository`(sqfliteで天井値を永続キャッシュ、`CheckinRepository`とは別DBファイル)。静的メソッド `Future<CeilingRepository> open({DatabaseFactory? factory, String? path})`、`Future<int?> getCachedCeiling(String shapeId)`、`Future<void> saveCeiling(String shapeId, int ceiling)`。Task 5の `CeilingService` がこれらを組み合わせる。

- [ ] **Step 1: 実際のOverpass `out count` レスポンス構造を確認する**

```powershell
$query = '[out:json][timeout:25];(node[amenity](poly:"35.0 139.0 35.1 139.0 35.1 139.1 35.0 139.1"););out count;'
Invoke-RestMethod -Uri "https://overpass-api.de/api/interpreter" -Method Post -Body @{ data = $query } | ConvertTo-Json -Depth 5
```

`elements` 配列内の `type: "count"` 要素の `tags` フィールド(`nodes`, `ways`, `relations`, `total` 等)の実際のキー名を確認し、以下のStepの実装で使う値を確定させる。

- [ ] **Step 2: `OverpassQueryBuilder` に失敗するテストを追記する**

`fogworld/test/services/overpass_query_builder_test.dart` に追記:

```dart
  test('ポリゴン内POI件数カウントクエリを生成する', () {
    final ring = [
      [139.0, 35.0],
      [139.1, 35.0],
      [139.1, 35.1],
      [139.0, 35.1],
      [139.0, 35.0],
    ];

    final query = OverpassQueryBuilder.buildPolygonCountQuery(ring);

    expect(query, contains('[out:json][timeout:25];'));
    expect(query, contains('poly:"35.0 139.0 35.0 139.1 35.1 139.1 35.1 139.0 35.0 139.0"'));
    expect(query, contains('out count;'));
  });
```

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_query_builder_test.dart
```

Expected: `buildPolygonCountQuery` が未定義でコンパイルエラー。

- [ ] **Step 4: `OverpassQueryBuilder` に実装を追加する**

`fogworld/lib/services/overpass_query_builder.dart` に追記:

```dart
  static String buildPolygonCountQuery(List<List<double>> outerRingLonLat) {
    final polyString = outerRingLonLat
        .map((point) => '${point[1]} ${point[0]}')
        .join(' ');
    final poly = 'poly:"$polyString"';

    final filters = [
      'node[amenity]($poly);',
      'way[amenity]($poly);',
      'node[shop]($poly);',
      'way[shop]($poly);',
      'node[tourism]($poly);',
      'way[tourism]($poly);',
      'node[leisure]($poly);',
      'way[leisure]($poly);',
      'node[historic]($poly);',
      'way[historic]($poly);',
      'node[railway~"^(station|halt)\$"]($poly);',
      'way[railway~"^(station|halt)\$"]($poly);',
      'node[public_transport]($poly);',
      'way[public_transport]($poly);',
    ].join('\n  ');

    return '[out:json][timeout:25];\n(\n  $filters\n);\nout count;';
  }
```

`buildNearbyPoiQuery` と対象タグの一覧が重複するため、共通の `_targetTagFilters(String selector)` プライベートヘルパーに抽出してよい(重複排除。実装時に整理する)。

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_query_builder_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: `OverpassClient` に失敗するテストを追記する**

`fogworld/test/services/overpass_client_test.dart` に追記(Step 1で確認した実際のJSONキー名に合わせて調整する。ここでは一般的な形式を仮定):

```dart
  test('ポリゴン内POI総数を取得する', () async {
    final mockClient = MockClient((request) async {
      final body = jsonEncode({
        'elements': [
          {
            'type': 'count',
            'tags': {'nodes': '10', 'ways': '5', 'relations': '0', 'total': '15'},
          },
        ],
      });
      return http.Response(body, 200);
    });

    final client = OverpassClient(httpClient: mockClient);
    final count = await client.countPoisInPolygon([
      [139.0, 35.0],
      [139.1, 35.0],
      [139.1, 35.1],
      [139.0, 35.1],
      [139.0, 35.0],
    ]);

    expect(count, 15);
  });
```

- [ ] **Step 7: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_client_test.dart
```

Expected: `countPoisInPolygon` が未定義でコンパイルエラー。

- [ ] **Step 8: `OverpassClient` に実装を追加する**

`fogworld/lib/services/overpass_client.dart` に追記:

```dart
  Future<int> countPoisInPolygon(List<List<double>> outerRingLonLat) async {
    await _waitForRateLimit();

    final query = OverpassQueryBuilder.buildPolygonCountQuery(outerRingLonLat);

    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      body: {'data': query},
    );

    _lastRequestAt = DateTime.now();

    if (response.statusCode != 200) {
      throw OverpassException('Overpass API returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>;
    final countElement = elements.first as Map<String, dynamic>;
    final tags = countElement['tags'] as Map<String, dynamic>;

    return int.parse(tags['total'] as String);
  }
```

- [ ] **Step 9: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/overpass_client_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 10: 失敗する `CeilingRepository` のテストを書く**

`fogworld/test/services/ceiling_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/services/ceiling_repository.dart';

void main() {
  sqfliteFfiInit();

  late CeilingRepository repository;

  setUp(() async {
    repository = await CeilingRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await repository.close();
  });

  test('未キャッシュの場合はnullを返す', () async {
    expect(await repository.getCachedCeiling('JPN-ADM2-001'), isNull);
  });

  test('保存した天井値を取得できる', () async {
    await repository.saveCeiling('JPN-ADM2-001', 42);
    expect(await repository.getCachedCeiling('JPN-ADM2-001'), 42);
  });

  test('同じshapeIdへの再保存は値を上書きする(通常は呼ばれない想定だが破壊しないことを確認)', () async {
    await repository.saveCeiling('JPN-ADM2-001', 42);
    await repository.saveCeiling('JPN-ADM2-001', 50);
    expect(await repository.getCachedCeiling('JPN-ADM2-001'), 50);
  });
}
```

- [ ] **Step 11: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/ceiling_repository_test.dart
```

Expected: `ceiling_repository.dart` が存在せずコンパイルエラー。

- [ ] **Step 12: 最小実装を書く**

`fogworld/lib/services/ceiling_repository.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

class CeilingRepository {
  final Database _db;

  CeilingRepository._(this._db);

  static Future<CeilingRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? sqflite.databaseFactory;
    final dbPath =
        path ?? p.join(await sqflite.getDatabasesPath(), 'fogworld_ceilings.db');

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ceilings (
              shape_id TEXT PRIMARY KEY,
              ceiling INTEGER NOT NULL,
              fetched_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    return CeilingRepository._(db);
  }

  Future<int?> getCachedCeiling(String shapeId) async {
    final rows = await _db.query(
      'ceilings',
      where: 'shape_id = ?',
      whereArgs: [shapeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['ceiling'] as int;
  }

  Future<void> saveCeiling(String shapeId, int ceiling) async {
    await _db.insert(
      'ceilings',
      {
        'shape_id': shapeId,
        'ceiling': ceiling,
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() => _db.close();
}
```

- [ ] **Step 13: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/ceiling_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 14: コミット**

```bash
git add fogworld/lib/services/overpass_query_builder.dart fogworld/lib/services/overpass_client.dart fogworld/lib/services/ceiling_repository.dart fogworld/test/services/overpass_query_builder_test.dart fogworld/test/services/overpass_client_test.dart fogworld/test/services/ceiling_repository_test.dart
git commit -m "feat: ポリゴン内POIカウントと天井値の永続キャッシュをTDDで実装"
```

---

### Task 5: `CeilingService` と `ScoreCalculator` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/ceiling_service.dart`
- Create: `fogworld/lib/services/score_calculator.dart`
- Test: `fogworld/test/services/ceiling_service_test.dart`
- Test: `fogworld/test/services/score_calculator_test.dart`

**Interfaces:**
- Consumes: Task 3の `Municipality`、Task 4の `CeilingRepository`/`OverpassClient.countPoisInPolygon`
- Produces: クラス `CeilingService`。コンストラクタ `CeilingService(CeilingRepository repository, OverpassClient client)`。メソッド `Future<int> getCeiling(Municipality municipality)` — キャッシュがあればそれを返し、無ければOverpassで取得して保存する。クラス `ScoreCalculator`。静的メソッド `int level(int score)` — `floor(sqrt(score)) + 1`(本プランで採用する暫定のレベル計算式。ゲームバランスの調整は別途行う前提の仮実装)。Task 6の `MapScreen` 統合で両方を使う。

- [ ] **Step 1: `CeilingService` の失敗するテストを書く**

`fogworld/test/services/ceiling_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fogworld/services/ceiling_repository.dart';
import 'package:fogworld/services/ceiling_service.dart';
import 'package:fogworld/services/municipality_resolver.dart';
import 'package:fogworld/services/overpass_client.dart';

class MockCeilingRepository extends Mock implements CeilingRepository {}

class MockOverpassClient extends Mock implements OverpassClient {}

void main() {
  late MockCeilingRepository mockRepository;
  late MockOverpassClient mockClient;
  late CeilingService service;

  const municipality = Municipality(
    shapeId: 'JPN-ADM2-001',
    name: 'サンプル市',
    outerRings: [
      [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0, 0.0]],
    ],
  );

  setUp(() {
    mockRepository = MockCeilingRepository();
    mockClient = MockOverpassClient();
    service = CeilingService(mockRepository, mockClient);
  });

  test('キャッシュがあればOverpassを呼ばずにキャッシュ値を返す', () async {
    when(() => mockRepository.getCachedCeiling('JPN-ADM2-001'))
        .thenAnswer((_) async => 120);

    final ceiling = await service.getCeiling(municipality);

    expect(ceiling, 120);
    verifyNever(() => mockClient.countPoisInPolygon(any()));
  });

  test('キャッシュが無ければOverpassで取得して保存する', () async {
    when(() => mockRepository.getCachedCeiling('JPN-ADM2-001'))
        .thenAnswer((_) async => null);
    when(() => mockClient.countPoisInPolygon(any()))
        .thenAnswer((_) async => 200);
    when(() => mockRepository.saveCeiling('JPN-ADM2-001', 200))
        .thenAnswer((_) async {});

    final ceiling = await service.getCeiling(municipality);

    expect(ceiling, 200);
    verify(() => mockRepository.saveCeiling('JPN-ADM2-001', 200)).called(1);
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/ceiling_service_test.dart
```

Expected: `ceiling_service.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: `CeilingService` の最小実装を書く**

`fogworld/lib/services/ceiling_service.dart`:

```dart
import 'ceiling_repository.dart';
import 'municipality_resolver.dart';
import 'overpass_client.dart';

class CeilingService {
  final CeilingRepository _repository;
  final OverpassClient _client;

  CeilingService(this._repository, this._client);

  Future<int> getCeiling(Municipality municipality) async {
    final cached = await _repository.getCachedCeiling(municipality.shapeId);
    if (cached != null) return cached;

    final ceiling =
        await _client.countPoisInPolygon(municipality.outerRings.first);
    await _repository.saveCeiling(municipality.shapeId, ceiling);
    return ceiling;
  }
}
```

複数の外周リング(MultiPolygon)を持つ市区町村の天井取得は `outerRings.first` のみを使う簡略化とする(離島等を含む市区町村では天井が過小評価される既知の制約。将来の改善候補とし、本Stepでは対応しない)。

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/ceiling_service_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: `ScoreCalculator` の失敗するテストを書く**

`fogworld/test/services/score_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/score_calculator.dart';

void main() {
  test('スコア0はレベル1', () {
    expect(ScoreCalculator.level(0), 1);
  });

  test('スコア1はレベル2', () {
    expect(ScoreCalculator.level(1), 2);
  });

  test('スコア4はレベル3', () {
    expect(ScoreCalculator.level(4), 3);
  });

  test('スコア9はレベル4', () {
    expect(ScoreCalculator.level(9), 4);
  });
}
```

- [ ] **Step 6: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/score_calculator_test.dart
```

Expected: `score_calculator.dart` が存在せずコンパイルエラー。

- [ ] **Step 7: 最小実装を書く**

`fogworld/lib/services/score_calculator.dart`:

```dart
import 'dart:math';

class ScoreCalculator {
  static int level(int score) {
    return sqrt(score).floor() + 1;
  }
}
```

- [ ] **Step 8: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/score_calculator_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 9: コミット**

```bash
git add fogworld/lib/services/ceiling_service.dart fogworld/lib/services/score_calculator.dart fogworld/test/services/ceiling_service_test.dart fogworld/test/services/score_calculator_test.dart
git commit -m "feat: 天井取得サービスとレベル計算をTDDで実装"
```

---

### Task 6: `MapScreen` にスコア・レベル・天井表示を統合する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 3〜5の全成果物、Task 1(Step 3)の `CheckinRepository`
- Produces: チェックイン成功時に対象POIの市区町村を判定し、その市区町村内でのスコア(チェックイン済みPOI数)・レベル・天井を計算して画面に表示する(AppBar直下に固定表示するバナーとする)。

- [ ] **Step 1: `CheckinRepository` に「特定エリア内のチェックイン済みPOI一覧」取得メソッドを追加する**

`fogworld/lib/services/checkin_repository.dart` に追記:

```dart
  Future<List<({String poiId, double lat, double lon})>> getAllCheckins() async {
    final rows = await _db.query('checkins', distinct: true, columns: ['poi_id', 'lat', 'lon']);
    return rows
        .map((row) => (
              poiId: row['poi_id'] as String,
              lat: row['lat'] as double,
              lon: row['lon'] as double,
            ))
        .toList();
  }
```

- [ ] **Step 2: `MapScreen` にスコア表示ロジックを追加する**

`fogworld/lib/screens/map_screen.dart` に追記(既存の `_checkIn` メソッドの末尾、`Navigator.of(context).pop()` の前に処理を追加し、state に表示用フィールドを追加する):

```dart
  // _MapScreenState に追加するフィールド
  MunicipalityResolver? _municipalityResolver;
  CeilingRepository? _ceilingRepository;
  CeilingService? _ceilingService;
  String? _currentMunicipalityName;
  int? _currentScore;
  int? _currentLevel;
  int? _currentCeiling;
```

`initState` を以下のように変更する:

```dart
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _checkinRepository = await CheckinRepository.open();
    _checkedInPoiIds = await _checkinRepository!.getCheckedInPoiIds();

    final geoJson = await rootBundle.loadString('assets/geo/jpn_adm2.geojson');
    _municipalityResolver = MunicipalityResolver.fromGeoJson(geoJson);

    _ceilingRepository = await CeilingRepository.open();
    _ceilingService = CeilingService(_ceilingRepository!, _overpassClient);
  }
```

(`import 'package:flutter/services.dart' show rootBundle;` を追加する)

`_checkIn` メソッドの `Navigator.of(context).pop();` の直前に追加:

```dart
    await _updateScoreForMunicipalityContaining(poi);
```

新規メソッドを追加:

```dart
  Future<void> _updateScoreForMunicipalityContaining(Poi poi) async {
    final resolver = _municipalityResolver;
    final ceilingService = _ceilingService;
    final checkinRepository = _checkinRepository;
    if (resolver == null || ceilingService == null || checkinRepository == null) {
      return;
    }

    final municipality = resolver.resolve(poi.lat, poi.lon);
    if (municipality == null) return;

    final ceiling = await ceilingService.getCeiling(municipality);

    final allCheckins = await checkinRepository.getAllCheckins();
    final score = allCheckins
        .where((c) => resolver.resolve(c.lat, c.lon)?.shapeId == municipality.shapeId)
        .length;

    if (!mounted) return;
    setState(() {
      _currentMunicipalityName = municipality.name;
      _currentScore = score;
      _currentLevel = ScoreCalculator.level(score);
      _currentCeiling = ceiling;
    });
  }
```

- [ ] **Step 3: スコア表示バナーをUIに追加する**

`build` メソッドの `Scaffold.body` を `Column` でラップし、地図の上にバナーを表示する:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FogWorld')),
      body: Column(
        children: [
          if (_currentMunicipalityName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                '$_currentMunicipalityName: Lv.$_currentLevel'
                '(スコア $_currentScore / 天井 $_currentCeiling)',
              ),
            ),
          Expanded(
            child: MapLibreMap(
              styleString: _openFreeMapLibertyStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(35.681236, 139.767125),
                zoom: 12,
              ),
              myLocationEnabled: false,
              onMapCreated: _onMapCreated,
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: `dispose` で `CeilingRepository` もクローズする**

```dart
  @override
  void dispose() {
    _checkinRepository?.close();
    _ceilingRepository?.close();
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

### Task 7: エミュレータ/実機でスコア・天井表示を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜6の全成果物
- Produces: 実機/エミュレータ上でチェックイン後にスコア・レベル・天井が表示される状態

- [ ] **Step 1: アプリを起動しPOIにチェックインする**

```powershell
cd fogworld
flutter run
```

Expected: チェックイン後、AppBar直下に「〇〇市: Lv.2(スコア 1 / 天井 XXX)」のようなバナーが表示される。天井取得はOverpassへのリクエストが発生するため数秒かかる場合がある。

- [ ] **Step 2: 別のPOIにもチェックインし、スコアが増えることを確認する**

同じ市区町村内の別POIにチェックインする。

Expected: スコアが2に増え、レベルが `ScoreCalculator.level(2)` の値に更新される。天井値は再取得されず、初回と同じ値のまま(Overpassへの追加リクエストが発生しないことをログや通信状況で確認できるとなお良い)。

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
git add fogworld/lib/screens/map_screen.dart fogworld/lib/services/checkin_repository.dart
git commit -m "feat: 市区町村単位のスコア・レベル・天井表示を追加"
```

---

## Step 4 完了条件(再掲)

- `flutter test` がパス(`PointInPolygon`, `MunicipalityResolver`, `OverpassQueryBuilder`/`OverpassClient` の拡張, `CeilingRepository`, `CeilingService`, `ScoreCalculator` の単体テスト)
- `flutter analyze` がクリーン
- チェックイン後、所属市区町村・スコア・レベル・天井がUIに表示される
- 同一市区町村への2回目以降のチェックインでは天井の再取得が発生しない(キャッシュが機能する)

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 5(階層レベルの全展開)に進む。
