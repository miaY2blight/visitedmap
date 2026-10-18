# Step 7: 除外地域 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** オンボーディングで志向をヒアリングし、キュレーション済みの除外候補(紛争地域等)を自動適用する。後から個別に手動調整もできる。除外された地域は階層レベル集計の対象から外れる。

**Architecture:** `ExclusionCandidate`(静的JSONアセット、`regionTier`+`regionId`+`category`+`label`)を「除外候補カタログ」とし、オンボーディングで選んだカテゴリに応じて `ExclusionRepository`(sqflite)に反映する。`ExclusionRepository` は実際に除外されている地域IDの集合を保持する唯一の情報源とし、Step 5の `HierarchyScoreAggregator` はこのリポジトリを追加で受け取り、除外地域に該当する階層を結果から除く。手動調整用の設定画面は `ExclusionRepository` を直接読み書きする。

**Tech Stack:** `shared_preferences` ^2.5.5(オンボーディング完了フラグの保存)。除外候補カタログは自前でキュレーションする静的JSONアセット(外部APIからの動的取得は行わない。CLAUDE.mdが要求する「キュレーション済みの除外候補」は開発者が用意するコンテンツであり、本プランはその収録の仕組みのみを実装する)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(除外地域の方針: 固定デフォルト除外リストは採用せず、オンボーディングでのヒアリング+自動適用+手動調整)、[`../../plan.md`](../../plan.md)(Step 7の位置づけ)、[`step5-hierarchical-levels.md`](step5-hierarchical-levels.md)(前提となる階層レベル集計)

## Global Constraints

- 除外候補カタログの中身(実際にどの国・地域を「紛争地域」等として収録するか)は本プランの範囲外とする。本プランはメカニズム(データ構造・適用ロジック・UI)のみを実装し、Task 1では動作確認可能な最小限のサンプルデータ(架空または一般に係争が広く報じられている数件)を用意するに留める。実運用に耐えるキュレーションデータの収集・監修は別途コンテンツ作業として行う。
- 除外はチェックイン自体を禁止するものではない(ユーザーが除外地域を実際に訪れてチェックインすることは可能)。除外は「階層レベル集計・天井計算の対象外にする」ことのみを意味する(CLAUDE.md方針)。
- 除外設定は国(country)またはより粗い粒度(将来的に大陸等)を基本単位とする。都道府県・市区町村単位の個別除外は本Stepの範囲外とする(手動調整も国単位までとする)。

---

### Task 1: 除外候補カタログを用意する

**Files:**
- Create: `fogworld/assets/geo/exclusion_candidates.json`
- Modify: `fogworld/pubspec.yaml`(アセット登録)

**Interfaces:**
- Consumes: なし
- Produces: 除外候補の静的データ。Task 2の `ExclusionCandidateCatalog` が読み込む。

- [ ] **Step 1: サンプルカタログを作成する**

`fogworld/assets/geo/exclusion_candidates.json`(`regionId` はStep 5で使っている国コード(`shapeISO`)に合わせる。実運用データは別途差し替える前提のプレースホルダーであることをコメント欄に明記する):

```json
{
  "categories": [
    {
      "id": "conflict",
      "label": "紛争・治安上の懸念がある地域",
      "regions": [
        {"tier": "country", "regionId": "SAMPLE1", "name": "サンプル地域A(要実データ差し替え)"},
        {"tier": "country", "regionId": "SAMPLE2", "name": "サンプル地域B(要実データ差し替え)"}
      ]
    }
  ]
}
```

- [ ] **Step 2: `pubspec.yaml` にアセットを登録する**

```yaml
  assets:
    - assets/geo/exclusion_candidates.json
```

- [ ] **Step 3: コミット**

```bash
git add fogworld/assets/geo/exclusion_candidates.json fogworld/pubspec.yaml
git commit -m "feat: 除外候補カタログのデータ構造とサンプルデータを追加"
```

---

### Task 2: `ExclusionCandidateCatalog` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/exclusion_candidate_catalog.dart`
- Test: `fogworld/test/services/exclusion_candidate_catalog_test.dart`

