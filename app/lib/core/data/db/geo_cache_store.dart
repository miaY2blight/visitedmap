import 'package:drift/drift.dart';
import 'package:fogworld/core/data/db/app_database.dart';

/// 外部サービスの応答のキャッシュ(端末内の DB の `geo_cache` 表)。
class GeoCacheStore {
  /// [now] は現在時刻を返す。
  GeoCacheStore(this._db, {required this._now});

  final AppDatabase _db;
  final DateTime Function() _now;

  /// 期限の既定値(24 時間)。
  static const Duration defaultTtl = Duration(hours: 24);

  /// [key] の本文。無い、取得から [ttl] を超えて経っている、または取得時刻が今より未来
  /// (端末の時計が戻った)なら null。
  ///
  /// 取得から [defaultTtl] を超えた行と、取得時刻が未来の行は、見つけたときにその行を削除してから
  /// null を返す(検索した範囲の履歴を、端末に残し続けないため)。[ttl] を [defaultTtl] より短く
  /// 指定しただけで期限切れになった行は、削除しない。
  ///
  /// DB の読み出し・削除に失敗したときは drift / SQLite の例外をそのまま投げる。
  Future<String?> get(String key, {Duration ttl = defaultTtl}) async {
    final row = await (_db.select(_db.geoCache)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    final age = _now().millisecondsSinceEpoch - row.fetchedAt;
    if (age < 0 || age > defaultTtl.inMilliseconds) {
      // 取得時刻まで条件に入れて、別の呼び出しが同じキーを新しく保存した行を消さないようにする
      await (_db.delete(_db.geoCache)
            ..where((t) => t.key.equals(key) & t.fetchedAt.equals(row.fetchedAt)))
          .go();
      return null;
    }
    if (age > ttl.inMilliseconds) return null;
    return row.body;
  }

  /// 期限([defaultTtl])を過ぎた行と、取得時刻が今より未来の行をすべて削除し、削除した件数を返す。
  ///
  /// 起動時などに呼ぶ(呼び出しの配線は呼び出し側の役目)。
  /// DB の書き込みに失敗したときは drift / SQLite の例外をそのまま投げる。
  Future<int> purgeExpired() {
    final nowMs = _now().millisecondsSinceEpoch;
    return (_db.delete(_db.geoCache)
          ..where(
            (t) =>
                t.fetchedAt.isSmallerThanValue(nowMs - defaultTtl.inMilliseconds) |
                t.fetchedAt.isBiggerThanValue(nowMs),
          ))
        .go();
  }

  /// [key] に [body] を、今の時刻で保存する。同じキーがあれば上書きする。
  ///
  /// あわせて、期限([defaultTtl])を過ぎた行と、取得時刻が今より未来の行を削除する
  /// (検索した範囲の履歴を、端末に残し続けないため)。削除と保存は 1 トランザクションで行う。
  ///
  /// DB の書き込みに失敗したときは drift / SQLite の例外をそのまま投げる。
  Future<void> put(String key, String body) async {
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.delete(_db.geoCache)
            ..where(
              (t) =>
                  t.fetchedAt.isSmallerThanValue(nowMs - defaultTtl.inMilliseconds) |
                  t.fetchedAt.isBiggerThanValue(nowMs),
            ))
          .go();
      await _db.into(_db.geoCache).insertOnConflictUpdate(
            GeoCacheCompanion.insert(key: key, body: body, fetchedAt: nowMs),
          );
    });
  }
}
