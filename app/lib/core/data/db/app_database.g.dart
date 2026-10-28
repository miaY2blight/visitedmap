// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitedOnMeta = const VerificationMeta(
    'visitedOn',
  );
  @override
  late final GeneratedColumn<String> visitedOn = GeneratedColumn<String>(
    'visited_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> serverUpdatedAt = GeneratedColumn<int>(
    'server_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schemaVerMeta = const VerificationMeta(
    'schemaVer',
  );
  @override
  late final GeneratedColumn<int> schemaVer = GeneratedColumn<int>(
    'schema_ver',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    visitedOn,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deviceId,
    deletedAt,
    schemaVer,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('visited_on')) {
      context.handle(
        _visitedOnMeta,
        visitedOn.isAcceptableOrUnknown(data['visited_on']!, _visitedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedOnMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('schema_ver')) {
      context.handle(
        _schemaVerMeta,
        schemaVer.isAcceptableOrUnknown(data['schema_ver']!, _schemaVerMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaVerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      visitedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visited_on'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_updated_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      schemaVer: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_ver'],
      )!,
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  /// 記録の ID(UUID)。
  final String id;

  /// 記録の種類(`spot` など)。CHECK 制約なし。
  final String kind;

  /// 訪問日(`YYYY-MM-DD`)。
  final String visitedOn;

  /// 作成時刻(エポックミリ秒)。
  final int createdAt;

  /// 更新時刻(エポックミリ秒)。
  final int updatedAt;

  /// サーバー側の更新時刻(同期用。未同期は null)。
  final int? serverUpdatedAt;

  /// 記録した端末の ID。
  final String deviceId;

  /// 削除した時刻(論理削除。null なら有効)。
  final int? deletedAt;

  /// 保存時のスキーマ版。
  final int schemaVer;
  const RecordRow({
    required this.id,
    required this.kind,
    required this.visitedOn,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    required this.deviceId,
    this.deletedAt,
    required this.schemaVer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['visited_on'] = Variable<String>(visitedOn);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<int>(serverUpdatedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['schema_ver'] = Variable<int>(schemaVer);
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      visitedOn: Value(visitedOn),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      deviceId: Value(deviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      schemaVer: Value(schemaVer),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      visitedOn: serializer.fromJson<String>(json['visitedOn']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<int?>(json['serverUpdatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      schemaVer: serializer.fromJson<int>(json['schemaVer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'visitedOn': serializer.toJson<String>(visitedOn),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'serverUpdatedAt': serializer.toJson<int?>(serverUpdatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'schemaVer': serializer.toJson<int>(schemaVer),
    };
  }

  RecordRow copyWith({
    String? id,
    String? kind,
    String? visitedOn,
    int? createdAt,
    int? updatedAt,
    Value<int?> serverUpdatedAt = const Value.absent(),
    String? deviceId,
    Value<int?> deletedAt = const Value.absent(),
    int? schemaVer,
  }) => RecordRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    visitedOn: visitedOn ?? this.visitedOn,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    deviceId: deviceId ?? this.deviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    schemaVer: schemaVer ?? this.schemaVer,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      visitedOn: data.visitedOn.present ? data.visitedOn.value : this.visitedOn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      schemaVer: data.schemaVer.present ? data.schemaVer.value : this.schemaVer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('visitedOn: $visitedOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('schemaVer: $schemaVer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    visitedOn,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    deviceId,
    deletedAt,
    schemaVer,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.visitedOn == this.visitedOn &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.deviceId == this.deviceId &&
          other.deletedAt == this.deletedAt &&
          other.schemaVer == this.schemaVer);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> visitedOn;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> serverUpdatedAt;
  final Value<String> deviceId;
  final Value<int?> deletedAt;
  final Value<int> schemaVer;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.visitedOn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.schemaVer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required String kind,
    required String visitedOn,
    required int createdAt,
    required int updatedAt,
    this.serverUpdatedAt = const Value.absent(),
    required String deviceId,
    this.deletedAt = const Value.absent(),
    required int schemaVer,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       visitedOn = Value(visitedOn),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       schemaVer = Value(schemaVer);
  static Insertable<RecordRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? visitedOn,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? serverUpdatedAt,
    Expression<String>? deviceId,
    Expression<int>? deletedAt,
    Expression<int>? schemaVer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (visitedOn != null) 'visited_on': visitedOn,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (schemaVer != null) 'schema_ver': schemaVer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? visitedOn,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? serverUpdatedAt,
    Value<String>? deviceId,
    Value<int?>? deletedAt,
    Value<int>? schemaVer,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      visitedOn: visitedOn ?? this.visitedOn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      schemaVer: schemaVer ?? this.schemaVer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (visitedOn.present) {
      map['visited_on'] = Variable<String>(visitedOn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<int>(serverUpdatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (schemaVer.present) {
      map['schema_ver'] = Variable<int>(schemaVer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('visitedOn: $visitedOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('schemaVer: $schemaVer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShapesTable extends Shapes with TableInfo<$ShapesTable, ShapeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShapesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geometryMeta = const VerificationMeta(
    'geometry',
  );
  @override
  late final GeneratedColumn<String> geometry = GeneratedColumn<String>(
    'geometry',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMMeta = const VerificationMeta(
    'radiusM',
  );
  @override
  late final GeneratedColumn<int> radiusM = GeneratedColumn<int>(
    'radius_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, geometry, radiusM, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shapes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShapeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('geometry')) {
      context.handle(
        _geometryMeta,
        geometry.isAcceptableOrUnknown(data['geometry']!, _geometryMeta),
      );
    } else if (isInserting) {
      context.missing(_geometryMeta);
    }
    if (data.containsKey('radius_m')) {
      context.handle(
        _radiusMMeta,
        radiusM.isAcceptableOrUnknown(data['radius_m']!, _radiusMMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShapeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShapeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      geometry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geometry'],
      )!,
      radiusM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius_m'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $ShapesTable createAlias(String alias) {
    return $ShapesTable(attachedDatabase, alias);
  }
}

class ShapeRow extends DataClass implements Insertable<ShapeRow> {
  /// 形の ID。
  final String id;

  /// 形の種類(`polygon` / `point_radius`)。
  final String kind;

  /// 形の JSON(`ShapeCodec` の形式)。
  final String geometry;

  /// 点+半径のときの半径(m)。ポリゴンは null。
  final int? radiusM;

  /// 形の出所(`nominatim` / `manual`)。
  final String source;
  const ShapeRow({
    required this.id,
    required this.kind,
    required this.geometry,
    this.radiusM,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['geometry'] = Variable<String>(geometry);
    if (!nullToAbsent || radiusM != null) {
      map['radius_m'] = Variable<int>(radiusM);
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  ShapesCompanion toCompanion(bool nullToAbsent) {
    return ShapesCompanion(
      id: Value(id),
      kind: Value(kind),
      geometry: Value(geometry),
      radiusM: radiusM == null && nullToAbsent
          ? const Value.absent()
          : Value(radiusM),
      source: Value(source),
    );
  }

  factory ShapeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShapeRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      geometry: serializer.fromJson<String>(json['geometry']),
      radiusM: serializer.fromJson<int?>(json['radiusM']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'geometry': serializer.toJson<String>(geometry),
      'radiusM': serializer.toJson<int?>(radiusM),
      'source': serializer.toJson<String>(source),
    };
  }

  ShapeRow copyWith({
    String? id,
    String? kind,
    String? geometry,
    Value<int?> radiusM = const Value.absent(),
    String? source,
  }) => ShapeRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    geometry: geometry ?? this.geometry,
    radiusM: radiusM.present ? radiusM.value : this.radiusM,
    source: source ?? this.source,
  );
  ShapeRow copyWithCompanion(ShapesCompanion data) {
    return ShapeRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      geometry: data.geometry.present ? data.geometry.value : this.geometry,
      radiusM: data.radiusM.present ? data.radiusM.value : this.radiusM,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShapeRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('geometry: $geometry, ')
          ..write('radiusM: $radiusM, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, geometry, radiusM, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShapeRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.geometry == this.geometry &&
          other.radiusM == this.radiusM &&
          other.source == this.source);
}

class ShapesCompanion extends UpdateCompanion<ShapeRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> geometry;
  final Value<int?> radiusM;
  final Value<String> source;
  final Value<int> rowid;
  const ShapesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.geometry = const Value.absent(),
    this.radiusM = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShapesCompanion.insert({
    required String id,
    required String kind,
    required String geometry,
    this.radiusM = const Value.absent(),
    required String source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       geometry = Value(geometry),
       source = Value(source);
  static Insertable<ShapeRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? geometry,
    Expression<int>? radiusM,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (geometry != null) 'geometry': geometry,
      if (radiusM != null) 'radius_m': radiusM,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShapesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? geometry,
    Value<int?>? radiusM,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return ShapesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      geometry: geometry ?? this.geometry,
      radiusM: radiusM ?? this.radiusM,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (geometry.present) {
      map['geometry'] = Variable<String>(geometry.value);
    }
    if (radiusM.present) {
      map['radius_m'] = Variable<int>(radiusM.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShapesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('geometry: $geometry, ')
          ..write('radiusM: $radiusM, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SpotsTable extends Spots with TableInfo<$SpotsTable, SpotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES records (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _osmRefMeta = const VerificationMeta('osmRef');
  @override
  late final GeneratedColumn<String> osmRef = GeneratedColumn<String>(
    'osm_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMajorMeta = const VerificationMeta(
    'categoryMajor',
  );
  @override
  late final GeneratedColumn<String> categoryMajor = GeneratedColumn<String>(
    'category_major',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMinorMeta = const VerificationMeta(
    'categoryMinor',
  );
  @override
  late final GeneratedColumn<String> categoryMinor = GeneratedColumn<String>(
    'category_minor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandKeyMeta = const VerificationMeta(
    'brandKey',
  );
  @override
  late final GeneratedColumn<String> brandKey = GeneratedColumn<String>(
    'brand_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoringMeta = const VerificationMeta(
    'scoring',
  );
  @override
  late final GeneratedColumn<String> scoring = GeneratedColumn<String>(
    'scoring',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoringOverriddenMeta = const VerificationMeta(
    'scoringOverridden',
  );
  @override
  late final GeneratedColumn<bool> scoringOverridden = GeneratedColumn<bool>(
    'scoring_overridden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("scoring_overridden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rawTagsMeta = const VerificationMeta(
    'rawTags',
  );
  @override
  late final GeneratedColumn<String> rawTags = GeneratedColumn<String>(
    'raw_tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeIdMeta = const VerificationMeta(
    'shapeId',
  );
  @override
  late final GeneratedColumn<String> shapeId = GeneratedColumn<String>(
    'shape_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    recordId,
    name,
    osmRef,
    lat,
    lon,
    categoryMajor,
    categoryMinor,
    brandKey,
    scoring,
    scoringOverridden,
    rawTags,
    shapeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('osm_ref')) {
      context.handle(
        _osmRefMeta,
        osmRef.isAcceptableOrUnknown(data['osm_ref']!, _osmRefMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    } else if (isInserting) {
      context.missing(_lonMeta);
    }
    if (data.containsKey('category_major')) {
      context.handle(
        _categoryMajorMeta,
        categoryMajor.isAcceptableOrUnknown(
          data['category_major']!,
          _categoryMajorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryMajorMeta);
    }
    if (data.containsKey('category_minor')) {
      context.handle(
        _categoryMinorMeta,
        categoryMinor.isAcceptableOrUnknown(
          data['category_minor']!,
          _categoryMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryMinorMeta);
    }
    if (data.containsKey('brand_key')) {
      context.handle(
        _brandKeyMeta,
        brandKey.isAcceptableOrUnknown(data['brand_key']!, _brandKeyMeta),
      );
    }
    if (data.containsKey('scoring')) {
      context.handle(
        _scoringMeta,
        scoring.isAcceptableOrUnknown(data['scoring']!, _scoringMeta),
      );
    } else if (isInserting) {
      context.missing(_scoringMeta);
    }
    if (data.containsKey('scoring_overridden')) {
      context.handle(
        _scoringOverriddenMeta,
        scoringOverridden.isAcceptableOrUnknown(
          data['scoring_overridden']!,
          _scoringOverriddenMeta,
        ),
      );
    }
    if (data.containsKey('raw_tags')) {
      context.handle(
        _rawTagsMeta,
        rawTags.isAcceptableOrUnknown(data['raw_tags']!, _rawTagsMeta),
      );
    }
    if (data.containsKey('shape_id')) {
      context.handle(
        _shapeIdMeta,
        shapeId.isAcceptableOrUnknown(data['shape_id']!, _shapeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shapeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId};
  @override
  SpotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpotRow(
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      osmRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}osm_ref'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      )!,
      categoryMajor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_major'],
      )!,
      categoryMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_minor'],
      )!,
      brandKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand_key'],
      ),
      scoring: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scoring'],
      )!,
      scoringOverridden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}scoring_overridden'],
      )!,
      rawTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_tags'],
      ),
      shapeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape_id'],
      )!,
    );
  }

  @override
  $SpotsTable createAlias(String alias) {
    return $SpotsTable(attachedDatabase, alias);
  }
}

class SpotRow extends DataClass implements Insertable<SpotRow> {
  /// 親の記録の ID。外部キー(`records.id`)。
  final String recordId;

  /// 場所の名前。
  final String name;

  /// OSM の参照(`way/123` など)。手動で置いた場所は null。
  final String? osmRef;

  /// 場所の代表点の緯度。
  final double lat;

  /// 場所の代表点の経度。
  final double lon;

  /// 大分類。
  final String categoryMajor;

  /// 小分類。
  final String categoryMinor;

  /// チェーン店などのブランド単位の識別子。なければ null。
  final String? brandKey;

  /// 加点の扱い(`target` / `record_only`)。
  final String scoring;

  /// 加点の扱いをユーザーが上書きしたか。
  final bool scoringOverridden;

  /// 元のタグ(JSON)。なければ null。
  final String? rawTags;

  /// 形の ID(`shapes.id`)。
  final String shapeId;
  const SpotRow({
    required this.recordId,
    required this.name,
    this.osmRef,
    required this.lat,
    required this.lon,
    required this.categoryMajor,
    required this.categoryMinor,
    this.brandKey,
    required this.scoring,
    required this.scoringOverridden,
    this.rawTags,
    required this.shapeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || osmRef != null) {
      map['osm_ref'] = Variable<String>(osmRef);
    }
    map['lat'] = Variable<double>(lat);
    map['lon'] = Variable<double>(lon);
    map['category_major'] = Variable<String>(categoryMajor);
    map['category_minor'] = Variable<String>(categoryMinor);
    if (!nullToAbsent || brandKey != null) {
      map['brand_key'] = Variable<String>(brandKey);
    }
    map['scoring'] = Variable<String>(scoring);
    map['scoring_overridden'] = Variable<bool>(scoringOverridden);
    if (!nullToAbsent || rawTags != null) {
      map['raw_tags'] = Variable<String>(rawTags);
    }
    map['shape_id'] = Variable<String>(shapeId);
    return map;
  }

  SpotsCompanion toCompanion(bool nullToAbsent) {
    return SpotsCompanion(
      recordId: Value(recordId),
      name: Value(name),
      osmRef: osmRef == null && nullToAbsent
          ? const Value.absent()
          : Value(osmRef),
      lat: Value(lat),
      lon: Value(lon),
      categoryMajor: Value(categoryMajor),
      categoryMinor: Value(categoryMinor),
      brandKey: brandKey == null && nullToAbsent
          ? const Value.absent()
          : Value(brandKey),
      scoring: Value(scoring),
      scoringOverridden: Value(scoringOverridden),
      rawTags: rawTags == null && nullToAbsent
          ? const Value.absent()
          : Value(rawTags),
      shapeId: Value(shapeId),
    );
  }

  factory SpotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpotRow(
      recordId: serializer.fromJson<String>(json['recordId']),
      name: serializer.fromJson<String>(json['name']),
      osmRef: serializer.fromJson<String?>(json['osmRef']),
      lat: serializer.fromJson<double>(json['lat']),
      lon: serializer.fromJson<double>(json['lon']),
      categoryMajor: serializer.fromJson<String>(json['categoryMajor']),
      categoryMinor: serializer.fromJson<String>(json['categoryMinor']),
      brandKey: serializer.fromJson<String?>(json['brandKey']),
      scoring: serializer.fromJson<String>(json['scoring']),
      scoringOverridden: serializer.fromJson<bool>(json['scoringOverridden']),
      rawTags: serializer.fromJson<String?>(json['rawTags']),
      shapeId: serializer.fromJson<String>(json['shapeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'name': serializer.toJson<String>(name),
      'osmRef': serializer.toJson<String?>(osmRef),
      'lat': serializer.toJson<double>(lat),
      'lon': serializer.toJson<double>(lon),
      'categoryMajor': serializer.toJson<String>(categoryMajor),
      'categoryMinor': serializer.toJson<String>(categoryMinor),
      'brandKey': serializer.toJson<String?>(brandKey),
      'scoring': serializer.toJson<String>(scoring),
      'scoringOverridden': serializer.toJson<bool>(scoringOverridden),
      'rawTags': serializer.toJson<String?>(rawTags),
      'shapeId': serializer.toJson<String>(shapeId),
    };
  }

  SpotRow copyWith({
    String? recordId,
    String? name,
    Value<String?> osmRef = const Value.absent(),
    double? lat,
    double? lon,
    String? categoryMajor,
    String? categoryMinor,
    Value<String?> brandKey = const Value.absent(),
    String? scoring,
    bool? scoringOverridden,
    Value<String?> rawTags = const Value.absent(),
    String? shapeId,
  }) => SpotRow(
    recordId: recordId ?? this.recordId,
    name: name ?? this.name,
    osmRef: osmRef.present ? osmRef.value : this.osmRef,
    lat: lat ?? this.lat,
    lon: lon ?? this.lon,
    categoryMajor: categoryMajor ?? this.categoryMajor,
    categoryMinor: categoryMinor ?? this.categoryMinor,
    brandKey: brandKey.present ? brandKey.value : this.brandKey,
    scoring: scoring ?? this.scoring,
    scoringOverridden: scoringOverridden ?? this.scoringOverridden,
    rawTags: rawTags.present ? rawTags.value : this.rawTags,
    shapeId: shapeId ?? this.shapeId,
  );
  SpotRow copyWithCompanion(SpotsCompanion data) {
    return SpotRow(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      name: data.name.present ? data.name.value : this.name,
      osmRef: data.osmRef.present ? data.osmRef.value : this.osmRef,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      categoryMajor: data.categoryMajor.present
          ? data.categoryMajor.value
          : this.categoryMajor,
      categoryMinor: data.categoryMinor.present
          ? data.categoryMinor.value
          : this.categoryMinor,
      brandKey: data.brandKey.present ? data.brandKey.value : this.brandKey,
      scoring: data.scoring.present ? data.scoring.value : this.scoring,
      scoringOverridden: data.scoringOverridden.present
          ? data.scoringOverridden.value
          : this.scoringOverridden,
      rawTags: data.rawTags.present ? data.rawTags.value : this.rawTags,
      shapeId: data.shapeId.present ? data.shapeId.value : this.shapeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpotRow(')
          ..write('recordId: $recordId, ')
          ..write('name: $name, ')
          ..write('osmRef: $osmRef, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('categoryMajor: $categoryMajor, ')
          ..write('categoryMinor: $categoryMinor, ')
          ..write('brandKey: $brandKey, ')
          ..write('scoring: $scoring, ')
          ..write('scoringOverridden: $scoringOverridden, ')
          ..write('rawTags: $rawTags, ')
          ..write('shapeId: $shapeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recordId,
    name,
    osmRef,
    lat,
    lon,
    categoryMajor,
    categoryMinor,
    brandKey,
    scoring,
    scoringOverridden,
    rawTags,
    shapeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpotRow &&
          other.recordId == this.recordId &&
          other.name == this.name &&
          other.osmRef == this.osmRef &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.categoryMajor == this.categoryMajor &&
          other.categoryMinor == this.categoryMinor &&
          other.brandKey == this.brandKey &&
          other.scoring == this.scoring &&
          other.scoringOverridden == this.scoringOverridden &&
          other.rawTags == this.rawTags &&
          other.shapeId == this.shapeId);
}

class SpotsCompanion extends UpdateCompanion<SpotRow> {
  final Value<String> recordId;
  final Value<String> name;
  final Value<String?> osmRef;
  final Value<double> lat;
  final Value<double> lon;
  final Value<String> categoryMajor;
  final Value<String> categoryMinor;
  final Value<String?> brandKey;
  final Value<String> scoring;
  final Value<bool> scoringOverridden;
  final Value<String?> rawTags;
  final Value<String> shapeId;
  final Value<int> rowid;
  const SpotsCompanion({
    this.recordId = const Value.absent(),
    this.name = const Value.absent(),
    this.osmRef = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.categoryMajor = const Value.absent(),
    this.categoryMinor = const Value.absent(),
    this.brandKey = const Value.absent(),
    this.scoring = const Value.absent(),
    this.scoringOverridden = const Value.absent(),
    this.rawTags = const Value.absent(),
    this.shapeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpotsCompanion.insert({
    required String recordId,
    required String name,
    this.osmRef = const Value.absent(),
    required double lat,
    required double lon,
    required String categoryMajor,
    required String categoryMinor,
    this.brandKey = const Value.absent(),
    required String scoring,
    this.scoringOverridden = const Value.absent(),
    this.rawTags = const Value.absent(),
    required String shapeId,
    this.rowid = const Value.absent(),
  }) : recordId = Value(recordId),
       name = Value(name),
       lat = Value(lat),
       lon = Value(lon),
       categoryMajor = Value(categoryMajor),
       categoryMinor = Value(categoryMinor),
       scoring = Value(scoring),
       shapeId = Value(shapeId);
  static Insertable<SpotRow> custom({
    Expression<String>? recordId,
    Expression<String>? name,
    Expression<String>? osmRef,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<String>? categoryMajor,
    Expression<String>? categoryMinor,
    Expression<String>? brandKey,
    Expression<String>? scoring,
    Expression<bool>? scoringOverridden,
    Expression<String>? rawTags,
    Expression<String>? shapeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (name != null) 'name': name,
      if (osmRef != null) 'osm_ref': osmRef,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (categoryMajor != null) 'category_major': categoryMajor,
      if (categoryMinor != null) 'category_minor': categoryMinor,
      if (brandKey != null) 'brand_key': brandKey,
      if (scoring != null) 'scoring': scoring,
      if (scoringOverridden != null) 'scoring_overridden': scoringOverridden,
      if (rawTags != null) 'raw_tags': rawTags,
      if (shapeId != null) 'shape_id': shapeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpotsCompanion copyWith({
    Value<String>? recordId,
    Value<String>? name,
    Value<String?>? osmRef,
    Value<double>? lat,
    Value<double>? lon,
    Value<String>? categoryMajor,
    Value<String>? categoryMinor,
    Value<String?>? brandKey,
    Value<String>? scoring,
    Value<bool>? scoringOverridden,
    Value<String?>? rawTags,
    Value<String>? shapeId,
    Value<int>? rowid,
  }) {
    return SpotsCompanion(
      recordId: recordId ?? this.recordId,
      name: name ?? this.name,
      osmRef: osmRef ?? this.osmRef,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      categoryMajor: categoryMajor ?? this.categoryMajor,
      categoryMinor: categoryMinor ?? this.categoryMinor,
      brandKey: brandKey ?? this.brandKey,
      scoring: scoring ?? this.scoring,
      scoringOverridden: scoringOverridden ?? this.scoringOverridden,
      rawTags: rawTags ?? this.rawTags,
      shapeId: shapeId ?? this.shapeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (osmRef.present) {
      map['osm_ref'] = Variable<String>(osmRef.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (categoryMajor.present) {
      map['category_major'] = Variable<String>(categoryMajor.value);
    }
    if (categoryMinor.present) {
      map['category_minor'] = Variable<String>(categoryMinor.value);
    }
    if (brandKey.present) {
      map['brand_key'] = Variable<String>(brandKey.value);
    }
    if (scoring.present) {
      map['scoring'] = Variable<String>(scoring.value);
    }
    if (scoringOverridden.present) {
      map['scoring_overridden'] = Variable<bool>(scoringOverridden.value);
    }
    if (rawTags.present) {
      map['raw_tags'] = Variable<String>(rawTags.value);
    }
    if (shapeId.present) {
      map['shape_id'] = Variable<String>(shapeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpotsCompanion(')
          ..write('recordId: $recordId, ')
          ..write('name: $name, ')
          ..write('osmRef: $osmRef, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('categoryMajor: $categoryMajor, ')
          ..write('categoryMinor: $categoryMinor, ')
          ..write('brandKey: $brandKey, ')
          ..write('scoring: $scoring, ')
          ..write('scoringOverridden: $scoringOverridden, ')
          ..write('rawTags: $rawTags, ')
          ..write('shapeId: $shapeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoverCellsTable extends CoverCells
    with TableInfo<$CoverCellsTable, CoverCellRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoverCellsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES records (id)',
    ),
  );
  static const VerificationMeta _zMeta = const VerificationMeta('z');
  @override
  late final GeneratedColumn<int> z = GeneratedColumn<int>(
    'z',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<int> x = GeneratedColumn<int>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<int> y = GeneratedColumn<int>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recordId, z, x, y, origin];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cover_cells';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoverCellRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('z')) {
      context.handle(_zMeta, z.isAcceptableOrUnknown(data['z']!, _zMeta));
    } else if (isInserting) {
      context.missing(_zMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId, z, x, y};
  @override
  CoverCellRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoverCellRow(
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      z: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}z'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}y'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
    );
  }

  @override
  $CoverCellsTable createAlias(String alias) {
    return $CoverCellsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class CoverCellRow extends DataClass implements Insertable<CoverCellRow> {
  /// 親の記録の ID。外部キー(`records.id`)。
  final String recordId;

  /// ズーム階層。
  final int z;

  /// タイル X。
  final int x;

  /// タイル Y。
  final int y;

  /// 塗られた理由(`spot` など)。
  final String origin;
  const CoverCellRow({
    required this.recordId,
    required this.z,
    required this.x,
    required this.y,
    required this.origin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['z'] = Variable<int>(z);
    map['x'] = Variable<int>(x);
    map['y'] = Variable<int>(y);
    map['origin'] = Variable<String>(origin);
    return map;
  }

  CoverCellsCompanion toCompanion(bool nullToAbsent) {
    return CoverCellsCompanion(
      recordId: Value(recordId),
      z: Value(z),
      x: Value(x),
      y: Value(y),
      origin: Value(origin),
    );
  }

  factory CoverCellRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoverCellRow(
      recordId: serializer.fromJson<String>(json['recordId']),
      z: serializer.fromJson<int>(json['z']),
      x: serializer.fromJson<int>(json['x']),
      y: serializer.fromJson<int>(json['y']),
      origin: serializer.fromJson<String>(json['origin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'z': serializer.toJson<int>(z),
      'x': serializer.toJson<int>(x),
      'y': serializer.toJson<int>(y),
      'origin': serializer.toJson<String>(origin),
    };
  }

  CoverCellRow copyWith({
    String? recordId,
    int? z,
    int? x,
    int? y,
    String? origin,
  }) => CoverCellRow(
    recordId: recordId ?? this.recordId,
    z: z ?? this.z,
    x: x ?? this.x,
    y: y ?? this.y,
    origin: origin ?? this.origin,
  );
  CoverCellRow copyWithCompanion(CoverCellsCompanion data) {
    return CoverCellRow(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      z: data.z.present ? data.z.value : this.z,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      origin: data.origin.present ? data.origin.value : this.origin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoverCellRow(')
          ..write('recordId: $recordId, ')
          ..write('z: $z, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('origin: $origin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordId, z, x, y, origin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoverCellRow &&
          other.recordId == this.recordId &&
          other.z == this.z &&
          other.x == this.x &&
          other.y == this.y &&
          other.origin == this.origin);
}

class CoverCellsCompanion extends UpdateCompanion<CoverCellRow> {
  final Value<String> recordId;
  final Value<int> z;
  final Value<int> x;
  final Value<int> y;
  final Value<String> origin;
  const CoverCellsCompanion({
    this.recordId = const Value.absent(),
    this.z = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.origin = const Value.absent(),
  });
  CoverCellsCompanion.insert({
    required String recordId,
    required int z,
    required int x,
    required int y,
    required String origin,
  }) : recordId = Value(recordId),
       z = Value(z),
       x = Value(x),
       y = Value(y),
       origin = Value(origin);
  static Insertable<CoverCellRow> custom({
    Expression<String>? recordId,
    Expression<int>? z,
    Expression<int>? x,
    Expression<int>? y,
    Expression<String>? origin,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (z != null) 'z': z,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (origin != null) 'origin': origin,
    });
  }

  CoverCellsCompanion copyWith({
    Value<String>? recordId,
    Value<int>? z,
    Value<int>? x,
    Value<int>? y,
    Value<String>? origin,
  }) {
    return CoverCellsCompanion(
      recordId: recordId ?? this.recordId,
      z: z ?? this.z,
      x: x ?? this.x,
      y: y ?? this.y,
      origin: origin ?? this.origin,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (z.present) {
      map['z'] = Variable<int>(z.value);
    }
    if (x.present) {
      map['x'] = Variable<int>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<int>(y.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoverCellsCompanion(')
          ..write('recordId: $recordId, ')
          ..write('z: $z, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('origin: $origin')
          ..write(')'))
        .toString();
  }
}

class $GeoCacheTable extends GeoCache
    with TableInfo<$GeoCacheTable, GeoCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeoCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, body, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'geo_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<GeoCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  GeoCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeoCacheRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $GeoCacheTable createAlias(String alias) {
    return $GeoCacheTable(attachedDatabase, alias);
  }
}

class GeoCacheRow extends DataClass implements Insertable<GeoCacheRow> {
  /// キャッシュのキー。
  final String key;

  /// 応答の本文。
  final String body;

  /// 取得時刻(エポックミリ秒)。
  final int fetchedAt;
  const GeoCacheRow({
    required this.key,
    required this.body,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['body'] = Variable<String>(body);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  GeoCacheCompanion toCompanion(bool nullToAbsent) {
    return GeoCacheCompanion(
      key: Value(key),
      body: Value(body),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory GeoCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeoCacheRow(
      key: serializer.fromJson<String>(json['key']),
      body: serializer.fromJson<String>(json['body']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'body': serializer.toJson<String>(body),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  GeoCacheRow copyWith({String? key, String? body, int? fetchedAt}) =>
      GeoCacheRow(
        key: key ?? this.key,
        body: body ?? this.body,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  GeoCacheRow copyWithCompanion(GeoCacheCompanion data) {
    return GeoCacheRow(
      key: data.key.present ? data.key.value : this.key,
      body: data.body.present ? data.body.value : this.body,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeoCacheRow(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, body, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoCacheRow &&
          other.key == this.key &&
          other.body == this.body &&
          other.fetchedAt == this.fetchedAt);
}

class GeoCacheCompanion extends UpdateCompanion<GeoCacheRow> {
  final Value<String> key;
  final Value<String> body;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const GeoCacheCompanion({
    this.key = const Value.absent(),
    this.body = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GeoCacheCompanion.insert({
    required String key,
    required String body,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       body = Value(body),
       fetchedAt = Value(fetchedAt);
  static Insertable<GeoCacheRow> custom({
    Expression<String>? key,
    Expression<String>? body,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (body != null) 'body': body,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GeoCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? body,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return GeoCacheCompanion(
      key: key ?? this.key,
      body: body ?? this.body,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeoCacheCompanion(')
          ..write('key: $key, ')
          ..write('body: $body, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  /// キー(`schema_ver` / `device_id` / `cover_ver`)。
  final String key;

  /// 値。
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $ShapesTable shapes = $ShapesTable(this);
  late final $SpotsTable spots = $SpotsTable(this);
  late final $CoverCellsTable coverCells = $CoverCellsTable(this);
  late final $GeoCacheTable geoCache = $GeoCacheTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final Index idxSpotsBrandKey = Index(
    'idx_spots_brand_key',
    'CREATE INDEX idx_spots_brand_key ON spots (brand_key)',
  );
  late final Index idxCoverCellsZxy = Index(
    'idx_cover_cells_zxy',
    'CREATE INDEX idx_cover_cells_zxy ON cover_cells (z, x, y)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    records,
    shapes,
    spots,
    coverCells,
    geoCache,
    meta,
    idxSpotsBrandKey,
    idxCoverCellsZxy,
  ];
}

typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String id,
  required String kind,
  required String visitedOn,
  required int createdAt,
  required int updatedAt,
  Value<int?> serverUpdatedAt,
  required String deviceId,
  Value<int?> deletedAt,
  required int schemaVer,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> visitedOn,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> serverUpdatedAt,
  Value<String> deviceId,
  Value<int?> deletedAt,
  Value<int> schemaVer,
  Value<int> rowid,
});

final class $$RecordsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordsTable, RecordRow> {
  $$RecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SpotsTable, List<SpotRow>> _spotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.spots,
    aliasName: 'records__id__spots__record_id',
  );

  $$SpotsTableProcessedTableManager get spotsRefs {
    final manager = $$SpotsTableTableManager(
      $_db,
      $_db.spots,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_spotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CoverCellsTable, List<CoverCellRow>>
  _coverCellsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.coverCells,
    aliasName: 'records__id__cover_cells__record_id',
  );

  $$CoverCellsTableProcessedTableManager get coverCellsRefs {
    final manager = $$CoverCellsTableTableManager(
      $_db,
      $_db.coverCells,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_coverCellsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visitedOn => $composableBuilder(
    column: $table.visitedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVer => $composableBuilder(
    column: $table.schemaVer,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> spotsRefs(
    Expression<bool> Function($$SpotsTableFilterComposer f) f,
  ) {
    final $$SpotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableFilterComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> coverCellsRefs(
    Expression<bool> Function($$CoverCellsTableFilterComposer f) f,
  ) {
    final $$CoverCellsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coverCells,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoverCellsTableFilterComposer(
            $db: $db,
            $table: $db.coverCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visitedOn => $composableBuilder(
    column: $table.visitedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVer => $composableBuilder(
    column: $table.schemaVer,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get visitedOn =>
      $composableBuilder(column: $table.visitedOn, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get schemaVer =>
      $composableBuilder(column: $table.schemaVer, builder: (column) => column);

  Expression<T> spotsRefs<T extends Object>(
    Expression<T> Function($$SpotsTableAnnotationComposer a) f,
  ) {
    final $$SpotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spots,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpotsTableAnnotationComposer(
            $db: $db,
            $table: $db.spots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> coverCellsRefs<T extends Object>(
    Expression<T> Function($$CoverCellsTableAnnotationComposer a) f,
  ) {
    final $$CoverCellsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coverCells,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoverCellsTableAnnotationComposer(
            $db: $db,
            $table: $db.coverCells,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (RecordRow, $$RecordsTableReferences),
          RecordRow,
          PrefetchHooks Function({bool spotsRefs, bool coverCellsRefs})
        > {
  $$RecordsTableTableManager(_$AppDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> visitedOn = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> serverUpdatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> schemaVer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                kind: kind,
                visitedOn: visitedOn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                schemaVer: schemaVer,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String visitedOn,
                required int createdAt,
                required int updatedAt,
                Value<int?> serverUpdatedAt = const Value.absent(),
                required String deviceId,
                Value<int?> deletedAt = const Value.absent(),
                required int schemaVer,
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                kind: kind,
                visitedOn: visitedOn,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                deviceId: deviceId,
                deletedAt: deletedAt,
                schemaVer: schemaVer,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, RecordRow>(table),
                  $$RecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({spotsRefs = false, coverCellsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (spotsRefs) db.spots,
                if (coverCellsRefs) db.coverCells,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (spotsRefs)
                    await $_getPrefetchedDataByColumns<
                      RecordRow,
                      $RecordsTable,
                      SpotRow,
                      $SpotsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RecordsTableReferences._spotsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RecordsTableReferences(db, table, p0).spotsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'record_id',
                      typedResults: items,
                    ),
                  if (coverCellsRefs)
                    await $_getPrefetchedDataByColumns<
                      RecordRow,
                      $RecordsTable,
                      CoverCellRow,
                      $CoverCellsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RecordsTableReferences
                          ._coverCellsRefsTable(db),
                      managerFromTypedResult: (p0) => $$RecordsTableReferences(
                        db,
                        table,
                        p0,
                      ).coverCellsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'record_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, $$RecordsTableReferences),
      RecordRow,
      PrefetchHooks Function({bool spotsRefs, bool coverCellsRefs})
    >;
typedef $$ShapesTableCreateCompanionBuilder = ShapesCompanion Function({
  required String id,
  required String kind,
  required String geometry,
  Value<int?> radiusM,
  required String source,
  Value<int> rowid,
});
typedef $$ShapesTableUpdateCompanionBuilder = ShapesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> geometry,
  Value<int?> radiusM,
  Value<String> source,
  Value<int> rowid,
});

class $$ShapesTableFilterComposer
    extends Composer<_$AppDatabase, $ShapesTable> {
  $$ShapesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geometry => $composableBuilder(
    column: $table.geometry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get radiusM => $composableBuilder(
    column: $table.radiusM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShapesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShapesTable> {
  $$ShapesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geometry => $composableBuilder(
    column: $table.geometry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get radiusM => $composableBuilder(
    column: $table.radiusM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShapesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShapesTable> {
  $$ShapesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get geometry =>
      $composableBuilder(column: $table.geometry, builder: (column) => column);

  GeneratedColumn<int> get radiusM =>
      $composableBuilder(column: $table.radiusM, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$ShapesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShapesTable,
          ShapeRow,
          $$ShapesTableFilterComposer,
          $$ShapesTableOrderingComposer,
          $$ShapesTableAnnotationComposer,
          $$ShapesTableCreateCompanionBuilder,
          $$ShapesTableUpdateCompanionBuilder,
          (ShapeRow, BaseReferences<_$AppDatabase, $ShapesTable, ShapeRow>),
          ShapeRow,
          PrefetchHooks Function()
        > {
  $$ShapesTableTableManager(_$AppDatabase db, $ShapesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShapesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShapesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShapesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> geometry = const Value.absent(),
                Value<int?> radiusM = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShapesCompanion(
                id: id,
                kind: kind,
                geometry: geometry,
                radiusM: radiusM,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String geometry,
                Value<int?> radiusM = const Value.absent(),
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => ShapesCompanion.insert(
                id: id,
                kind: kind,
                geometry: geometry,
                radiusM: radiusM,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShapesTable, ShapeRow>(table),
                  BaseReferences<_$AppDatabase, $ShapesTable, ShapeRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShapesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShapesTable,
      ShapeRow,
      $$ShapesTableFilterComposer,
      $$ShapesTableOrderingComposer,
      $$ShapesTableAnnotationComposer,
      $$ShapesTableCreateCompanionBuilder,
      $$ShapesTableUpdateCompanionBuilder,
      (ShapeRow, BaseReferences<_$AppDatabase, $ShapesTable, ShapeRow>),
      ShapeRow,
      PrefetchHooks Function()
    >;
typedef $$SpotsTableCreateCompanionBuilder = SpotsCompanion Function({
  required String recordId,
  required String name,
  Value<String?> osmRef,
  required double lat,
  required double lon,
  required String categoryMajor,
  required String categoryMinor,
  Value<String?> brandKey,
  required String scoring,
  Value<bool> scoringOverridden,
  Value<String?> rawTags,
  required String shapeId,
  Value<int> rowid,
});
typedef $$SpotsTableUpdateCompanionBuilder = SpotsCompanion Function({
  Value<String> recordId,
  Value<String> name,
  Value<String?> osmRef,
  Value<double> lat,
  Value<double> lon,
  Value<String> categoryMajor,
  Value<String> categoryMinor,
  Value<String?> brandKey,
  Value<String> scoring,
  Value<bool> scoringOverridden,
  Value<String?> rawTags,
  Value<String> shapeId,
  Value<int> rowid,
});

final class $$SpotsTableReferences
    extends BaseReferences<_$AppDatabase, $SpotsTable, SpotRow> {
  $$SpotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordsTable _recordIdTable(_$AppDatabase db) =>
      db.records.createAlias('spots__record_id__records__id');

  $$RecordsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpotsTableFilterComposer extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osmRef => $composableBuilder(
    column: $table.osmRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryMajor => $composableBuilder(
    column: $table.categoryMajor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryMinor => $composableBuilder(
    column: $table.categoryMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brandKey => $composableBuilder(
    column: $table.brandKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoring => $composableBuilder(
    column: $table.scoring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get scoringOverridden => $composableBuilder(
    column: $table.scoringOverridden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTags => $composableBuilder(
    column: $table.rawTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shapeId => $composableBuilder(
    column: $table.shapeId,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordsTableFilterComposer get recordId {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osmRef => $composableBuilder(
    column: $table.osmRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryMajor => $composableBuilder(
    column: $table.categoryMajor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryMinor => $composableBuilder(
    column: $table.categoryMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brandKey => $composableBuilder(
    column: $table.brandKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoring => $composableBuilder(
    column: $table.scoring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get scoringOverridden => $composableBuilder(
    column: $table.scoringOverridden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTags => $composableBuilder(
    column: $table.rawTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shapeId => $composableBuilder(
    column: $table.shapeId,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordsTableOrderingComposer get recordId {
    final $$RecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableOrderingComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpotsTable> {
  $$SpotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get osmRef =>
      $composableBuilder(column: $table.osmRef, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<String> get categoryMajor => $composableBuilder(
    column: $table.categoryMajor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryMinor => $composableBuilder(
    column: $table.categoryMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get brandKey =>
      $composableBuilder(column: $table.brandKey, builder: (column) => column);

  GeneratedColumn<String> get scoring =>
      $composableBuilder(column: $table.scoring, builder: (column) => column);

  GeneratedColumn<bool> get scoringOverridden => $composableBuilder(
    column: $table.scoringOverridden,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawTags =>
      $composableBuilder(column: $table.rawTags, builder: (column) => column);

  GeneratedColumn<String> get shapeId =>
      $composableBuilder(column: $table.shapeId, builder: (column) => column);

  $$RecordsTableAnnotationComposer get recordId {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpotsTable,
          SpotRow,
          $$SpotsTableFilterComposer,
          $$SpotsTableOrderingComposer,
          $$SpotsTableAnnotationComposer,
          $$SpotsTableCreateCompanionBuilder,
          $$SpotsTableUpdateCompanionBuilder,
          (SpotRow, $$SpotsTableReferences),
          SpotRow,
          PrefetchHooks Function({bool recordId})
        > {
  $$SpotsTableTableManager(_$AppDatabase db, $SpotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> osmRef = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lon = const Value.absent(),
                Value<String> categoryMajor = const Value.absent(),
                Value<String> categoryMinor = const Value.absent(),
                Value<String?> brandKey = const Value.absent(),
                Value<String> scoring = const Value.absent(),
                Value<bool> scoringOverridden = const Value.absent(),
                Value<String?> rawTags = const Value.absent(),
                Value<String> shapeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpotsCompanion(
                recordId: recordId,
                name: name,
                osmRef: osmRef,
                lat: lat,
                lon: lon,
                categoryMajor: categoryMajor,
                categoryMinor: categoryMinor,
                brandKey: brandKey,
                scoring: scoring,
                scoringOverridden: scoringOverridden,
                rawTags: rawTags,
                shapeId: shapeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordId,
                required String name,
                Value<String?> osmRef = const Value.absent(),
                required double lat,
                required double lon,
                required String categoryMajor,
                required String categoryMinor,
                Value<String?> brandKey = const Value.absent(),
                required String scoring,
                Value<bool> scoringOverridden = const Value.absent(),
                Value<String?> rawTags = const Value.absent(),
                required String shapeId,
                Value<int> rowid = const Value.absent(),
              }) => SpotsCompanion.insert(
                recordId: recordId,
                name: name,
                osmRef: osmRef,
                lat: lat,
                lon: lon,
                categoryMajor: categoryMajor,
                categoryMinor: categoryMinor,
                brandKey: brandKey,
                scoring: scoring,
                scoringOverridden: scoringOverridden,
                rawTags: rawTags,
                shapeId: shapeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpotsTable, SpotRow>(table),
                  $$SpotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordId,
                        referencedTable: $$SpotsTableReferences._recordIdTable(
                          db,
                        ),
                        referencedColumn: $$SpotsTableReferences
                            ._recordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpotsTable,
      SpotRow,
      $$SpotsTableFilterComposer,
      $$SpotsTableOrderingComposer,
      $$SpotsTableAnnotationComposer,
      $$SpotsTableCreateCompanionBuilder,
      $$SpotsTableUpdateCompanionBuilder,
      (SpotRow, $$SpotsTableReferences),
      SpotRow,
      PrefetchHooks Function({bool recordId})
    >;
typedef $$CoverCellsTableCreateCompanionBuilder = CoverCellsCompanion Function({
  required String recordId,
  required int z,
  required int x,
  required int y,
  required String origin,
});
typedef $$CoverCellsTableUpdateCompanionBuilder = CoverCellsCompanion Function({
  Value<String> recordId,
  Value<int> z,
  Value<int> x,
  Value<int> y,
  Value<String> origin,
});

final class $$CoverCellsTableReferences
    extends BaseReferences<_$AppDatabase, $CoverCellsTable, CoverCellRow> {
  $$CoverCellsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordsTable _recordIdTable(_$AppDatabase db) =>
      db.records.createAlias('cover_cells__record_id__records__id');

  $$RecordsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CoverCellsTableFilterComposer
    extends Composer<_$AppDatabase, $CoverCellsTable> {
  $$CoverCellsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get z => $composableBuilder(
    column: $table.z,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordsTableFilterComposer get recordId {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoverCellsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoverCellsTable> {
  $$CoverCellsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get z => $composableBuilder(
    column: $table.z,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordsTableOrderingComposer get recordId {
    final $$RecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableOrderingComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoverCellsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoverCellsTable> {
  $$CoverCellsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get z =>
      $composableBuilder(column: $table.z, builder: (column) => column);

  GeneratedColumn<int> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<int> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  $$RecordsTableAnnotationComposer get recordId {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoverCellsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoverCellsTable,
          CoverCellRow,
          $$CoverCellsTableFilterComposer,
          $$CoverCellsTableOrderingComposer,
          $$CoverCellsTableAnnotationComposer,
          $$CoverCellsTableCreateCompanionBuilder,
          $$CoverCellsTableUpdateCompanionBuilder,
          (CoverCellRow, $$CoverCellsTableReferences),
          CoverCellRow,
          PrefetchHooks Function({bool recordId})
        > {
  $$CoverCellsTableTableManager(_$AppDatabase db, $CoverCellsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoverCellsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoverCellsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoverCellsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordId = const Value.absent(),
                Value<int> z = const Value.absent(),
                Value<int> x = const Value.absent(),
                Value<int> y = const Value.absent(),
                Value<String> origin = const Value.absent(),
              }) => CoverCellsCompanion(
                recordId: recordId,
                z: z,
                x: x,
                y: y,
                origin: origin,
              ),
          createCompanionCallback:
              ({
                required String recordId,
                required int z,
                required int x,
                required int y,
                required String origin,
              }) => CoverCellsCompanion.insert(
                recordId: recordId,
                z: z,
                x: x,
                y: y,
                origin: origin,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoverCellsTable, CoverCellRow>(table),
                  $$CoverCellsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordId,
                        referencedTable: $$CoverCellsTableReferences
                            ._recordIdTable(db),
                        referencedColumn: $$CoverCellsTableReferences
                            ._recordIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CoverCellsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoverCellsTable,
      CoverCellRow,
      $$CoverCellsTableFilterComposer,
      $$CoverCellsTableOrderingComposer,
      $$CoverCellsTableAnnotationComposer,
      $$CoverCellsTableCreateCompanionBuilder,
      $$CoverCellsTableUpdateCompanionBuilder,
      (CoverCellRow, $$CoverCellsTableReferences),
      CoverCellRow,
      PrefetchHooks Function({bool recordId})
    >;
typedef $$GeoCacheTableCreateCompanionBuilder = GeoCacheCompanion Function({
  required String key,
  required String body,
  required int fetchedAt,
  Value<int> rowid,
});
typedef $$GeoCacheTableUpdateCompanionBuilder = GeoCacheCompanion Function({
  Value<String> key,
  Value<String> body,
  Value<int> fetchedAt,
  Value<int> rowid,
});

class $$GeoCacheTableFilterComposer
    extends Composer<_$AppDatabase, $GeoCacheTable> {
  $$GeoCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GeoCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $GeoCacheTable> {
  $$GeoCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GeoCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeoCacheTable> {
  $$GeoCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$GeoCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GeoCacheTable,
          GeoCacheRow,
          $$GeoCacheTableFilterComposer,
          $$GeoCacheTableOrderingComposer,
          $$GeoCacheTableAnnotationComposer,
          $$GeoCacheTableCreateCompanionBuilder,
          $$GeoCacheTableUpdateCompanionBuilder,
          (
            GeoCacheRow,
            BaseReferences<_$AppDatabase, $GeoCacheTable, GeoCacheRow>,
          ),
          GeoCacheRow,
          PrefetchHooks Function()
        > {
  $$GeoCacheTableTableManager(_$AppDatabase db, $GeoCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeoCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeoCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeoCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GeoCacheCompanion(
                key: key,
                body: body,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String body,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => GeoCacheCompanion.insert(
                key: key,
                body: body,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GeoCacheTable, GeoCacheRow>(table),
                  BaseReferences<_$AppDatabase, $GeoCacheTable, GeoCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GeoCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GeoCacheTable,
      GeoCacheRow,
      $$GeoCacheTableFilterComposer,
      $$GeoCacheTableOrderingComposer,
      $$GeoCacheTableAnnotationComposer,
      $$GeoCacheTableCreateCompanionBuilder,
      $$GeoCacheTableUpdateCompanionBuilder,
      (GeoCacheRow, BaseReferences<_$AppDatabase, $GeoCacheTable, GeoCacheRow>),
      GeoCacheRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaRow>(table),
                  BaseReferences<_$AppDatabase, $MetaTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$ShapesTableTableManager get shapes =>
      $$ShapesTableTableManager(_db, _db.shapes);
  $$SpotsTableTableManager get spots =>
      $$SpotsTableTableManager(_db, _db.spots);
  $$CoverCellsTableTableManager get coverCells =>
      $$CoverCellsTableTableManager(_db, _db.coverCells);
  $$GeoCacheTableTableManager get geoCache =>
      $$GeoCacheTableTableManager(_db, _db.geoCache);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