**Interfaces:**
- Consumes: Task 1のJSON文字列
- Produces: クラス `ExclusionCandidateRegion`(`String tier`, `String regionId`, `String name`)。クラス `ExclusionCategory`(`String id`, `String label`, `List<ExclusionCandidateRegion> regions`)。クラス `ExclusionCandidateCatalog`。ファクトリ `ExclusionCandidateCatalog.fromJson(String jsonString)`。ゲッター `List<ExclusionCategory> categories`。Task 4のオンボーディング適用ロジックが使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/exclusion_candidate_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/exclusion_candidate_catalog.dart';

void main() {
  const sampleJson = '''
{
  "categories": [
    {
      "id": "conflict",
      "label": "紛争地域",
      "regions": [
        {"tier": "country", "regionId": "SAMPLE1", "name": "サンプル地域A"}
      ]
    }
  ]
}
''';

  test('JSONからカテゴリと地域を読み込む', () {
    final catalog = ExclusionCandidateCatalog.fromJson(sampleJson);

    expect(catalog.categories.length, 1);
    expect(catalog.categories.first.id, 'conflict');
    expect(catalog.categories.first.regions.first.regionId, 'SAMPLE1');
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/exclusion_candidate_catalog_test.dart
```

Expected: コンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/exclusion_candidate_catalog.dart`:

```dart
import 'dart:convert';

class ExclusionCandidateRegion {
  final String tier;
  final String regionId;
  final String name;

  const ExclusionCandidateRegion({
    required this.tier,
    required this.regionId,
    required this.name,
  });
}

class ExclusionCategory {
  final String id;
  final String label;
  final List<ExclusionCandidateRegion> regions;

  const ExclusionCategory({
    required this.id,
    required this.label,
    required this.regions,
  });
}

class ExclusionCandidateCatalog {
  final List<ExclusionCategory> categories;

  const ExclusionCandidateCatalog(this.categories);

  factory ExclusionCandidateCatalog.fromJson(String jsonString) {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final categoriesJson = decoded['categories'] as List<dynamic>;

    final categories = categoriesJson.map((c) {
      final category = c as Map<String, dynamic>;
      final regionsJson = category['regions'] as List<dynamic>;
      final regions = regionsJson.map((r) {
        final region = r as Map<String, dynamic>;
        return ExclusionCandidateRegion(
          tier: region['tier'] as String,
          regionId: region['regionId'] as String,
          name: region['name'] as String,
        );
      }).toList();

      return ExclusionCategory(
        id: category['id'] as String,
        label: category['label'] as String,
        regions: regions,
      );
    }).toList();

    return ExclusionCandidateCatalog(categories);
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/exclusion_candidate_catalog_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/exclusion_candidate_catalog.dart fogworld/test/services/exclusion_candidate_catalog_test.dart
git commit -m "feat: 除外候補カタログのパーサーをTDDで実装"
```

---

### Task 3: `ExclusionRepository` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/exclusion_repository.dart`
- Test: `fogworld/test/services/exclusion_repository_test.dart`

**Interfaces:**
- Consumes: なし(sqfliteのみ)
- Produces: クラス `ExclusionRepository`。静的メソッド `Future<ExclusionRepository> open({DatabaseFactory? factory, String? path})`。メソッド `Future<void> exclude({required String tier, required String regionId})`、`Future<void> include({required String tier, required String regionId})`(除外解除)、`Future<bool> isExcluded({required String tier, required String regionId})`、`Future<Set<String>> getExcludedRegionIds(String tier)`。Task 4・6が使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/exclusion_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/services/exclusion_repository.dart';

void main() {
  sqfliteFfiInit();

  late ExclusionRepository repository;

  setUp(() async {
    repository = await ExclusionRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await repository.close();
  });

  test('除外前はisExcludedがfalse', () async {
    expect(
      await repository.isExcluded(tier: 'country', regionId: 'SAMPLE1'),
      isFalse,
    );
  });

  test('excludeするとisExcludedがtrueになる', () async {
    await repository.exclude(tier: 'country', regionId: 'SAMPLE1');
    expect(
      await repository.isExcluded(tier: 'country', regionId: 'SAMPLE1'),
      isTrue,
    );
  });

  test('includeで除外を解除できる', () async {
    await repository.exclude(tier: 'country', regionId: 'SAMPLE1');
    await repository.include(tier: 'country', regionId: 'SAMPLE1');
    expect(
      await repository.isExcluded(tier: 'country', regionId: 'SAMPLE1'),
      isFalse,
    );
  });

  test('getExcludedRegionIdsはtier別に取得できる', () async {
    await repository.exclude(tier: 'country', regionId: 'SAMPLE1');
    await repository.exclude(tier: 'country', regionId: 'SAMPLE2');

    final ids = await repository.getExcludedRegionIds('country');
    expect(ids, {'SAMPLE1', 'SAMPLE2'});
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/exclusion_repository_test.dart
```

Expected: コンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/exclusion_repository.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

class ExclusionRepository {
  final Database _db;

  ExclusionRepository._(this._db);

  static Future<ExclusionRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final dbFactory = factory ?? sqflite.databaseFactory;
    final dbPath = path ??
        p.join(await sqflite.getDatabasesPath(), 'fogworld_exclusions.db');

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE excluded_regions (
              tier TEXT NOT NULL,
              region_id TEXT NOT NULL,
              PRIMARY KEY (tier, region_id)
            )
          ''');
        },
      ),
    );

    return ExclusionRepository._(db);
  }

  Future<void> exclude({required String tier, required String regionId}) async {
    await _db.insert(
      'excluded_regions',
      {'tier': tier, 'region_id': regionId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> include({required String tier, required String regionId}) async {
    await _db.delete(
      'excluded_regions',
      where: 'tier = ? AND region_id = ?',
      whereArgs: [tier, regionId],
    );
  }

  Future<bool> isExcluded({required String tier, required String regionId}) async {
    final rows = await _db.query(
      'excluded_regions',
      where: 'tier = ? AND region_id = ?',
      whereArgs: [tier, regionId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getExcludedRegionIds(String tier) async {
    final rows = await _db.query(
      'excluded_regions',
      where: 'tier = ?',
      whereArgs: [tier],
      columns: ['region_id'],
    );
    return rows.map((row) => row['region_id'] as String).toSet();
  }

  Future<void> close() => _db.close();
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/exclusion_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/exclusion_repository.dart fogworld/test/services/exclusion_repository_test.dart
git commit -m "feat: 除外地域の永続化を行うExclusionRepositoryをTDDで実装"
```

---

### Task 4: オンボーディング適用ロジックをTDDで実装する

**Files:**
- Create: `fogworld/lib/services/onboarding_preferences.dart`
- Test: `fogworld/test/services/onboarding_preferences_test.dart`
- Modify: `fogworld/pubspec.yaml`(`shared_preferences` 追加)

**Interfaces:**
- Consumes: Task 2の `ExclusionCandidateCatalog`、Task 3の `ExclusionRepository`
- Produces: クラス `OnboardingPreferences`。静的メソッド `Future<OnboardingPreferences> open({SharedPreferences? prefs})`。メソッド `Future<bool> isOnboardingCompleted()`、`Future<void> completeOnboarding()`。関数 `Future<void> applySelectedCategories({required ExclusionCandidateCatalog catalog, required ExclusionRepository exclusionRepository, required Set<String> selectedCategoryIds})` — 選択されたカテゴリに含まれる全地域を `exclusionRepository.exclude(...)` で登録する(トップレベル関数、または `OnboardingPreferences` の静的メソッドとして実装してよい。ここでは静的メソッドとする)。Task 5のオンボーディング画面がこれらを呼び出す。

- [ ] **Step 1: `pubspec.yaml` に `shared_preferences` を追加する**

```yaml
  shared_preferences: ^2.5.5
```

```powershell
cd fogworld
flutter pub get
```

- [ ] **Step 2: 失敗するテストを書く**

`fogworld/test/services/onboarding_preferences_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/services/exclusion_candidate_catalog.dart';
import 'package:fogworld/services/exclusion_repository.dart';
import 'package:fogworld/services/onboarding_preferences.dart';

void main() {
  sqfliteFfiInit();

  test('初回はオンボーディング未完了', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await OnboardingPreferences.open();
    expect(await prefs.isOnboardingCompleted(), isFalse);
  });

  test('completeOnboarding後は完了状態になる', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await OnboardingPreferences.open();
    await prefs.completeOnboarding();
    expect(await prefs.isOnboardingCompleted(), isTrue);
  });

  test('選択したカテゴリの全地域が除外される', () async {
    const catalog = ExclusionCandidateCatalog([
      ExclusionCategory(
        id: 'conflict',
        label: '紛争地域',
        regions: [
          ExclusionCandidateRegion(tier: 'country', regionId: 'SAMPLE1', name: 'A'),
          ExclusionCandidateRegion(tier: 'country', regionId: 'SAMPLE2', name: 'B'),
        ],
      ),
      ExclusionCategory(
        id: 'remote',
        label: '秘境',
        regions: [
          ExclusionCandidateRegion(tier: 'country', regionId: 'SAMPLE3', name: 'C'),
        ],
      ),
    ]);

    final exclusionRepository = await ExclusionRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    await OnboardingPreferences.applySelectedCategories(
      catalog: catalog,
      exclusionRepository: exclusionRepository,
      selectedCategoryIds: {'conflict'},
    );

    expect(
      await exclusionRepository.isExcluded(tier: 'country', regionId: 'SAMPLE1'),
      isTrue,
    );
    expect(
      await exclusionRepository.isExcluded(tier: 'country', regionId: 'SAMPLE2'),
      isTrue,
    );
    expect(
      await exclusionRepository.isExcluded(tier: 'country', regionId: 'SAMPLE3'),
      isFalse,
    );

    await exclusionRepository.close();
  });
}
```

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/onboarding_preferences_test.dart
```

Expected: コンパイルエラー(`ExclusionCandidateCatalog`, `ExclusionCategory`, `ExclusionCandidateRegion` を `const` コンストラクタで使えるようにする必要があるため、Task 2のクラス定義に `const` コンストラクタを追加する)。

- [ ] **Step 4: Task 2のモデルクラスに `const` コンストラクタを付与する**

`fogworld/lib/services/exclusion_candidate_catalog.dart` の `ExclusionCandidateRegion`, `ExclusionCategory` のコンストラクタに `const` を付与する(既存コードの `const` 修飾のみの変更。ロジック変更なし)。

- [ ] **Step 5: `OnboardingPreferences` の最小実装を書く**

`fogworld/lib/services/onboarding_preferences.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'exclusion_candidate_catalog.dart';
import 'exclusion_repository.dart';

class OnboardingPreferences {
  static const _completedKey = 'onboarding_completed';

  final SharedPreferences _prefs;

  OnboardingPreferences._(this._prefs);

  static Future<OnboardingPreferences> open({SharedPreferences? prefs}) async {
    final resolved = prefs ?? await SharedPreferences.getInstance();
    return OnboardingPreferences._(resolved);
  }

  Future<bool> isOnboardingCompleted() async {
    return _prefs.getBool(_completedKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_completedKey, true);
  }

  static Future<void> applySelectedCategories({
    required ExclusionCandidateCatalog catalog,
    required ExclusionRepository exclusionRepository,
    required Set<String> selectedCategoryIds,
  }) async {
    for (final category in catalog.categories) {
      if (!selectedCategoryIds.contains(category.id)) continue;
      for (final region in category.regions) {
        await exclusionRepository.exclude(
          tier: region.tier,
          regionId: region.regionId,
        );
      }
    }
  }
}
```

- [ ] **Step 6: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/onboarding_preferences_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 7: コミット**

```bash
git add fogworld/lib/services/onboarding_preferences.dart fogworld/lib/services/exclusion_candidate_catalog.dart fogworld/test/services/onboarding_preferences_test.dart fogworld/pubspec.yaml fogworld/pubspec.lock
git commit -m "feat: オンボーディング選択に基づく除外地域自動適用をTDDで実装"
```

---

### Task 5: `HierarchyScoreAggregator` を除外対応にする

**Files:**
- Modify: `fogworld/lib/services/hierarchy_score_aggregator.dart`
- Modify: `fogworld/test/services/hierarchy_score_aggregator_test.dart`

**Interfaces:**
- Consumes: Task 3の `ExclusionRepository`
- Produces: `HierarchyScoreAggregator` のコンストラクタに `required ExclusionRepository exclusionRepository` を追加。`aggregateForCheckins` は、各階層の `region.id`(国・都道府県・市区町村)が除外されている場合、その階層を結果リストに含めない。

- [ ] **Step 1: 失敗するテストを追記する**

`fogworld/test/services/hierarchy_score_aggregator_test.dart` に追記(`MockExclusionRepository` を追加し、既存の `setUp` に組み込む):

```dart
class MockExclusionRepository extends Mock implements ExclusionRepository {}
```

`setUp` 内で `mockExclusionRepository` を作成し、デフォルトで `isExcluded` が常に `false` を返すよう設定した上で、`HierarchyScoreAggregator` のコンストラクタに渡す(既存の全テストを通すため)。その上で新規テストを追加:

```dart
  test('除外されている国はcountry/continentがリストから除かれる', () async {
    when(() => mockExclusionRepository.isExcluded(
          tier: 'country',
          regionId: 'JPN-001',
        )).thenAnswer((_) async => true);

    final checkins = [(poiId: 'p1', lat: 5.0, lon: 5.0)];

    final result = await aggregator.aggregateForCheckins(
      checkins,
      currentLat: 5.0,
      currentLon: 5.0,
    );

    expect(result.any((r) => r.tier == 'country'), isFalse);
    expect(result.any((r) => r.tier == 'continent'), isFalse);
    expect(result.any((r) => r.tier == 'municipality'), isTrue);
  });
```

`_sampleGeoJson('JPN', ...)` を使っている既存テストの `countryResolver` は `shapeISO` に `'JPN-001'`(`countryResolver` 生成時の `id` 引数)を使っているため、テストの `_sampleGeoJson` 呼び出し箇所の国IDを `'JPN-001'` に統一する(既存テストの `country.id`/`continent`名の期待値もこのIDに合わせて調整する)。

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/hierarchy_score_aggregator_test.dart
```

Expected: `exclusionRepository` 引数が無くコンパイルエラー。

- [ ] **Step 3: `HierarchyScoreAggregator` に除外チェックを追加する**

`fogworld/lib/services/hierarchy_score_aggregator.dart` を変更する:

```dart
import 'ceiling_service.dart';
import 'exclusion_repository.dart';
import 'level_history_repository.dart';
import 'region_resolver.dart';
import 'score_calculator.dart';

// ...(RegionLevelInfoは変更なし)

class HierarchyScoreAggregator {
  final RegionResolver municipalityResolver;
  final RegionResolver prefectureResolver;
  final RegionResolver countryResolver;
  final Map<String, String> countryToContinent;
  final CeilingService ceilingService;
  final LevelHistoryRepository levelHistoryRepository;
  final ExclusionRepository exclusionRepository;

  HierarchyScoreAggregator({
    required this.municipalityResolver,
    required this.prefectureResolver,
    required this.countryResolver,
    required this.countryToContinent,
    required this.ceilingService,
    required this.levelHistoryRepository,
    required this.exclusionRepository,
  });

  // ...(_filterByRegion, _tierWithCeiling, _tierWithoutCeilingは変更なし)

  Future<List<RegionLevelInfo>> aggregateForCheckins(
    List<({String poiId, double lat, double lon})> checkins, {
    required double currentLat,
    required double currentLon,
  }) async {
    final results = <RegionLevelInfo>[];

    final municipality = municipalityResolver.resolve(currentLat, currentLon);
    if (municipality != null &&
        !await exclusionRepository.isExcluded(
            tier: 'municipality', regionId: municipality.id)) {
      final scoped =
          await _filterByRegion(checkins, municipalityResolver, municipality.id);
      results.add(await _tierWithCeiling(
        tier: 'municipality',
        region: municipality,
        score: scoped.length,
      ));
    }

    final prefecture = prefectureResolver.resolve(currentLat, currentLon);
    if (prefecture != null &&
        !await exclusionRepository.isExcluded(
            tier: 'prefecture', regionId: prefecture.id)) {
      final scoped =
          await _filterByRegion(checkins, prefectureResolver, prefecture.id);
      results.add(await _tierWithCeiling(
        tier: 'prefecture',
        region: prefecture,
        score: scoped.length,
      ));
    }

    final country = countryResolver.resolve(currentLat, currentLon);
    final countryExcluded = country != null &&
        await exclusionRepository.isExcluded(
            tier: 'country', regionId: country.id);

    if (country != null && !countryExcluded) {
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

世界階層(`world`)は除外対象にしない(常に表示する)。国が除外された場合、その国に紐づく大陸表示もあわせて省略する(大陸全体を除外するには全構成国を除外候補に含める必要がある、という運用上の制約になるが、大陸単位の除外UIは本Stepでは提供しない)。

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/hierarchy_score_aggregator_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/hierarchy_score_aggregator.dart fogworld/test/services/hierarchy_score_aggregator_test.dart
git commit -m "feat: HierarchyScoreAggregatorを除外地域対応にする"
```

---

### Task 6: オンボーディング画面を実装する

**Files:**
- Create: `fogworld/lib/screens/onboarding_screen.dart`
- Modify: `fogworld/lib/main.dart`

**Interfaces:**
- Consumes: Task 1のJSONアセット、Task 2〜4の全成果物
- Produces: ウィジェット `OnboardingScreen extends StatefulWidget`。カテゴリごとにチェックボックスを表示し、「はじめる」ボタンで `OnboardingPreferences.applySelectedCategories` を実行後、`completeOnboarding()` を呼んで `MapScreen` に遷移する。`main.dart` は起動時に `OnboardingPreferences.isOnboardingCompleted()` を確認し、未完了なら `OnboardingScreen`、完了済みなら `MapScreen` を表示する。

- [ ] **Step 1: `OnboardingScreen` を作成する**

`fogworld/lib/screens/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/exclusion_candidate_catalog.dart';
import '../services/exclusion_repository.dart';
import '../services/onboarding_preferences.dart';
import 'map_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  ExclusionCandidateCatalog? _catalog;
  final Set<String> _selectedCategoryIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final jsonString =
        await rootBundle.loadString('assets/geo/exclusion_candidates.json');
    setState(() {
      _catalog = ExclusionCandidateCatalog.fromJson(jsonString);
    });
  }

  Future<void> _submit() async {
    final catalog = _catalog;
    if (catalog == null) return;

    setState(() => _isSubmitting = true);

    final exclusionRepository = await ExclusionRepository.open();
    await OnboardingPreferences.applySelectedCategories(
      catalog: catalog,
      exclusionRepository: exclusionRepository,
      selectedCategoryIds: _selectedCategoryIds,
    );
    await exclusionRepository.close();

    final onboardingPreferences = await OnboardingPreferences.open();
    await onboardingPreferences.completeOnboarding();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    return Scaffold(
      appBar: AppBar(title: const Text('はじめに')),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('集計から除外したい地域のカテゴリを選択してください(後から変更できます)'),
                  const SizedBox(height: 16),
                  ...catalog.categories.map((category) {
                    final selected = _selectedCategoryIds.contains(category.id);
                    return CheckboxListTile(
                      title: Text(category.label),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedCategoryIds.add(category.id);
                          } else {
                            _selectedCategoryIds.remove(category.id);
                          }
                        });
                      },
                    );
                  }),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: const Text('はじめる'),
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: `main.dart` を起動時分岐に変更する**

`fogworld/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/onboarding_preferences.dart';

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
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatelessWidget {
  const _StartupRouter();

  Future<bool> _isOnboardingCompleted() async {
    final prefs = await OnboardingPreferences.open();
    return prefs.isOnboardingCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingCompleted(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const MapScreen() : const OnboardingScreen();
      },
    );
  }
}
```

- [ ] **Step 3: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 7: 除外地域の手動調整画面を実装する

**Files:**
- Create: `fogworld/lib/screens/exclusion_settings_screen.dart`
- Modify: `fogworld/lib/screens/map_screen.dart`(設定画面への導線を追加)

**Interfaces:**
- Consumes: Task 1のカタログ、Task 3の `ExclusionRepository`
- Produces: ウィジェット `ExclusionSettingsScreen`。カタログの全地域を一覧表示し、それぞれの除外ON/OFFを個別にトグルできる(`ExclusionRepository.exclude`/`include` を直接呼ぶ)。`MapScreen` の `AppBar` に設定画面への導線(アイコンボタン)を追加する。

- [ ] **Step 1: `ExclusionSettingsScreen` を作成する**

`fogworld/lib/screens/exclusion_settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/exclusion_candidate_catalog.dart';
import '../services/exclusion_repository.dart';

class ExclusionSettingsScreen extends StatefulWidget {
  const ExclusionSettingsScreen({super.key});

  @override
  State<ExclusionSettingsScreen> createState() =>
      _ExclusionSettingsScreenState();
}

class _ExclusionSettingsScreenState extends State<ExclusionSettingsScreen> {
  ExclusionCandidateCatalog? _catalog;
  ExclusionRepository? _repository;
  final Map<String, bool> _excludedState = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jsonString =
        await rootBundle.loadString('assets/geo/exclusion_candidates.json');
    final catalog = ExclusionCandidateCatalog.fromJson(jsonString);
    final repository = await ExclusionRepository.open();

    final state = <String, bool>{};
    for (final category in catalog.categories) {
      for (final region in category.regions) {
        state[region.regionId] = await repository.isExcluded(
          tier: region.tier,
          regionId: region.regionId,
        );
      }
    }

    setState(() {
      _catalog = catalog;
      _repository = repository;
      _excludedState.addAll(state);
    });
  }

  Future<void> _toggle(String tier, String regionId, bool excluded) async {
    final repository = _repository;
    if (repository == null) return;

    if (excluded) {
      await repository.exclude(tier: tier, regionId: regionId);
    } else {
      await repository.include(tier: tier, regionId: regionId);
    }

    setState(() {
      _excludedState[regionId] = excluded;
    });
  }

  @override
  void dispose() {
    _repository?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    return Scaffold(
      appBar: AppBar(title: const Text('除外地域の設定')),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: catalog.categories.expand((category) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      category.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ...category.regions.map((region) {
                    return SwitchListTile(
                      title: Text(region.name),
                      value: _excludedState[region.regionId] ?? false,
                      onChanged: (value) =>
                          _toggle(region.tier, region.regionId, value),
                    );
                  }),
                ];
              }).toList(),
            ),
    );
  }
}
```

- [ ] **Step 2: `MapScreen` の `AppBar` に設定画面への導線を追加する**

`fogworld/lib/screens/map_screen.dart` の `AppBar` を変更する:

```dart
      appBar: AppBar(
        title: const Text('FogWorld'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExclusionSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
```

`import 'exclusion_settings_screen.dart';` を追加する。

- [ ] **Step 3: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 8: エミュレータ/実機でオンボーディング〜除外設定を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜7の全成果物
- Produces: 実機/エミュレータ上でオンボーディング〜除外反映〜手動調整が一通り動作する状態

- [ ] **Step 1: アプリを初回起動しオンボーディングを確認する**

初回起動前にアプリをアンインストールしておく(オンボーディング完了フラグをリセットするため)。

```powershell
cd fogworld
flutter run
```

Expected: 起動直後にオンボーディング画面が表示され、除外候補カテゴリのチェックボックスが表示される。

- [ ] **Step 2: カテゴリを選択して「はじめる」を押す**

Expected: `MapScreen` に遷移する。

- [ ] **Step 3: 設定画面から除外状態を確認・変更する**

`AppBar` の歯車アイコンから設定画面を開く。

Expected: Step 2で選択したカテゴリの地域がすべてONになっている。任意の項目をOFFにすると即座に反映される。

- [ ] **Step 4: アプリを再起動し、2回目以降はオンボーディングが表示されないことを確認する**

ターミナルで `q` を入力後、再度 `flutter run` する。

Expected: オンボーディングをスキップして直接 `MapScreen` が表示される。

- [ ] **Step 5: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 9: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 6〜8の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/onboarding_screen.dart fogworld/lib/screens/exclusion_settings_screen.dart fogworld/lib/screens/map_screen.dart fogworld/lib/main.dart
git commit -m "feat: オンボーディングと除外地域の手動調整画面を追加"
```

---

## Step 7 完了条件(再掲)

- `flutter test` がパス(`ExclusionCandidateCatalog`, `ExclusionRepository`, `OnboardingPreferences`, `HierarchyScoreAggregator` 拡張分の単体テスト)
- `flutter analyze` がクリーン
- オンボーディングで選択した地域が自動的に除外される
- 除外地域は階層レベル集計(表示リスト)から除かれる
- 設定画面から個別に除外のON/OFFを調整できる
- 2回目以降の起動ではオンボーディングがスキップされる

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 8(クラウド認証・同期)に進む。

## 既知の制約・積み残し

- 除外候補カタログの実データ(実際の紛争地域リスト等)のキュレーションは本プランの範囲外。Task 1のサンプルデータを実データに差し替える作業が別途必要。
- 大陸単位の一括除外UIは提供しない(国単位の個別トグルのみ)。
