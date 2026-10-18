# 日報 2026-10-07

## 作業内容
ロードマップ Step 0(環境構築)を完了。
- Flutter SDK 3.47.6(stable)を `C:\src\flutter` に導入し、ユーザーPATHに登録
- Temurin JDK 17、Android SDK(platform-tools / android-36 / build-tools 36.0.0 / NDK 28.2.13676358)を導入
- `FogWorld/app/` に Flutter プロジェクトを作成(パッケージID は仮の `com.example.fogworld`)
- 実機 Samsung SM-F731N(adb: `R3CWA02426E`)で「Hello World」表示を確認
- `flutter test`(1件)成功、`flutter analyze` 問題なし

## 備考(つまずいた点)
- winget に Flutter SDK 本体はなく、今回に限り許可を得て `git clone` で導入した。`flutter upgrade` は内部で git を使うため、実行前に要確認
- Android Studio は winget 導入が失敗していたのに完了と誤報した。ビルドには不要だったため導入せず、JDK 17 を単体で導入して対応
- 新しい sdkmanager(Android CLI)は ID が `ndk/28.2...` 形式で、Gradle の NDK 自動導入が「Package ndk not found」で失敗。NDK を手動導入して解決
- cmdline-tools の zip 展開が、パスが長く(260文字制限)失敗。短いパスの SDK 配下へ直接展開して解決
- 初回は既定のカウンターデモを「Hello World」と誤報した。`main.dart` を修正し、旧テストが壊れたため差し替えてからテストを実行
- 実機が `unauthorized` のままだったため、端末側で USBデバッグの「許可」が必要だった

## 引継ぎ(次回 Step 1 から)
**次の作業**: Step 1(地図表示のみ: `maplibre_gl` + OpenFreeMap ベクタータイル、現在地取得・表示)。要件は `CLAUDE.md` に記載済み

**環境**
- JDK: `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`。ビルド時は `JAVA_HOME` に指定する
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`。NDK 等を追加で要求されたら `sdkmanager --sdk_root=... "ndk/<ver>"` で手動導入
- 実機で起動: `cd app` → `flutter run -d R3CWA02426E --debug`
- 新しいターミナルを開いて `flutter --version` が通ることを確認(PATH 反映のため再起動が必要)
- Visual Studio の `flutter doctor` 警告は Windows デスクトップ向けで無関係

**未決・要確認**
- パッケージID: 仮の `com.example.fogworld`。Step 1 で位置情報権限を入れるため、変更するなら Step 1 の前が手戻り最小(Step 8 の Firebase 前には必須)
- 地図の初期表示位置、現在地ボタンの有無などの希望
- 実機の位置情報とネット接続をオンにしておく
- `app/` は未コミット(Git 操作はユーザーが手動で実施)

**運用ルール**
- 検証(テスト・lint 等)は完了を宣言する前に実行し、結果を踏まえて報告する
- タスク完了ごとに報告し、要件判断が必要になったら都度質問する
