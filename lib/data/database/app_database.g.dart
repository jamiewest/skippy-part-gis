// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SnapshotsTable extends Snapshots
    with TableInfo<$SnapshotsTable, SnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressCountMeta = const VerificationMeta(
    'addressCount',
  );
  @override
  late final GeneratedColumn<int> addressCount = GeneratedColumn<int>(
    'address_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _parcelCountMeta = const VerificationMeta(
    'parcelCount',
  );
  @override
  late final GeneratedColumn<int> parcelCount = GeneratedColumn<int>(
    'parcel_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _countyMeta = const VerificationMeta('county');
  @override
  late final GeneratedColumn<String> county = GeneratedColumn<String>(
    'county',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('riverside'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    startedAt,
    completedAt,
    addressCount,
    parcelCount,
    county,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('address_count')) {
      context.handle(
        _addressCountMeta,
        addressCount.isAcceptableOrUnknown(
          data['address_count']!,
          _addressCountMeta,
        ),
      );
    }
    if (data.containsKey('parcel_count')) {
      context.handle(
        _parcelCountMeta,
        parcelCount.isAcceptableOrUnknown(
          data['parcel_count']!,
          _parcelCountMeta,
        ),
      );
    }
    if (data.containsKey('county')) {
      context.handle(
        _countyMeta,
        county.isAcceptableOrUnknown(data['county']!, _countyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      addressCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}address_count'],
      )!,
      parcelCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parcel_count'],
      )!,
      county: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}county'],
      )!,
    );
  }

  @override
  $SnapshotsTable createAlias(String alias) {
    return $SnapshotsTable(attachedDatabase, alias);
  }
}

class SnapshotRow extends DataClass implements Insertable<SnapshotRow> {
  /// Local snapshot identifier.
  final int id;

  /// Import lifecycle status.
  final String status;

  /// Import start time.
  final DateTime startedAt;

  /// Successful activation time.
  final DateTime? completedAt;

  /// Number of imported addresses.
  final int addressCount;

  /// Number of imported parcels.
  final int parcelCount;

  /// Identifier of the county the snapshot was downloaded from.
  ///
  /// Snapshots predating multi-county support are all Riverside.
  final String county;
  const SnapshotRow({
    required this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.addressCount,
    required this.parcelCount,
    required this.county,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['address_count'] = Variable<int>(addressCount);
    map['parcel_count'] = Variable<int>(parcelCount);
    map['county'] = Variable<String>(county);
    return map;
  }

  SnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotsCompanion(
      id: Value(id),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      addressCount: Value(addressCount),
      parcelCount: Value(parcelCount),
      county: Value(county),
    );
  }

  factory SnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRow(
      id: serializer.fromJson<int>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      addressCount: serializer.fromJson<int>(json['addressCount']),
      parcelCount: serializer.fromJson<int>(json['parcelCount']),
      county: serializer.fromJson<String>(json['county']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'addressCount': serializer.toJson<int>(addressCount),
      'parcelCount': serializer.toJson<int>(parcelCount),
      'county': serializer.toJson<String>(county),
    };
  }

  SnapshotRow copyWith({
    int? id,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? addressCount,
    int? parcelCount,
    String? county,
  }) => SnapshotRow(
    id: id ?? this.id,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    addressCount: addressCount ?? this.addressCount,
    parcelCount: parcelCount ?? this.parcelCount,
    county: county ?? this.county,
  );
  SnapshotRow copyWithCompanion(SnapshotsCompanion data) {
    return SnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      addressCount: data.addressCount.present
          ? data.addressCount.value
          : this.addressCount,
      parcelCount: data.parcelCount.present
          ? data.parcelCount.value
          : this.parcelCount,
      county: data.county.present ? data.county.value : this.county,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('addressCount: $addressCount, ')
          ..write('parcelCount: $parcelCount, ')
          ..write('county: $county')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    startedAt,
    completedAt,
    addressCount,
    parcelCount,
    county,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.addressCount == this.addressCount &&
          other.parcelCount == this.parcelCount &&
          other.county == this.county);
}

class SnapshotsCompanion extends UpdateCompanion<SnapshotRow> {
  final Value<int> id;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> addressCount;
  final Value<int> parcelCount;
  final Value<String> county;
  const SnapshotsCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.addressCount = const Value.absent(),
    this.parcelCount = const Value.absent(),
    this.county = const Value.absent(),
  });
  SnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required String status,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.addressCount = const Value.absent(),
    this.parcelCount = const Value.absent(),
    this.county = const Value.absent(),
  }) : status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<SnapshotRow> custom({
    Expression<int>? id,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? addressCount,
    Expression<int>? parcelCount,
    Expression<String>? county,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (addressCount != null) 'address_count': addressCount,
      if (parcelCount != null) 'parcel_count': parcelCount,
      if (county != null) 'county': county,
    });
  }

  SnapshotsCompanion copyWith({
    Value<int>? id,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? addressCount,
    Value<int>? parcelCount,
    Value<String>? county,
  }) {
    return SnapshotsCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      addressCount: addressCount ?? this.addressCount,
      parcelCount: parcelCount ?? this.parcelCount,
      county: county ?? this.county,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (addressCount.present) {
      map['address_count'] = Variable<int>(addressCount.value);
    }
    if (parcelCount.present) {
      map['parcel_count'] = Variable<int>(parcelCount.value);
    }
    if (county.present) {
      map['county'] = Variable<String>(county.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('addressCount: $addressCount, ')
          ..write('parcelCount: $parcelCount, ')
          ..write('county: $county')
          ..write(')'))
        .toString();
  }
}

class $AddressesTable extends Addresses
    with TableInfo<$AddressesTable, AddressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  @override
  late final GeneratedColumn<int> snapshotId = GeneratedColumn<int>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snapshots (id)',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceObjectIdMeta = const VerificationMeta(
    'sourceObjectId',
  );
  @override
  late final GeneratedColumn<int> sourceObjectId = GeneratedColumn<int>(
    'source_object_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fullAddressMeta = const VerificationMeta(
    'fullAddress',
  );
  @override
  late final GeneratedColumn<String> fullAddress = GeneratedColumn<String>(
    'full_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _houseNumberMeta = const VerificationMeta(
    'houseNumber',
  );
  @override
  late final GeneratedColumn<int> houseNumber = GeneratedColumn<int>(
    'house_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streetNameMeta = const VerificationMeta(
    'streetName',
  );
  @override
  late final GeneratedColumn<String> streetName = GeneratedColumn<String>(
    'street_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streetTypeMeta = const VerificationMeta(
    'streetType',
  );
  @override
  late final GeneratedColumn<String> streetType = GeneratedColumn<String>(
    'street_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zipCodeMeta = const VerificationMeta(
    'zipCode',
  );
  @override
  late final GeneratedColumn<String> zipCode = GeneratedColumn<String>(
    'zip_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apnMeta = const VerificationMeta('apn');
  @override
  late final GeneratedColumn<String> apn = GeneratedColumn<String>(
    'apn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressTypeMeta = const VerificationMeta(
    'addressType',
  );
  @override
  late final GeneratedColumn<String> addressType = GeneratedColumn<String>(
    'address_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberOfUnitsMeta = const VerificationMeta(
    'numberOfUnits',
  );
  @override
  late final GeneratedColumn<int> numberOfUnits = GeneratedColumn<int>(
    'number_of_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUpdatedAtMeta = const VerificationMeta(
    'sourceUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> sourceUpdatedAt =
      GeneratedColumn<DateTime>(
        'source_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapshotId,
    sourceId,
    sourceObjectId,
    fullAddress,
    houseNumber,
    streetName,
    streetType,
    unit,
    city,
    zipCode,
    apn,
    addressType,
    numberOfUnits,
    latitude,
    longitude,
    sourceUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<AddressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_object_id')) {
      context.handle(
        _sourceObjectIdMeta,
        sourceObjectId.isAcceptableOrUnknown(
          data['source_object_id']!,
          _sourceObjectIdMeta,
        ),
      );
    }
    if (data.containsKey('full_address')) {
      context.handle(
        _fullAddressMeta,
        fullAddress.isAcceptableOrUnknown(
          data['full_address']!,
          _fullAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fullAddressMeta);
    }
    if (data.containsKey('house_number')) {
      context.handle(
        _houseNumberMeta,
        houseNumber.isAcceptableOrUnknown(
          data['house_number']!,
          _houseNumberMeta,
        ),
      );
    }
    if (data.containsKey('street_name')) {
      context.handle(
        _streetNameMeta,
        streetName.isAcceptableOrUnknown(data['street_name']!, _streetNameMeta),
      );
    } else if (isInserting) {
      context.missing(_streetNameMeta);
    }
    if (data.containsKey('street_type')) {
      context.handle(
        _streetTypeMeta,
        streetType.isAcceptableOrUnknown(data['street_type']!, _streetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_streetTypeMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('zip_code')) {
      context.handle(
        _zipCodeMeta,
        zipCode.isAcceptableOrUnknown(data['zip_code']!, _zipCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_zipCodeMeta);
    }
    if (data.containsKey('apn')) {
      context.handle(
        _apnMeta,
        apn.isAcceptableOrUnknown(data['apn']!, _apnMeta),
      );
    } else if (isInserting) {
      context.missing(_apnMeta);
    }
    if (data.containsKey('address_type')) {
      context.handle(
        _addressTypeMeta,
        addressType.isAcceptableOrUnknown(
          data['address_type']!,
          _addressTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressTypeMeta);
    }
    if (data.containsKey('number_of_units')) {
      context.handle(
        _numberOfUnitsMeta,
        numberOfUnits.isAcceptableOrUnknown(
          data['number_of_units']!,
          _numberOfUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_numberOfUnitsMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('source_updated_at')) {
      context.handle(
        _sourceUpdatedAtMeta,
        sourceUpdatedAt.isAcceptableOrUnknown(
          data['source_updated_at']!,
          _sourceUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {snapshotId, sourceId},
    {snapshotId, sourceObjectId},
  ];
  @override
  AddressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AddressRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snapshot_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      sourceObjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_object_id'],
      )!,
      fullAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_address'],
      )!,
      houseNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}house_number'],
      ),
      streetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}street_name'],
      )!,
      streetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}street_type'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      zipCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zip_code'],
      )!,
      apn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}apn'],
      )!,
      addressType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_type'],
      )!,
      numberOfUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number_of_units'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      sourceUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}source_updated_at'],
      ),
    );
  }

  @override
  $AddressesTable createAlias(String alias) {
    return $AddressesTable(attachedDatabase, alias);
  }
}

class AddressRow extends DataClass implements Insertable<AddressRow> {
  /// Local row identifier used by FTS and RTree indexes.
  final int id;

  /// Owning snapshot.
  final int snapshotId;

  /// Riverside County address identifier.
  final int sourceId;

  /// ArcGIS object identifier used to resume batch downloads.
  final int sourceObjectId;

  /// Primary street address.
  final String fullAddress;

  /// Numeric house component.
  final int? houseNumber;

  /// Street name component.
  final String streetName;

  /// Street type component.
  final String streetType;

  /// Unit component.
  final String unit;

  /// Situs city.
  final String city;

  /// ZIP code.
  final String zipCode;

  /// Assessor parcel number.
  final String apn;

  /// Raw county address type code.
  final String addressType;

  /// Number of units at this point.
  final int numberOfUnits;

  /// WGS84 latitude.
  final double latitude;

  /// WGS84 longitude.
  final double longitude;

