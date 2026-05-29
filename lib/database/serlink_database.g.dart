// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serlink_database.dart';

// ignore_for_file: type=lint
class $VaultHeadersTable extends VaultHeaders
    with TableInfo<$VaultHeadersTable, VaultHeaderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultHeadersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_headers';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultHeaderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultHeaderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultHeaderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VaultHeadersTable createAlias(String alias) {
    return $VaultHeadersTable(attachedDatabase, alias);
  }
}

class VaultHeaderRow extends DataClass implements Insertable<VaultHeaderRow> {
  final String id;
  final String json;
  final DateTime updatedAt;
  const VaultHeaderRow({
    required this.id,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  VaultHeadersCompanion toCompanion(bool nullToAbsent) {
    return VaultHeadersCompanion(
      id: Value(id),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory VaultHeaderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultHeaderRow(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  VaultHeaderRow copyWith({String? id, String? json, DateTime? updatedAt}) =>
      VaultHeaderRow(
        id: id ?? this.id,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  VaultHeaderRow copyWithCompanion(VaultHeadersCompanion data) {
    return VaultHeaderRow(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultHeaderRow(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultHeaderRow &&
          other.id == this.id &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class VaultHeadersCompanion extends UpdateCompanion<VaultHeaderRow> {
  final Value<String> id;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const VaultHeadersCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultHeadersCompanion.insert({
    required String id,
    required String json,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<VaultHeaderRow> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultHeadersCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return VaultHeadersCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultHeadersCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EncryptedRecordsTable extends EncryptedRecords
    with TableInfo<$EncryptedRecordsTable, EncryptedRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<Uint8List> mac = GeneratedColumn<Uint8List>(
    'mac',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _associatedDataMeta = const VerificationMeta(
    'associatedData',
  );
  @override
  late final GeneratedColumn<Uint8List> associatedData =
      GeneratedColumn<Uint8List>(
        'associated_data',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    schemaVersion,
    revision,
    nonce,
    mac,
    associatedData,
    ciphertext,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    } else if (isInserting) {
      context.missing(_macMeta);
    }
    if (data.containsKey('associated_data')) {
      context.handle(
        _associatedDataMeta,
        associatedData.isAcceptableOrUnknown(
          data['associated_data']!,
          _associatedDataMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_associatedDataMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EncryptedRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}mac'],
      )!,
      associatedData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}associated_data'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EncryptedRecordsTable createAlias(String alias) {
    return $EncryptedRecordsTable(attachedDatabase, alias);
  }
}

class EncryptedRecordRow extends DataClass
    implements Insertable<EncryptedRecordRow> {
  final String id;
  final String type;
  final int schemaVersion;
  final String revision;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List associatedData;
  final Uint8List ciphertext;
  final DateTime updatedAt;
  const EncryptedRecordRow({
    required this.id,
    required this.type,
    required this.schemaVersion,
    required this.revision,
    required this.nonce,
    required this.mac,
    required this.associatedData,
    required this.ciphertext,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['revision'] = Variable<String>(revision);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['mac'] = Variable<Uint8List>(mac);
    map['associated_data'] = Variable<Uint8List>(associatedData);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EncryptedRecordsCompanion toCompanion(bool nullToAbsent) {
    return EncryptedRecordsCompanion(
      id: Value(id),
      type: Value(type),
      schemaVersion: Value(schemaVersion),
      revision: Value(revision),
      nonce: Value(nonce),
      mac: Value(mac),
      associatedData: Value(associatedData),
      ciphertext: Value(ciphertext),
      updatedAt: Value(updatedAt),
    );
  }

  factory EncryptedRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedRecordRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      revision: serializer.fromJson<String>(json['revision']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      mac: serializer.fromJson<Uint8List>(json['mac']),
      associatedData: serializer.fromJson<Uint8List>(json['associatedData']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'revision': serializer.toJson<String>(revision),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'mac': serializer.toJson<Uint8List>(mac),
      'associatedData': serializer.toJson<Uint8List>(associatedData),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EncryptedRecordRow copyWith({
    String? id,
    String? type,
    int? schemaVersion,
    String? revision,
    Uint8List? nonce,
    Uint8List? mac,
    Uint8List? associatedData,
    Uint8List? ciphertext,
    DateTime? updatedAt,
  }) => EncryptedRecordRow(
    id: id ?? this.id,
    type: type ?? this.type,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    revision: revision ?? this.revision,
    nonce: nonce ?? this.nonce,
    mac: mac ?? this.mac,
    associatedData: associatedData ?? this.associatedData,
    ciphertext: ciphertext ?? this.ciphertext,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EncryptedRecordRow copyWithCompanion(EncryptedRecordsCompanion data) {
    return EncryptedRecordRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      revision: data.revision.present ? data.revision.value : this.revision,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      mac: data.mac.present ? data.mac.value : this.mac,
      associatedData: data.associatedData.present
          ? data.associatedData.value
          : this.associatedData,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedRecordRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('revision: $revision, ')
          ..write('nonce: $nonce, ')
          ..write('mac: $mac, ')
          ..write('associatedData: $associatedData, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    schemaVersion,
    revision,
    $driftBlobEquality.hash(nonce),
    $driftBlobEquality.hash(mac),
    $driftBlobEquality.hash(associatedData),
    $driftBlobEquality.hash(ciphertext),
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedRecordRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.schemaVersion == this.schemaVersion &&
          other.revision == this.revision &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          $driftBlobEquality.equals(other.mac, this.mac) &&
          $driftBlobEquality.equals(
            other.associatedData,
            this.associatedData,
          ) &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext) &&
          other.updatedAt == this.updatedAt);
}

class EncryptedRecordsCompanion extends UpdateCompanion<EncryptedRecordRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> schemaVersion;
  final Value<String> revision;
  final Value<Uint8List> nonce;
  final Value<Uint8List> mac;
  final Value<Uint8List> associatedData;
  final Value<Uint8List> ciphertext;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EncryptedRecordsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.revision = const Value.absent(),
    this.nonce = const Value.absent(),
    this.mac = const Value.absent(),
    this.associatedData = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EncryptedRecordsCompanion.insert({
    required String id,
    required String type,
    required int schemaVersion,
    required String revision,
    required Uint8List nonce,
    required Uint8List mac,
    required Uint8List associatedData,
    required Uint8List ciphertext,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       schemaVersion = Value(schemaVersion),
       revision = Value(revision),
       nonce = Value(nonce),
       mac = Value(mac),
       associatedData = Value(associatedData),
       ciphertext = Value(ciphertext),
       updatedAt = Value(updatedAt);
  static Insertable<EncryptedRecordRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? schemaVersion,
    Expression<String>? revision,
    Expression<Uint8List>? nonce,
    Expression<Uint8List>? mac,
    Expression<Uint8List>? associatedData,
    Expression<Uint8List>? ciphertext,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (revision != null) 'revision': revision,
      if (nonce != null) 'nonce': nonce,
      if (mac != null) 'mac': mac,
      if (associatedData != null) 'associated_data': associatedData,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EncryptedRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int>? schemaVersion,
    Value<String>? revision,
    Value<Uint8List>? nonce,
    Value<Uint8List>? mac,
    Value<Uint8List>? associatedData,
    Value<Uint8List>? ciphertext,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EncryptedRecordsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      associatedData: associatedData ?? this.associatedData,
      ciphertext: ciphertext ?? this.ciphertext,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (mac.present) {
      map['mac'] = Variable<Uint8List>(mac.value);
    }
    if (associatedData.present) {
      map['associated_data'] = Variable<Uint8List>(associatedData.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedRecordsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('revision: $revision, ')
          ..write('nonce: $nonce, ')
          ..write('mac: $mac, ')
          ..write('associatedData: $associatedData, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SerlinkDatabase extends GeneratedDatabase {
  _$SerlinkDatabase(QueryExecutor e) : super(e);
  $SerlinkDatabaseManager get managers => $SerlinkDatabaseManager(this);
  late final $VaultHeadersTable vaultHeaders = $VaultHeadersTable(this);
  late final $EncryptedRecordsTable encryptedRecords = $EncryptedRecordsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultHeaders,
    encryptedRecords,
  ];
}

typedef $$VaultHeadersTableCreateCompanionBuilder =
    VaultHeadersCompanion Function({
      required String id,
      required String json,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$VaultHeadersTableUpdateCompanionBuilder =
    VaultHeadersCompanion Function({
      Value<String> id,
      Value<String> json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$VaultHeadersTableFilterComposer
    extends Composer<_$SerlinkDatabase, $VaultHeadersTable> {
  $$VaultHeadersTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultHeadersTableOrderingComposer
    extends Composer<_$SerlinkDatabase, $VaultHeadersTable> {
  $$VaultHeadersTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultHeadersTableAnnotationComposer
    extends Composer<_$SerlinkDatabase, $VaultHeadersTable> {
  $$VaultHeadersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VaultHeadersTableTableManager
    extends
        RootTableManager<
          _$SerlinkDatabase,
          $VaultHeadersTable,
          VaultHeaderRow,
          $$VaultHeadersTableFilterComposer,
          $$VaultHeadersTableOrderingComposer,
          $$VaultHeadersTableAnnotationComposer,
          $$VaultHeadersTableCreateCompanionBuilder,
          $$VaultHeadersTableUpdateCompanionBuilder,
          (
            VaultHeaderRow,
            BaseReferences<
              _$SerlinkDatabase,
              $VaultHeadersTable,
              VaultHeaderRow
            >,
          ),
          VaultHeaderRow,
          PrefetchHooks Function()
        > {
  $$VaultHeadersTableTableManager(
    _$SerlinkDatabase db,
    $VaultHeadersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultHeadersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultHeadersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultHeadersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultHeadersCompanion(
                id: id,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultHeadersCompanion.insert(
                id: id,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultHeadersTableProcessedTableManager =
    ProcessedTableManager<
      _$SerlinkDatabase,
      $VaultHeadersTable,
      VaultHeaderRow,
      $$VaultHeadersTableFilterComposer,
      $$VaultHeadersTableOrderingComposer,
      $$VaultHeadersTableAnnotationComposer,
      $$VaultHeadersTableCreateCompanionBuilder,
      $$VaultHeadersTableUpdateCompanionBuilder,
      (
        VaultHeaderRow,
        BaseReferences<_$SerlinkDatabase, $VaultHeadersTable, VaultHeaderRow>,
      ),
      VaultHeaderRow,
      PrefetchHooks Function()
    >;
typedef $$EncryptedRecordsTableCreateCompanionBuilder =
    EncryptedRecordsCompanion Function({
      required String id,
      required String type,
      required int schemaVersion,
      required String revision,
      required Uint8List nonce,
      required Uint8List mac,
      required Uint8List associatedData,
      required Uint8List ciphertext,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EncryptedRecordsTableUpdateCompanionBuilder =
    EncryptedRecordsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<int> schemaVersion,
      Value<String> revision,
      Value<Uint8List> nonce,
      Value<Uint8List> mac,
      Value<Uint8List> associatedData,
      Value<Uint8List> ciphertext,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EncryptedRecordsTableFilterComposer
    extends Composer<_$SerlinkDatabase, $EncryptedRecordsTable> {
  $$EncryptedRecordsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get associatedData => $composableBuilder(
    column: $table.associatedData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EncryptedRecordsTableOrderingComposer
    extends Composer<_$SerlinkDatabase, $EncryptedRecordsTable> {
  $$EncryptedRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get associatedData => $composableBuilder(
    column: $table.associatedData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EncryptedRecordsTableAnnotationComposer
    extends Composer<_$SerlinkDatabase, $EncryptedRecordsTable> {
  $$EncryptedRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<Uint8List> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<Uint8List> get associatedData => $composableBuilder(
    column: $table.associatedData,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EncryptedRecordsTableTableManager
    extends
        RootTableManager<
          _$SerlinkDatabase,
          $EncryptedRecordsTable,
          EncryptedRecordRow,
          $$EncryptedRecordsTableFilterComposer,
          $$EncryptedRecordsTableOrderingComposer,
          $$EncryptedRecordsTableAnnotationComposer,
          $$EncryptedRecordsTableCreateCompanionBuilder,
          $$EncryptedRecordsTableUpdateCompanionBuilder,
          (
            EncryptedRecordRow,
            BaseReferences<
              _$SerlinkDatabase,
              $EncryptedRecordsTable,
              EncryptedRecordRow
            >,
          ),
          EncryptedRecordRow,
          PrefetchHooks Function()
        > {
  $$EncryptedRecordsTableTableManager(
    _$SerlinkDatabase db,
    $EncryptedRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EncryptedRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EncryptedRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EncryptedRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> revision = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<Uint8List> mac = const Value.absent(),
                Value<Uint8List> associatedData = const Value.absent(),
                Value<Uint8List> ciphertext = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EncryptedRecordsCompanion(
                id: id,
                type: type,
                schemaVersion: schemaVersion,
                revision: revision,
                nonce: nonce,
                mac: mac,
                associatedData: associatedData,
                ciphertext: ciphertext,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required int schemaVersion,
                required String revision,
                required Uint8List nonce,
                required Uint8List mac,
                required Uint8List associatedData,
                required Uint8List ciphertext,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EncryptedRecordsCompanion.insert(
                id: id,
                type: type,
                schemaVersion: schemaVersion,
                revision: revision,
                nonce: nonce,
                mac: mac,
                associatedData: associatedData,
                ciphertext: ciphertext,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EncryptedRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$SerlinkDatabase,
      $EncryptedRecordsTable,
      EncryptedRecordRow,
      $$EncryptedRecordsTableFilterComposer,
      $$EncryptedRecordsTableOrderingComposer,
      $$EncryptedRecordsTableAnnotationComposer,
      $$EncryptedRecordsTableCreateCompanionBuilder,
      $$EncryptedRecordsTableUpdateCompanionBuilder,
      (
        EncryptedRecordRow,
        BaseReferences<
          _$SerlinkDatabase,
          $EncryptedRecordsTable,
          EncryptedRecordRow
        >,
      ),
      EncryptedRecordRow,
      PrefetchHooks Function()
    >;

class $SerlinkDatabaseManager {
  final _$SerlinkDatabase _db;
  $SerlinkDatabaseManager(this._db);
  $$VaultHeadersTableTableManager get vaultHeaders =>
      $$VaultHeadersTableTableManager(_db, _db.vaultHeaders);
  $$EncryptedRecordsTableTableManager get encryptedRecords =>
      $$EncryptedRecordsTableTableManager(_db, _db.encryptedRecords);
}
