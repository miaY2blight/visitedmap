# Step 6: 過去日付でのバックデート記録機能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** チェックインUIに日付指定機能を追加し、過去日付でチェックインを記録できるようにする。バックデートされたチェックインもスコア・レベル集計に正しく反映される。

**Architecture:** Step 3で実装した `CheckinRepository.checkIn(Poi poi, {DateTime? checkedInAt})` は既にオプショナルな日付引数を持っているため、リポジトリ層の変更は不要。本Stepは主にUI層(日付選択ダイアログの追加)と、「未来日付を禁止する」バリデーションの追加が中心になる。Step 4・5で実装したスコア集計(`getAllCheckins()` ベースの件数カウント)はチェックイン日時に依存しないため、バックデートしても自動的に正しく反映される(追加のロジック変更は不要)。

**Tech Stack:** 追加パッケージなし(Flutter標準の `showDatePicker` を使用)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(「記録は後からでも可能にする」というバックデート方針)、[`../../plan.md`](../../plan.md)(Step 6の位置づけ)、[`step3-manual-checkin.md`](step3-manual-checkin.md)(前提となるチェックイン機能・`CheckinRepository`)

## Global Constraints

- 未来日付でのチェックインは許可しない(バリデーションで防ぐ)。
- 過去日付チェックインもスコア・レベル集計への影響は通常チェックインと同一とする(初回チェックインのみ加点、という既存ルールをそのまま適用する。同一POIへの2回目以降のバックデート記録は履歴として保存されるが、スコアには影響しない)。
- 「初回チェックイン」の判定は、Step 4・5のスコア集計が `getAllCheckins()` の `distinct poi_id` 件数を数える設計になっている前提に依存する。もし将来的にスコア計算式が「最も古いチェックイン日時」等を参照するように変わった場合、バックデートによって過去に遡って初回判定が変わる(既存のチェックイン履歴より古い日付でバックデートすると、そちらが「初回」になる)可能性がある点に注意する。本Stepの時点では影響なし(現在の集計は日時を見ないため)。

---

### Task 1: `CheckinRepository` に「同一POIの最古チェックイン日時取得」を追加する(将来のバックデート整合性チェック用)

**Files:**
- Modify: `fogworld/lib/services/checkin_repository.dart`
- Test: `fogworld/test/services/checkin_repository_test.dart`(追記)

**Interfaces:**
- Consumes: なし
- Produces: `CheckinRepository.getCheckinHistory(String poiId)` → `Future<List<DateTime>>`(古い順にソート済み)。Task 3のUIで「このPOIの既存チェックイン履歴」を表示する際に使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/checkin_repository_test.dart` に追記:

```dart
  test('getCheckinHistoryは日時の昇順でチェックイン履歴を返す', () async {
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 3, 1));
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 1, 1));
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 2, 1));

    final history = await repository.getCheckinHistory(poi.id);

    expect(history, [
      DateTime(2026, 1, 1),
      DateTime(2026, 2, 1),
      DateTime(2026, 3, 1),
    ]);
  });
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_repository_test.dart
```

Expected: `getCheckinHistory` が未定義でコンパイルエラー。

- [ ] **Step 3: 実装を追加する**

`fogworld/lib/services/checkin_repository.dart` に追記:

```dart
  Future<List<DateTime>> getCheckinHistory(String poiId) async {
    final rows = await _db.query(
      'checkins',
      where: 'poi_id = ?',
      whereArgs: [poiId],
      orderBy: 'checked_in_at ASC',
      columns: ['checked_in_at'],
    );
    return rows
        .map((row) => DateTime.parse(row['checked_in_at'] as String))
        .toList();
  }
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/checkin_repository.dart fogworld/test/services/checkin_repository_test.dart
git commit -m "feat: CheckinRepositoryにチェックイン履歴取得を追加"
```

---

### Task 2: 日付バリデーションユーティリティをTDDで実装する

**Files:**
- Create: `fogworld/lib/services/checkin_date_validator.dart`
- Test: `fogworld/test/services/checkin_date_validator_test.dart`

**Interfaces:**
- Consumes: なし
- Produces: クラス `CheckinDateValidator`。静的メソッド `bool isValid(DateTime candidate, {required DateTime now})` — `candidate` が `now` より未来なら `false`(日付の大小比較。時刻部分は無視し「今日以前」を許可する)。Task 3のUIがこれを使って未来日付選択を防ぐ。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/checkin_date_validator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/checkin_date_validator.dart';

void main() {
  final now = DateTime(2026, 9, 4, 15, 30);

  test('今日の日付は有効', () {
    expect(
      CheckinDateValidator.isValid(DateTime(2026, 9, 4), now: now),
      isTrue,
    );
  });

  test('過去の日付は有効', () {
    expect(
      CheckinDateValidator.isValid(DateTime(2020, 1, 1), now: now),
      isTrue,
    );
  });

  test('未来の日付は無効', () {
    expect(
      CheckinDateValidator.isValid(DateTime(2026, 9, 5), now: now),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_date_validator_test.dart
```

