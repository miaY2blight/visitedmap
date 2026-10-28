import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fogworld/core/data/db/app_database.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/shape/shape_codec.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';

/// 加点の扱い。[recordOnly] はチェーン店などで、ブランド単位の初回のみ加点する。
enum SpotScoring {
  target('target'),
  recordOnly('record_only');

  const SpotScoring(this.dbValue);

  /// DB に保存する文字列。
  final String dbValue;

  /// DB の文字列から戻す。未知の値は [FormatException]。
  static SpotScoring fromDb(String value) {
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    throw FormatException('加点の扱いが不明です: $value');
  }
}

/// 形の出所。
enum ShapeSource {
  nominatim,
  manual;

  /// DB の文字列から戻す。未知の値は [FormatException]。
  static ShapeSource fromDb(String value) {
    for (final s in values) {
      if (s.name == value) return s;
    }
    throw FormatException('形の出所が不明です: $value');
  }
}

/// これから保存するスポット。
class NewSpot {
  const NewSpot({
    required this.name,
    required this.shape,
    required this.source,
    required this.representative,
    required this.major,
    required this.minor,
    required this.scoring,
    required this.visitedOn,
    this.osmRef,
    this.brandKey,
    this.scoringOverridden = false,
    this.rawTags,
  });

  /// 場所の名前。
  final String name;

  /// 場所の形。
  final SpotShape shape;

  /// 形の出所。
  final ShapeSource source;

  /// 場所の代表点(DB の lat / lon に入る)。
  final GeoPoint representative;

  /// 大分類。
  final MajorCategory major;

  /// 小分類。
  final String minor;

  /// 加点の扱い。
  final SpotScoring scoring;

  /// 訪問日(`YYYY-MM-DD`)。
  final String visitedOn;

  /// OSM の参照(`way/123` など)。手動で置いた場所は null。
  final String? osmRef;

  /// ブランド単位の識別子。なければ null。
  final String? brandKey;

  /// 加点の扱いをユーザーが上書きしたか。
  final bool scoringOverridden;

  /// 元のタグ。JSON にして保存する。
  final Map<String, String>? rawTags;
}

/// 保存済みのスポット(削除済みでないもの)。
class SavedSpot {
  const SavedSpot({
    required this.id,
    required this.name,
    required this.shape,
    required this.source,
    required this.representative,
    required this.major,
    required this.minor,
    required this.scoring,
    required this.brandKey,
    required this.visitedOn,
    required this.osmRef,
  });

  /// 記録の ID。
  final String id;
  final String name;
  final SpotShape shape;
  final ShapeSource source;
  final GeoPoint representative;
  final MajorCategory major;
  final String minor;
  final SpotScoring scoring;
  final String? brandKey;
  final String visitedOn;
  final String? osmRef;
}

/// スポットの記録の保存と読み出し(端末内の DB のみ)。
class SpotRepository {
  /// [now] は現在時刻、[newId] は記録・形の ID(本番は UUID v4)を返す。
  SpotRepository(this._db, {required this._now, required this._newId});

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;
  static const _codec = ShapeCodec();

  /// 被覆セルを一度に挿入する行数。
  static const int _coverChunk = 1000;

  /// records の rowid(保存の順に増える)。records は TEXT 主キーだが、WITHOUT ROWID ではないので rowid を持つ。
  /// 入力の値を含まない固定の式。
  static const _recordsRowId = CustomExpression<int>('"records"."rowid"');