  /// County edit time.
  final DateTime? sourceUpdatedAt;
  const AddressRow({
    required this.id,
    required this.snapshotId,
    required this.sourceId,
    required this.sourceObjectId,
    required this.fullAddress,
    this.houseNumber,
    required this.streetName,
    required this.streetType,
    required this.unit,
    required this.city,
    required this.zipCode,
    required this.apn,
    required this.addressType,
    required this.numberOfUnits,
    required this.latitude,
    required this.longitude,
    this.sourceUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['snapshot_id'] = Variable<int>(snapshotId);
    map['source_id'] = Variable<int>(sourceId);
    map['source_object_id'] = Variable<int>(sourceObjectId);
    map['full_address'] = Variable<String>(fullAddress);
    if (!nullToAbsent || houseNumber != null) {
      map['house_number'] = Variable<int>(houseNumber);
    }
    map['street_name'] = Variable<String>(streetName);
    map['street_type'] = Variable<String>(streetType);
    map['unit'] = Variable<String>(unit);
    map['city'] = Variable<String>(city);
    map['zip_code'] = Variable<String>(zipCode);
    map['apn'] = Variable<String>(apn);
    map['address_type'] = Variable<String>(addressType);
    map['number_of_units'] = Variable<int>(numberOfUnits);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || sourceUpdatedAt != null) {
      map['source_updated_at'] = Variable<DateTime>(sourceUpdatedAt);
    }
    return map;
  }

