# Step 8: クラウド認証・同期 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Google/Appleソーシャルログインを導入し、ローカルsqliteのチェックイン履歴をFirestoreに同期する。複数端末でログインすると同じチェックイン履歴が復元される。

**Architecture:** `AuthProvider`(インターフェース)/`FirebaseAuthProvider`(実装)で認証SDK呼び出しを抽象化する(Step 1の `LocationProvider` と同じパターン)。`CheckinRepository` に `CheckinRecord` モデル(sqlite行の型安全な表現)と重複防止付き挿入メソッドを追加する。`CheckinSyncRepository` がFirestoreとの読み書きを担当し(`fake_cloud_firestore` でテスト)、`CheckinSyncService` がローカル⇔クラウドの両方向マージ(ローカルのみの記録をアップロード、クラウドのみの記録をローカルに反映)を行う。ログインは必須にせず、ログインしている場合のみ同期が動作する(未ログインでもStep 3〜7の機能はローカルのみで従来どおり使える)。

**Tech Stack:** `firebase_core` ^4.14.0、`firebase_auth` ^6.6.1、`cloud_firestore` ^6.9.0、`google_sign_in` ^7.2.0、`sign_in_with_apple` ^8.2.0、`fake_cloud_firestore` ^4.2.0(テスト用dev_dependency)。Firebaseプロジェクト自体はSpark(無料)プランを使う(CLAUDE.md記載のコスト方針どおり)。

**Spec:** [`../../../CLAUDE.md`](../../../CLAUDE.md)(認証・クラウド同期の方針、Firebase Spark無料枠)、[`../../plan.md`](../../plan.md)(Step 8の位置づけ)、[`step3-manual-checkin.md`](step3-manual-checkin.md)(前提となる`CheckinRepository`)

## Global Constraints

- 認証方式はGoogle/Appleソーシャルログインのみ。メール/パスワード認証は実装しない(CLAUDE.md方針)。
- Firestoreに保存するのはユーザー個別データ(チェックイン履歴)のみ。POI参照データ・天井キャッシュ等の全ユーザー共通データはFirestoreに置かない(CLAUDE.md方針。Step 4の`CeilingRepository`等は本Stepでは同期対象にしない)。
- Apple Sign-Inの実機確認はiOS実機/シミュレータ(macOS環境)が必要なため、本Windows開発環境では確認できない。本Stepの実機確認(Task 8)はAndroid上でのGoogleサインインのみを対象とし、Apple Sign-Inはコード実装のみ行い動作確認は将来macOS環境が用意でき次第行う。
- Firebaseプロジェクトの作成(Firebaseコンソールでのプロジェクト作成、アプリ登録)は外部サービスでのアカウント操作を伴うため、Claude Codeが代行実行することはない。Task 1はユーザー自身が行う手順として記載する。

---

### Task 1: Firebaseプロジェクトをセットアップする(ユーザー自身が実施)

**Files:**
- Create: `fogworld/lib/firebase_options.dart`(FlutterFire CLIによる自動生成)
- Create: `fogworld/android/app/google-services.json`(Firebaseコンソールからダウンロード)

**Interfaces:**
- Consumes: なし
- Produces: Firebaseプロジェクトへの接続設定。Task 2以降のFirebase SDK初期化がこれを使う。

**この Task はユーザー自身が実施してください(Claude Codeはアカウント操作・外部サービスでのリソース作成を代行しません)。**

- [ ] **Step 1: Firebaseコンソールでプロジェクトを作成する**

https://console.firebase.google.com/ にアクセスし、新規プロジェクトを作成する(プラン: Spark 無料プラン)。

- [ ] **Step 2: Android/iOSアプリを登録する**

Androidアプリ(パッケージ名 `com.fogworld.fogworld`、Task 3(Step 0)の `flutter create --org com.fogworld` に対応)を登録し、`google-services.json` をダウンロードして `fogworld/android/app/google-services.json` に配置する。iOSアプリも同様に登録する(Bundle ID `com.fogworld.fogworld`)。

