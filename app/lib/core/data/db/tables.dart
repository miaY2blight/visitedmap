import 'package:drift/drift.dart';

/// 記録(基本設計 §4.2)。スポット・散歩・海などの共通の親。
///
/// `kind` は開いた集合(D-29)。将来の種類を足せるよう、CHECK 制約を付けない。
@DataClassName('RecordRow')
class Records extends Table {
  /// 記録の ID(UUID)。
  TextColumn get id => text()();

  /// 記録の種類(`spot` など)。CHECK 制約なし。
  TextColumn get kind => text()();

  /// 訪問日(`YYYY-MM-DD`)。
  TextColumn get visitedOn => text()();

  /// 作成時刻(エポックミリ秒)。
  IntColumn get createdAt => integer()();

  /// 更新時刻(エポックミリ秒)。
  IntColumn get updatedAt => integer()();

  /// サーバー側の更新時刻(同期用。未同期は null)。
  IntColumn get serverUpdatedAt => integer().nullable()();

  /// 記録した端末の ID。
  TextColumn get deviceId => text()();

  /// 削除した時刻(論理削除。null なら有効)。
  IntColumn get deletedAt => integer().nullable()();

  /// 保存時のスキーマ版。
  IntColumn get schemaVer => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 場所の形。ポリゴン、または点+半径。
@DataClassName('ShapeRow')
class Shapes extends Table {
  /// 形の ID。
  TextColumn get id => text()();

  /// 形の種類(`polygon` / `point_radius`)。
  TextColumn get kind => text()();

  /// 形の JSON(`ShapeCodec` の形式)。
  TextColumn get geometry => text()();

  /// 点+半径のときの半径(m)。ポリゴンは null。
  IntColumn get radiusM => integer().nullable()();

  /// 形の出所(`nominatim` / `manual`)。
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// スポットの記録(Records の子)。
@DataClassName('SpotRow')
@TableIndex(name: 'idx_spots_brand_key', columns: {#brandKey})
class Spots extends Table {
  /// 親の記録の ID。外部キー(`records.id`)。
  TextColumn get recordId => text().references(Records, #id)();

  /// 場所の名前。
  TextColumn get name => text()();

  /// OSM の参照(`way/123` など)。手動で置いた場所は null。
  TextColumn get osmRef => text().nullable()();

  /// 場所の代表点の緯度。
  RealColumn get lat => real()();

  /// 場所の代表点の経度。
  RealColumn get lon => real()();

  /// 大分類。
  TextColumn get categoryMajor => text()();

  /// 小分類。
  TextColumn get categoryMinor => text()();

  /// チェーン店などのブランド単位の識別子。なければ null。
  TextColumn get brandKey => text().nullable()();

  /// 加点の扱い(`target` / `record_only`)。
  TextColumn get scoring => text()();

  /// 加点の扱いをユーザーが上書きしたか。
  BoolColumn get scoringOverridden =>
      boolean().withDefault(const Constant(false))();

  /// 元のタグ(JSON)。なければ null。
  TextColumn get rawTags => text().nullable()();

  /// 形の ID(`shapes.id`)。
  TextColumn get shapeId => text()();

  @override
  Set<Column> get primaryKey => {recordId};
}

/// 記録が覆うセル(導出データ)。z, x, y は整数 3 列(文字列キーにしない)。
@DataClassName('CoverCellRow')
@TableIndex(name: 'idx_cover_cells_zxy', columns: {#z, #x, #y})
class CoverCells extends Table {
  /// 親の記録の ID。外部キー(`records.id`)。
  TextColumn get recordId => text().references(Records, #id)();

  /// ズーム階層。
  IntColumn get z => integer()();

  /// タイル X。
  IntColumn get x => integer()();

  /// タイル Y。
  IntColumn get y => integer()();

  /// 塗られた理由(`spot` など)。
  TextColumn get origin => text()();

  @override
  Set<Column> get primaryKey => {recordId, z, x, y};

  /// 主キーの自動索引と表本体の重複をなくし、容量を減らす(V-04 の容量対策)。
  @override
  bool get withoutRowId => true;
}

/// 外部サービスの応答のキャッシュ(導出データ)。
@DataClassName('GeoCacheRow')
class GeoCache extends Table {
  /// キャッシュのキー。
  TextColumn get key => text()();

  /// 応答の本文。
  TextColumn get body => text()();

  /// 取得時刻(エポックミリ秒)。
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}

/// DB 全体のメタ情報(キーと値)。
@DataClassName('MetaRow')
class Meta extends Table {
  /// キー(`schema_ver` / `device_id` / `cover_ver`)。
  TextColumn get key => text()();

  /// 値。
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
