# Step 0: 環境構築 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter SDKをセットアップし、`fogworld` プロジェクトを新規作成、実機またはエミュレータ/シミュレータでデフォルトのカウンターアプリ(Hello World相当)を起動・動作確認できる状態にする。

**Architecture:** `flutter create` で生成される標準プロジェクト構成をそのまま使用する。この段階では独自コードを書かない(デフォルトテンプレートの動作確認のみ)。

**Tech Stack:** Flutter SDK(stable channel)、Dart、Android Studio(Androidエミュレータ/SDK用)、Windows環境のため実機確認はAndroid実機またはAndroidエミュレータを基本とする(iOS実機/シミュレータ確認はmacOS環境が別途必要なため本Stepの対象外とし、Step 1以降でmacOS環境が用意でき次第追加確認する)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(コンセプト・技術スタック)、[`../../plan.md`](../../plan.md)(ロードマップ概要、Step 0の位置づけ)

## Global Constraints

- 認証・地図・POI検索など他Stepの機能は一切実装しない。本Stepは環境構築とデフォルトアプリの起動確認のみ。
- Windows開発環境のため、本Stepの実機/エミュレータ確認は Android を対象とする。
- 作業確認時点(2026-09-04)でこの開発機に Flutter SDK は未インストール(`flutter` コマンドが `command not found`)。Task 1でのインストールが必須の前提。

---

### Task 1: Flutter SDKのインストールとPATH設定

**Files:**
- Create: なし(SDK自体はリポジトリ外、任意のローカルディレクトリに展開)
- Modify: Windowsユーザー環境変数 `Path`
- Test: なし(コマンド実行結果で確認)

**Interfaces:**
- Consumes: なし
- Produces: `flutter` コマンドがどのディレクトリからでも実行可能な状態

- [ ] **Step 1: Flutter SDK stable版のZIPをダウンロードする**

ブラウザで https://docs.flutter.dev/get-started/install/windows を開き、"Flutter SDK" の最新stable版ZIPをダウンロードする。

- [ ] **Step 2: SDKを展開する**

ダウンロードしたZIPを `C:\dev\flutter` に展開する(`C:\Program Files` 等、書き込み権限が制限されるディレクトリ配下には置かない)。

PowerShellで展開先を確認:

```powershell
Test-Path C:\dev\flutter\bin\flutter.bat
```

Expected: `True`

- [ ] **Step 3: PATH環境変数に追加する**

PowerShell(管理者権限不要、ユーザー環境変数への追加):

```powershell
$flutterBin = "C:\dev\flutter\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$flutterBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBin", "User")
}
```

- [ ] **Step 4: 新しいシェルで `flutter` コマンドが認識されることを確認する**

PATH変更はプロセス起動時に読み込まれるため、**新しいターミナルウィンドウ**を開いて実行する:

```powershell
flutter --version
```

Expected: Flutterのバージョン番号とDartのバージョンが表示される(エラーなし)。

---

### Task 2: `flutter doctor` で開発環境の不足を解消する

**Files:**
- Create: なし
- Modify: なし(必要に応じてAndroid Studio / Android SDKをインストール)
- Test: なし(コマンド実行結果で確認)

**Interfaces:**
- Consumes: Task 1で確立した `flutter` コマンド
- Produces: `flutter doctor` が Android toolchain について致命的エラーなしと報告する状態

- [ ] **Step 1: `flutter doctor` を実行し、不足項目を洗い出す**

```powershell
flutter doctor -v
```

Expected: 各項目(Flutter, Android toolchain, Android Studio, Connected device等)の状態が一覧表示される。この時点では `[✗]` 項目があってもよい。

- [ ] **Step 2: Android Studioをインストールする(未インストールの場合)**

https://developer.android.com/studio からAndroid Studioをダウンロード・インストールする。インストーラーの初回起動ウィザードで Android SDK, Android SDK Platform-Tools, Android Virtual Device のデフォルトコンポーネントをすべてインストールする。

- [ ] **Step 3: Androidライセンスに同意する**

```powershell
flutter doctor --android-licenses
```

すべてのプロンプトで `y` を入力して同意する。

- [ ] **Step 4: `flutter doctor` を再実行し、Android toolchainがクリアであることを確認する**

```powershell
flutter doctor -v
```

Expected: `[✓] Android toolchain - develop for Android devices` と表示される。(`Visual Studio` や `iOS` 等、本Stepの対象外の項目に `[✗]` が残っていても問題ない)

---