- [ ] **Step 3: FlutterFire CLIをセットアップする**

```powershell
dart pub global activate flutterfire_cli
cd fogworld
flutterfire configure
```

プロンプトに従い、Step 1で作成したFirebaseプロジェクトと登録済みアプリを選択する。これにより `fogworld/lib/firebase_options.dart` が自動生成される。

- [ ] **Step 4: Firebase Authenticationで Google / Apple プロバイダを有効化する**

Firebaseコンソールの Authentication > Sign-in method で「Google」と「Apple」を有効化する。

- [ ] **Step 5: Firestoreを作成する**

Firebaseコンソールの Firestore Database で新規データベースを作成する(モード: 本番環境、ロケーションは任意)。

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/firebase_options.dart fogworld/android/app/google-services.json
git commit -m "chore: Firebaseプロジェクト接続設定を追加"
```

---

### Task 2: Firebaseパッケージを追加し初期化する

**Files:**
- Modify: `fogworld/pubspec.yaml`
- Modify: `fogworld/lib/main.dart`
- Modify: `fogworld/android/app/build.gradle`(Google Services Gradle Plugin)
- Modify: `fogworld/android/build.gradle`(Google Services Gradle Plugin クラスパス)

**Interfaces:**
- Consumes: Task 1の `firebase_options.dart`
- Produces: アプリ起動時にFirebaseが初期化された状態。Task 3以降のAuth/Firestore呼び出しの前提になる。

- [ ] **Step 1: `pubspec.yaml` に依存関係を追加する**

```yaml
  firebase_core: ^4.14.0
  firebase_auth: ^6.6.1
  cloud_firestore: ^6.9.0
  google_sign_in: ^7.2.0
  sign_in_with_apple: ^8.2.0
```

`dev_dependencies:` に追加:

```yaml
  fake_cloud_firestore: ^4.2.0
```

```powershell
cd fogworld
flutter pub get
```

- [ ] **Step 2: AndroidのGoogle Servicesプラグインを設定する**

`fogworld/android/build.gradle` の `dependencies` ブロックに追加:

```gradle
        classpath 'com.google.gms:google-services:4.4.2'
```

`fogworld/android/app/build.gradle` の末尾に追加:

```gradle
apply plugin: 'com.google.gms.google-services'
```

(バージョン `4.4.2` は本プラン作成時点の一般的な安定版。実装時に https://mvnrepository.com/artifact/com.google.gms/google-services で最新版を確認して差し替える)

- [ ] **Step 3: `main.dart` でFirebaseを初期化する**

`fogworld/lib/main.dart` を変更する:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/onboarding_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FogWorldApp());
}
```

(`DefaultFirebaseOptions` はTask 1の `flutterfire configure` が生成する `firebase_options.dart` に定義されている)

- [ ] **Step 4: ビルドが通ることを確認する**

```powershell
cd fogworld
flutter build apk --debug
```

Expected: ビルドが成功する(Google Servicesプラグインの設定ミスがあればここで検出される)。

- [ ] **Step 5: コミット**

```bash
git add fogworld/pubspec.yaml fogworld/pubspec.lock fogworld/android/build.gradle fogworld/android/app/build.gradle fogworld/lib/main.dart
git commit -m "feat: Firebase SDKを導入し起動時に初期化する"
```

---

### Task 3: `AuthProvider`/`AuthService` をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/auth_provider.dart`
- Create: `fogworld/lib/services/auth_service.dart`
- Test: `fogworld/test/services/auth_service_test.dart`