  /// [spot] と、その被覆 [cover] を 1 トランザクションで保存し、保存した内容を返す。
  ///
  /// チェーン(`recordOnly`)でも、同じ系列の記録が既にあっても保存する(訪れた場所として霧を晴らすため)。
  /// 加点が系列の最初の 1 回だけになる判定は、点数の計算側で行う。
  /// DB の書き込みに失敗したとき(被覆の重複など)は drift / SQLite の例外をそのまま投げ、何も残さない。
  /// メタに device_id が無いときは [StateError]。
  Future<SavedSpot> saveSpot(NewSpot spot, List<CellKey> cover) {
    return _db.transaction(() async {
      final brandKey = spot.brandKey;
      final deviceId = await _db.deviceId();
      final recordId = _newId();
      final shapeId = _newId();
      final nowMs = _now().millisecondsSinceEpoch;
      final shape = spot.shape;

      await _db.into(_db.records).insert(
            RecordsCompanion.insert(
              id: recordId,
              kind: 'spot',
              visitedOn: spot.visitedOn,
              createdAt: nowMs,
              updatedAt: nowMs,
              deviceId: deviceId,
              schemaVer: AppDatabase.currentSchemaVersion,
            ),
          );
      await _db.into(_db.shapes).insert(
            ShapesCompanion.insert(
              id: shapeId,
              kind: switch (shape) {
                PolygonShape() => 'polygon',
                PointRadiusShape() => 'point_radius',
              },
              geometry: _codec.encode(shape),
              radiusM: Value(switch (shape) {
                PolygonShape() => null,
                PointRadiusShape(:final radiusMeters) => radiusMeters,
              }),
              source: spot.source.name,
            ),
          );
      await _db.into(_db.spots).insert(
            SpotsCompanion.insert(
              recordId: recordId,
              name: spot.name,
              osmRef: Value(spot.osmRef),
              lat: spot.representative.lat,
              lon: spot.representative.lon,
              categoryMajor: spot.major.name,
              categoryMinor: spot.minor,
              brandKey: Value(brandKey),
              scoring: spot.scoring.dbValue,
              scoringOverridden: Value(spot.scoringOverridden),
              rawTags: Value(spot.rawTags == null ? null : jsonEncode(spot.rawTags)),
              shapeId: shapeId,
            ),
          );

      for (var i = 0; i < cover.length; i += _coverChunk) {
        final end = i + _coverChunk < cover.length ? i + _coverChunk : cover.length;
        final chunk = cover.sublist(i, end);
        await _db.batch((b) {
          b.insertAll(_db.coverCells, [
            for (final c in chunk)
              CoverCellsCompanion.insert(recordId: recordId, z: c.z, x: c.x, y: c.y, origin: 'spot'),
          ]);
        });
      }

      return SavedSpot(
        id: recordId,
        name: spot.name,
        shape: _codec.decode(_codec.encode(shape)),
        source: spot.source,
        representative: spot.representative,
        major: spot.major,
        minor: spot.minor,
        scoring: spot.scoring,
        brandKey: brandKey,
        visitedOn: spot.visitedOn,
        osmRef: spot.osmRef,
      );
    });
  }

  /// 同じ系列 [brandKey] の、削除済みでない `recordOnly` の記録のうち最古の 1 件。無ければ null。
  ///
  /// 保存済みの値が壊れているとき(形の JSON、分類の名前)は [FormatException]。
  Future<SavedSpot?> findChainRecord(String brandKey) async {
    final query = _joined()
      ..where(
        _db.records.deletedAt.isNull() &
            _db.spots.scoring.equals(SpotScoring.recordOnly.dbValue) &
            _db.spots.brandKey.equals(brandKey),
      )
      ..orderBy([
        OrderingTerm.asc(_db.records.createdAt),
        OrderingTerm.asc(_db.records.id),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _toSaved(row);
  }

  /// 削除済みを除くすべてのスポット。新しい順(作成時刻の降順、同時刻は保存の新しい順 = records の rowid の降順)。
  ///
  /// 保存済みの値が壊れているとき(形の JSON、分類の名前)は [FormatException]。
  Future<List<SavedSpot>> allSpots() async {
    final query = _joined()
      ..where(_db.records.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(_db.records.createdAt),
        OrderingTerm.desc(_recordsRowId),
      ]);
    final rows = await query.get();
    return [for (final r in rows) _toSaved(r)];
  }

  /// records を起点に、spots と shapes を内部結合した問い合わせ(kind=spot のみ)。
  JoinedSelectStatement<HasResultSet, dynamic> _joined() {
    return _db.select(_db.records).join([
      innerJoin(_db.spots, _db.spots.recordId.equalsExp(_db.records.id)),
      innerJoin(_db.shapes, _db.shapes.id.equalsExp(_db.spots.shapeId)),
    ])
      ..where(_db.records.kind.equals('spot'));
  }

  SavedSpot _toSaved(TypedResult row) {
    final rec = row.readTable(_db.records);
    final spot = row.readTable(_db.spots);
    final shape = row.readTable(_db.shapes);
    return SavedSpot(
      id: rec.id,
      name: spot.name,
      shape: _codec.decode(shape.geometry),
      source: ShapeSource.fromDb(shape.source),
      representative: GeoPoint(spot.lat, spot.lon),
      major: _majorFromDb(spot.categoryMajor),
      minor: spot.categoryMinor,
      scoring: SpotScoring.fromDb(spot.scoring),
      brandKey: spot.brandKey,
      visitedOn: rec.visitedOn,
      osmRef: spot.osmRef,
    );
  }

  static MajorCategory _majorFromDb(String value) {
    for (final c in MajorCategory.values) {
      if (c.name == value) return c;
    }
    throw FormatException('大分類が不明です: $value');
  }
}