Expected: `checkin_date_validator.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/checkin_date_validator.dart`:

```dart
class CheckinDateValidator {
  static bool isValid(DateTime candidate, {required DateTime now}) {
    final candidateDate = DateTime(candidate.year, candidate.month, candidate.day);
    final today = DateTime(now.year, now.month, now.day);
    return !candidateDate.isAfter(today);
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_date_validator_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/checkin_date_validator.dart fogworld/test/services/checkin_date_validator_test.dart
git commit -m "feat: 未来日付を拒否するCheckinDateValidatorをTDDで実装"
```

---

### Task 3: POI詳細ボトムシートに日付選択UIを追加する

**Files:**
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 2の `CheckinDateValidator`、既存の `CheckinRepository.checkIn(poi, checkedInAt: ...)`
- Produces: POI詳細ボトムシートに「チェックイン日」表示と「日付を変更」ボタンを追加する。デフォルトは今日の日付。`showDatePicker` で過去日付を選択でき、選択後に選んだ日付で `_checkIn(poi, checkedInAt: selectedDate)` を呼ぶ。

- [ ] **Step 1: `_showPoiDetail` をStatefulなダイアログ内容にする**

`showModalBottomSheet` の `builder` を `StatefulBuilder` でラップし、選択中の日付を保持する:

```dart
  void _showPoiDetail(Poi poi) {
    final isCheckedIn = _checkedInPoiIds.contains(poi.id);
    var selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                  else ...[
                    Row(
                      children: [
                        Text('チェックイン日: ${_formatDate(selectedDate)}'),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('日付を変更'),
                        ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () => _checkIn(poi, checkedInAt: selectedDate),
                      child: const Text('チェックインする'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
```

`showDatePicker` の `lastDate: DateTime.now()` により、カレンダーUI上で未来日付はそもそも選択できない(UIレベルでの一次防御)。

- [ ] **Step 2: `_checkIn` メソッドに日付引数とバリデーションを追加する**

```dart
  Future<void> _checkIn(Poi poi, {required DateTime checkedInAt}) async {
    if (!CheckinDateValidator.isValid(checkedInAt, now: DateTime.now())) {
      _showMessage('未来の日付ではチェックインできません');
      return;
    }

    final repository = _checkinRepository;
    if (repository == null) return;

    await repository.checkIn(poi, checkedInAt: checkedInAt);
    _checkedInPoiIds = {..._checkedInPoiIds, poi.id};

    final symbol = _symbolByPoiId[poi.id];
    final controller = _mapController;
    if (symbol != null && controller != null) {
      await controller.updateSymbol(
        symbol,
        const SymbolOptions(iconImage: _checkedInIcon),
      );
    }

    await _updateHierarchyLevels(poi);

    if (mounted) Navigator.of(context).pop();
  }
```

`import '../services/checkin_date_validator.dart';` を追加する。`CheckinDateValidator.isValid` によるバリデーションは、`showDatePicker` の `lastDate` 制約を回避する手段(将来的なプログラム的呼び出し等)に備えた二重防御として実装する。

- [ ] **Step 3: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 4: エミュレータ/実機でバックデートチェックインを確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜3の全成果物
- Produces: 実機/エミュレータ上で過去日付を指定したチェックインが記録され、スコアに反映される状態

- [ ] **Step 1: アプリを起動し、日付を過去に変更してチェックインする**

```powershell
cd fogworld
flutter run
```

任意のPOIをタップし、「日付を変更」から1週間前の日付を選択してチェックインする。

Expected: チェックインが成功し、ピンがハイライトされ、スコアが1増える(Step 5のバナー表示で確認)。

- [ ] **Step 2: カレンダーUIで未来日付が選択できないことを確認する**

`showDatePicker` を開き、今日より後の日付がグレーアウトされ選択不可であることを目視確認する。

- [ ] **Step 3: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 5: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 3〜4の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/map_screen.dart
git commit -m "feat: 過去日付を指定したバックデートチェックイン機能を追加"
```

---

## Step 6 完了条件(再掲)

- `flutter test` がパス(`CheckinDateValidator`、`CheckinRepository.getCheckinHistory` の単体テスト)
- `flutter analyze` がクリーン
- 任意の過去日付でチェックインを記録でき、スコアに正しく反映される
- 未来日付はUI・バリデーションの両方でブロックされる

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 7(除外地域)に進む。