**Interfaces:**
- Consumes: `firebase_auth`, `google_sign_in`, `sign_in_with_apple` の各SDK
- Produces: 抽象クラス `AuthProvider`(メソッド: `Future<String?> signInWithGoogle()`, `Future<String?> signInWithApple()`, `Future<void> signOut()`, `String? get currentUserId()` — いずれもユーザーID(`uid`)を返す/参照する)。具象クラス `FirebaseAuthProvider implements AuthProvider`(単体テスト対象外。実機確認で検証する)。クラス `AuthService`。コンストラクタ `AuthService(AuthProvider provider)`。メソッド `Future<bool> signInWithGoogle()`, `Future<bool> signInWithApple()`, `Future<void> signOut()`, `bool get isSignedIn`, `String? get currentUserId`。Task 6の同期サービス・Task 7のUIが使う。

- [ ] **Step 1: `AuthProvider`/`FirebaseAuthProvider` を作成する**

`fogworld/lib/services/auth_provider.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract class AuthProvider {
  Future<String?> signInWithGoogle();
  Future<String?> signInWithApple();
  Future<void> signOut();
  String? get currentUserId;
}

class FirebaseAuthProvider implements AuthProvider {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  Future<String?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user?.uid;
  }

  @override
  Future<String?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final userCredential = await _auth.signInWithCredential(oauthCredential);
    return userCredential.user?.uid;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  String? get currentUserId => _auth.currentUser?.uid;
}
```

`GoogleSignIn.instance`/`authenticate()` はgoogle_sign_in 7.x系のAPI(旧来の `GoogleSignIn()` コンストラクタ+`signIn()` から変更されている)。実装時にpub.devの最新ドキュメントでAPIの詳細(初期化に `GoogleSignIn.instance.initialize()` が必要かどうか等)を確認して調整する。

- [ ] **Step 2: 失敗する `AuthService` テストを書く**

`fogworld/test/services/auth_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fogworld/services/auth_provider.dart';
import 'package:fogworld/services/auth_service.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockProvider;
  late AuthService service;

  setUp(() {
    mockProvider = MockAuthProvider();
    service = AuthService(mockProvider);
  });

  test('Googleサインイン成功時はtrueを返す', () async {
    when(() => mockProvider.signInWithGoogle())
        .thenAnswer((_) async => 'uid-123');

    final result = await service.signInWithGoogle();

    expect(result, isTrue);
  });

  test('Googleサインインがnullを返した場合(キャンセル等)はfalseを返す', () async {
    when(() => mockProvider.signInWithGoogle()).thenAnswer((_) async => null);

    final result = await service.signInWithGoogle();

    expect(result, isFalse);
  });

  test('currentUserIdはproviderの値をそのまま返す', () {
    when(() => mockProvider.currentUserId).thenReturn('uid-456');
    expect(service.currentUserId, 'uid-456');
  });

  test('isSignedInはcurrentUserIdがnullでない場合にtrue', () {
    when(() => mockProvider.currentUserId).thenReturn('uid-456');
    expect(service.isSignedIn, isTrue);
  });

  test('isSignedInはcurrentUserIdがnullの場合にfalse', () {
    when(() => mockProvider.currentUserId).thenReturn(null);
    expect(service.isSignedIn, isFalse);
  });
}
```

- [ ] **Step 3: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/auth_service_test.dart
```

Expected: `auth_service.dart` が存在せずコンパイルエラー。

- [ ] **Step 4: `AuthService` の最小実装を書く**

`fogworld/lib/services/auth_service.dart`:

```dart
import 'auth_provider.dart';

class AuthService {
  final AuthProvider _provider;

  AuthService(this._provider);

  Future<bool> signInWithGoogle() async {
    final uid = await _provider.signInWithGoogle();
    return uid != null;
  }

  Future<bool> signInWithApple() async {
    final uid = await _provider.signInWithApple();
    return uid != null;
  }

  Future<void> signOut() => _provider.signOut();

  String? get currentUserId => _provider.currentUserId;