  AddressesCompanion toCompanion(bool nullToAbsent) {
    return AddressesCompanion(
      id: Value(id),
      snapshotId: Value(snapshotId),
      sourceId: Value(sourceId),
      sourceObjectId: Value(sourceObjectId),
      fullAddress: Value(fullAddress),
      houseNumber: houseNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(houseNumber),
      streetName: Value(streetName),
      streetType: Value(streetType),
      unit: Value(unit),
      city: Value(city),
      zipCode: Value(zipCode),
      apn: Value(apn),
      addressType: Value(addressType),
      numberOfUnits: Value(numberOfUnits),
      latitude: Value(latitude),
      longitude: Value(longitude),
      sourceUpdatedAt: sourceUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUpdatedAt),
    );
  }

  factory AddressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AddressRow(
      id: serializer.fromJson<int>(json['id']),
      snapshotId: serializer.fromJson<int>(json['snapshotId']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      sourceObjectId: serializer.fromJson<int>(json['sourceObjectId']),
      fullAddress: serializer.fromJson<String>(json['fullAddress']),
      houseNumber: serializer.fromJson<int?>(json['houseNumber']),
      streetName: serializer.fromJson<String>(json['streetName']),
      streetType: serializer.fromJson<String>(json['streetType']),
      unit: serializer.fromJson<String>(json['unit']),
      city: serializer.fromJson<String>(json['city']),
      zipCode: serializer.fromJson<String>(json['zipCode']),
      apn: serializer.fromJson<String>(json['apn']),
      addressType: serializer.fromJson<String>(json['addressType']),
      numberOfUnits: serializer.fromJson<int>(json['numberOfUnits']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      sourceUpdatedAt: serializer.fromJson<DateTime?>(json['sourceUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'snapshotId': serializer.toJson<int>(snapshotId),
      'sourceId': serializer.toJson<int>(sourceId),
      'sourceObjectId': serializer.toJson<int>(sourceObjectId),
      'fullAddress': serializer.toJson<String>(fullAddress),
      'houseNumber': serializer.toJson<int?>(houseNumber),
      'streetName': serializer.toJson<String>(streetName),
      'streetType': serializer.toJson<String>(streetType),
      'unit': serializer.toJson<String>(unit),
      'city': serializer.toJson<String>(city),
      'zipCode': serializer.toJson<String>(zipCode),
      'apn': serializer.toJson<String>(apn),
      'addressType': serializer.toJson<String>(addressType),
      'numberOfUnits': serializer.toJson<int>(numberOfUnits),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'sourceUpdatedAt': serializer.toJson<DateTime?>(sourceUpdatedAt),
    };
  }

  AddressRow copyWith({
    int? id,
    int? snapshotId,
    int? sourceId,
    int? sourceObjectId,
    String? fullAddress,
    Value<int?> houseNumber = const Value.absent(),
    String? streetName,
    String? streetType,
    String? unit,
    String? city,
    String? zipCode,
    String? apn,
    String? addressType,
    int? numberOfUnits,
    double? latitude,
    double? longitude,
    Value<DateTime?> sourceUpdatedAt = const Value.absent(),
  }) => AddressRow(
    id: id ?? this.id,
    snapshotId: snapshotId ?? this.snapshotId,
    sourceId: sourceId ?? this.sourceId,
    sourceObjectId: sourceObjectId ?? this.sourceObjectId,
    fullAddress: fullAddress ?? this.fullAddress,
    houseNumber: houseNumber.present ? houseNumber.value : this.houseNumber,
    streetName: streetName ?? this.streetName,
    streetType: streetType ?? this.streetType,
    unit: unit ?? this.unit,
    city: city ?? this.city,
    zipCode: zipCode ?? this.zipCode,
    apn: apn ?? this.apn,
    addressType: addressType ?? this.addressType,
    numberOfUnits: numberOfUnits ?? this.numberOfUnits,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    sourceUpdatedAt: sourceUpdatedAt.present
        ? sourceUpdatedAt.value
        : this.sourceUpdatedAt,
  );
  AddressRow copyWithCompanion(AddressesCompanion data) {
    return AddressRow(
      id: data.id.present ? data.id.value : this.id,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceObjectId: data.sourceObjectId.present
          ? data.sourceObjectId.value
          : this.sourceObjectId,
      fullAddress: data.fullAddress.present
          ? data.fullAddress.value
          : this.fullAddress,
      houseNumber: data.houseNumber.present
          ? data.houseNumber.value
          : this.houseNumber,
      streetName: data.streetName.present
          ? data.streetName.value
          : this.streetName,
      streetType: data.streetType.present
          ? data.streetType.value
          : this.streetType,
      unit: data.unit.present ? data.unit.value : this.unit,
      city: data.city.present ? data.city.value : this.city,
      zipCode: data.zipCode.present ? data.zipCode.value : this.zipCode,
      apn: data.apn.present ? data.apn.value : this.apn,
      addressType: data.addressType.present
          ? data.addressType.value
          : this.addressType,
      numberOfUnits: data.numberOfUnits.present
          ? data.numberOfUnits.value
          : this.numberOfUnits,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      sourceUpdatedAt: data.sourceUpdatedAt.present
          ? data.sourceUpdatedAt.value
          : this.sourceUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AddressRow(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceObjectId: $sourceObjectId, ')
          ..write('fullAddress: $fullAddress, ')
          ..write('houseNumber: $houseNumber, ')
          ..write('streetName: $streetName, ')
          ..write('streetType: $streetType, ')
          ..write('unit: $unit, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('apn: $apn, ')
          ..write('addressType: $addressType, ')
          ..write('numberOfUnits: $numberOfUnits, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('sourceUpdatedAt: $sourceUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapshotId,
    sourceId,
    sourceObjectId,
    fullAddress,
    houseNumber,
    streetName,
    streetType,
    unit,
    city,
    zipCode,
    apn,
    addressType,
    numberOfUnits,
    latitude,
    longitude,
    sourceUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AddressRow &&
          other.id == this.id &&
          other.snapshotId == this.snapshotId &&
          other.sourceId == this.sourceId &&
          other.sourceObjectId == this.sourceObjectId &&
          other.fullAddress == this.fullAddress &&
          other.houseNumber == this.houseNumber &&
          other.streetName == this.streetName &&
          other.streetType == this.streetType &&
          other.unit == this.unit &&
          other.city == this.city &&
          other.zipCode == this.zipCode &&
          other.apn == this.apn &&
          other.addressType == this.addressType &&
          other.numberOfUnits == this.numberOfUnits &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.sourceUpdatedAt == this.sourceUpdatedAt);
}

class AddressesCompanion extends UpdateCompanion<AddressRow> {
  final Value<int> id;
  final Value<int> snapshotId;
  final Value<int> sourceId;
  final Value<int> sourceObjectId;
  final Value<String> fullAddress;
  final Value<int?> houseNumber;
  final Value<String> streetName;
  final Value<String> streetType;
  final Value<String> unit;
  final Value<String> city;
  final Value<String> zipCode;
  final Value<String> apn;
  final Value<String> addressType;
  final Value<int> numberOfUnits;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime?> sourceUpdatedAt;
  const AddressesCompanion({
    this.id = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceObjectId = const Value.absent(),
    this.fullAddress = const Value.absent(),
    this.houseNumber = const Value.absent(),
    this.streetName = const Value.absent(),
    this.streetType = const Value.absent(),
    this.unit = const Value.absent(),
    this.city = const Value.absent(),
    this.zipCode = const Value.absent(),
    this.apn = const Value.absent(),
    this.addressType = const Value.absent(),
    this.numberOfUnits = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.sourceUpdatedAt = const Value.absent(),
  });
  AddressesCompanion.insert({
    this.id = const Value.absent(),
    required int snapshotId,
    required int sourceId,
    this.sourceObjectId = const Value.absent(),
    required String fullAddress,
    this.houseNumber = const Value.absent(),
    required String streetName,
    required String streetType,
    required String unit,
    required String city,
    required String zipCode,
    required String apn,
    required String addressType,
    required int numberOfUnits,
    required double latitude,
    required double longitude,
    this.sourceUpdatedAt = const Value.absent(),
  }) : snapshotId = Value(snapshotId),
       sourceId = Value(sourceId),
       fullAddress = Value(fullAddress),
       streetName = Value(streetName),
       streetType = Value(streetType),
       unit = Value(unit),
       city = Value(city),
       zipCode = Value(zipCode),
       apn = Value(apn),
       addressType = Value(addressType),
       numberOfUnits = Value(numberOfUnits),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<AddressRow> custom({
    Expression<int>? id,
    Expression<int>? snapshotId,
    Expression<int>? sourceId,
    Expression<int>? sourceObjectId,
    Expression<String>? fullAddress,
    Expression<int>? houseNumber,
    Expression<String>? streetName,
    Expression<String>? streetType,
    Expression<String>? unit,
    Expression<String>? city,
    Expression<String>? zipCode,
    Expression<String>? apn,
    Expression<String>? addressType,
    Expression<int>? numberOfUnits,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? sourceUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceObjectId != null) 'source_object_id': sourceObjectId,
      if (fullAddress != null) 'full_address': fullAddress,
      if (houseNumber != null) 'house_number': houseNumber,
      if (streetName != null) 'street_name': streetName,
      if (streetType != null) 'street_type': streetType,
      if (unit != null) 'unit': unit,
      if (city != null) 'city': city,
      if (zipCode != null) 'zip_code': zipCode,
      if (apn != null) 'apn': apn,
      if (addressType != null) 'address_type': addressType,
      if (numberOfUnits != null) 'number_of_units': numberOfUnits,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (sourceUpdatedAt != null) 'source_updated_at': sourceUpdatedAt,
    });
  }

  AddressesCompanion copyWith({
    Value<int>? id,
    Value<int>? snapshotId,
    Value<int>? sourceId,
    Value<int>? sourceObjectId,
    Value<String>? fullAddress,
    Value<int?>? houseNumber,
    Value<String>? streetName,
    Value<String>? streetType,
    Value<String>? unit,
    Value<String>? city,
    Value<String>? zipCode,
    Value<String>? apn,
    Value<String>? addressType,
    Value<int>? numberOfUnits,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<DateTime?>? sourceUpdatedAt,
  }) {
    return AddressesCompanion(
      id: id ?? this.id,
      snapshotId: snapshotId ?? this.snapshotId,
      sourceId: sourceId ?? this.sourceId,
      sourceObjectId: sourceObjectId ?? this.sourceObjectId,
      fullAddress: fullAddress ?? this.fullAddress,
      houseNumber: houseNumber ?? this.houseNumber,
      streetName: streetName ?? this.streetName,
      streetType: streetType ?? this.streetType,
      unit: unit ?? this.unit,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      apn: apn ?? this.apn,
      addressType: addressType ?? this.addressType,
      numberOfUnits: numberOfUnits ?? this.numberOfUnits,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sourceUpdatedAt: sourceUpdatedAt ?? this.sourceUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<int>(snapshotId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (sourceObjectId.present) {
      map['source_object_id'] = Variable<int>(sourceObjectId.value);
    }
    if (fullAddress.present) {
      map['full_address'] = Variable<String>(fullAddress.value);
    }
    if (houseNumber.present) {
      map['house_number'] = Variable<int>(houseNumber.value);
    }
    if (streetName.present) {
      map['street_name'] = Variable<String>(streetName.value);
    }
    if (streetType.present) {
      map['street_type'] = Variable<String>(streetType.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (zipCode.present) {
      map['zip_code'] = Variable<String>(zipCode.value);
    }
    if (apn.present) {
      map['apn'] = Variable<String>(apn.value);
    }
    if (addressType.present) {
      map['address_type'] = Variable<String>(addressType.value);
    }
    if (numberOfUnits.present) {
      map['number_of_units'] = Variable<int>(numberOfUnits.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (sourceUpdatedAt.present) {
      map['source_updated_at'] = Variable<DateTime>(sourceUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AddressesCompanion(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceObjectId: $sourceObjectId, ')
          ..write('fullAddress: $fullAddress, ')
          ..write('houseNumber: $houseNumber, ')
          ..write('streetName: $streetName, ')
          ..write('streetType: $streetType, ')
          ..write('unit: $unit, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('apn: $apn, ')
          ..write('addressType: $addressType, ')
          ..write('numberOfUnits: $numberOfUnits, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('sourceUpdatedAt: $sourceUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $ParcelsTable extends Parcels with TableInfo<$ParcelsTable, ParcelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParcelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _snapshotIdMeta = const VerificationMeta(
    'snapshotId',
  );
  @override
  late final GeneratedColumn<int> snapshotId = GeneratedColumn<int>(
    'snapshot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES snapshots (id)',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apnMeta = const VerificationMeta('apn');
  @override
  late final GeneratedColumn<String> apn = GeneratedColumn<String>(
    'apn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _situsAddressMeta = const VerificationMeta(
    'situsAddress',
  );
  @override
  late final GeneratedColumn<String> situsAddress = GeneratedColumn<String>(
    'situs_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zipCodeMeta = const VerificationMeta(
    'zipCode',
  );
  @override
  late final GeneratedColumn<String> zipCode = GeneratedColumn<String>(
    'zip_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _landUseMeta = const VerificationMeta(
    'landUse',
  );
  @override
  late final GeneratedColumn<String> landUse = GeneratedColumn<String>(
    'land_use',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acreageMeta = const VerificationMeta(
    'acreage',
  );
  @override
  late final GeneratedColumn<double> acreage = GeneratedColumn<double>(
    'acreage',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geometryJsonMeta = const VerificationMeta(
    'geometryJson',
  );
  @override
  late final GeneratedColumn<String> geometryJson = GeneratedColumn<String>(
    'geometry_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minLongitudeMeta = const VerificationMeta(
    'minLongitude',
  );
  @override
  late final GeneratedColumn<double> minLongitude = GeneratedColumn<double>(
    'min_longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxLongitudeMeta = const VerificationMeta(
    'maxLongitude',
  );
  @override
  late final GeneratedColumn<double> maxLongitude = GeneratedColumn<double>(
    'max_longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minLatitudeMeta = const VerificationMeta(
    'minLatitude',
  );
  @override
  late final GeneratedColumn<double> minLatitude = GeneratedColumn<double>(
    'min_latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxLatitudeMeta = const VerificationMeta(
    'maxLatitude',
  );
  @override
  late final GeneratedColumn<double> maxLatitude = GeneratedColumn<double>(
    'max_latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    snapshotId,
    sourceId,
    apn,
    situsAddress,
    city,
    zipCode,
    landUse,
    acreage,
    geometryJson,
    minLongitude,
    maxLongitude,
    minLatitude,
    maxLatitude,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parcels';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParcelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('snapshot_id')) {
      context.handle(
        _snapshotIdMeta,
        snapshotId.isAcceptableOrUnknown(data['snapshot_id']!, _snapshotIdMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('apn')) {
      context.handle(
        _apnMeta,
        apn.isAcceptableOrUnknown(data['apn']!, _apnMeta),
      );
    } else if (isInserting) {
      context.missing(_apnMeta);
    }
    if (data.containsKey('situs_address')) {
      context.handle(
        _situsAddressMeta,
        situsAddress.isAcceptableOrUnknown(
          data['situs_address']!,
          _situsAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_situsAddressMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('zip_code')) {
      context.handle(
        _zipCodeMeta,
        zipCode.isAcceptableOrUnknown(data['zip_code']!, _zipCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_zipCodeMeta);
    }
    if (data.containsKey('land_use')) {
      context.handle(
        _landUseMeta,
        landUse.isAcceptableOrUnknown(data['land_use']!, _landUseMeta),
      );
    } else if (isInserting) {
      context.missing(_landUseMeta);
    }
    if (data.containsKey('acreage')) {
      context.handle(
        _acreageMeta,
        acreage.isAcceptableOrUnknown(data['acreage']!, _acreageMeta),
      );
    }
    if (data.containsKey('geometry_json')) {
      context.handle(
        _geometryJsonMeta,
        geometryJson.isAcceptableOrUnknown(
          data['geometry_json']!,
          _geometryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_geometryJsonMeta);
    }
    if (data.containsKey('min_longitude')) {
      context.handle(
        _minLongitudeMeta,
        minLongitude.isAcceptableOrUnknown(
          data['min_longitude']!,
          _minLongitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minLongitudeMeta);
    }
    if (data.containsKey('max_longitude')) {
      context.handle(
        _maxLongitudeMeta,
        maxLongitude.isAcceptableOrUnknown(
          data['max_longitude']!,
          _maxLongitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxLongitudeMeta);
    }
    if (data.containsKey('min_latitude')) {
      context.handle(
        _minLatitudeMeta,
        minLatitude.isAcceptableOrUnknown(
          data['min_latitude']!,
          _minLatitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minLatitudeMeta);
    }
    if (data.containsKey('max_latitude')) {
      context.handle(
        _maxLatitudeMeta,
        maxLatitude.isAcceptableOrUnknown(
          data['max_latitude']!,
          _maxLatitudeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxLatitudeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {snapshotId, sourceId},
  ];
  @override
  ParcelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParcelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      snapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snapshot_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      apn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}apn'],
      )!,
      situsAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}situs_address'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      zipCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zip_code'],
      )!,
      landUse: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}land_use'],
      )!,
      acreage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}acreage'],
      ),
      geometryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geometry_json'],
      )!,
      minLongitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_longitude'],
      )!,
      maxLongitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_longitude'],
      )!,
      minLatitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_latitude'],
      )!,
      maxLatitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_latitude'],
      )!,
    );
  }

  @override
  $ParcelsTable createAlias(String alias) {
    return $ParcelsTable(attachedDatabase, alias);
  }
}

class ParcelRow extends DataClass implements Insertable<ParcelRow> {
  /// Local row identifier used by the RTree index.
  final int id;

  /// Owning snapshot.
  final int snapshotId;

  /// Riverside County object identifier.
  final int sourceId;

  /// Assessor parcel number.
  final String apn;

  /// Situs street address.
  final String situsAddress;

  /// Situs city.
  final String city;

  /// ZIP code.
  final String zipCode;

  /// Assessor class or land-use description.
  final String landUse;

  /// Assessed acreage.
  final double? acreage;

  /// JSON-encoded WGS84 polygon rings.
  final String geometryJson;

  /// Western geometry bound.
  final double minLongitude;

  /// Eastern geometry bound.
  final double maxLongitude;

  /// Southern geometry bound.
  final double minLatitude;

  /// Northern geometry bound.
  final double maxLatitude;
  const ParcelRow({
    required this.id,
    required this.snapshotId,
    required this.sourceId,
    required this.apn,
    required this.situsAddress,
    required this.city,
    required this.zipCode,
    required this.landUse,
    this.acreage,
    required this.geometryJson,
    required this.minLongitude,
    required this.maxLongitude,
    required this.minLatitude,
    required this.maxLatitude,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['snapshot_id'] = Variable<int>(snapshotId);
    map['source_id'] = Variable<int>(sourceId);
    map['apn'] = Variable<String>(apn);
    map['situs_address'] = Variable<String>(situsAddress);
    map['city'] = Variable<String>(city);
    map['zip_code'] = Variable<String>(zipCode);
    map['land_use'] = Variable<String>(landUse);
    if (!nullToAbsent || acreage != null) {
      map['acreage'] = Variable<double>(acreage);
    }
    map['geometry_json'] = Variable<String>(geometryJson);
    map['min_longitude'] = Variable<double>(minLongitude);
    map['max_longitude'] = Variable<double>(maxLongitude);
    map['min_latitude'] = Variable<double>(minLatitude);
    map['max_latitude'] = Variable<double>(maxLatitude);
    return map;
  }

  ParcelsCompanion toCompanion(bool nullToAbsent) {
    return ParcelsCompanion(
      id: Value(id),
      snapshotId: Value(snapshotId),
      sourceId: Value(sourceId),
      apn: Value(apn),
      situsAddress: Value(situsAddress),
      city: Value(city),
      zipCode: Value(zipCode),
      landUse: Value(landUse),
      acreage: acreage == null && nullToAbsent
          ? const Value.absent()
          : Value(acreage),
      geometryJson: Value(geometryJson),
      minLongitude: Value(minLongitude),
      maxLongitude: Value(maxLongitude),
      minLatitude: Value(minLatitude),
      maxLatitude: Value(maxLatitude),
    );
  }

  factory ParcelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParcelRow(
      id: serializer.fromJson<int>(json['id']),
      snapshotId: serializer.fromJson<int>(json['snapshotId']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      apn: serializer.fromJson<String>(json['apn']),
      situsAddress: serializer.fromJson<String>(json['situsAddress']),
      city: serializer.fromJson<String>(json['city']),
      zipCode: serializer.fromJson<String>(json['zipCode']),
      landUse: serializer.fromJson<String>(json['landUse']),
      acreage: serializer.fromJson<double?>(json['acreage']),
      geometryJson: serializer.fromJson<String>(json['geometryJson']),
      minLongitude: serializer.fromJson<double>(json['minLongitude']),
      maxLongitude: serializer.fromJson<double>(json['maxLongitude']),
      minLatitude: serializer.fromJson<double>(json['minLatitude']),
      maxLatitude: serializer.fromJson<double>(json['maxLatitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'snapshotId': serializer.toJson<int>(snapshotId),
      'sourceId': serializer.toJson<int>(sourceId),
      'apn': serializer.toJson<String>(apn),
      'situsAddress': serializer.toJson<String>(situsAddress),
      'city': serializer.toJson<String>(city),
      'zipCode': serializer.toJson<String>(zipCode),
      'landUse': serializer.toJson<String>(landUse),
      'acreage': serializer.toJson<double?>(acreage),
      'geometryJson': serializer.toJson<String>(geometryJson),
      'minLongitude': serializer.toJson<double>(minLongitude),
      'maxLongitude': serializer.toJson<double>(maxLongitude),
      'minLatitude': serializer.toJson<double>(minLatitude),
      'maxLatitude': serializer.toJson<double>(maxLatitude),
    };
  }

  ParcelRow copyWith({
    int? id,
    int? snapshotId,
    int? sourceId,
    String? apn,
    String? situsAddress,
    String? city,
    String? zipCode,
    String? landUse,
    Value<double?> acreage = const Value.absent(),
    String? geometryJson,
    double? minLongitude,
    double? maxLongitude,
    double? minLatitude,
    double? maxLatitude,
  }) => ParcelRow(
    id: id ?? this.id,
    snapshotId: snapshotId ?? this.snapshotId,
    sourceId: sourceId ?? this.sourceId,
    apn: apn ?? this.apn,
    situsAddress: situsAddress ?? this.situsAddress,
    city: city ?? this.city,
    zipCode: zipCode ?? this.zipCode,
    landUse: landUse ?? this.landUse,
    acreage: acreage.present ? acreage.value : this.acreage,
    geometryJson: geometryJson ?? this.geometryJson,
    minLongitude: minLongitude ?? this.minLongitude,
    maxLongitude: maxLongitude ?? this.maxLongitude,
    minLatitude: minLatitude ?? this.minLatitude,
    maxLatitude: maxLatitude ?? this.maxLatitude,
  );
  ParcelRow copyWithCompanion(ParcelsCompanion data) {
    return ParcelRow(
      id: data.id.present ? data.id.value : this.id,
      snapshotId: data.snapshotId.present
          ? data.snapshotId.value
          : this.snapshotId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      apn: data.apn.present ? data.apn.value : this.apn,
      situsAddress: data.situsAddress.present
          ? data.situsAddress.value
          : this.situsAddress,
      city: data.city.present ? data.city.value : this.city,
      zipCode: data.zipCode.present ? data.zipCode.value : this.zipCode,
      landUse: data.landUse.present ? data.landUse.value : this.landUse,
      acreage: data.acreage.present ? data.acreage.value : this.acreage,
      geometryJson: data.geometryJson.present
          ? data.geometryJson.value
          : this.geometryJson,
      minLongitude: data.minLongitude.present
          ? data.minLongitude.value
          : this.minLongitude,
      maxLongitude: data.maxLongitude.present
          ? data.maxLongitude.value
          : this.maxLongitude,
      minLatitude: data.minLatitude.present
          ? data.minLatitude.value
          : this.minLatitude,
      maxLatitude: data.maxLatitude.present
          ? data.maxLatitude.value
          : this.maxLatitude,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParcelRow(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('sourceId: $sourceId, ')
          ..write('apn: $apn, ')
          ..write('situsAddress: $situsAddress, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('landUse: $landUse, ')
          ..write('acreage: $acreage, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('minLongitude: $minLongitude, ')
          ..write('maxLongitude: $maxLongitude, ')
          ..write('minLatitude: $minLatitude, ')
          ..write('maxLatitude: $maxLatitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    snapshotId,
    sourceId,
    apn,
    situsAddress,
    city,
    zipCode,
    landUse,
    acreage,
    geometryJson,
    minLongitude,
    maxLongitude,
    minLatitude,
    maxLatitude,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParcelRow &&
          other.id == this.id &&
          other.snapshotId == this.snapshotId &&
          other.sourceId == this.sourceId &&
          other.apn == this.apn &&
          other.situsAddress == this.situsAddress &&
          other.city == this.city &&
          other.zipCode == this.zipCode &&
          other.landUse == this.landUse &&
          other.acreage == this.acreage &&
          other.geometryJson == this.geometryJson &&
          other.minLongitude == this.minLongitude &&
          other.maxLongitude == this.maxLongitude &&
          other.minLatitude == this.minLatitude &&
          other.maxLatitude == this.maxLatitude);
}

class ParcelsCompanion extends UpdateCompanion<ParcelRow> {
  final Value<int> id;
  final Value<int> snapshotId;
  final Value<int> sourceId;
  final Value<String> apn;
  final Value<String> situsAddress;
  final Value<String> city;
  final Value<String> zipCode;
  final Value<String> landUse;
  final Value<double?> acreage;
  final Value<String> geometryJson;
  final Value<double> minLongitude;
  final Value<double> maxLongitude;
  final Value<double> minLatitude;
  final Value<double> maxLatitude;
  const ParcelsCompanion({
    this.id = const Value.absent(),
    this.snapshotId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.apn = const Value.absent(),
    this.situsAddress = const Value.absent(),
    this.city = const Value.absent(),
    this.zipCode = const Value.absent(),
    this.landUse = const Value.absent(),
    this.acreage = const Value.absent(),
    this.geometryJson = const Value.absent(),
    this.minLongitude = const Value.absent(),
    this.maxLongitude = const Value.absent(),
    this.minLatitude = const Value.absent(),
    this.maxLatitude = const Value.absent(),
  });
  ParcelsCompanion.insert({
    this.id = const Value.absent(),
    required int snapshotId,
    required int sourceId,
    required String apn,
    required String situsAddress,
    required String city,
    required String zipCode,
    required String landUse,
    this.acreage = const Value.absent(),
    required String geometryJson,
    required double minLongitude,
    required double maxLongitude,
    required double minLatitude,
    required double maxLatitude,
  }) : snapshotId = Value(snapshotId),
       sourceId = Value(sourceId),
       apn = Value(apn),
       situsAddress = Value(situsAddress),
       city = Value(city),
       zipCode = Value(zipCode),
       landUse = Value(landUse),
       geometryJson = Value(geometryJson),
       minLongitude = Value(minLongitude),
       maxLongitude = Value(maxLongitude),
       minLatitude = Value(minLatitude),
       maxLatitude = Value(maxLatitude);
  static Insertable<ParcelRow> custom({
    Expression<int>? id,
    Expression<int>? snapshotId,
    Expression<int>? sourceId,
    Expression<String>? apn,
    Expression<String>? situsAddress,
    Expression<String>? city,
    Expression<String>? zipCode,
    Expression<String>? landUse,
    Expression<double>? acreage,
    Expression<String>? geometryJson,
    Expression<double>? minLongitude,
    Expression<double>? maxLongitude,
    Expression<double>? minLatitude,
    Expression<double>? maxLatitude,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (snapshotId != null) 'snapshot_id': snapshotId,
      if (sourceId != null) 'source_id': sourceId,
      if (apn != null) 'apn': apn,
      if (situsAddress != null) 'situs_address': situsAddress,
      if (city != null) 'city': city,
      if (zipCode != null) 'zip_code': zipCode,
      if (landUse != null) 'land_use': landUse,
      if (acreage != null) 'acreage': acreage,
      if (geometryJson != null) 'geometry_json': geometryJson,
      if (minLongitude != null) 'min_longitude': minLongitude,
      if (maxLongitude != null) 'max_longitude': maxLongitude,
      if (minLatitude != null) 'min_latitude': minLatitude,
      if (maxLatitude != null) 'max_latitude': maxLatitude,
    });
  }

  ParcelsCompanion copyWith({
    Value<int>? id,
    Value<int>? snapshotId,
    Value<int>? sourceId,
    Value<String>? apn,
    Value<String>? situsAddress,
    Value<String>? city,
    Value<String>? zipCode,
    Value<String>? landUse,
    Value<double?>? acreage,
    Value<String>? geometryJson,
    Value<double>? minLongitude,
    Value<double>? maxLongitude,
    Value<double>? minLatitude,
    Value<double>? maxLatitude,
  }) {
    return ParcelsCompanion(
      id: id ?? this.id,
      snapshotId: snapshotId ?? this.snapshotId,
      sourceId: sourceId ?? this.sourceId,
      apn: apn ?? this.apn,
      situsAddress: situsAddress ?? this.situsAddress,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      landUse: landUse ?? this.landUse,
      acreage: acreage ?? this.acreage,
      geometryJson: geometryJson ?? this.geometryJson,
      minLongitude: minLongitude ?? this.minLongitude,
      maxLongitude: maxLongitude ?? this.maxLongitude,
      minLatitude: minLatitude ?? this.minLatitude,
      maxLatitude: maxLatitude ?? this.maxLatitude,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (snapshotId.present) {
      map['snapshot_id'] = Variable<int>(snapshotId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (apn.present) {
      map['apn'] = Variable<String>(apn.value);
    }
    if (situsAddress.present) {
      map['situs_address'] = Variable<String>(situsAddress.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (zipCode.present) {
      map['zip_code'] = Variable<String>(zipCode.value);
    }
    if (landUse.present) {
      map['land_use'] = Variable<String>(landUse.value);
    }
    if (acreage.present) {
      map['acreage'] = Variable<double>(acreage.value);
    }
    if (geometryJson.present) {
      map['geometry_json'] = Variable<String>(geometryJson.value);
    }
    if (minLongitude.present) {
      map['min_longitude'] = Variable<double>(minLongitude.value);
    }
    if (maxLongitude.present) {
      map['max_longitude'] = Variable<double>(maxLongitude.value);
    }
    if (minLatitude.present) {
      map['min_latitude'] = Variable<double>(minLatitude.value);
    }
    if (maxLatitude.present) {
      map['max_latitude'] = Variable<double>(maxLatitude.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParcelsCompanion(')
          ..write('id: $id, ')
          ..write('snapshotId: $snapshotId, ')
          ..write('sourceId: $sourceId, ')
          ..write('apn: $apn, ')
          ..write('situsAddress: $situsAddress, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('landUse: $landUse, ')
          ..write('acreage: $acreage, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('minLongitude: $minLongitude, ')
          ..write('maxLongitude: $maxLongitude, ')
          ..write('minLatitude: $minLatitude, ')
          ..write('maxLatitude: $maxLatitude')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
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
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
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
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  /// Setting name.
  final String key;

  /// Setting value.
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
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

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
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
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
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

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PropertyOwnerCacheTable extends PropertyOwnerCache
    with TableInfo<$PropertyOwnerCacheTable, PropertyOwnerCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PropertyOwnerCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _propertyKeyMeta = const VerificationMeta(
    'propertyKey',
  );
  @override
  late final GeneratedColumn<String> propertyKey = GeneratedColumn<String>(
    'property_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parcelIdMeta = const VerificationMeta(
    'parcelId',
  );
  @override
  late final GeneratedColumn<String> parcelId = GeneratedColumn<String>(
    'parcel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchedAddressMeta = const VerificationMeta(
    'matchedAddress',
  );
  @override
  late final GeneratedColumn<String> matchedAddress = GeneratedColumn<String>(
    'matched_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    propertyKey,
    ownerName,
    parcelId,
    matchedAddress,
    sourceUrl,
    status,
    checkedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'property_owner_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PropertyOwnerCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('property_key')) {
      context.handle(
        _propertyKeyMeta,
        propertyKey.isAcceptableOrUnknown(
          data['property_key']!,
          _propertyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_propertyKeyMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    }
    if (data.containsKey('parcel_id')) {
      context.handle(
        _parcelIdMeta,
        parcelId.isAcceptableOrUnknown(data['parcel_id']!, _parcelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_parcelIdMeta);
    }
    if (data.containsKey('matched_address')) {
      context.handle(
        _matchedAddressMeta,
        matchedAddress.isAcceptableOrUnknown(
          data['matched_address']!,
          _matchedAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_matchedAddressMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {propertyKey};
  @override
  PropertyOwnerCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PropertyOwnerCacheRow(
      propertyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}property_key'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      ),
      parcelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parcel_id'],
      )!,
      matchedAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matched_address'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $PropertyOwnerCacheTable createAlias(String alias) {
    return $PropertyOwnerCacheTable(attachedDatabase, alias);
  }
}

class PropertyOwnerCacheRow extends DataClass
    implements Insertable<PropertyOwnerCacheRow> {
  /// Stable jurisdiction and property identifier, normally the APN.
  final String propertyKey;

  /// Published current owner, or null for a confirmed no-match result.
  final String? ownerName;

  /// Parcel identifier returned by the property-tax source.
  final String parcelId;

  /// Situs address used to validate the source result.
  final String matchedAddress;

  /// Public page that supplied the record.
  final String sourceUrl;

  /// Whether the lookup found an owner or confirmed no exact match.
  final String status;

  /// Time the public source was checked.
  final DateTime checkedAt;

  /// Time after which the public source should be checked again.
  final DateTime expiresAt;
  const PropertyOwnerCacheRow({
    required this.propertyKey,
    this.ownerName,
    required this.parcelId,
    required this.matchedAddress,
    required this.sourceUrl,
    required this.status,
    required this.checkedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['property_key'] = Variable<String>(propertyKey);
    if (!nullToAbsent || ownerName != null) {
      map['owner_name'] = Variable<String>(ownerName);
    }
    map['parcel_id'] = Variable<String>(parcelId);
    map['matched_address'] = Variable<String>(matchedAddress);
    map['source_url'] = Variable<String>(sourceUrl);
    map['status'] = Variable<String>(status);
    map['checked_at'] = Variable<DateTime>(checkedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  PropertyOwnerCacheCompanion toCompanion(bool nullToAbsent) {
    return PropertyOwnerCacheCompanion(
      propertyKey: Value(propertyKey),
      ownerName: ownerName == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerName),
      parcelId: Value(parcelId),
      matchedAddress: Value(matchedAddress),
      sourceUrl: Value(sourceUrl),
      status: Value(status),
      checkedAt: Value(checkedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory PropertyOwnerCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PropertyOwnerCacheRow(
      propertyKey: serializer.fromJson<String>(json['propertyKey']),
      ownerName: serializer.fromJson<String?>(json['ownerName']),
      parcelId: serializer.fromJson<String>(json['parcelId']),
      matchedAddress: serializer.fromJson<String>(json['matchedAddress']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      status: serializer.fromJson<String>(json['status']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'propertyKey': serializer.toJson<String>(propertyKey),
      'ownerName': serializer.toJson<String?>(ownerName),
      'parcelId': serializer.toJson<String>(parcelId),
      'matchedAddress': serializer.toJson<String>(matchedAddress),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'status': serializer.toJson<String>(status),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  PropertyOwnerCacheRow copyWith({
    String? propertyKey,
    Value<String?> ownerName = const Value.absent(),
    String? parcelId,
    String? matchedAddress,
    String? sourceUrl,
    String? status,
    DateTime? checkedAt,
    DateTime? expiresAt,
  }) => PropertyOwnerCacheRow(
    propertyKey: propertyKey ?? this.propertyKey,
    ownerName: ownerName.present ? ownerName.value : this.ownerName,
    parcelId: parcelId ?? this.parcelId,
    matchedAddress: matchedAddress ?? this.matchedAddress,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
    checkedAt: checkedAt ?? this.checkedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  PropertyOwnerCacheRow copyWithCompanion(PropertyOwnerCacheCompanion data) {
    return PropertyOwnerCacheRow(
      propertyKey: data.propertyKey.present
          ? data.propertyKey.value
          : this.propertyKey,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      parcelId: data.parcelId.present ? data.parcelId.value : this.parcelId,
      matchedAddress: data.matchedAddress.present
          ? data.matchedAddress.value
          : this.matchedAddress,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      status: data.status.present ? data.status.value : this.status,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PropertyOwnerCacheRow(')
          ..write('propertyKey: $propertyKey, ')
          ..write('ownerName: $ownerName, ')
          ..write('parcelId: $parcelId, ')
          ..write('matchedAddress: $matchedAddress, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    propertyKey,
    ownerName,
    parcelId,
    matchedAddress,
    sourceUrl,
    status,
    checkedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PropertyOwnerCacheRow &&
          other.propertyKey == this.propertyKey &&
          other.ownerName == this.ownerName &&
          other.parcelId == this.parcelId &&
          other.matchedAddress == this.matchedAddress &&
          other.sourceUrl == this.sourceUrl &&
          other.status == this.status &&
          other.checkedAt == this.checkedAt &&
          other.expiresAt == this.expiresAt);
}

class PropertyOwnerCacheCompanion
    extends UpdateCompanion<PropertyOwnerCacheRow> {
  final Value<String> propertyKey;
  final Value<String?> ownerName;
  final Value<String> parcelId;
  final Value<String> matchedAddress;
  final Value<String> sourceUrl;
  final Value<String> status;
  final Value<DateTime> checkedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const PropertyOwnerCacheCompanion({
    this.propertyKey = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.parcelId = const Value.absent(),
    this.matchedAddress = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PropertyOwnerCacheCompanion.insert({
    required String propertyKey,
    this.ownerName = const Value.absent(),
    required String parcelId,
    required String matchedAddress,
    required String sourceUrl,
    required String status,
    required DateTime checkedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : propertyKey = Value(propertyKey),
       parcelId = Value(parcelId),
       matchedAddress = Value(matchedAddress),
       sourceUrl = Value(sourceUrl),
       status = Value(status),
       checkedAt = Value(checkedAt),
       expiresAt = Value(expiresAt);
  static Insertable<PropertyOwnerCacheRow> custom({
    Expression<String>? propertyKey,
    Expression<String>? ownerName,
    Expression<String>? parcelId,
    Expression<String>? matchedAddress,
    Expression<String>? sourceUrl,
    Expression<String>? status,
    Expression<DateTime>? checkedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (propertyKey != null) 'property_key': propertyKey,
      if (ownerName != null) 'owner_name': ownerName,
      if (parcelId != null) 'parcel_id': parcelId,
      if (matchedAddress != null) 'matched_address': matchedAddress,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (status != null) 'status': status,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PropertyOwnerCacheCompanion copyWith({
    Value<String>? propertyKey,
    Value<String?>? ownerName,
    Value<String>? parcelId,
    Value<String>? matchedAddress,
    Value<String>? sourceUrl,
    Value<String>? status,
    Value<DateTime>? checkedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return PropertyOwnerCacheCompanion(
      propertyKey: propertyKey ?? this.propertyKey,
      ownerName: ownerName ?? this.ownerName,
      parcelId: parcelId ?? this.parcelId,
      matchedAddress: matchedAddress ?? this.matchedAddress,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      checkedAt: checkedAt ?? this.checkedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (propertyKey.present) {
      map['property_key'] = Variable<String>(propertyKey.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (parcelId.present) {
      map['parcel_id'] = Variable<String>(parcelId.value);
    }
    if (matchedAddress.present) {
      map['matched_address'] = Variable<String>(matchedAddress.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PropertyOwnerCacheCompanion(')
          ..write('propertyKey: $propertyKey, ')
          ..write('ownerName: $ownerName, ')
          ..write('parcelId: $parcelId, ')
          ..write('matchedAddress: $matchedAddress, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnclaimedPropertyCacheTable extends UnclaimedPropertyCache
    with TableInfo<$UnclaimedPropertyCacheTable, UnclaimedPropertyCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnclaimedPropertyCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _searchKeyMeta = const VerificationMeta(
    'searchKey',
  );
  @override
  late final GeneratedColumn<String> searchKey = GeneratedColumn<String>(
    'search_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zipCodeMeta = const VerificationMeta(
    'zipCode',
  );
  @override
  late final GeneratedColumn<String> zipCode = GeneratedColumn<String>(
    'zip_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foundMeta = const VerificationMeta('found');
  @override
  late final GeneratedColumn<bool> found = GeneratedColumn<bool>(
    'found',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("found" IN (0, 1))',
    ),
  );
  static const VerificationMeta _resultCountMeta = const VerificationMeta(
    'resultCount',
  );
  @override
  late final GeneratedColumn<int> resultCount = GeneratedColumn<int>(
    'result_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    searchKey,
    ownerName,
    firstName,
    lastName,
    city,
    zipCode,
    found,
    resultCount,
    sourceUrl,
    checkedAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unclaimed_property_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<UnclaimedPropertyCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('search_key')) {
      context.handle(
        _searchKeyMeta,
        searchKey.isAcceptableOrUnknown(data['search_key']!, _searchKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_searchKeyMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerNameMeta);
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('zip_code')) {
      context.handle(
        _zipCodeMeta,
        zipCode.isAcceptableOrUnknown(data['zip_code']!, _zipCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_zipCodeMeta);
    }
    if (data.containsKey('found')) {
      context.handle(
        _foundMeta,
        found.isAcceptableOrUnknown(data['found']!, _foundMeta),
      );
    } else if (isInserting) {
      context.missing(_foundMeta);
    }
    if (data.containsKey('result_count')) {
      context.handle(
        _resultCountMeta,
        resultCount.isAcceptableOrUnknown(
          data['result_count']!,
          _resultCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultCountMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {searchKey};
  @override
  UnclaimedPropertyCacheRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnclaimedPropertyCacheRow(
      searchKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_key'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      )!,
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      zipCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zip_code'],
      )!,
      found: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}found'],
      )!,
      resultCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_count'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $UnclaimedPropertyCacheTable createAlias(String alias) {
    return $UnclaimedPropertyCacheTable(attachedDatabase, alias);
  }
}

class UnclaimedPropertyCacheRow extends DataClass
    implements Insertable<UnclaimedPropertyCacheRow> {
  /// Normalized owner and location lookup key.
  final String searchKey;

  /// Owner text supplied by the Riverside County source.
  final String ownerName;

  /// First name submitted to the official search page.
  final String firstName;

  /// Last name or business name submitted to the official search page.
  final String lastName;

  /// Optional city submitted to narrow the result.
  final String city;

  /// Optional ZIP code submitted to narrow the result.
  final String zipCode;

  /// Whether the state reported at least one exact match.
  final bool found;

  /// Number of records returned by the state search.
  final int resultCount;

  /// Official page used for the search.
  final String sourceUrl;

  /// Time the state source was checked.
  final DateTime checkedAt;

  /// Time after which a fresh state search should be offered.
  final DateTime expiresAt;
  const UnclaimedPropertyCacheRow({
    required this.searchKey,
    required this.ownerName,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.zipCode,
    required this.found,
    required this.resultCount,
    required this.sourceUrl,
    required this.checkedAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['search_key'] = Variable<String>(searchKey);
    map['owner_name'] = Variable<String>(ownerName);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    map['city'] = Variable<String>(city);
    map['zip_code'] = Variable<String>(zipCode);
    map['found'] = Variable<bool>(found);
    map['result_count'] = Variable<int>(resultCount);
    map['source_url'] = Variable<String>(sourceUrl);
    map['checked_at'] = Variable<DateTime>(checkedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  UnclaimedPropertyCacheCompanion toCompanion(bool nullToAbsent) {
    return UnclaimedPropertyCacheCompanion(
      searchKey: Value(searchKey),
      ownerName: Value(ownerName),
      firstName: Value(firstName),
      lastName: Value(lastName),
      city: Value(city),
      zipCode: Value(zipCode),
      found: Value(found),
      resultCount: Value(resultCount),
      sourceUrl: Value(sourceUrl),
      checkedAt: Value(checkedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory UnclaimedPropertyCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnclaimedPropertyCacheRow(
      searchKey: serializer.fromJson<String>(json['searchKey']),
      ownerName: serializer.fromJson<String>(json['ownerName']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      city: serializer.fromJson<String>(json['city']),
      zipCode: serializer.fromJson<String>(json['zipCode']),
      found: serializer.fromJson<bool>(json['found']),
      resultCount: serializer.fromJson<int>(json['resultCount']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'searchKey': serializer.toJson<String>(searchKey),
      'ownerName': serializer.toJson<String>(ownerName),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'city': serializer.toJson<String>(city),
      'zipCode': serializer.toJson<String>(zipCode),
      'found': serializer.toJson<bool>(found),
      'resultCount': serializer.toJson<int>(resultCount),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  UnclaimedPropertyCacheRow copyWith({
    String? searchKey,
    String? ownerName,
    String? firstName,
    String? lastName,
    String? city,
    String? zipCode,
    bool? found,
    int? resultCount,
    String? sourceUrl,
    DateTime? checkedAt,
    DateTime? expiresAt,
  }) => UnclaimedPropertyCacheRow(
    searchKey: searchKey ?? this.searchKey,
    ownerName: ownerName ?? this.ownerName,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    city: city ?? this.city,
    zipCode: zipCode ?? this.zipCode,
    found: found ?? this.found,
    resultCount: resultCount ?? this.resultCount,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    checkedAt: checkedAt ?? this.checkedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  UnclaimedPropertyCacheRow copyWithCompanion(
    UnclaimedPropertyCacheCompanion data,
  ) {
    return UnclaimedPropertyCacheRow(
      searchKey: data.searchKey.present ? data.searchKey.value : this.searchKey,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      city: data.city.present ? data.city.value : this.city,
      zipCode: data.zipCode.present ? data.zipCode.value : this.zipCode,
      found: data.found.present ? data.found.value : this.found,
      resultCount: data.resultCount.present
          ? data.resultCount.value
          : this.resultCount,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnclaimedPropertyCacheRow(')
          ..write('searchKey: $searchKey, ')
          ..write('ownerName: $ownerName, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('found: $found, ')
          ..write('resultCount: $resultCount, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    searchKey,
    ownerName,
    firstName,
    lastName,
    city,
    zipCode,
    found,
    resultCount,
    sourceUrl,
    checkedAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnclaimedPropertyCacheRow &&
          other.searchKey == this.searchKey &&
          other.ownerName == this.ownerName &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.city == this.city &&
          other.zipCode == this.zipCode &&
          other.found == this.found &&
          other.resultCount == this.resultCount &&
          other.sourceUrl == this.sourceUrl &&
          other.checkedAt == this.checkedAt &&
          other.expiresAt == this.expiresAt);
}

class UnclaimedPropertyCacheCompanion
    extends UpdateCompanion<UnclaimedPropertyCacheRow> {
  final Value<String> searchKey;
  final Value<String> ownerName;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String> city;
  final Value<String> zipCode;
  final Value<bool> found;
  final Value<int> resultCount;
  final Value<String> sourceUrl;
  final Value<DateTime> checkedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const UnclaimedPropertyCacheCompanion({
    this.searchKey = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.city = const Value.absent(),
    this.zipCode = const Value.absent(),
    this.found = const Value.absent(),
    this.resultCount = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnclaimedPropertyCacheCompanion.insert({
    required String searchKey,
    required String ownerName,
    required String firstName,
    required String lastName,
    required String city,
    required String zipCode,
    required bool found,
    required int resultCount,
    required String sourceUrl,
    required DateTime checkedAt,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : searchKey = Value(searchKey),
       ownerName = Value(ownerName),
       firstName = Value(firstName),
       lastName = Value(lastName),
       city = Value(city),
       zipCode = Value(zipCode),
       found = Value(found),
       resultCount = Value(resultCount),
       sourceUrl = Value(sourceUrl),
       checkedAt = Value(checkedAt),
       expiresAt = Value(expiresAt);
  static Insertable<UnclaimedPropertyCacheRow> custom({
    Expression<String>? searchKey,
    Expression<String>? ownerName,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? city,
    Expression<String>? zipCode,
    Expression<bool>? found,
    Expression<int>? resultCount,
    Expression<String>? sourceUrl,
    Expression<DateTime>? checkedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (searchKey != null) 'search_key': searchKey,
      if (ownerName != null) 'owner_name': ownerName,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (city != null) 'city': city,
      if (zipCode != null) 'zip_code': zipCode,
      if (found != null) 'found': found,
      if (resultCount != null) 'result_count': resultCount,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnclaimedPropertyCacheCompanion copyWith({
    Value<String>? searchKey,
    Value<String>? ownerName,
    Value<String>? firstName,
    Value<String>? lastName,
    Value<String>? city,
    Value<String>? zipCode,
    Value<bool>? found,
    Value<int>? resultCount,
    Value<String>? sourceUrl,
    Value<DateTime>? checkedAt,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return UnclaimedPropertyCacheCompanion(
      searchKey: searchKey ?? this.searchKey,
      ownerName: ownerName ?? this.ownerName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      city: city ?? this.city,
      zipCode: zipCode ?? this.zipCode,
      found: found ?? this.found,
      resultCount: resultCount ?? this.resultCount,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      checkedAt: checkedAt ?? this.checkedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (searchKey.present) {
      map['search_key'] = Variable<String>(searchKey.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (zipCode.present) {
      map['zip_code'] = Variable<String>(zipCode.value);
    }
    if (found.present) {
      map['found'] = Variable<bool>(found.value);
    }
    if (resultCount.present) {
      map['result_count'] = Variable<int>(resultCount.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnclaimedPropertyCacheCompanion(')
          ..write('searchKey: $searchKey, ')
          ..write('ownerName: $ownerName, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('city: $city, ')
          ..write('zipCode: $zipCode, ')
          ..write('found: $found, ')
          ..write('resultCount: $resultCount, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SnapshotsTable snapshots = $SnapshotsTable(this);
  late final $AddressesTable addresses = $AddressesTable(this);
  late final $ParcelsTable parcels = $ParcelsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PropertyOwnerCacheTable propertyOwnerCache =
      $PropertyOwnerCacheTable(this);
  late final $UnclaimedPropertyCacheTable unclaimedPropertyCache =
      $UnclaimedPropertyCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    snapshots,
    addresses,
    parcels,
    settings,
    propertyOwnerCache,
    unclaimedPropertyCache,
  ];
}

typedef $$SnapshotsTableCreateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<int> addressCount,
      Value<int> parcelCount,
      Value<String> county,
    });
typedef $$SnapshotsTableUpdateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> addressCount,
      Value<int> parcelCount,
      Value<String> county,
    });

final class $$SnapshotsTableReferences
    extends BaseReferences<_$AppDatabase, $SnapshotsTable, SnapshotRow> {
  $$SnapshotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AddressesTable, List<AddressRow>>
  _addressesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.addresses,
    aliasName: 'snapshots__id__addresses__snapshot_id',
  );

  $$AddressesTableProcessedTableManager get addressesRefs {
    final manager = $$AddressesTableTableManager(
      $_db,
      $_db.addresses,
    ).filter((f) => f.snapshotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_addressesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ParcelsTable, List<ParcelRow>> _parcelsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.parcels,
    aliasName: 'snapshots__id__parcels__snapshot_id',
  );

  $$ParcelsTableProcessedTableManager get parcelsRefs {
    final manager = $$ParcelsTableTableManager(
      $_db,
      $_db.parcels,
    ).filter((f) => f.snapshotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_parcelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addressCount => $composableBuilder(
    column: $table.addressCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parcelCount => $composableBuilder(
    column: $table.parcelCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get county => $composableBuilder(
    column: $table.county,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> addressesRefs(
    Expression<bool> Function($$AddressesTableFilterComposer f) f,
  ) {
    final $$AddressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.addresses,
      getReferencedColumn: (t) => t.snapshotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AddressesTableFilterComposer(
            $db: $db,
            $table: $db.addresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> parcelsRefs(
    Expression<bool> Function($$ParcelsTableFilterComposer f) f,
  ) {
    final $$ParcelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parcels,
      getReferencedColumn: (t) => t.snapshotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParcelsTableFilterComposer(
            $db: $db,
            $table: $db.parcels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addressCount => $composableBuilder(
    column: $table.addressCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parcelCount => $composableBuilder(
    column: $table.parcelCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get county => $composableBuilder(
    column: $table.county,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addressCount => $composableBuilder(
    column: $table.addressCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parcelCount => $composableBuilder(
    column: $table.parcelCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get county =>
      $composableBuilder(column: $table.county, builder: (column) => column);

  Expression<T> addressesRefs<T extends Object>(
    Expression<T> Function($$AddressesTableAnnotationComposer a) f,
  ) {
    final $$AddressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.addresses,
      getReferencedColumn: (t) => t.snapshotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AddressesTableAnnotationComposer(
            $db: $db,
            $table: $db.addresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> parcelsRefs<T extends Object>(
    Expression<T> Function($$ParcelsTableAnnotationComposer a) f,
  ) {
    final $$ParcelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.parcels,
      getReferencedColumn: (t) => t.snapshotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParcelsTableAnnotationComposer(
            $db: $db,
            $table: $db.parcels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotsTable,
          SnapshotRow,
          $$SnapshotsTableFilterComposer,
          $$SnapshotsTableOrderingComposer,
          $$SnapshotsTableAnnotationComposer,
          $$SnapshotsTableCreateCompanionBuilder,
          $$SnapshotsTableUpdateCompanionBuilder,
          (SnapshotRow, $$SnapshotsTableReferences),
          SnapshotRow,
          PrefetchHooks Function({bool addressesRefs, bool parcelsRefs})
        > {
  $$SnapshotsTableTableManager(_$AppDatabase db, $SnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> addressCount = const Value.absent(),
                Value<int> parcelCount = const Value.absent(),
                Value<String> county = const Value.absent(),
              }) => SnapshotsCompanion(
                id: id,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                addressCount: addressCount,
                parcelCount: parcelCount,
                county: county,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String status,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> addressCount = const Value.absent(),
                Value<int> parcelCount = const Value.absent(),
                Value<String> county = const Value.absent(),
              }) => SnapshotsCompanion.insert(
                id: id,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                addressCount: addressCount,
                parcelCount: parcelCount,
                county: county,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({addressesRefs = false, parcelsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (addressesRefs) db.addresses,
                    if (parcelsRefs) db.parcels,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (addressesRefs)
                        await $_getPrefetchedData<
                          SnapshotRow,
                          $SnapshotsTable,
                          AddressRow
                        >(
                          currentTable: table,
                          referencedTable: $$SnapshotsTableReferences
                              ._addressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SnapshotsTableReferences(
                                db,
                                table,
                                p0,
                              ).addressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snapshotId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (parcelsRefs)
                        await $_getPrefetchedData<
                          SnapshotRow,
                          $SnapshotsTable,
                          ParcelRow
                        >(
                          currentTable: table,
                          referencedTable: $$SnapshotsTableReferences
                              ._parcelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SnapshotsTableReferences(
                                db,
                                table,
                                p0,
                              ).parcelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snapshotId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotsTable,
      SnapshotRow,
      $$SnapshotsTableFilterComposer,
      $$SnapshotsTableOrderingComposer,
      $$SnapshotsTableAnnotationComposer,
      $$SnapshotsTableCreateCompanionBuilder,
      $$SnapshotsTableUpdateCompanionBuilder,
      (SnapshotRow, $$SnapshotsTableReferences),
      SnapshotRow,
      PrefetchHooks Function({bool addressesRefs, bool parcelsRefs})
    >;
typedef $$AddressesTableCreateCompanionBuilder =
    AddressesCompanion Function({
      Value<int> id,
      required int snapshotId,
      required int sourceId,
      Value<int> sourceObjectId,
      required String fullAddress,
      Value<int?> houseNumber,
      required String streetName,
      required String streetType,
      required String unit,
      required String city,
      required String zipCode,
      required String apn,
      required String addressType,
      required int numberOfUnits,
      required double latitude,
      required double longitude,
      Value<DateTime?> sourceUpdatedAt,
    });
typedef $$AddressesTableUpdateCompanionBuilder =
    AddressesCompanion Function({
      Value<int> id,
      Value<int> snapshotId,
      Value<int> sourceId,
      Value<int> sourceObjectId,
      Value<String> fullAddress,
      Value<int?> houseNumber,
      Value<String> streetName,
      Value<String> streetType,
      Value<String> unit,
      Value<String> city,
      Value<String> zipCode,
      Value<String> apn,
      Value<String> addressType,
      Value<int> numberOfUnits,
      Value<double> latitude,
      Value<double> longitude,
      Value<DateTime?> sourceUpdatedAt,
    });

final class $$AddressesTableReferences
    extends BaseReferences<_$AppDatabase, $AddressesTable, AddressRow> {
  $$AddressesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SnapshotsTable _snapshotIdTable(_$AppDatabase db) =>
      db.snapshots.createAlias('addresses__snapshot_id__snapshots__id');

  $$SnapshotsTableProcessedTableManager get snapshotId {
    final $_column = $_itemColumn<int>('snapshot_id')!;

    final manager = $$SnapshotsTableTableManager(
      $_db,
      $_db.snapshots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snapshotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AddressesTableFilterComposer
    extends Composer<_$AppDatabase, $AddressesTable> {
  $$AddressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceObjectId => $composableBuilder(
    column: $table.sourceObjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullAddress => $composableBuilder(
    column: $table.fullAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get houseNumber => $composableBuilder(
    column: $table.houseNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streetName => $composableBuilder(
    column: $table.streetName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streetType => $composableBuilder(
    column: $table.streetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apn => $composableBuilder(
    column: $table.apn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressType => $composableBuilder(
    column: $table.addressType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numberOfUnits => $composableBuilder(
    column: $table.numberOfUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SnapshotsTableFilterComposer get snapshotId {
    final $$SnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableOrderingComposer
    extends Composer<_$AppDatabase, $AddressesTable> {
  $$AddressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceObjectId => $composableBuilder(
    column: $table.sourceObjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullAddress => $composableBuilder(
    column: $table.fullAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get houseNumber => $composableBuilder(
    column: $table.houseNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streetName => $composableBuilder(
    column: $table.streetName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streetType => $composableBuilder(
    column: $table.streetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apn => $composableBuilder(
    column: $table.apn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressType => $composableBuilder(
    column: $table.addressType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numberOfUnits => $composableBuilder(
    column: $table.numberOfUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnapshotsTableOrderingComposer get snapshotId {
    final $$SnapshotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableOrderingComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AddressesTable> {
  $$AddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get sourceObjectId => $composableBuilder(
    column: $table.sourceObjectId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fullAddress => $composableBuilder(
    column: $table.fullAddress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get houseNumber => $composableBuilder(
    column: $table.houseNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streetName => $composableBuilder(
    column: $table.streetName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streetType => $composableBuilder(
    column: $table.streetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get zipCode =>
      $composableBuilder(column: $table.zipCode, builder: (column) => column);

  GeneratedColumn<String> get apn =>
      $composableBuilder(column: $table.apn, builder: (column) => column);

  GeneratedColumn<String> get addressType => $composableBuilder(
    column: $table.addressType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numberOfUnits => $composableBuilder(
    column: $table.numberOfUnits,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get sourceUpdatedAt => $composableBuilder(
    column: $table.sourceUpdatedAt,
    builder: (column) => column,
  );

  $$SnapshotsTableAnnotationComposer get snapshotId {
    final $$SnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AddressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AddressesTable,
          AddressRow,
          $$AddressesTableFilterComposer,
          $$AddressesTableOrderingComposer,
          $$AddressesTableAnnotationComposer,
          $$AddressesTableCreateCompanionBuilder,
          $$AddressesTableUpdateCompanionBuilder,
          (AddressRow, $$AddressesTableReferences),
          AddressRow,
          PrefetchHooks Function({bool snapshotId})
        > {
  $$AddressesTableTableManager(_$AppDatabase db, $AddressesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AddressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snapshotId = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<int> sourceObjectId = const Value.absent(),
                Value<String> fullAddress = const Value.absent(),
                Value<int?> houseNumber = const Value.absent(),
                Value<String> streetName = const Value.absent(),
                Value<String> streetType = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> zipCode = const Value.absent(),
                Value<String> apn = const Value.absent(),
                Value<String> addressType = const Value.absent(),
                Value<int> numberOfUnits = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<DateTime?> sourceUpdatedAt = const Value.absent(),
              }) => AddressesCompanion(
                id: id,
                snapshotId: snapshotId,
                sourceId: sourceId,
                sourceObjectId: sourceObjectId,
                fullAddress: fullAddress,
                houseNumber: houseNumber,
                streetName: streetName,
                streetType: streetType,
                unit: unit,
                city: city,
                zipCode: zipCode,
                apn: apn,
                addressType: addressType,
                numberOfUnits: numberOfUnits,
                latitude: latitude,
                longitude: longitude,
                sourceUpdatedAt: sourceUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int snapshotId,
                required int sourceId,
                Value<int> sourceObjectId = const Value.absent(),
                required String fullAddress,
                Value<int?> houseNumber = const Value.absent(),
                required String streetName,
                required String streetType,
                required String unit,
                required String city,
                required String zipCode,
                required String apn,
                required String addressType,
                required int numberOfUnits,
                required double latitude,
                required double longitude,
                Value<DateTime?> sourceUpdatedAt = const Value.absent(),
              }) => AddressesCompanion.insert(
                id: id,
                snapshotId: snapshotId,
                sourceId: sourceId,
                sourceObjectId: sourceObjectId,
                fullAddress: fullAddress,
                houseNumber: houseNumber,
                streetName: streetName,
                streetType: streetType,
                unit: unit,
                city: city,
                zipCode: zipCode,
                apn: apn,
                addressType: addressType,
                numberOfUnits: numberOfUnits,
                latitude: latitude,
                longitude: longitude,
                sourceUpdatedAt: sourceUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AddressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotId = false}) {
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
                    if (snapshotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snapshotId,
                                referencedTable: $$AddressesTableReferences
                                    ._snapshotIdTable(db),
                                referencedColumn: $$AddressesTableReferences
                                    ._snapshotIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$AddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AddressesTable,
      AddressRow,
      $$AddressesTableFilterComposer,
      $$AddressesTableOrderingComposer,
      $$AddressesTableAnnotationComposer,
      $$AddressesTableCreateCompanionBuilder,
      $$AddressesTableUpdateCompanionBuilder,
      (AddressRow, $$AddressesTableReferences),
      AddressRow,
      PrefetchHooks Function({bool snapshotId})
    >;
typedef $$ParcelsTableCreateCompanionBuilder =
    ParcelsCompanion Function({
      Value<int> id,
      required int snapshotId,
      required int sourceId,
      required String apn,
      required String situsAddress,
      required String city,
      required String zipCode,
      required String landUse,
      Value<double?> acreage,
      required String geometryJson,
      required double minLongitude,
      required double maxLongitude,
      required double minLatitude,
      required double maxLatitude,
    });
typedef $$ParcelsTableUpdateCompanionBuilder =
    ParcelsCompanion Function({
      Value<int> id,
      Value<int> snapshotId,
      Value<int> sourceId,
      Value<String> apn,
      Value<String> situsAddress,
      Value<String> city,
      Value<String> zipCode,
      Value<String> landUse,
      Value<double?> acreage,
      Value<String> geometryJson,
      Value<double> minLongitude,
      Value<double> maxLongitude,
      Value<double> minLatitude,
      Value<double> maxLatitude,
    });

final class $$ParcelsTableReferences
    extends BaseReferences<_$AppDatabase, $ParcelsTable, ParcelRow> {
  $$ParcelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SnapshotsTable _snapshotIdTable(_$AppDatabase db) =>
      db.snapshots.createAlias('parcels__snapshot_id__snapshots__id');

  $$SnapshotsTableProcessedTableManager get snapshotId {
    final $_column = $_itemColumn<int>('snapshot_id')!;

    final manager = $$SnapshotsTableTableManager(
      $_db,
      $_db.snapshots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snapshotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ParcelsTableFilterComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apn => $composableBuilder(
    column: $table.apn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get situsAddress => $composableBuilder(
    column: $table.situsAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get landUse => $composableBuilder(
    column: $table.landUse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get acreage => $composableBuilder(
    column: $table.acreage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minLongitude => $composableBuilder(
    column: $table.minLongitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxLongitude => $composableBuilder(
    column: $table.maxLongitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minLatitude => $composableBuilder(
    column: $table.minLatitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxLatitude => $composableBuilder(
    column: $table.maxLatitude,
    builder: (column) => ColumnFilters(column),
  );

  $$SnapshotsTableFilterComposer get snapshotId {
    final $$SnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParcelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apn => $composableBuilder(
    column: $table.apn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get situsAddress => $composableBuilder(
    column: $table.situsAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get landUse => $composableBuilder(
    column: $table.landUse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get acreage => $composableBuilder(
    column: $table.acreage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minLongitude => $composableBuilder(
    column: $table.minLongitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxLongitude => $composableBuilder(
    column: $table.maxLongitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minLatitude => $composableBuilder(
    column: $table.minLatitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxLatitude => $composableBuilder(
    column: $table.maxLatitude,
    builder: (column) => ColumnOrderings(column),
  );

  $$SnapshotsTableOrderingComposer get snapshotId {
    final $$SnapshotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableOrderingComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParcelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get apn =>
      $composableBuilder(column: $table.apn, builder: (column) => column);

  GeneratedColumn<String> get situsAddress => $composableBuilder(
    column: $table.situsAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get zipCode =>
      $composableBuilder(column: $table.zipCode, builder: (column) => column);

  GeneratedColumn<String> get landUse =>
      $composableBuilder(column: $table.landUse, builder: (column) => column);

  GeneratedColumn<double> get acreage =>
      $composableBuilder(column: $table.acreage, builder: (column) => column);

  GeneratedColumn<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minLongitude => $composableBuilder(
    column: $table.minLongitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxLongitude => $composableBuilder(
    column: $table.maxLongitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minLatitude => $composableBuilder(
    column: $table.minLatitude,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxLatitude => $composableBuilder(
    column: $table.maxLatitude,
    builder: (column) => column,
  );

  $$SnapshotsTableAnnotationComposer get snapshotId {
    final $$SnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotId,
      referencedTable: $db.snapshots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.snapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParcelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParcelsTable,
          ParcelRow,
          $$ParcelsTableFilterComposer,
          $$ParcelsTableOrderingComposer,
          $$ParcelsTableAnnotationComposer,
          $$ParcelsTableCreateCompanionBuilder,
          $$ParcelsTableUpdateCompanionBuilder,
          (ParcelRow, $$ParcelsTableReferences),
          ParcelRow,
          PrefetchHooks Function({bool snapshotId})
        > {
  $$ParcelsTableTableManager(_$AppDatabase db, $ParcelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParcelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParcelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParcelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> snapshotId = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<String> apn = const Value.absent(),
                Value<String> situsAddress = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> zipCode = const Value.absent(),
                Value<String> landUse = const Value.absent(),
                Value<double?> acreage = const Value.absent(),
                Value<String> geometryJson = const Value.absent(),
                Value<double> minLongitude = const Value.absent(),
                Value<double> maxLongitude = const Value.absent(),
                Value<double> minLatitude = const Value.absent(),
                Value<double> maxLatitude = const Value.absent(),
              }) => ParcelsCompanion(
                id: id,
                snapshotId: snapshotId,
                sourceId: sourceId,
                apn: apn,
                situsAddress: situsAddress,
                city: city,
                zipCode: zipCode,
                landUse: landUse,
                acreage: acreage,
                geometryJson: geometryJson,
                minLongitude: minLongitude,
                maxLongitude: maxLongitude,
                minLatitude: minLatitude,
                maxLatitude: maxLatitude,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int snapshotId,
                required int sourceId,
                required String apn,
                required String situsAddress,
                required String city,
                required String zipCode,
                required String landUse,
                Value<double?> acreage = const Value.absent(),
                required String geometryJson,
                required double minLongitude,
                required double maxLongitude,
                required double minLatitude,
                required double maxLatitude,
              }) => ParcelsCompanion.insert(
                id: id,
                snapshotId: snapshotId,
                sourceId: sourceId,
                apn: apn,
                situsAddress: situsAddress,
                city: city,
                zipCode: zipCode,
                landUse: landUse,
                acreage: acreage,
                geometryJson: geometryJson,
                minLongitude: minLongitude,
                maxLongitude: maxLongitude,
                minLatitude: minLatitude,
                maxLatitude: maxLatitude,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ParcelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({snapshotId = false}) {
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
                    if (snapshotId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.snapshotId,
                                referencedTable: $$ParcelsTableReferences
                                    ._snapshotIdTable(db),
                                referencedColumn: $$ParcelsTableReferences
                                    ._snapshotIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$ParcelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParcelsTable,
      ParcelRow,
      $$ParcelsTableFilterComposer,
      $$ParcelsTableOrderingComposer,
      $$ParcelsTableAnnotationComposer,
      $$ParcelsTableCreateCompanionBuilder,
      $$ParcelsTableUpdateCompanionBuilder,
      (ParcelRow, $$ParcelsTableReferences),
      ParcelRow,
      PrefetchHooks Function({bool snapshotId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$PropertyOwnerCacheTableCreateCompanionBuilder =
    PropertyOwnerCacheCompanion Function({
      required String propertyKey,
      Value<String?> ownerName,
      required String parcelId,
      required String matchedAddress,
      required String sourceUrl,
      required String status,
      required DateTime checkedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$PropertyOwnerCacheTableUpdateCompanionBuilder =
    PropertyOwnerCacheCompanion Function({
      Value<String> propertyKey,
      Value<String?> ownerName,
      Value<String> parcelId,
      Value<String> matchedAddress,
      Value<String> sourceUrl,
      Value<String> status,
      Value<DateTime> checkedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$PropertyOwnerCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PropertyOwnerCacheTable> {
  $$PropertyOwnerCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get propertyKey => $composableBuilder(
    column: $table.propertyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parcelId => $composableBuilder(
    column: $table.parcelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchedAddress => $composableBuilder(
    column: $table.matchedAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PropertyOwnerCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PropertyOwnerCacheTable> {
  $$PropertyOwnerCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get propertyKey => $composableBuilder(
    column: $table.propertyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parcelId => $composableBuilder(
    column: $table.parcelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchedAddress => $composableBuilder(
    column: $table.matchedAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PropertyOwnerCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PropertyOwnerCacheTable> {
  $$PropertyOwnerCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get propertyKey => $composableBuilder(
    column: $table.propertyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get parcelId =>
      $composableBuilder(column: $table.parcelId, builder: (column) => column);

  GeneratedColumn<String> get matchedAddress => $composableBuilder(
    column: $table.matchedAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$PropertyOwnerCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PropertyOwnerCacheTable,
          PropertyOwnerCacheRow,
          $$PropertyOwnerCacheTableFilterComposer,
          $$PropertyOwnerCacheTableOrderingComposer,
          $$PropertyOwnerCacheTableAnnotationComposer,
          $$PropertyOwnerCacheTableCreateCompanionBuilder,
          $$PropertyOwnerCacheTableUpdateCompanionBuilder,
          (
            PropertyOwnerCacheRow,
            BaseReferences<
              _$AppDatabase,
              $PropertyOwnerCacheTable,
              PropertyOwnerCacheRow
            >,
          ),
          PropertyOwnerCacheRow,
          PrefetchHooks Function()
        > {
  $$PropertyOwnerCacheTableTableManager(
    _$AppDatabase db,
    $PropertyOwnerCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PropertyOwnerCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PropertyOwnerCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PropertyOwnerCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> propertyKey = const Value.absent(),
                Value<String?> ownerName = const Value.absent(),
                Value<String> parcelId = const Value.absent(),
                Value<String> matchedAddress = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PropertyOwnerCacheCompanion(
                propertyKey: propertyKey,
                ownerName: ownerName,
                parcelId: parcelId,
                matchedAddress: matchedAddress,
                sourceUrl: sourceUrl,
                status: status,
                checkedAt: checkedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String propertyKey,
                Value<String?> ownerName = const Value.absent(),
                required String parcelId,
                required String matchedAddress,
                required String sourceUrl,
                required String status,
                required DateTime checkedAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => PropertyOwnerCacheCompanion.insert(
                propertyKey: propertyKey,
                ownerName: ownerName,
                parcelId: parcelId,
                matchedAddress: matchedAddress,
                sourceUrl: sourceUrl,
                status: status,
                checkedAt: checkedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PropertyOwnerCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PropertyOwnerCacheTable,
      PropertyOwnerCacheRow,
      $$PropertyOwnerCacheTableFilterComposer,
      $$PropertyOwnerCacheTableOrderingComposer,
      $$PropertyOwnerCacheTableAnnotationComposer,
      $$PropertyOwnerCacheTableCreateCompanionBuilder,
      $$PropertyOwnerCacheTableUpdateCompanionBuilder,
      (
        PropertyOwnerCacheRow,
        BaseReferences<
          _$AppDatabase,
          $PropertyOwnerCacheTable,
          PropertyOwnerCacheRow
        >,
      ),
      PropertyOwnerCacheRow,
      PrefetchHooks Function()
    >;
typedef $$UnclaimedPropertyCacheTableCreateCompanionBuilder =
    UnclaimedPropertyCacheCompanion Function({
      required String searchKey,
      required String ownerName,
      required String firstName,
      required String lastName,
      required String city,
      required String zipCode,
      required bool found,
      required int resultCount,
      required String sourceUrl,
      required DateTime checkedAt,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$UnclaimedPropertyCacheTableUpdateCompanionBuilder =
    UnclaimedPropertyCacheCompanion Function({
      Value<String> searchKey,
      Value<String> ownerName,
      Value<String> firstName,
      Value<String> lastName,
      Value<String> city,
      Value<String> zipCode,
      Value<bool> found,
      Value<int> resultCount,
      Value<String> sourceUrl,
      Value<DateTime> checkedAt,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$UnclaimedPropertyCacheTableFilterComposer
    extends Composer<_$AppDatabase, $UnclaimedPropertyCacheTable> {
  $$UnclaimedPropertyCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get found => $composableBuilder(
    column: $table.found,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultCount => $composableBuilder(
    column: $table.resultCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UnclaimedPropertyCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $UnclaimedPropertyCacheTable> {
  $$UnclaimedPropertyCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get searchKey => $composableBuilder(
    column: $table.searchKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zipCode => $composableBuilder(
    column: $table.zipCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get found => $composableBuilder(
    column: $table.found,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultCount => $composableBuilder(
    column: $table.resultCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnclaimedPropertyCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnclaimedPropertyCacheTable> {
  $$UnclaimedPropertyCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get searchKey =>
      $composableBuilder(column: $table.searchKey, builder: (column) => column);

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get zipCode =>
      $composableBuilder(column: $table.zipCode, builder: (column) => column);

  GeneratedColumn<bool> get found =>
      $composableBuilder(column: $table.found, builder: (column) => column);

  GeneratedColumn<int> get resultCount => $composableBuilder(
    column: $table.resultCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$UnclaimedPropertyCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnclaimedPropertyCacheTable,
          UnclaimedPropertyCacheRow,
          $$UnclaimedPropertyCacheTableFilterComposer,
          $$UnclaimedPropertyCacheTableOrderingComposer,
          $$UnclaimedPropertyCacheTableAnnotationComposer,
          $$UnclaimedPropertyCacheTableCreateCompanionBuilder,
          $$UnclaimedPropertyCacheTableUpdateCompanionBuilder,
          (
            UnclaimedPropertyCacheRow,
            BaseReferences<
              _$AppDatabase,
              $UnclaimedPropertyCacheTable,
              UnclaimedPropertyCacheRow
            >,
          ),
          UnclaimedPropertyCacheRow,
          PrefetchHooks Function()
        > {
  $$UnclaimedPropertyCacheTableTableManager(
    _$AppDatabase db,
    $UnclaimedPropertyCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnclaimedPropertyCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$UnclaimedPropertyCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UnclaimedPropertyCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> searchKey = const Value.absent(),
                Value<String> ownerName = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> zipCode = const Value.absent(),
                Value<bool> found = const Value.absent(),
                Value<int> resultCount = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnclaimedPropertyCacheCompanion(
                searchKey: searchKey,
                ownerName: ownerName,
                firstName: firstName,
                lastName: lastName,
                city: city,
                zipCode: zipCode,
                found: found,
                resultCount: resultCount,
                sourceUrl: sourceUrl,
                checkedAt: checkedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String searchKey,
                required String ownerName,
                required String firstName,
                required String lastName,
                required String city,
                required String zipCode,
                required bool found,
                required int resultCount,
                required String sourceUrl,
                required DateTime checkedAt,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => UnclaimedPropertyCacheCompanion.insert(
                searchKey: searchKey,
                ownerName: ownerName,
                firstName: firstName,
                lastName: lastName,
                city: city,
                zipCode: zipCode,
                found: found,
                resultCount: resultCount,
                sourceUrl: sourceUrl,
                checkedAt: checkedAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UnclaimedPropertyCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnclaimedPropertyCacheTable,
      UnclaimedPropertyCacheRow,
      $$UnclaimedPropertyCacheTableFilterComposer,
      $$UnclaimedPropertyCacheTableOrderingComposer,
      $$UnclaimedPropertyCacheTableAnnotationComposer,
      $$UnclaimedPropertyCacheTableCreateCompanionBuilder,
      $$UnclaimedPropertyCacheTableUpdateCompanionBuilder,
      (
        UnclaimedPropertyCacheRow,
        BaseReferences<
          _$AppDatabase,
          $UnclaimedPropertyCacheTable,
          UnclaimedPropertyCacheRow
        >,
      ),
      UnclaimedPropertyCacheRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SnapshotsTableTableManager get snapshots =>
      $$SnapshotsTableTableManager(_db, _db.snapshots);
  $$AddressesTableTableManager get addresses =>
      $$AddressesTableTableManager(_db, _db.addresses);
  $$ParcelsTableTableManager get parcels =>
      $$ParcelsTableTableManager(_db, _db.parcels);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PropertyOwnerCacheTableTableManager get propertyOwnerCache =>
      $$PropertyOwnerCacheTableTableManager(_db, _db.propertyOwnerCache);
  $$UnclaimedPropertyCacheTableTableManager get unclaimedPropertyCache =>
      $$UnclaimedPropertyCacheTableTableManager(
        _db,
        _db.unclaimedPropertyCache,
      );
}
