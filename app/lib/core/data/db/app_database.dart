import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fogworld/core/data/db/tables.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

/// アプリの DB(drift / SQLite)。
@DriftDatabase(tables: [Records, Shapes, Spots, CoverCells, GeoCache, Meta])
class AppDatabase extends _$AppDatabase {
  /// [e] は接続(本番は drift_flutter、テストは `NativeDatabase.memory()`)。
  AppDatabase(super.e);

  /// テスト用のメモリ DB。閉じると内容は消える。
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  /// 本番用の端末内 DB(`drift_flutter`)。単体テストでは呼ばない。
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'fogworld'));

  /// 現在のスキーマ版。
  static const int currentSchemaVersion = 1;

  /// 導出データ(被覆セルの計算方式)の版の初期値。
  static const int _initialCoverVer = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // 版 1 のみのため、まだ移行はない。版 2 を作るときにここへ移行処理を書く。
    },
    beforeOpen: (details) async {
      // 外部キー(spots.recordId → records.id など)を有効にする。接続ごとに必要。
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureMeta();
    },
  );

  /// メタの初期値を入れる。既にあるキーは変えない(開き直しても `device_id` は同じ)。
  Future<void> _ensureMeta() async {
    await into(meta).insert(
      MetaCompanion.insert(
        key: 'schema_ver',
        value: currentSchemaVersion.toString(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await into(meta).insert(
      MetaCompanion.insert(key: 'device_id', value: const Uuid().v4()),
      mode: InsertMode.insertOrIgnore,
    );
    await into(meta).insert(
      MetaCompanion.insert(key: 'cover_ver', value: _initialCoverVer.toString()),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// メタの値を返す。キーが無ければ null。
  Future<String?> metaValue(String key) async {
    final row = await (select(meta)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// この端末の ID(初回に作った UUID)。
  ///
  /// 開くときに必ず保存されるため、通常は例外にならない。
  /// メタが壊れて無い場合は [StateError]。
  Future<String> deviceId() async {
    final id = await metaValue('device_id');
    if (id == null) {
      throw StateError('メタに device_id がありません。');
    }
    return id;
  }
}