  bool get isSignedIn => currentUserId != null;
}
```

- [ ] **Step 5: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/auth_service_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: コミット**

```bash
git add fogworld/lib/services/auth_provider.dart fogworld/lib/services/auth_service.dart fogworld/test/services/auth_service_test.dart
git commit -m "feat: Google/Apple認証を抽象化するAuthProvider/AuthServiceをTDDで実装"
```

---

### Task 4: `CheckinRepository` に `CheckinRecord` モデルと重複防止挿入を追加する

**Files:**
- Modify: `fogworld/lib/services/checkin_repository.dart`
- Test: `fogworld/test/services/checkin_repository_test.dart`(追記)

**Interfaces:**
- Consumes: なし
- Produces: クラス `CheckinRecord`(フィールド: `String poiId`, `String? name`, `double lat`, `double lon`, `DateTime checkedInAt`)。`CheckinRepository.getAllCheckinRecords()` → `Future<List<CheckinRecord>>`(重複含む全履歴)。`CheckinRepository.insertIfNotExists(CheckinRecord record)` → `Future<void>`(同一 `poiId`+`checkedInAt` の組がすでに存在すれば何もしない)。Task 6の同期サービスがこれらを使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/checkin_repository_test.dart` に追記:

```dart
  test('getAllCheckinRecordsは全チェックイン履歴をCheckinRecordのリストで返す', () async {
    await repository.checkIn(poi, checkedInAt: DateTime(2026, 1, 1));

    final records = await repository.getAllCheckinRecords();

    expect(records.length, 1);
    expect(records.first.poiId, poi.id);
    expect(records.first.checkedInAt, DateTime(2026, 1, 1));
  });

  test('insertIfNotExistsは同じpoiId+checkedInAtが既にあれば何もしない', () async {
    final record = CheckinRecord(
      poiId: poi.id,
      name: poi.name,
      lat: poi.lat,
      lon: poi.lon,
      checkedInAt: DateTime(2026, 1, 1),
    );

    await repository.insertIfNotExists(record);
    await repository.insertIfNotExists(record);

    final records = await repository.getAllCheckinRecords();
    expect(records.length, 1);
  });

  test('insertIfNotExistsは異なるcheckedInAtなら別レコードとして追加する', () async {
    await repository.insertIfNotExists(CheckinRecord(
      poiId: poi.id,
      name: poi.name,
      lat: poi.lat,
      lon: poi.lon,
      checkedInAt: DateTime(2026, 1, 1),
    ));
    await repository.insertIfNotExists(CheckinRecord(
      poiId: poi.id,
      name: poi.name,
      lat: poi.lat,
      lon: poi.lon,
      checkedInAt: DateTime(2026, 2, 1),
    ));

    final records = await repository.getAllCheckinRecords();
    expect(records.length, 2);
  });
```

`import 'package:fogworld/services/checkin_repository.dart';` に `CheckinRecord` も含まれるため追加のimportは不要。

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_repository_test.dart
```

Expected: `CheckinRecord`/メソッド未定義でコンパイルエラー。

- [ ] **Step 3: 実装を追加する**

`fogworld/lib/services/checkin_repository.dart` の先頭付近にクラスを追加:

```dart
class CheckinRecord {
  final String poiId;
  final String? name;
  final double lat;
  final double lon;
  final DateTime checkedInAt;