### Task 3: `fogworld` プロジェクトを作成する

**Files:**
- Create: `fogworld/`(プロジェクトルート以下、`flutter create` によって自動生成される標準構成一式。主要ファイルは `fogworld/lib/main.dart`, `fogworld/pubspec.yaml`, `fogworld/test/widget_test.dart`)
- Modify: なし
- Test: `fogworld/test/widget_test.dart`(`flutter create` が自動生成するデフォルトテスト)

**Interfaces:**
- Consumes: Task 1・2で確立した `flutter` コマンドおよび開発環境
- Produces: `fogworld/` 配下の標準Flutterプロジェクト。以降のStepはこの `fogworld/` ディレクトリ配下で作業する。

- [ ] **Step 1: リポジトリ直下でプロジェクトを作成する**

```powershell
flutter create --org com.fogworld --project-name fogworld fogworld
```

Expected: コマンドが成功し、`fogworld/` ディレクトリと `lib/main.dart`, `pubspec.yaml`, `test/widget_test.dart` 等が生成される。

- [ ] **Step 2: 生成されたファイル構成を確認する**

```powershell
Get-ChildItem fogworld -Name
```

Expected: `android`, `ios`, `lib`, `test`, `pubspec.yaml` 等が含まれる。

---

### Task 4: デフォルトのウィジェットテストが通ることを確認する

**Files:**
- Create: なし
- Modify: なし
- Test: `fogworld/test/widget_test.dart`(`flutter create` が生成したデフォルトテスト。カウンターアプリのタップでインクリメントされることを検証する)

**Interfaces:**
- Consumes: Task 3で作成した `fogworld/` プロジェクト
- Produces: テストがパスすることの確認(この段階でのアプリ独自ロジックはまだ無いため、テスト内容自体はデフォルトのまま)

- [ ] **Step 1: デフォルトテストの内容を確認する**

`fogworld/test/widget_test.dart` を開き、内容が以下のようなカウンターインクリメントの検証になっていることを確認する(`flutter create` のFlutter SDKバージョンにより文言は多少異なる場合がある):

```dart
testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.text('0'), findsOneWidget);
  expect(find.text('1'), findsNothing);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  expect(find.text('0'), findsNothing);
  expect(find.text('1'), findsOneWidget);
});
```

- [ ] **Step 2: テストを実行する**

```powershell
cd fogworld
flutter test
```

Expected: `All tests passed!`

---

### Task 5: エミュレータ/実機でアプリを起動する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視での起動確認)

**Interfaces:**
- Consumes: Task 3で作成した `fogworld/` プロジェクト、Task 2で確立したAndroid開発環境
- Produces: 実機またはエミュレータ上で動作するデフォルトカウンターアプリ。以降のStep 1でこのアプリに地図表示を追加していく。

- [ ] **Step 1: Androidエミュレータを起動する(実機を使わない場合)**

Android Studioの Device Manager から任意のAVD(例: Pixelシリーズ、API level 34以上)を作成し、起動する。実機を使う場合は開発者モード・USBデバッグを有効にしたAndroid端末をUSB接続する。

- [ ] **Step 2: 接続デバイスを確認する**

```powershell
cd fogworld
flutter devices
```

Expected: 起動したエミュレータまたは接続した実機が一覧に表示される。

- [ ] **Step 3: アプリを起動する**

```powershell
flutter run
```

Expected: ビルドが成功し、エミュレータ/実機にデフォルトのFlutterカウンターアプリ(「You have pushed the button this many times:」の画面)が表示される。画面右下の `+` ボタンをタップしてカウンターが増加することを目視確認する。

- [ ] **Step 4: アプリを終了する**

ターミナルで `q` を入力してホットリロードセッションを終了する。

---

### Task 6: コミット

**Files:**
- Create: `fogworld/.gitignore` は `flutter create` が自動生成済み(ビルド成果物・`.dart_tool/` 等は既に除外設定される)
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 1〜5の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う — プロジェクトルール上、Claude Codeからのgit操作実行は禁止)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

Expected: `fogworld/` ディレクトリ以下が未追跡として表示される。

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/
git commit -m "feat: Flutterプロジェクト(fogworld)を初期作成しHello World起動を確認"
```

---

## Step 0 完了条件(再掲)

- `flutter doctor` でAndroid toolchainがクリア
- `fogworld/` プロジェクトが作成済み
- `flutter test` がパス
- エミュレータまたは実機でデフォルトアプリが起動し、カウンター操作が機能する

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 1(地図表示)に進む。