  const CheckinRecord({
    required this.poiId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.checkedInAt,
  });
}
```

`CheckinRepository` クラスに追記:

```dart
  Future<List<CheckinRecord>> getAllCheckinRecords() async {
    final rows = await _db.query('checkins');
    return rows
        .map((row) => CheckinRecord(
              poiId: row['poi_id'] as String,
              name: row['name'] as String?,
              lat: row['lat'] as double,
              lon: row['lon'] as double,
              checkedInAt: DateTime.parse(row['checked_in_at'] as String),
            ))
        .toList();
  }

  Future<void> insertIfNotExists(CheckinRecord record) async {
    final existing = await _db.query(
      'checkins',
      where: 'poi_id = ? AND checked_in_at = ?',
      whereArgs: [record.poiId, record.checkedInAt.toIso8601String()],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await _db.insert('checkins', {
      'poi_id': record.poiId,
      'name': record.name,
      'lat': record.lat,
      'lon': record.lon,
      'checked_in_at': record.checkedInAt.toIso8601String(),
    });
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
git commit -m "feat: CheckinRepositoryにCheckinRecordと重複防止挿入を追加"
```

---

### Task 5: `CheckinSyncRepository`(Firestore読み書き)をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/checkin_sync_repository.dart`
- Test: `fogworld/test/services/checkin_sync_repository_test.dart`

**Interfaces:**
- Consumes: `cloud_firestore` の `FirebaseFirestore` インターフェース(テストでは `fake_cloud_firestore` の `FakeFirebaseFirestore` を注入)、Task 4の `CheckinRecord`
- Produces: クラス `CheckinSyncRepository`。コンストラクタ `CheckinSyncRepository(FirebaseFirestore firestore)`。メソッド `Future<void> pushCheckin(String uid, CheckinRecord record)`(ドキュメントID `'${poiId}_${checkedInAt.toIso8601String()}'` でupsert)、`Future<List<CheckinRecord>> fetchAllCheckins(String uid)`。Task 6の `CheckinSyncService` が使う。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/checkin_sync_repository_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/services/checkin_repository.dart';
import 'package:fogworld/services/checkin_sync_repository.dart';

void main() {
  late FirebaseFirestore firestore;
  late CheckinSyncRepository syncRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    syncRepository = CheckinSyncRepository(firestore);
  });

  final record = CheckinRecord(
    poiId: 'node/1',
    name: 'Sample Cafe',
    lat: 35.68,
    lon: 139.76,
    checkedInAt: DateTime(2026, 1, 1),
  );

  test('pushCheckinしたレコードをfetchAllCheckinsで取得できる', () async {
    await syncRepository.pushCheckin('uid-1', record);

    final records = await syncRepository.fetchAllCheckins('uid-1');

    expect(records.length, 1);
    expect(records.first.poiId, 'node/1');
  });

  test('同一レコードを2回pushしても重複しない(upsert)', () async {
    await syncRepository.pushCheckin('uid-1', record);
    await syncRepository.pushCheckin('uid-1', record);

    final records = await syncRepository.fetchAllCheckins('uid-1');
    expect(records.length, 1);
  });

  test('異なるuidのデータは分離される', () async {
    await syncRepository.pushCheckin('uid-1', record);

    final records = await syncRepository.fetchAllCheckins('uid-2');
    expect(records, isEmpty);
  });
}
```

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_sync_repository_test.dart
```

Expected: `checkin_sync_repository.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/checkin_sync_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'checkin_repository.dart';

class CheckinSyncRepository {
  final FirebaseFirestore _firestore;

  CheckinSyncRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _checkinsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('checkins');
  }

  Future<void> pushCheckin(String uid, CheckinRecord record) async {
    final docId = '${record.poiId}_${record.checkedInAt.toIso8601String()}';
    await _checkinsCollection(uid).doc(docId).set({
      'poiId': record.poiId,
      'name': record.name,
      'lat': record.lat,
      'lon': record.lon,
      'checkedInAt': record.checkedInAt.toIso8601String(),
    });
  }

  Future<List<CheckinRecord>> fetchAllCheckins(String uid) async {
    final snapshot = await _checkinsCollection(uid).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CheckinRecord(
        poiId: data['poiId'] as String,
        name: data['name'] as String?,
        lat: (data['lat'] as num).toDouble(),
        lon: (data['lon'] as num).toDouble(),
        checkedInAt: DateTime.parse(data['checkedInAt'] as String),
      );
    }).toList();
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_sync_repository_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/checkin_sync_repository.dart fogworld/test/services/checkin_sync_repository_test.dart
git commit -m "feat: FirestoreとのチェックインデータやりとりをTDDで実装"
```

---

### Task 6: `CheckinSyncService`(双方向マージ)をTDDで実装する

**Files:**
- Create: `fogworld/lib/services/checkin_sync_service.dart`
- Test: `fogworld/test/services/checkin_sync_service_test.dart`

**Interfaces:**
- Consumes: Task 4の `CheckinRepository`(`getAllCheckinRecords`, `insertIfNotExists`)、Task 5の `CheckinSyncRepository`
- Produces: クラス `CheckinSyncService`。コンストラクタ `CheckinSyncService(CheckinRepository localRepository, CheckinSyncRepository remoteRepository)`。メソッド `Future<void> sync(String uid)` — ローカルの全レコードをリモートにpush(upsertなので重複しても安全)し、リモートの全レコードをローカルに `insertIfNotExists` で反映する。Task 7のUIがログイン成功時にこれを呼ぶ。

- [ ] **Step 1: 失敗するテストを書く**

`fogworld/test/services/checkin_sync_service_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fogworld/services/checkin_repository.dart';
import 'package:fogworld/services/checkin_sync_repository.dart';
import 'package:fogworld/services/checkin_sync_service.dart';

void main() {
  sqfliteFfiInit();

  late CheckinRepository localRepository;
  late CheckinSyncRepository remoteRepository;
  late CheckinSyncService syncService;

  setUp(() async {
    localRepository = await CheckinRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    remoteRepository = CheckinSyncRepository(FakeFirebaseFirestore());
    syncService = CheckinSyncService(localRepository, remoteRepository);
  });

  tearDown(() async {
    await localRepository.close();
  });

  const poi = Poi(
    id: 'node/1',
    lat: 35.68,
    lon: 139.76,
    name: 'Sample Cafe',
    tags: {'amenity': 'cafe'},
  );

  test('ローカルのみの記録はリモートにアップロードされる', () async {
    await localRepository.checkIn(poi, checkedInAt: DateTime(2026, 1, 1));

    await syncService.sync('uid-1');

    final remoteRecords = await remoteRepository.fetchAllCheckins('uid-1');
    expect(remoteRecords.length, 1);
    expect(remoteRecords.first.poiId, 'node/1');
  });

  test('リモートのみの記録はローカルに反映される', () async {
    await remoteRepository.pushCheckin(
      'uid-1',
      CheckinRecord(
        poiId: 'node/2',
        name: 'Remote POI',
        lat: 1.0,
        lon: 2.0,
        checkedInAt: DateTime(2026, 3, 1),
      ),
    );

    await syncService.sync('uid-1');

    final localIds = await localRepository.getCheckedInPoiIds();
    expect(localIds, contains('node/2'));
  });

  test('双方に同じ記録があっても重複しない', () async {
    await localRepository.checkIn(poi, checkedInAt: DateTime(2026, 1, 1));
    await remoteRepository.pushCheckin(
      'uid-1',
      CheckinRecord(
        poiId: poi.id,
        name: poi.name,
        lat: poi.lat,
        lon: poi.lon,
        checkedInAt: DateTime(2026, 1, 1),
      ),
    );

    await syncService.sync('uid-1');

    final localRecords = await localRepository.getAllCheckinRecords();
    expect(localRecords.length, 1);

    final remoteRecords = await remoteRepository.fetchAllCheckins('uid-1');
    expect(remoteRecords.length, 1);
  });
}
```

`import 'package:fogworld/models/poi.dart';` を追加する。

- [ ] **Step 2: テストを実行し、失敗することを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_sync_service_test.dart
```

Expected: `checkin_sync_service.dart` が存在せずコンパイルエラー。

- [ ] **Step 3: 最小実装を書く**

`fogworld/lib/services/checkin_sync_service.dart`:

```dart
import 'checkin_repository.dart';
import 'checkin_sync_repository.dart';

class CheckinSyncService {
  final CheckinRepository _localRepository;
  final CheckinSyncRepository _remoteRepository;

  CheckinSyncService(this._localRepository, this._remoteRepository);

  Future<void> sync(String uid) async {
    final localRecords = await _localRepository.getAllCheckinRecords();
    for (final record in localRecords) {
      await _remoteRepository.pushCheckin(uid, record);
    }

    final remoteRecords = await _remoteRepository.fetchAllCheckins(uid);
    for (final record in remoteRecords) {
      await _localRepository.insertIfNotExists(record);
    }
  }
}
```

- [ ] **Step 4: テストを再実行し、パスすることを確認する**

```powershell
cd fogworld
flutter test test/services/checkin_sync_service_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: コミット**

```bash
git add fogworld/lib/services/checkin_sync_service.dart fogworld/test/services/checkin_sync_service_test.dart
git commit -m "feat: ローカル/リモート双方向マージを行うCheckinSyncServiceをTDDで実装"
```

---

### Task 7: アカウント画面を実装し `MapScreen` から導線を追加する

**Files:**
- Create: `fogworld/lib/screens/account_screen.dart`
- Modify: `fogworld/lib/screens/map_screen.dart`

**Interfaces:**
- Consumes: Task 3の `AuthService`、Task 6の `CheckinSyncService`
- Produces: ウィジェット `AccountScreen`。未ログイン時はGoogle/Appleサインインボタンを表示し、ログイン成功時に `CheckinSyncService.sync(uid)` を実行する。ログイン済みならサインアウトボタンと「同期する」ボタンを表示する。`MapScreen` の `AppBar` に `AccountScreen` への導線(人アイコン)を追加する。

- [ ] **Step 1: `AccountScreen` を作成する**

`fogworld/lib/screens/account_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/checkin_repository.dart';
import '../services/checkin_sync_repository.dart';
import '../services/checkin_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService(FirebaseAuthProvider());
  bool _isBusy = false;
  String? _message;

  Future<void> _syncNow() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    setState(() => _isBusy = true);

    final localRepository = await CheckinRepository.open();
    final remoteRepository = CheckinSyncRepository(FirebaseFirestore.instance);
    final syncService = CheckinSyncService(localRepository, remoteRepository);

    await syncService.sync(uid);
    await localRepository.close();

    setState(() {
      _isBusy = false;
      _message = '同期が完了しました';
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isBusy = true);
    final success = await _authService.signInWithGoogle();
    setState(() => _isBusy = false);

    if (success) {
      await _syncNow();
    } else {
      setState(() => _message = 'サインインに失敗またはキャンセルされました');
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isBusy = true);
    final success = await _authService.signInWithApple();
    setState(() => _isBusy = false);

    if (success) {
      await _syncNow();
    } else {
      setState(() => _message = 'サインインに失敗またはキャンセルされました');
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = _authService.isSignedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_message != null) Text(_message!),
            const SizedBox(height: 16),
            if (_isBusy) const CircularProgressIndicator(),
            if (!_isBusy && !isSignedIn) ...[
              FilledButton(
                onPressed: _signInWithGoogle,
                child: const Text('Googleでサインイン'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _signInWithApple,
                child: const Text('Appleでサインイン'),
              ),
            ],
            if (!_isBusy && isSignedIn) ...[
              Text('サインイン中: ${_authService.currentUserId}'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _syncNow,
                child: const Text('今すぐ同期する'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _signOut,
                child: const Text('サインアウト'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: `MapScreen` の `AppBar` に導線を追加する**

`fogworld/lib/screens/map_screen.dart` の `AppBar.actions` に追記:

```dart
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
          ),
```

`import 'account_screen.dart';` を追加する。

- [ ] **Step 3: 静的解析が通ることを確認する**

```powershell
cd fogworld
flutter analyze
```

Expected: `No issues found!`

---

### Task 8: エミュレータ/実機でGoogleサインインと同期を確認する

**Files:**
- Create: なし
- Modify: なし
- Test: なし(目視確認)

**Interfaces:**
- Consumes: Task 1〜7の全成果物
- Produces: 実機/エミュレータ上でGoogleサインイン・同期が機能する状態

- [ ] **Step 1: Google Play開発者サービス入りのエミュレータを用意する**

`google_sign_in` の動作確認にはGoogle Play開発者サービスが必要なため、Android Studio Device Managerで "Google Play" アイコン付きのシステムイメージを使ったAVDを用意する(通常のAOSPイメージでは動作しない)。

- [ ] **Step 2: アプリを起動し、いくつかチェックインした後にGoogleサインインする**

```powershell
cd fogworld
flutter run
```

チェックインを2〜3件行った後、アカウント画面から「Googleでサインイン」する。

Expected: Google アカウント選択ダイアログが表示され、サインイン後「同期が完了しました」と表示される。

- [ ] **Step 3: Firebaseコンソールでデータを確認する**

Firebaseコンソールの Firestore Database で `users/{uid}/checkins` 配下にTask 2でチェックインしたレコードが存在することを確認する。

- [ ] **Step 4: 別デバイス(または同一エミュレータのアプリ再インストール)で同期を確認する**

アプリをアンインストールして再インストールする(ローカルDBをリセットするため)。再度Googleサインインする。

Expected: サインイン直後の同期処理により、以前チェックインしたPOIのハイライトがローカルDBに復元される(地図を再度開いてPOI検索を行うと、該当POIがハイライト表示される)。

- [ ] **Step 5: サインアウトを確認する**

アカウント画面で「サインアウト」を押す。

Expected: サインイン状態が解除され、ボタン表示がサインインボタンに戻る。ローカルのチェックインデータは削除されない(サインアウトはログアウトのみで、ローカルデータの削除は行わない仕様とする)。

- [ ] **Step 6: アプリを終了する**

ターミナルで `q` を入力する。

---

### Task 9: コミット

**Files:**
- Create: なし
- Modify: なし
- Test: なし

**Interfaces:**
- Consumes: Task 7〜8の全成果物
- Produces: リポジトリへのコミット(コマンド例のみ提示。実行はユーザー自身が行う)

- [ ] **Step 1: 差分を確認する**

```bash
git status
```

- [ ] **Step 2: コミットする(コマンド例。実行はユーザーが行う)**

```bash
git add fogworld/lib/screens/account_screen.dart fogworld/lib/screens/map_screen.dart
git commit -m "feat: アカウント画面とクラウド同期の導線を追加"
```

---

## Step 8 完了条件(再掲)

- `flutter test` がパス(`AuthService`, `CheckinRepository`拡張分, `CheckinSyncRepository`, `CheckinSyncService` の単体テスト)
- `flutter analyze` がクリーン
- Googleサインインができ、ログイン後にローカルのチェックイン履歴がFirestoreにアップロードされる
- アプリ再インストール後、同じアカウントでサインインするとチェックイン履歴が復元される
- サインアウトができる

この完了条件を満たせば [`../../plan.md`](../../plan.md) の Step 9(UI/UXの磨き込み)に進む。

## 既知の制約・積み残し

- Apple Sign-Inの実機確認はmacOS環境が無いため未実施。コードは実装するが、iOS実機/シミュレータでの検証はTask 1のiOSアプリ登録も含め別途macOS環境で行う。
- 自動同期(バックグラウンドや定期的な同期)は実装しない。同期はサインイン時・「今すぐ同期する」ボタン押下時のみ発生する(明示的トリガーのみ)。
- 同時編集の競合解決(同じPOIに複数端末からほぼ同時にチェックインした場合の扱い)は、Firestoreドキュメントの決定的ID(`poiId_checkedInAt`)による自然な重複排除に委ねており、明示的な競合解決ロジックは実装しない。
