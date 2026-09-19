// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guardian_database.dart';

// ignore_for_file: type=lint
class $LocalContactsTable extends LocalContacts
    with TableInfo<$LocalContactsTable, LocalContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _contactUidMeta =
      const VerificationMeta('contactUid');
  @override
  late final GeneratedColumn<String> contactUid = GeneratedColumn<String>(
      'contact_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _relationshipMeta =
      const VerificationMeta('relationship');
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
      'relationship', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _isPrimaryMeta =
      const VerificationMeta('isPrimary');
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
      'is_primary', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_primary" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _pendingSyncMeta =
      const VerificationMeta('pendingSync');
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
      'pending_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pending_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        contactUid,
        name,
        phone,
        relationship,
        isPrimary,
        createdAt,
        syncedAt,
        pendingSync
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalContact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('contact_uid')) {
      context.handle(
          _contactUidMeta,
          contactUid.isAcceptableOrUnknown(
              data['contact_uid']!, _contactUidMeta));
    } else if (isInserting) {
      context.missing(_contactUidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('relationship')) {
      context.handle(
          _relationshipMeta,
          relationship.isAcceptableOrUnknown(
              data['relationship']!, _relationshipMeta));
    }
    if (data.containsKey('is_primary')) {
      context.handle(_isPrimaryMeta,
          isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
          _pendingSyncMeta,
          pendingSync.isAcceptableOrUnknown(
              data['pending_sync']!, _pendingSyncMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      contactUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_uid'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      relationship: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}relationship'])!,
      isPrimary: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_primary'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      pendingSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pending_sync'])!,
    );
  }

  @override
  $LocalContactsTable createAlias(String alias) {
    return $LocalContactsTable(attachedDatabase, alias);
  }
}

class LocalContact extends DataClass implements Insertable<LocalContact> {
  final int id;
  final String contactUid;
  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final bool pendingSync;
  const LocalContact(
      {required this.id,
      required this.contactUid,
      required this.name,
      required this.phone,
      required this.relationship,
      required this.isPrimary,
      required this.createdAt,
      this.syncedAt,
      required this.pendingSync});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['contact_uid'] = Variable<String>(contactUid);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['relationship'] = Variable<String>(relationship);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['pending_sync'] = Variable<bool>(pendingSync);
    return map;
  }

  LocalContactsCompanion toCompanion(bool nullToAbsent) {
    return LocalContactsCompanion(
      id: Value(id),
      contactUid: Value(contactUid),
      name: Value(name),
      phone: Value(phone),
      relationship: Value(relationship),
      isPrimary: Value(isPrimary),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      pendingSync: Value(pendingSync),
    );
  }

  factory LocalContact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContact(
      id: serializer.fromJson<int>(json['id']),
      contactUid: serializer.fromJson<String>(json['contactUid']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      relationship: serializer.fromJson<String>(json['relationship']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contactUid': serializer.toJson<String>(contactUid),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'relationship': serializer.toJson<String>(relationship),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'pendingSync': serializer.toJson<bool>(pendingSync),
    };
  }

  LocalContact copyWith(
          {int? id,
          String? contactUid,
          String? name,
          String? phone,
          String? relationship,
          bool? isPrimary,
          DateTime? createdAt,
          Value<DateTime?> syncedAt = const Value.absent(),
          bool? pendingSync}) =>
      LocalContact(
        id: id ?? this.id,
        contactUid: contactUid ?? this.contactUid,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relationship: relationship ?? this.relationship,
        isPrimary: isPrimary ?? this.isPrimary,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        pendingSync: pendingSync ?? this.pendingSync,
      );
  LocalContact copyWithCompanion(LocalContactsCompanion data) {
    return LocalContact(
      id: data.id.present ? data.id.value : this.id,
      contactUid:
          data.contactUid.present ? data.contactUid.value : this.contactUid,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      pendingSync:
          data.pendingSync.present ? data.pendingSync.value : this.pendingSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContact(')
          ..write('id: $id, ')
          ..write('contactUid: $contactUid, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relationship: $relationship, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('pendingSync: $pendingSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, contactUid, name, phone, relationship,
      isPrimary, createdAt, syncedAt, pendingSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContact &&
          other.id == this.id &&
          other.contactUid == this.contactUid &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.relationship == this.relationship &&
          other.isPrimary == this.isPrimary &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt &&
          other.pendingSync == this.pendingSync);
}

class LocalContactsCompanion extends UpdateCompanion<LocalContact> {
  final Value<int> id;
  final Value<String> contactUid;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> relationship;
  final Value<bool> isPrimary;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<bool> pendingSync;
  const LocalContactsCompanion({
    this.id = const Value.absent(),
    this.contactUid = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.relationship = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.pendingSync = const Value.absent(),
  });
  LocalContactsCompanion.insert({
    this.id = const Value.absent(),
    required String contactUid,
    required String name,
    required String phone,
    this.relationship = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.pendingSync = const Value.absent(),
  })  : contactUid = Value(contactUid),
        name = Value(name),
        phone = Value(phone);
  static Insertable<LocalContact> custom({
    Expression<int>? id,
    Expression<String>? contactUid,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? relationship,
    Expression<bool>? isPrimary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<bool>? pendingSync,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contactUid != null) 'contact_uid': contactUid,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (relationship != null) 'relationship': relationship,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (pendingSync != null) 'pending_sync': pendingSync,
    });
  }

  LocalContactsCompanion copyWith(
      {Value<int>? id,
      Value<String>? contactUid,
      Value<String>? name,
      Value<String>? phone,
      Value<String>? relationship,
      Value<bool>? isPrimary,
      Value<DateTime>? createdAt,
      Value<DateTime?>? syncedAt,
      Value<bool>? pendingSync}) {
    return LocalContactsCompanion(
      id: id ?? this.id,
      contactUid: contactUid ?? this.contactUid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contactUid.present) {
      map['contact_uid'] = Variable<String>(contactUid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactsCompanion(')
          ..write('id: $id, ')
          ..write('contactUid: $contactUid, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relationship: $relationship, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('pendingSync: $pendingSync')
          ..write(')'))
        .toString();
  }
}

class $LocalAlertsTable extends LocalAlerts
    with TableInfo<$LocalAlertsTable, LocalAlert> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _alertIdMeta =
      const VerificationMeta('alertId');
  @override
  late final GeneratedColumn<String> alertId = GeneratedColumn<String>(
      'alert_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _accuracyMeta =
      const VerificationMeta('accuracy');
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
      'accuracy', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _customMessageMeta =
      const VerificationMeta('customMessage');
  @override
  late final GeneratedColumn<String> customMessage = GeneratedColumn<String>(
      'custom_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _resolvedAtMeta =
      const VerificationMeta('resolvedAt');
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
      'resolved_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _smsSentMeta =
      const VerificationMeta('smsSent');
  @override
  late final GeneratedColumn<bool> smsSent = GeneratedColumn<bool>(
      'sms_sent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("sms_sent" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _smsCountMeta =
      const VerificationMeta('smsCount');
  @override
  late final GeneratedColumn<int> smsCount = GeneratedColumn<int>(
      'sms_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncedToCloudMeta =
      const VerificationMeta('syncedToCloud');
  @override
  late final GeneratedColumn<bool> syncedToCloud = GeneratedColumn<bool>(
      'synced_to_cloud', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("synced_to_cloud" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        alertId,
        userId,
        source,
        status,
        latitude,
        longitude,
        accuracy,
        customMessage,
        startedAt,
        resolvedAt,
        smsSent,
        smsCount,
        syncedToCloud,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_alerts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAlert> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alert_id')) {
      context.handle(_alertIdMeta,
          alertId.isAcceptableOrUnknown(data['alert_id']!, _alertIdMeta));
    } else if (isInserting) {
      context.missing(_alertIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('accuracy')) {
      context.handle(_accuracyMeta,
          accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta));
    }
    if (data.containsKey('custom_message')) {
      context.handle(
          _customMessageMeta,
          customMessage.isAcceptableOrUnknown(
              data['custom_message']!, _customMessageMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
          _resolvedAtMeta,
          resolvedAt.isAcceptableOrUnknown(
              data['resolved_at']!, _resolvedAtMeta));
    }
    if (data.containsKey('sms_sent')) {
      context.handle(_smsSentMeta,
          smsSent.isAcceptableOrUnknown(data['sms_sent']!, _smsSentMeta));
    }
    if (data.containsKey('sms_count')) {
      context.handle(_smsCountMeta,
          smsCount.isAcceptableOrUnknown(data['sms_count']!, _smsCountMeta));
    }
    if (data.containsKey('synced_to_cloud')) {
      context.handle(
          _syncedToCloudMeta,
          syncedToCloud.isAcceptableOrUnknown(
              data['synced_to_cloud']!, _syncedToCloudMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {alertId};
  @override
  LocalAlert map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAlert(
      alertId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alert_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      accuracy: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy']),
      customMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_message']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      resolvedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}resolved_at']),
      smsSent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}sms_sent'])!,
      smsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sms_count'])!,
      syncedToCloud: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced_to_cloud'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalAlertsTable createAlias(String alias) {
    return $LocalAlertsTable(attachedDatabase, alias);
  }
}

class LocalAlert extends DataClass implements Insertable<LocalAlert> {
  final String alertId;
  final String userId;
  final String source;
  final String status;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? customMessage;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final bool smsSent;
  final int smsCount;
  final bool syncedToCloud;
  final DateTime createdAt;
  const LocalAlert(
      {required this.alertId,
      required this.userId,
      required this.source,
      required this.status,
      this.latitude,
      this.longitude,
      this.accuracy,
      this.customMessage,
      required this.startedAt,
      this.resolvedAt,
      required this.smsSent,
      required this.smsCount,
      required this.syncedToCloud,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alert_id'] = Variable<String>(alertId);
    map['user_id'] = Variable<String>(userId);
    map['source'] = Variable<String>(source);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    if (!nullToAbsent || customMessage != null) {
      map['custom_message'] = Variable<String>(customMessage);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    map['sms_sent'] = Variable<bool>(smsSent);
    map['sms_count'] = Variable<int>(smsCount);
    map['synced_to_cloud'] = Variable<bool>(syncedToCloud);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAlertsCompanion toCompanion(bool nullToAbsent) {
    return LocalAlertsCompanion(
      alertId: Value(alertId),
      userId: Value(userId),
      source: Value(source),
      status: Value(status),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      accuracy: accuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracy),
      customMessage: customMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(customMessage),
      startedAt: Value(startedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      smsSent: Value(smsSent),
      smsCount: Value(smsCount),
      syncedToCloud: Value(syncedToCloud),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAlert.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAlert(
      alertId: serializer.fromJson<String>(json['alertId']),
      userId: serializer.fromJson<String>(json['userId']),
      source: serializer.fromJson<String>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      customMessage: serializer.fromJson<String?>(json['customMessage']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      smsSent: serializer.fromJson<bool>(json['smsSent']),
      smsCount: serializer.fromJson<int>(json['smsCount']),
      syncedToCloud: serializer.fromJson<bool>(json['syncedToCloud']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alertId': serializer.toJson<String>(alertId),
      'userId': serializer.toJson<String>(userId),
      'source': serializer.toJson<String>(source),
      'status': serializer.toJson<String>(status),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'accuracy': serializer.toJson<double?>(accuracy),
      'customMessage': serializer.toJson<String?>(customMessage),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'smsSent': serializer.toJson<bool>(smsSent),
      'smsCount': serializer.toJson<int>(smsCount),
      'syncedToCloud': serializer.toJson<bool>(syncedToCloud),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAlert copyWith(
          {String? alertId,
          String? userId,
          String? source,
          String? status,
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<double?> accuracy = const Value.absent(),
          Value<String?> customMessage = const Value.absent(),
          DateTime? startedAt,
          Value<DateTime?> resolvedAt = const Value.absent(),
          bool? smsSent,
          int? smsCount,
          bool? syncedToCloud,
          DateTime? createdAt}) =>
      LocalAlert(
        alertId: alertId ?? this.alertId,
        userId: userId ?? this.userId,
        source: source ?? this.source,
        status: status ?? this.status,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        accuracy: accuracy.present ? accuracy.value : this.accuracy,
        customMessage:
            customMessage.present ? customMessage.value : this.customMessage,
        startedAt: startedAt ?? this.startedAt,
        resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
        smsSent: smsSent ?? this.smsSent,
        smsCount: smsCount ?? this.smsCount,
        syncedToCloud: syncedToCloud ?? this.syncedToCloud,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalAlert copyWithCompanion(LocalAlertsCompanion data) {
    return LocalAlert(
      alertId: data.alertId.present ? data.alertId.value : this.alertId,
      userId: data.userId.present ? data.userId.value : this.userId,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      customMessage: data.customMessage.present
          ? data.customMessage.value
          : this.customMessage,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
      smsSent: data.smsSent.present ? data.smsSent.value : this.smsSent,
      smsCount: data.smsCount.present ? data.smsCount.value : this.smsCount,
      syncedToCloud: data.syncedToCloud.present
          ? data.syncedToCloud.value
          : this.syncedToCloud,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlert(')
          ..write('alertId: $alertId, ')
          ..write('userId: $userId, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('customMessage: $customMessage, ')
          ..write('startedAt: $startedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('smsSent: $smsSent, ')
          ..write('smsCount: $smsCount, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      alertId,
      userId,
      source,
      status,
      latitude,
      longitude,
      accuracy,
      customMessage,
      startedAt,
      resolvedAt,
      smsSent,
      smsCount,
      syncedToCloud,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAlert &&
          other.alertId == this.alertId &&
          other.userId == this.userId &&
          other.source == this.source &&
          other.status == this.status &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.customMessage == this.customMessage &&
          other.startedAt == this.startedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.smsSent == this.smsSent &&
          other.smsCount == this.smsCount &&
          other.syncedToCloud == this.syncedToCloud &&
          other.createdAt == this.createdAt);
}

class LocalAlertsCompanion extends UpdateCompanion<LocalAlert> {
  final Value<String> alertId;
  final Value<String> userId;
  final Value<String> source;
  final Value<String> status;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> accuracy;
  final Value<String?> customMessage;
  final Value<DateTime> startedAt;
  final Value<DateTime?> resolvedAt;
  final Value<bool> smsSent;
  final Value<int> smsCount;
  final Value<bool> syncedToCloud;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalAlertsCompanion({
    this.alertId = const Value.absent(),
    this.userId = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.customMessage = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.smsSent = const Value.absent(),
    this.smsCount = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAlertsCompanion.insert({
    required String alertId,
    required String userId,
    required String source,
    required String status,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.customMessage = const Value.absent(),
    required DateTime startedAt,
    this.resolvedAt = const Value.absent(),
    this.smsSent = const Value.absent(),
    this.smsCount = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : alertId = Value(alertId),
        userId = Value(userId),
        source = Value(source),
        status = Value(status),
        startedAt = Value(startedAt);
  static Insertable<LocalAlert> custom({
    Expression<String>? alertId,
    Expression<String>? userId,
    Expression<String>? source,
    Expression<String>? status,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<String>? customMessage,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? resolvedAt,
    Expression<bool>? smsSent,
    Expression<int>? smsCount,
    Expression<bool>? syncedToCloud,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (alertId != null) 'alert_id': alertId,
      if (userId != null) 'user_id': userId,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (customMessage != null) 'custom_message': customMessage,
      if (startedAt != null) 'started_at': startedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (smsSent != null) 'sms_sent': smsSent,
      if (smsCount != null) 'sms_count': smsCount,
      if (syncedToCloud != null) 'synced_to_cloud': syncedToCloud,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAlertsCompanion copyWith(
      {Value<String>? alertId,
      Value<String>? userId,
      Value<String>? source,
      Value<String>? status,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<double?>? accuracy,
      Value<String?>? customMessage,
      Value<DateTime>? startedAt,
      Value<DateTime?>? resolvedAt,
      Value<bool>? smsSent,
      Value<int>? smsCount,
      Value<bool>? syncedToCloud,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalAlertsCompanion(
      alertId: alertId ?? this.alertId,
      userId: userId ?? this.userId,
      source: source ?? this.source,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      customMessage: customMessage ?? this.customMessage,
      startedAt: startedAt ?? this.startedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      smsSent: smsSent ?? this.smsSent,
      smsCount: smsCount ?? this.smsCount,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alertId.present) {
      map['alert_id'] = Variable<String>(alertId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (customMessage.present) {
      map['custom_message'] = Variable<String>(customMessage.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (smsSent.present) {
      map['sms_sent'] = Variable<bool>(smsSent.value);
    }
    if (smsCount.present) {
      map['sms_count'] = Variable<int>(smsCount.value);
    }
    if (syncedToCloud.present) {
      map['synced_to_cloud'] = Variable<bool>(syncedToCloud.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAlertsCompanion(')
          ..write('alertId: $alertId, ')
          ..write('userId: $userId, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('customMessage: $customMessage, ')
          ..write('startedAt: $startedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('smsSent: $smsSent, ')
          ..write('smsCount: $smsCount, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSafeZonesTable extends LocalSafeZones
    with TableInfo<$LocalSafeZonesTable, LocalSafeZone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSafeZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _radiusMetersMeta =
      const VerificationMeta('radiusMeters');
  @override
  late final GeneratedColumn<double> radiusMeters = GeneratedColumn<double>(
      'radius_meters', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(200.0));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('safe'));
  static const VerificationMeta _alertOnExitMeta =
      const VerificationMeta('alertOnExit');
  @override
  late final GeneratedColumn<bool> alertOnExit = GeneratedColumn<bool>(
      'alert_on_exit', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("alert_on_exit" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        latitude,
        longitude,
        radiusMeters,
        type,
        alertOnExit,
        isActive,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_safe_zones';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSafeZone> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
          _radiusMetersMeta,
          radiusMeters.isAcceptableOrUnknown(
              data['radius_meters']!, _radiusMetersMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('alert_on_exit')) {
      context.handle(
          _alertOnExitMeta,
          alertOnExit.isAcceptableOrUnknown(
              data['alert_on_exit']!, _alertOnExitMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSafeZone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSafeZone(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      radiusMeters: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}radius_meters'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      alertOnExit: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}alert_on_exit'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalSafeZonesTable createAlias(String alias) {
    return $LocalSafeZonesTable(attachedDatabase, alias);
  }
}

class LocalSafeZone extends DataClass implements Insertable<LocalSafeZone> {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String type;
  final bool alertOnExit;
  final bool isActive;
  final DateTime createdAt;
  const LocalSafeZone(
      {required this.id,
      required this.name,
      required this.latitude,
      required this.longitude,
      required this.radiusMeters,
      required this.type,
      required this.alertOnExit,
      required this.isActive,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['radius_meters'] = Variable<double>(radiusMeters);
    map['type'] = Variable<String>(type);
    map['alert_on_exit'] = Variable<bool>(alertOnExit);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalSafeZonesCompanion toCompanion(bool nullToAbsent) {
    return LocalSafeZonesCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      radiusMeters: Value(radiusMeters),
      type: Value(type),
      alertOnExit: Value(alertOnExit),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory LocalSafeZone.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSafeZone(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      radiusMeters: serializer.fromJson<double>(json['radiusMeters']),
      type: serializer.fromJson<String>(json['type']),
      alertOnExit: serializer.fromJson<bool>(json['alertOnExit']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'radiusMeters': serializer.toJson<double>(radiusMeters),
      'type': serializer.toJson<String>(type),
      'alertOnExit': serializer.toJson<bool>(alertOnExit),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalSafeZone copyWith(
          {int? id,
          String? name,
          double? latitude,
          double? longitude,
          double? radiusMeters,
          String? type,
          bool? alertOnExit,
          bool? isActive,
          DateTime? createdAt}) =>
      LocalSafeZone(
        id: id ?? this.id,
        name: name ?? this.name,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        type: type ?? this.type,
        alertOnExit: alertOnExit ?? this.alertOnExit,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalSafeZone copyWithCompanion(LocalSafeZonesCompanion data) {
    return LocalSafeZone(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      type: data.type.present ? data.type.value : this.type,
      alertOnExit:
          data.alertOnExit.present ? data.alertOnExit.value : this.alertOnExit,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSafeZone(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('type: $type, ')
          ..write('alertOnExit: $alertOnExit, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, radiusMeters,
      type, alertOnExit, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSafeZone &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radiusMeters == this.radiusMeters &&
          other.type == this.type &&
          other.alertOnExit == this.alertOnExit &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class LocalSafeZonesCompanion extends UpdateCompanion<LocalSafeZone> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> radiusMeters;
  final Value<String> type;
  final Value<bool> alertOnExit;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const LocalSafeZonesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.type = const Value.absent(),
    this.alertOnExit = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalSafeZonesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.radiusMeters = const Value.absent(),
    this.type = const Value.absent(),
    this.alertOnExit = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : name = Value(name),
        latitude = Value(latitude),
        longitude = Value(longitude);
  static Insertable<LocalSafeZone> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? radiusMeters,
    Expression<String>? type,
    Expression<bool>? alertOnExit,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (type != null) 'type': type,
      if (alertOnExit != null) 'alert_on_exit': alertOnExit,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalSafeZonesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double>? radiusMeters,
      Value<String>? type,
      Value<bool>? alertOnExit,
      Value<bool>? isActive,
      Value<DateTime>? createdAt}) {
    return LocalSafeZonesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      type: type ?? this.type,
      alertOnExit: alertOnExit ?? this.alertOnExit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<double>(radiusMeters.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (alertOnExit.present) {
      map['alert_on_exit'] = Variable<bool>(alertOnExit.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSafeZonesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('type: $type, ')
          ..write('alertOnExit: $alertOnExit, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalCheckInsTable extends LocalCheckIns
    with TableInfo<$LocalCheckInsTable, LocalCheckIn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduledAtMeta =
      const VerificationMeta('scheduledAt');
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
      'scheduled_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _confirmedAtMeta =
      const VerificationMeta('confirmedAt');
  @override
  late final GeneratedColumn<DateTime> confirmedAt = GeneratedColumn<DateTime>(
      'confirmed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _escalationMinutesMeta =
      const VerificationMeta('escalationMinutes');
  @override
  late final GeneratedColumn<int> escalationMinutes = GeneratedColumn<int>(
      'escalation_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _escalatedMeta =
      const VerificationMeta('escalated');
  @override
  late final GeneratedColumn<bool> escalated = GeneratedColumn<bool>(
      'escalated', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("escalated" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        scheduledAt,
        confirmedAt,
        status,
        escalationMinutes,
        escalated,
        location
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_check_ins';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCheckIn> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
          _scheduledAtMeta,
          scheduledAt.isAcceptableOrUnknown(
              data['scheduled_at']!, _scheduledAtMeta));
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('confirmed_at')) {
      context.handle(
          _confirmedAtMeta,
          confirmedAt.isAcceptableOrUnknown(
              data['confirmed_at']!, _confirmedAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('escalation_minutes')) {
      context.handle(
          _escalationMinutesMeta,
          escalationMinutes.isAcceptableOrUnknown(
              data['escalation_minutes']!, _escalationMinutesMeta));
    }
    if (data.containsKey('escalated')) {
      context.handle(_escalatedMeta,
          escalated.isAcceptableOrUnknown(data['escalated']!, _escalatedMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCheckIn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCheckIn(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      scheduledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_at'])!,
      confirmedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}confirmed_at']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      escalationMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}escalation_minutes'])!,
      escalated: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}escalated'])!,
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
    );
  }

  @override
  $LocalCheckInsTable createAlias(String alias) {
    return $LocalCheckInsTable(attachedDatabase, alias);
  }
}

class LocalCheckIn extends DataClass implements Insertable<LocalCheckIn> {
  final int id;
  final String title;
  final DateTime scheduledAt;
  final DateTime? confirmedAt;
  final String status;
  final int escalationMinutes;
  final bool escalated;
  final String? location;
  const LocalCheckIn(
      {required this.id,
      required this.title,
      required this.scheduledAt,
      this.confirmedAt,
      required this.status,
      required this.escalationMinutes,
      required this.escalated,
      this.location});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    if (!nullToAbsent || confirmedAt != null) {
      map['confirmed_at'] = Variable<DateTime>(confirmedAt);
    }
    map['status'] = Variable<String>(status);
    map['escalation_minutes'] = Variable<int>(escalationMinutes);
    map['escalated'] = Variable<bool>(escalated);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    return map;
  }

  LocalCheckInsCompanion toCompanion(bool nullToAbsent) {
    return LocalCheckInsCompanion(
      id: Value(id),
      title: Value(title),
      scheduledAt: Value(scheduledAt),
      confirmedAt: confirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAt),
      status: Value(status),
      escalationMinutes: Value(escalationMinutes),
      escalated: Value(escalated),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
    );
  }

  factory LocalCheckIn.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCheckIn(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
      confirmedAt: serializer.fromJson<DateTime?>(json['confirmedAt']),
      status: serializer.fromJson<String>(json['status']),
      escalationMinutes: serializer.fromJson<int>(json['escalationMinutes']),
      escalated: serializer.fromJson<bool>(json['escalated']),
      location: serializer.fromJson<String?>(json['location']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
      'confirmedAt': serializer.toJson<DateTime?>(confirmedAt),
      'status': serializer.toJson<String>(status),
      'escalationMinutes': serializer.toJson<int>(escalationMinutes),
      'escalated': serializer.toJson<bool>(escalated),
      'location': serializer.toJson<String?>(location),
    };
  }

  LocalCheckIn copyWith(
          {int? id,
          String? title,
          DateTime? scheduledAt,
          Value<DateTime?> confirmedAt = const Value.absent(),
          String? status,
          int? escalationMinutes,
          bool? escalated,
          Value<String?> location = const Value.absent()}) =>
      LocalCheckIn(
        id: id ?? this.id,
        title: title ?? this.title,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        confirmedAt: confirmedAt.present ? confirmedAt.value : this.confirmedAt,
        status: status ?? this.status,
        escalationMinutes: escalationMinutes ?? this.escalationMinutes,
        escalated: escalated ?? this.escalated,
        location: location.present ? location.value : this.location,
      );
  LocalCheckIn copyWithCompanion(LocalCheckInsCompanion data) {
    return LocalCheckIn(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      scheduledAt:
          data.scheduledAt.present ? data.scheduledAt.value : this.scheduledAt,
      confirmedAt:
          data.confirmedAt.present ? data.confirmedAt.value : this.confirmedAt,
      status: data.status.present ? data.status.value : this.status,
      escalationMinutes: data.escalationMinutes.present
          ? data.escalationMinutes.value
          : this.escalationMinutes,
      escalated: data.escalated.present ? data.escalated.value : this.escalated,
      location: data.location.present ? data.location.value : this.location,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckIn(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('status: $status, ')
          ..write('escalationMinutes: $escalationMinutes, ')
          ..write('escalated: $escalated, ')
          ..write('location: $location')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, scheduledAt, confirmedAt, status,
      escalationMinutes, escalated, location);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCheckIn &&
          other.id == this.id &&
          other.title == this.title &&
          other.scheduledAt == this.scheduledAt &&
          other.confirmedAt == this.confirmedAt &&
          other.status == this.status &&
          other.escalationMinutes == this.escalationMinutes &&
          other.escalated == this.escalated &&
          other.location == this.location);
}

class LocalCheckInsCompanion extends UpdateCompanion<LocalCheckIn> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> scheduledAt;
  final Value<DateTime?> confirmedAt;
  final Value<String> status;
  final Value<int> escalationMinutes;
  final Value<bool> escalated;
  final Value<String?> location;
  const LocalCheckInsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.escalationMinutes = const Value.absent(),
    this.escalated = const Value.absent(),
    this.location = const Value.absent(),
  });
  LocalCheckInsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime scheduledAt,
    this.confirmedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.escalationMinutes = const Value.absent(),
    this.escalated = const Value.absent(),
    this.location = const Value.absent(),
  })  : title = Value(title),
        scheduledAt = Value(scheduledAt);
  static Insertable<LocalCheckIn> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? scheduledAt,
    Expression<DateTime>? confirmedAt,
    Expression<String>? status,
    Expression<int>? escalationMinutes,
    Expression<bool>? escalated,
    Expression<String>? location,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (status != null) 'status': status,
      if (escalationMinutes != null) 'escalation_minutes': escalationMinutes,
      if (escalated != null) 'escalated': escalated,
      if (location != null) 'location': location,
    });
  }

  LocalCheckInsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<DateTime>? scheduledAt,
      Value<DateTime?>? confirmedAt,
      Value<String>? status,
      Value<int>? escalationMinutes,
      Value<bool>? escalated,
      Value<String?>? location}) {
    return LocalCheckInsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      status: status ?? this.status,
      escalationMinutes: escalationMinutes ?? this.escalationMinutes,
      escalated: escalated ?? this.escalated,
      location: location ?? this.location,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<DateTime>(confirmedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (escalationMinutes.present) {
      map['escalation_minutes'] = Variable<int>(escalationMinutes.value);
    }
    if (escalated.present) {
      map['escalated'] = Variable<bool>(escalated.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCheckInsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('status: $status, ')
          ..write('escalationMinutes: $escalationMinutes, ')
          ..write('escalated: $escalated, ')
          ..write('location: $location')
          ..write(')'))
        .toString();
  }
}

class $LocalLocationLogTable extends LocalLocationLog
    with TableInfo<$LocalLocationLogTable, LocalLocationLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLocationLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _accuracyMeta =
      const VerificationMeta('accuracy');
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
      'accuracy', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _altitudeMeta =
      const VerificationMeta('altitude');
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
      'altitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
      'speed', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _headingMeta =
      const VerificationMeta('heading');
  @override
  late final GeneratedColumn<double> heading = GeneratedColumn<double>(
      'heading', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        latitude,
        longitude,
        accuracy,
        altitude,
        speed,
        heading,
        provider,
        timestamp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_location_log';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalLocationLogData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(_accuracyMeta,
          accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta));
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('altitude')) {
      context.handle(_altitudeMeta,
          altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('heading')) {
      context.handle(_headingMeta,
          heading.isAcceptableOrUnknown(data['heading']!, _headingMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalLocationLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLocationLogData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      accuracy: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy'])!,
      altitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}altitude']),
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speed']),
      heading: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}heading']),
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $LocalLocationLogTable createAlias(String alias) {
    return $LocalLocationLogTable(attachedDatabase, alias);
  }
}

class LocalLocationLogData extends DataClass
    implements Insertable<LocalLocationLogData> {
  final int id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String provider;
  final DateTime timestamp;
  const LocalLocationLogData(
      {required this.id,
      required this.latitude,
      required this.longitude,
      required this.accuracy,
      this.altitude,
      this.speed,
      this.heading,
      required this.provider,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['accuracy'] = Variable<double>(accuracy);
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || heading != null) {
      map['heading'] = Variable<double>(heading);
    }
    map['provider'] = Variable<String>(provider);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  LocalLocationLogCompanion toCompanion(bool nullToAbsent) {
    return LocalLocationLogCompanion(
      id: Value(id),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracy: Value(accuracy),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      heading: heading == null && nullToAbsent
          ? const Value.absent()
          : Value(heading),
      provider: Value(provider),
      timestamp: Value(timestamp),
    );
  }

  factory LocalLocationLogData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLocationLogData(
      id: serializer.fromJson<int>(json['id']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      speed: serializer.fromJson<double?>(json['speed']),
      heading: serializer.fromJson<double?>(json['heading']),
      provider: serializer.fromJson<String>(json['provider']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracy': serializer.toJson<double>(accuracy),
      'altitude': serializer.toJson<double?>(altitude),
      'speed': serializer.toJson<double?>(speed),
      'heading': serializer.toJson<double?>(heading),
      'provider': serializer.toJson<String>(provider),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  LocalLocationLogData copyWith(
          {int? id,
          double? latitude,
          double? longitude,
          double? accuracy,
          Value<double?> altitude = const Value.absent(),
          Value<double?> speed = const Value.absent(),
          Value<double?> heading = const Value.absent(),
          String? provider,
          DateTime? timestamp}) =>
      LocalLocationLogData(
        id: id ?? this.id,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracy: accuracy ?? this.accuracy,
        altitude: altitude.present ? altitude.value : this.altitude,
        speed: speed.present ? speed.value : this.speed,
        heading: heading.present ? heading.value : this.heading,
        provider: provider ?? this.provider,
        timestamp: timestamp ?? this.timestamp,
      );
  LocalLocationLogData copyWithCompanion(LocalLocationLogCompanion data) {
    return LocalLocationLogData(
      id: data.id.present ? data.id.value : this.id,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      speed: data.speed.present ? data.speed.value : this.speed,
      heading: data.heading.present ? data.heading.value : this.heading,
      provider: data.provider.present ? data.provider.value : this.provider,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLocationLogData(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed, ')
          ..write('heading: $heading, ')
          ..write('provider: $provider, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, latitude, longitude, accuracy, altitude,
      speed, heading, provider, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLocationLogData &&
          other.id == this.id &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.altitude == this.altitude &&
          other.speed == this.speed &&
          other.heading == this.heading &&
          other.provider == this.provider &&
          other.timestamp == this.timestamp);
}

class LocalLocationLogCompanion extends UpdateCompanion<LocalLocationLogData> {
  final Value<int> id;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> accuracy;
  final Value<double?> altitude;
  final Value<double?> speed;
  final Value<double?> heading;
  final Value<String> provider;
  final Value<DateTime> timestamp;
  const LocalLocationLogCompanion({
    this.id = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
    this.heading = const Value.absent(),
    this.provider = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  LocalLocationLogCompanion.insert({
    this.id = const Value.absent(),
    required double latitude,
    required double longitude,
    required double accuracy,
    this.altitude = const Value.absent(),
    this.speed = const Value.absent(),
    this.heading = const Value.absent(),
    required String provider,
    this.timestamp = const Value.absent(),
  })  : latitude = Value(latitude),
        longitude = Value(longitude),
        accuracy = Value(accuracy),
        provider = Value(provider);
  static Insertable<LocalLocationLogData> custom({
    Expression<int>? id,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<double>? altitude,
    Expression<double>? speed,
    Expression<double>? heading,
    Expression<String>? provider,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (provider != null) 'provider': provider,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  LocalLocationLogCompanion copyWith(
      {Value<int>? id,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double>? accuracy,
      Value<double?>? altitude,
      Value<double?>? speed,
      Value<double?>? heading,
      Value<String>? provider,
      Value<DateTime>? timestamp}) {
    return LocalLocationLogCompanion(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      provider: provider ?? this.provider,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (heading.present) {
      map['heading'] = Variable<double>(heading.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLocationLogCompanion(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('altitude: $altitude, ')
          ..write('speed: $speed, ')
          ..write('heading: $heading, ')
          ..write('provider: $provider, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $LocalMeshBeaconsTable extends LocalMeshBeacons
    with TableInfo<$LocalMeshBeaconsTable, LocalMeshBeacon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMeshBeaconsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _beaconIdMeta =
      const VerificationMeta('beaconId');
  @override
  late final GeneratedColumn<String> beaconId = GeneratedColumn<String>(
      'beacon_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userHashMeta =
      const VerificationMeta('userHash');
  @override
  late final GeneratedColumn<String> userHash = GeneratedColumn<String>(
      'user_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _hopCountMeta =
      const VerificationMeta('hopCount');
  @override
  late final GeneratedColumn<int> hopCount = GeneratedColumn<int>(
      'hop_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _maxHopsMeta =
      const VerificationMeta('maxHops');
  @override
  late final GeneratedColumn<int> maxHops = GeneratedColumn<int>(
      'max_hops', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _forwardedMeta =
      const VerificationMeta('forwarded');
  @override
  late final GeneratedColumn<bool> forwarded = GeneratedColumn<bool>(
      'forwarded', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("forwarded" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _relayedToCloudMeta =
      const VerificationMeta('relayedToCloud');
  @override
  late final GeneratedColumn<bool> relayedToCloud = GeneratedColumn<bool>(
      'relayed_to_cloud', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("relayed_to_cloud" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _expiresAtMeta =
      const VerificationMeta('expiresAt');
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
      'expires_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        beaconId,
        userHash,
        latitude,
        longitude,
        hopCount,
        maxHops,
        forwarded,
        relayedToCloud,
        receivedAt,
        expiresAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_mesh_beacons';
  @override
  VerificationContext validateIntegrity(Insertable<LocalMeshBeacon> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('beacon_id')) {
      context.handle(_beaconIdMeta,
          beaconId.isAcceptableOrUnknown(data['beacon_id']!, _beaconIdMeta));
    } else if (isInserting) {
      context.missing(_beaconIdMeta);
    }
    if (data.containsKey('user_hash')) {
      context.handle(_userHashMeta,
          userHash.isAcceptableOrUnknown(data['user_hash']!, _userHashMeta));
    } else if (isInserting) {
      context.missing(_userHashMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('hop_count')) {
      context.handle(_hopCountMeta,
          hopCount.isAcceptableOrUnknown(data['hop_count']!, _hopCountMeta));
    }
    if (data.containsKey('max_hops')) {
      context.handle(_maxHopsMeta,
          maxHops.isAcceptableOrUnknown(data['max_hops']!, _maxHopsMeta));
    }
    if (data.containsKey('forwarded')) {
      context.handle(_forwardedMeta,
          forwarded.isAcceptableOrUnknown(data['forwarded']!, _forwardedMeta));
    }
    if (data.containsKey('relayed_to_cloud')) {
      context.handle(
          _relayedToCloudMeta,
          relayedToCloud.isAcceptableOrUnknown(
              data['relayed_to_cloud']!, _relayedToCloudMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    }
    if (data.containsKey('expires_at')) {
      context.handle(_expiresAtMeta,
          expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta));
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {beaconId};
  @override
  LocalMeshBeacon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMeshBeacon(
      beaconId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}beacon_id'])!,
      userHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_hash'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      hopCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hop_count'])!,
      maxHops: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_hops'])!,
      forwarded: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}forwarded'])!,
      relayedToCloud: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}relayed_to_cloud'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
      expiresAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expires_at'])!,
    );
  }

  @override
  $LocalMeshBeaconsTable createAlias(String alias) {
    return $LocalMeshBeaconsTable(attachedDatabase, alias);
  }
}

class LocalMeshBeacon extends DataClass implements Insertable<LocalMeshBeacon> {
  final String beaconId;
  final String userHash;
  final double? latitude;
  final double? longitude;
  final int hopCount;
  final int maxHops;
  final bool forwarded;
  final bool relayedToCloud;
  final DateTime receivedAt;
  final DateTime expiresAt;
  const LocalMeshBeacon(
      {required this.beaconId,
      required this.userHash,
      this.latitude,
      this.longitude,
      required this.hopCount,
      required this.maxHops,
      required this.forwarded,
      required this.relayedToCloud,
      required this.receivedAt,
      required this.expiresAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['beacon_id'] = Variable<String>(beaconId);
    map['user_hash'] = Variable<String>(userHash);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['hop_count'] = Variable<int>(hopCount);
    map['max_hops'] = Variable<int>(maxHops);
    map['forwarded'] = Variable<bool>(forwarded);
    map['relayed_to_cloud'] = Variable<bool>(relayedToCloud);
    map['received_at'] = Variable<DateTime>(receivedAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  LocalMeshBeaconsCompanion toCompanion(bool nullToAbsent) {
    return LocalMeshBeaconsCompanion(
      beaconId: Value(beaconId),
      userHash: Value(userHash),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      hopCount: Value(hopCount),
      maxHops: Value(maxHops),
      forwarded: Value(forwarded),
      relayedToCloud: Value(relayedToCloud),
      receivedAt: Value(receivedAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory LocalMeshBeacon.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMeshBeacon(
      beaconId: serializer.fromJson<String>(json['beaconId']),
      userHash: serializer.fromJson<String>(json['userHash']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      hopCount: serializer.fromJson<int>(json['hopCount']),
      maxHops: serializer.fromJson<int>(json['maxHops']),
      forwarded: serializer.fromJson<bool>(json['forwarded']),
      relayedToCloud: serializer.fromJson<bool>(json['relayedToCloud']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'beaconId': serializer.toJson<String>(beaconId),
      'userHash': serializer.toJson<String>(userHash),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'hopCount': serializer.toJson<int>(hopCount),
      'maxHops': serializer.toJson<int>(maxHops),
      'forwarded': serializer.toJson<bool>(forwarded),
      'relayedToCloud': serializer.toJson<bool>(relayedToCloud),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  LocalMeshBeacon copyWith(
          {String? beaconId,
          String? userHash,
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          int? hopCount,
          int? maxHops,
          bool? forwarded,
          bool? relayedToCloud,
          DateTime? receivedAt,
          DateTime? expiresAt}) =>
      LocalMeshBeacon(
        beaconId: beaconId ?? this.beaconId,
        userHash: userHash ?? this.userHash,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        hopCount: hopCount ?? this.hopCount,
        maxHops: maxHops ?? this.maxHops,
        forwarded: forwarded ?? this.forwarded,
        relayedToCloud: relayedToCloud ?? this.relayedToCloud,
        receivedAt: receivedAt ?? this.receivedAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  LocalMeshBeacon copyWithCompanion(LocalMeshBeaconsCompanion data) {
    return LocalMeshBeacon(
      beaconId: data.beaconId.present ? data.beaconId.value : this.beaconId,
      userHash: data.userHash.present ? data.userHash.value : this.userHash,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      hopCount: data.hopCount.present ? data.hopCount.value : this.hopCount,
      maxHops: data.maxHops.present ? data.maxHops.value : this.maxHops,
      forwarded: data.forwarded.present ? data.forwarded.value : this.forwarded,
      relayedToCloud: data.relayedToCloud.present
          ? data.relayedToCloud.value
          : this.relayedToCloud,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMeshBeacon(')
          ..write('beaconId: $beaconId, ')
          ..write('userHash: $userHash, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('hopCount: $hopCount, ')
          ..write('maxHops: $maxHops, ')
          ..write('forwarded: $forwarded, ')
          ..write('relayedToCloud: $relayedToCloud, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(beaconId, userHash, latitude, longitude,
      hopCount, maxHops, forwarded, relayedToCloud, receivedAt, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMeshBeacon &&
          other.beaconId == this.beaconId &&
          other.userHash == this.userHash &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.hopCount == this.hopCount &&
          other.maxHops == this.maxHops &&
          other.forwarded == this.forwarded &&
          other.relayedToCloud == this.relayedToCloud &&
          other.receivedAt == this.receivedAt &&
          other.expiresAt == this.expiresAt);
}

class LocalMeshBeaconsCompanion extends UpdateCompanion<LocalMeshBeacon> {
  final Value<String> beaconId;
  final Value<String> userHash;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<int> hopCount;
  final Value<int> maxHops;
  final Value<bool> forwarded;
  final Value<bool> relayedToCloud;
  final Value<DateTime> receivedAt;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const LocalMeshBeaconsCompanion({
    this.beaconId = const Value.absent(),
    this.userHash = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.hopCount = const Value.absent(),
    this.maxHops = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.relayedToCloud = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMeshBeaconsCompanion.insert({
    required String beaconId,
    required String userHash,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.hopCount = const Value.absent(),
    this.maxHops = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.relayedToCloud = const Value.absent(),
    this.receivedAt = const Value.absent(),
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  })  : beaconId = Value(beaconId),
        userHash = Value(userHash),
        expiresAt = Value(expiresAt);
  static Insertable<LocalMeshBeacon> custom({
    Expression<String>? beaconId,
    Expression<String>? userHash,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? hopCount,
    Expression<int>? maxHops,
    Expression<bool>? forwarded,
    Expression<bool>? relayedToCloud,
    Expression<DateTime>? receivedAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (beaconId != null) 'beacon_id': beaconId,
      if (userHash != null) 'user_hash': userHash,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (hopCount != null) 'hop_count': hopCount,
      if (maxHops != null) 'max_hops': maxHops,
      if (forwarded != null) 'forwarded': forwarded,
      if (relayedToCloud != null) 'relayed_to_cloud': relayedToCloud,
      if (receivedAt != null) 'received_at': receivedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMeshBeaconsCompanion copyWith(
      {Value<String>? beaconId,
      Value<String>? userHash,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<int>? hopCount,
      Value<int>? maxHops,
      Value<bool>? forwarded,
      Value<bool>? relayedToCloud,
      Value<DateTime>? receivedAt,
      Value<DateTime>? expiresAt,
      Value<int>? rowid}) {
    return LocalMeshBeaconsCompanion(
      beaconId: beaconId ?? this.beaconId,
      userHash: userHash ?? this.userHash,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hopCount: hopCount ?? this.hopCount,
      maxHops: maxHops ?? this.maxHops,
      forwarded: forwarded ?? this.forwarded,
      relayedToCloud: relayedToCloud ?? this.relayedToCloud,
      receivedAt: receivedAt ?? this.receivedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (beaconId.present) {
      map['beacon_id'] = Variable<String>(beaconId.value);
    }
    if (userHash.present) {
      map['user_hash'] = Variable<String>(userHash.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (hopCount.present) {
      map['hop_count'] = Variable<int>(hopCount.value);
    }
    if (maxHops.present) {
      map['max_hops'] = Variable<int>(maxHops.value);
    }
    if (forwarded.present) {
      map['forwarded'] = Variable<bool>(forwarded.value);
    }
    if (relayedToCloud.present) {
      map['relayed_to_cloud'] = Variable<bool>(relayedToCloud.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
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
    return (StringBuffer('LocalMeshBeaconsCompanion(')
          ..write('beaconId: $beaconId, ')
          ..write('userHash: $userHash, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('hopCount: $hopCount, ')
          ..write('maxHops: $maxHops, ')
          ..write('forwarded: $forwarded, ')
          ..write('relayedToCloud: $relayedToCloud, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalIncidentsTable extends LocalIncidents
    with TableInfo<$LocalIncidentsTable, LocalIncident> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalIncidentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _anonymousMeta =
      const VerificationMeta('anonymous');
  @override
  late final GeneratedColumn<bool> anonymous = GeneratedColumn<bool>(
      'anonymous', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("anonymous" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _syncedToCloudMeta =
      const VerificationMeta('syncedToCloud');
  @override
  late final GeneratedColumn<bool> syncedToCloud = GeneratedColumn<bool>(
      'synced_to_cloud', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("synced_to_cloud" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        description,
        latitude,
        longitude,
        address,
        anonymous,
        syncedToCloud,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_incidents';
  @override
  VerificationContext validateIntegrity(Insertable<LocalIncident> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('anonymous')) {
      context.handle(_anonymousMeta,
          anonymous.isAcceptableOrUnknown(data['anonymous']!, _anonymousMeta));
    }
    if (data.containsKey('synced_to_cloud')) {
      context.handle(
          _syncedToCloudMeta,
          syncedToCloud.isAcceptableOrUnknown(
              data['synced_to_cloud']!, _syncedToCloudMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalIncident map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalIncident(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      anonymous: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}anonymous'])!,
      syncedToCloud: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}synced_to_cloud'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalIncidentsTable createAlias(String alias) {
    return $LocalIncidentsTable(attachedDatabase, alias);
  }
}

class LocalIncident extends DataClass implements Insertable<LocalIncident> {
  final int id;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final String? address;
  final bool anonymous;
  final bool syncedToCloud;
  final DateTime createdAt;
  const LocalIncident(
      {required this.id,
      required this.type,
      required this.description,
      required this.latitude,
      required this.longitude,
      this.address,
      required this.anonymous,
      required this.syncedToCloud,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['description'] = Variable<String>(description);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['anonymous'] = Variable<bool>(anonymous);
    map['synced_to_cloud'] = Variable<bool>(syncedToCloud);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalIncidentsCompanion toCompanion(bool nullToAbsent) {
    return LocalIncidentsCompanion(
      id: Value(id),
      type: Value(type),
      description: Value(description),
      latitude: Value(latitude),
      longitude: Value(longitude),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      anonymous: Value(anonymous),
      syncedToCloud: Value(syncedToCloud),
      createdAt: Value(createdAt),
    );
  }

  factory LocalIncident.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalIncident(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String>(json['description']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      address: serializer.fromJson<String?>(json['address']),
      anonymous: serializer.fromJson<bool>(json['anonymous']),
      syncedToCloud: serializer.fromJson<bool>(json['syncedToCloud']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String>(description),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'address': serializer.toJson<String?>(address),
      'anonymous': serializer.toJson<bool>(anonymous),
      'syncedToCloud': serializer.toJson<bool>(syncedToCloud),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalIncident copyWith(
          {int? id,
          String? type,
          String? description,
          double? latitude,
          double? longitude,
          Value<String?> address = const Value.absent(),
          bool? anonymous,
          bool? syncedToCloud,
          DateTime? createdAt}) =>
      LocalIncident(
        id: id ?? this.id,
        type: type ?? this.type,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address.present ? address.value : this.address,
        anonymous: anonymous ?? this.anonymous,
        syncedToCloud: syncedToCloud ?? this.syncedToCloud,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalIncident copyWithCompanion(LocalIncidentsCompanion data) {
    return LocalIncident(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      description:
          data.description.present ? data.description.value : this.description,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      address: data.address.present ? data.address.value : this.address,
      anonymous: data.anonymous.present ? data.anonymous.value : this.anonymous,
      syncedToCloud: data.syncedToCloud.present
          ? data.syncedToCloud.value
          : this.syncedToCloud,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncident(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('address: $address, ')
          ..write('anonymous: $anonymous, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, description, latitude, longitude,
      address, anonymous, syncedToCloud, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalIncident &&
          other.id == this.id &&
          other.type == this.type &&
          other.description == this.description &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.address == this.address &&
          other.anonymous == this.anonymous &&
          other.syncedToCloud == this.syncedToCloud &&
          other.createdAt == this.createdAt);
}

class LocalIncidentsCompanion extends UpdateCompanion<LocalIncident> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> description;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String?> address;
  final Value<bool> anonymous;
  final Value<bool> syncedToCloud;
  final Value<DateTime> createdAt;
  const LocalIncidentsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.address = const Value.absent(),
    this.anonymous = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalIncidentsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String description,
    required double latitude,
    required double longitude,
    this.address = const Value.absent(),
    this.anonymous = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : type = Value(type),
        description = Value(description),
        latitude = Value(latitude),
        longitude = Value(longitude);
  static Insertable<LocalIncident> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? description,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? address,
    Expression<bool>? anonymous,
    Expression<bool>? syncedToCloud,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      if (anonymous != null) 'anonymous': anonymous,
      if (syncedToCloud != null) 'synced_to_cloud': syncedToCloud,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalIncidentsCompanion copyWith(
      {Value<int>? id,
      Value<String>? type,
      Value<String>? description,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<String?>? address,
      Value<bool>? anonymous,
      Value<bool>? syncedToCloud,
      Value<DateTime>? createdAt}) {
    return LocalIncidentsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      anonymous: anonymous ?? this.anonymous,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (anonymous.present) {
      map['anonymous'] = Variable<bool>(anonymous.value);
    }
    if (syncedToCloud.present) {
      map['synced_to_cloud'] = Variable<bool>(syncedToCloud.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncidentsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('address: $address, ')
          ..write('anonymous: $anonymous, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalIncidentEventsTable extends LocalIncidentEvents
    with TableInfo<$LocalIncidentEventsTable, LocalIncidentEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalIncidentEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _incidentIdMeta =
      const VerificationMeta('incidentId');
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
      'incident_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _incidentStateMeta =
      const VerificationMeta('incidentState');
  @override
  late final GeneratedColumn<String> incidentState = GeneratedColumn<String>(
      'incident_state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorTypeMeta =
      const VerificationMeta('actorType');
  @override
  late final GeneratedColumn<String> actorType = GeneratedColumn<String>(
      'actor_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        eventId,
        incidentId,
        eventType,
        incidentState,
        actorType,
        actorId,
        payloadJson,
        occurredAt,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_incident_events';
  @override
  VerificationContext validateIntegrity(Insertable<LocalIncidentEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
          _incidentIdMeta,
          incidentId.isAcceptableOrUnknown(
              data['incident_id']!, _incidentIdMeta));
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('incident_state')) {
      context.handle(
          _incidentStateMeta,
          incidentState.isAcceptableOrUnknown(
              data['incident_state']!, _incidentStateMeta));
    } else if (isInserting) {
      context.missing(_incidentStateMeta);
    }
    if (data.containsKey('actor_type')) {
      context.handle(_actorTypeMeta,
          actorType.isAcceptableOrUnknown(data['actor_type']!, _actorTypeMeta));
    } else if (isInserting) {
      context.missing(_actorTypeMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  LocalIncidentEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalIncidentEvent(
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id'])!,
      incidentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}incident_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      incidentState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}incident_state'])!,
      actorType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_type'])!,
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id']),
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalIncidentEventsTable createAlias(String alias) {
    return $LocalIncidentEventsTable(attachedDatabase, alias);
  }
}

class LocalIncidentEvent extends DataClass
    implements Insertable<LocalIncidentEvent> {
  final String eventId;
  final String incidentId;
  final String eventType;
  final String incidentState;
  final String actorType;
  final String? actorId;
  final String payloadJson;
  final DateTime occurredAt;
  final DateTime createdAt;
  const LocalIncidentEvent(
      {required this.eventId,
      required this.incidentId,
      required this.eventType,
      required this.incidentState,
      required this.actorType,
      this.actorId,
      required this.payloadJson,
      required this.occurredAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['incident_id'] = Variable<String>(incidentId);
    map['event_type'] = Variable<String>(eventType);
    map['incident_state'] = Variable<String>(incidentState);
    map['actor_type'] = Variable<String>(actorType);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalIncidentEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalIncidentEventsCompanion(
      eventId: Value(eventId),
      incidentId: Value(incidentId),
      eventType: Value(eventType),
      incidentState: Value(incidentState),
      actorType: Value(actorType),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      payloadJson: Value(payloadJson),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
    );
  }

  factory LocalIncidentEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalIncidentEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      incidentState: serializer.fromJson<String>(json['incidentState']),
      actorType: serializer.fromJson<String>(json['actorType']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'incidentId': serializer.toJson<String>(incidentId),
      'eventType': serializer.toJson<String>(eventType),
      'incidentState': serializer.toJson<String>(incidentState),
      'actorType': serializer.toJson<String>(actorType),
      'actorId': serializer.toJson<String?>(actorId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalIncidentEvent copyWith(
          {String? eventId,
          String? incidentId,
          String? eventType,
          String? incidentState,
          String? actorType,
          Value<String?> actorId = const Value.absent(),
          String? payloadJson,
          DateTime? occurredAt,
          DateTime? createdAt}) =>
      LocalIncidentEvent(
        eventId: eventId ?? this.eventId,
        incidentId: incidentId ?? this.incidentId,
        eventType: eventType ?? this.eventType,
        incidentState: incidentState ?? this.incidentState,
        actorType: actorType ?? this.actorType,
        actorId: actorId.present ? actorId.value : this.actorId,
        payloadJson: payloadJson ?? this.payloadJson,
        occurredAt: occurredAt ?? this.occurredAt,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalIncidentEvent copyWithCompanion(LocalIncidentEventsCompanion data) {
    return LocalIncidentEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      incidentId:
          data.incidentId.present ? data.incidentId.value : this.incidentId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      incidentState: data.incidentState.present
          ? data.incidentState.value
          : this.incidentState,
      actorType: data.actorType.present ? data.actorType.value : this.actorType,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncidentEvent(')
          ..write('eventId: $eventId, ')
          ..write('incidentId: $incidentId, ')
          ..write('eventType: $eventType, ')
          ..write('incidentState: $incidentState, ')
          ..write('actorType: $actorType, ')
          ..write('actorId: $actorId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, incidentId, eventType, incidentState,
      actorType, actorId, payloadJson, occurredAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalIncidentEvent &&
          other.eventId == this.eventId &&
          other.incidentId == this.incidentId &&
          other.eventType == this.eventType &&
          other.incidentState == this.incidentState &&
          other.actorType == this.actorType &&
          other.actorId == this.actorId &&
          other.payloadJson == this.payloadJson &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt);
}

class LocalIncidentEventsCompanion extends UpdateCompanion<LocalIncidentEvent> {
  final Value<String> eventId;
  final Value<String> incidentId;
  final Value<String> eventType;
  final Value<String> incidentState;
  final Value<String> actorType;
  final Value<String?> actorId;
  final Value<String> payloadJson;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalIncidentEventsCompanion({
    this.eventId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.incidentState = const Value.absent(),
    this.actorType = const Value.absent(),
    this.actorId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalIncidentEventsCompanion.insert({
    required String eventId,
    required String incidentId,
    required String eventType,
    required String incidentState,
    required String actorType,
    this.actorId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required DateTime occurredAt,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : eventId = Value(eventId),
        incidentId = Value(incidentId),
        eventType = Value(eventType),
        incidentState = Value(incidentState),
        actorType = Value(actorType),
        occurredAt = Value(occurredAt);
  static Insertable<LocalIncidentEvent> custom({
    Expression<String>? eventId,
    Expression<String>? incidentId,
    Expression<String>? eventType,
    Expression<String>? incidentState,
    Expression<String>? actorType,
    Expression<String>? actorId,
    Expression<String>? payloadJson,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (incidentId != null) 'incident_id': incidentId,
      if (eventType != null) 'event_type': eventType,
      if (incidentState != null) 'incident_state': incidentState,
      if (actorType != null) 'actor_type': actorType,
      if (actorId != null) 'actor_id': actorId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalIncidentEventsCompanion copyWith(
      {Value<String>? eventId,
      Value<String>? incidentId,
      Value<String>? eventType,
      Value<String>? incidentState,
      Value<String>? actorType,
      Value<String?>? actorId,
      Value<String>? payloadJson,
      Value<DateTime>? occurredAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalIncidentEventsCompanion(
      eventId: eventId ?? this.eventId,
      incidentId: incidentId ?? this.incidentId,
      eventType: eventType ?? this.eventType,
      incidentState: incidentState ?? this.incidentState,
      actorType: actorType ?? this.actorType,
      actorId: actorId ?? this.actorId,
      payloadJson: payloadJson ?? this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (incidentState.present) {
      map['incident_state'] = Variable<String>(incidentState.value);
    }
    if (actorType.present) {
      map['actor_type'] = Variable<String>(actorType.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncidentEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('incidentId: $incidentId, ')
          ..write('eventType: $eventType, ')
          ..write('incidentState: $incidentState, ')
          ..write('actorType: $actorType, ')
          ..write('actorId: $actorId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalOutboxOperationsTable extends LocalOutboxOperations
    with TableInfo<$LocalOutboxOperationsTable, LocalOutboxOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalOutboxOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aggregateTypeMeta =
      const VerificationMeta('aggregateType');
  @override
  late final GeneratedColumn<String> aggregateType = GeneratedColumn<String>(
      'aggregate_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aggregateIdMeta =
      const VerificationMeta('aggregateId');
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
      'aggregate_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationTypeMeta =
      const VerificationMeta('operationType');
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
      'operation_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dependencyIdMeta =
      const VerificationMeta('dependencyId');
  @override
  late final GeneratedColumn<String> dependencyId = GeneratedColumn<String>(
      'dependency_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>('next_attempt_at', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        operationId,
        aggregateType,
        aggregateId,
        operationType,
        payloadJson,
        dependencyId,
        status,
        attemptCount,
        nextAttemptAt,
        lastError,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_outbox_operations';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalOutboxOperation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('aggregate_type')) {
      context.handle(
          _aggregateTypeMeta,
          aggregateType.isAcceptableOrUnknown(
              data['aggregate_type']!, _aggregateTypeMeta));
    } else if (isInserting) {
      context.missing(_aggregateTypeMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
          _aggregateIdMeta,
          aggregateId.isAcceptableOrUnknown(
              data['aggregate_id']!, _aggregateIdMeta));
    } else if (isInserting) {
      context.missing(_aggregateIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
          _operationTypeMeta,
          operationType.isAcceptableOrUnknown(
              data['operation_type']!, _operationTypeMeta));
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('dependency_id')) {
      context.handle(
          _dependencyIdMeta,
          dependencyId.isAcceptableOrUnknown(
              data['dependency_id']!, _dependencyIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  LocalOutboxOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalOutboxOperation(
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id'])!,
      aggregateType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aggregate_type'])!,
      aggregateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}aggregate_id'])!,
      operationType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      dependencyId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dependency_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}next_attempt_at'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalOutboxOperationsTable createAlias(String alias) {
    return $LocalOutboxOperationsTable(attachedDatabase, alias);
  }
}

class LocalOutboxOperation extends DataClass
    implements Insertable<LocalOutboxOperation> {
  final String operationId;
  final String aggregateType;
  final String aggregateId;
  final String operationType;
  final String payloadJson;
  final String? dependencyId;
  final String status;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalOutboxOperation(
      {required this.operationId,
      required this.aggregateType,
      required this.aggregateId,
      required this.operationType,
      required this.payloadJson,
      this.dependencyId,
      required this.status,
      required this.attemptCount,
      required this.nextAttemptAt,
      this.lastError,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['aggregate_type'] = Variable<String>(aggregateType);
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['operation_type'] = Variable<String>(operationType);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || dependencyId != null) {
      map['dependency_id'] = Variable<String>(dependencyId);
    }
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalOutboxOperationsCompanion toCompanion(bool nullToAbsent) {
    return LocalOutboxOperationsCompanion(
      operationId: Value(operationId),
      aggregateType: Value(aggregateType),
      aggregateId: Value(aggregateId),
      operationType: Value(operationType),
      payloadJson: Value(payloadJson),
      dependencyId: dependencyId == null && nullToAbsent
          ? const Value.absent()
          : Value(dependencyId),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalOutboxOperation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalOutboxOperation(
      operationId: serializer.fromJson<String>(json['operationId']),
      aggregateType: serializer.fromJson<String>(json['aggregateType']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      dependencyId: serializer.fromJson<String?>(json['dependencyId']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'aggregateType': serializer.toJson<String>(aggregateType),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'operationType': serializer.toJson<String>(operationType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'dependencyId': serializer.toJson<String?>(dependencyId),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalOutboxOperation copyWith(
          {String? operationId,
          String? aggregateType,
          String? aggregateId,
          String? operationType,
          String? payloadJson,
          Value<String?> dependencyId = const Value.absent(),
          String? status,
          int? attemptCount,
          DateTime? nextAttemptAt,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      LocalOutboxOperation(
        operationId: operationId ?? this.operationId,
        aggregateType: aggregateType ?? this.aggregateType,
        aggregateId: aggregateId ?? this.aggregateId,
        operationType: operationType ?? this.operationType,
        payloadJson: payloadJson ?? this.payloadJson,
        dependencyId:
            dependencyId.present ? dependencyId.value : this.dependencyId,
        status: status ?? this.status,
        attemptCount: attemptCount ?? this.attemptCount,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalOutboxOperation copyWithCompanion(LocalOutboxOperationsCompanion data) {
    return LocalOutboxOperation(
      operationId:
          data.operationId.present ? data.operationId.value : this.operationId,
      aggregateType: data.aggregateType.present
          ? data.aggregateType.value
          : this.aggregateType,
      aggregateId:
          data.aggregateId.present ? data.aggregateId.value : this.aggregateId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      dependencyId: data.dependencyId.present
          ? data.dependencyId.value
          : this.dependencyId,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalOutboxOperation(')
          ..write('operationId: $operationId, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('dependencyId: $dependencyId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      operationId,
      aggregateType,
      aggregateId,
      operationType,
      payloadJson,
      dependencyId,
      status,
      attemptCount,
      nextAttemptAt,
      lastError,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalOutboxOperation &&
          other.operationId == this.operationId &&
          other.aggregateType == this.aggregateType &&
          other.aggregateId == this.aggregateId &&
          other.operationType == this.operationType &&
          other.payloadJson == this.payloadJson &&
          other.dependencyId == this.dependencyId &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalOutboxOperationsCompanion
    extends UpdateCompanion<LocalOutboxOperation> {
  final Value<String> operationId;
  final Value<String> aggregateType;
  final Value<String> aggregateId;
  final Value<String> operationType;
  final Value<String> payloadJson;
  final Value<String?> dependencyId;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalOutboxOperationsCompanion({
    this.operationId = const Value.absent(),
    this.aggregateType = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.dependencyId = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalOutboxOperationsCompanion.insert({
    required String operationId,
    required String aggregateType,
    required String aggregateId,
    required String operationType,
    required String payloadJson,
    this.dependencyId = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : operationId = Value(operationId),
        aggregateType = Value(aggregateType),
        aggregateId = Value(aggregateId),
        operationType = Value(operationType),
        payloadJson = Value(payloadJson);
  static Insertable<LocalOutboxOperation> custom({
    Expression<String>? operationId,
    Expression<String>? aggregateType,
    Expression<String>? aggregateId,
    Expression<String>? operationType,
    Expression<String>? payloadJson,
    Expression<String>? dependencyId,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (aggregateType != null) 'aggregate_type': aggregateType,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (operationType != null) 'operation_type': operationType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (dependencyId != null) 'dependency_id': dependencyId,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalOutboxOperationsCompanion copyWith(
      {Value<String>? operationId,
      Value<String>? aggregateType,
      Value<String>? aggregateId,
      Value<String>? operationType,
      Value<String>? payloadJson,
      Value<String?>? dependencyId,
      Value<String>? status,
      Value<int>? attemptCount,
      Value<DateTime>? nextAttemptAt,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalOutboxOperationsCompanion(
      operationId: operationId ?? this.operationId,
      aggregateType: aggregateType ?? this.aggregateType,
      aggregateId: aggregateId ?? this.aggregateId,
      operationType: operationType ?? this.operationType,
      payloadJson: payloadJson ?? this.payloadJson,
      dependencyId: dependencyId ?? this.dependencyId,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (aggregateType.present) {
      map['aggregate_type'] = Variable<String>(aggregateType.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (dependencyId.present) {
      map['dependency_id'] = Variable<String>(dependencyId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('LocalOutboxOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('aggregateType: $aggregateType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('operationType: $operationType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('dependencyId: $dependencyId, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDeliveryAttemptsTable extends LocalDeliveryAttempts
    with TableInfo<$LocalDeliveryAttemptsTable, LocalDeliveryAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDeliveryAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta =
      const VerificationMeta('attemptId');
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
      'attempt_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _incidentIdMeta =
      const VerificationMeta('incidentId');
  @override
  late final GeneratedColumn<String> incidentId = GeneratedColumn<String>(
      'incident_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _channelMeta =
      const VerificationMeta('channel');
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
      'channel', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipientRefMeta =
      const VerificationMeta('recipientRef');
  @override
  late final GeneratedColumn<String> recipientRef = GeneratedColumn<String>(
      'recipient_ref', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerMessageIdMeta =
      const VerificationMeta('providerMessageId');
  @override
  late final GeneratedColumn<String> providerMessageId =
      GeneratedColumn<String>('provider_message_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _failureCodeMeta =
      const VerificationMeta('failureCode');
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
      'failure_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _queuedAtMeta =
      const VerificationMeta('queuedAt');
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
      'queued_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _acknowledgedAtMeta =
      const VerificationMeta('acknowledgedAt');
  @override
  late final GeneratedColumn<DateTime> acknowledgedAt =
      GeneratedColumn<DateTime>('acknowledged_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        attemptId,
        incidentId,
        channel,
        recipientRef,
        status,
        providerMessageId,
        failureCode,
        queuedAt,
        updatedAt,
        acknowledgedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_delivery_attempts';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalDeliveryAttempt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(_attemptIdMeta,
          attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta));
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('incident_id')) {
      context.handle(
          _incidentIdMeta,
          incidentId.isAcceptableOrUnknown(
              data['incident_id']!, _incidentIdMeta));
    } else if (isInserting) {
      context.missing(_incidentIdMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(_channelMeta,
          channel.isAcceptableOrUnknown(data['channel']!, _channelMeta));
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('recipient_ref')) {
      context.handle(
          _recipientRefMeta,
          recipientRef.isAcceptableOrUnknown(
              data['recipient_ref']!, _recipientRefMeta));
    } else if (isInserting) {
      context.missing(_recipientRefMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('provider_message_id')) {
      context.handle(
          _providerMessageIdMeta,
          providerMessageId.isAcceptableOrUnknown(
              data['provider_message_id']!, _providerMessageIdMeta));
    }
    if (data.containsKey('failure_code')) {
      context.handle(
          _failureCodeMeta,
          failureCode.isAcceptableOrUnknown(
              data['failure_code']!, _failureCodeMeta));
    }
    if (data.containsKey('queued_at')) {
      context.handle(_queuedAtMeta,
          queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta));
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('acknowledged_at')) {
      context.handle(
          _acknowledgedAtMeta,
          acknowledgedAt.isAcceptableOrUnknown(
              data['acknowledged_at']!, _acknowledgedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId};
  @override
  LocalDeliveryAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDeliveryAttempt(
      attemptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attempt_id'])!,
      incidentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}incident_id'])!,
      channel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}channel'])!,
      recipientRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipient_ref'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      providerMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}provider_message_id']),
      failureCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}failure_code']),
      queuedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}queued_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      acknowledgedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}acknowledged_at']),
    );
  }

  @override
  $LocalDeliveryAttemptsTable createAlias(String alias) {
    return $LocalDeliveryAttemptsTable(attachedDatabase, alias);
  }
}

class LocalDeliveryAttempt extends DataClass
    implements Insertable<LocalDeliveryAttempt> {
  final String attemptId;
  final String incidentId;
  final String channel;
  final String recipientRef;
  final String status;
  final String? providerMessageId;
  final String? failureCode;
  final DateTime queuedAt;
  final DateTime updatedAt;
  final DateTime? acknowledgedAt;
  const LocalDeliveryAttempt(
      {required this.attemptId,
      required this.incidentId,
      required this.channel,
      required this.recipientRef,
      required this.status,
      this.providerMessageId,
      this.failureCode,
      required this.queuedAt,
      required this.updatedAt,
      this.acknowledgedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    map['incident_id'] = Variable<String>(incidentId);
    map['channel'] = Variable<String>(channel);
    map['recipient_ref'] = Variable<String>(recipientRef);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || providerMessageId != null) {
      map['provider_message_id'] = Variable<String>(providerMessageId);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || acknowledgedAt != null) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt);
    }
    return map;
  }

  LocalDeliveryAttemptsCompanion toCompanion(bool nullToAbsent) {
    return LocalDeliveryAttemptsCompanion(
      attemptId: Value(attemptId),
      incidentId: Value(incidentId),
      channel: Value(channel),
      recipientRef: Value(recipientRef),
      status: Value(status),
      providerMessageId: providerMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerMessageId),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      queuedAt: Value(queuedAt),
      updatedAt: Value(updatedAt),
      acknowledgedAt: acknowledgedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acknowledgedAt),
    );
  }

  factory LocalDeliveryAttempt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDeliveryAttempt(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      incidentId: serializer.fromJson<String>(json['incidentId']),
      channel: serializer.fromJson<String>(json['channel']),
      recipientRef: serializer.fromJson<String>(json['recipientRef']),
      status: serializer.fromJson<String>(json['status']),
      providerMessageId:
          serializer.fromJson<String?>(json['providerMessageId']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      acknowledgedAt: serializer.fromJson<DateTime?>(json['acknowledgedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'incidentId': serializer.toJson<String>(incidentId),
      'channel': serializer.toJson<String>(channel),
      'recipientRef': serializer.toJson<String>(recipientRef),
      'status': serializer.toJson<String>(status),
      'providerMessageId': serializer.toJson<String?>(providerMessageId),
      'failureCode': serializer.toJson<String?>(failureCode),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'acknowledgedAt': serializer.toJson<DateTime?>(acknowledgedAt),
    };
  }

  LocalDeliveryAttempt copyWith(
          {String? attemptId,
          String? incidentId,
          String? channel,
          String? recipientRef,
          String? status,
          Value<String?> providerMessageId = const Value.absent(),
          Value<String?> failureCode = const Value.absent(),
          DateTime? queuedAt,
          DateTime? updatedAt,
          Value<DateTime?> acknowledgedAt = const Value.absent()}) =>
      LocalDeliveryAttempt(
        attemptId: attemptId ?? this.attemptId,
        incidentId: incidentId ?? this.incidentId,
        channel: channel ?? this.channel,
        recipientRef: recipientRef ?? this.recipientRef,
        status: status ?? this.status,
        providerMessageId: providerMessageId.present
            ? providerMessageId.value
            : this.providerMessageId,
        failureCode: failureCode.present ? failureCode.value : this.failureCode,
        queuedAt: queuedAt ?? this.queuedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        acknowledgedAt:
            acknowledgedAt.present ? acknowledgedAt.value : this.acknowledgedAt,
      );
  LocalDeliveryAttempt copyWithCompanion(LocalDeliveryAttemptsCompanion data) {
    return LocalDeliveryAttempt(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      incidentId:
          data.incidentId.present ? data.incidentId.value : this.incidentId,
      channel: data.channel.present ? data.channel.value : this.channel,
      recipientRef: data.recipientRef.present
          ? data.recipientRef.value
          : this.recipientRef,
      status: data.status.present ? data.status.value : this.status,
      providerMessageId: data.providerMessageId.present
          ? data.providerMessageId.value
          : this.providerMessageId,
      failureCode:
          data.failureCode.present ? data.failureCode.value : this.failureCode,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      acknowledgedAt: data.acknowledgedAt.present
          ? data.acknowledgedAt.value
          : this.acknowledgedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDeliveryAttempt(')
          ..write('attemptId: $attemptId, ')
          ..write('incidentId: $incidentId, ')
          ..write('channel: $channel, ')
          ..write('recipientRef: $recipientRef, ')
          ..write('status: $status, ')
          ..write('providerMessageId: $providerMessageId, ')
          ..write('failureCode: $failureCode, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      attemptId,
      incidentId,
      channel,
      recipientRef,
      status,
      providerMessageId,
      failureCode,
      queuedAt,
      updatedAt,
      acknowledgedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDeliveryAttempt &&
          other.attemptId == this.attemptId &&
          other.incidentId == this.incidentId &&
          other.channel == this.channel &&
          other.recipientRef == this.recipientRef &&
          other.status == this.status &&
          other.providerMessageId == this.providerMessageId &&
          other.failureCode == this.failureCode &&
          other.queuedAt == this.queuedAt &&
          other.updatedAt == this.updatedAt &&
          other.acknowledgedAt == this.acknowledgedAt);
}

class LocalDeliveryAttemptsCompanion
    extends UpdateCompanion<LocalDeliveryAttempt> {
  final Value<String> attemptId;
  final Value<String> incidentId;
  final Value<String> channel;
  final Value<String> recipientRef;
  final Value<String> status;
  final Value<String?> providerMessageId;
  final Value<String?> failureCode;
  final Value<DateTime> queuedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> acknowledgedAt;
  final Value<int> rowid;
  const LocalDeliveryAttemptsCompanion({
    this.attemptId = const Value.absent(),
    this.incidentId = const Value.absent(),
    this.channel = const Value.absent(),
    this.recipientRef = const Value.absent(),
    this.status = const Value.absent(),
    this.providerMessageId = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDeliveryAttemptsCompanion.insert({
    required String attemptId,
    required String incidentId,
    required String channel,
    required String recipientRef,
    required String status,
    this.providerMessageId = const Value.absent(),
    this.failureCode = const Value.absent(),
    required DateTime queuedAt,
    required DateTime updatedAt,
    this.acknowledgedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : attemptId = Value(attemptId),
        incidentId = Value(incidentId),
        channel = Value(channel),
        recipientRef = Value(recipientRef),
        status = Value(status),
        queuedAt = Value(queuedAt),
        updatedAt = Value(updatedAt);
  static Insertable<LocalDeliveryAttempt> custom({
    Expression<String>? attemptId,
    Expression<String>? incidentId,
    Expression<String>? channel,
    Expression<String>? recipientRef,
    Expression<String>? status,
    Expression<String>? providerMessageId,
    Expression<String>? failureCode,
    Expression<DateTime>? queuedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? acknowledgedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (incidentId != null) 'incident_id': incidentId,
      if (channel != null) 'channel': channel,
      if (recipientRef != null) 'recipient_ref': recipientRef,
      if (status != null) 'status': status,
      if (providerMessageId != null) 'provider_message_id': providerMessageId,
      if (failureCode != null) 'failure_code': failureCode,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDeliveryAttemptsCompanion copyWith(
      {Value<String>? attemptId,
      Value<String>? incidentId,
      Value<String>? channel,
      Value<String>? recipientRef,
      Value<String>? status,
      Value<String?>? providerMessageId,
      Value<String?>? failureCode,
      Value<DateTime>? queuedAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? acknowledgedAt,
      Value<int>? rowid}) {
    return LocalDeliveryAttemptsCompanion(
      attemptId: attemptId ?? this.attemptId,
      incidentId: incidentId ?? this.incidentId,
      channel: channel ?? this.channel,
      recipientRef: recipientRef ?? this.recipientRef,
      status: status ?? this.status,
      providerMessageId: providerMessageId ?? this.providerMessageId,
      failureCode: failureCode ?? this.failureCode,
      queuedAt: queuedAt ?? this.queuedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (incidentId.present) {
      map['incident_id'] = Variable<String>(incidentId.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (recipientRef.present) {
      map['recipient_ref'] = Variable<String>(recipientRef.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (providerMessageId.present) {
      map['provider_message_id'] = Variable<String>(providerMessageId.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (acknowledgedAt.present) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDeliveryAttemptsCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('incidentId: $incidentId, ')
          ..write('channel: $channel, ')
          ..write('recipientRef: $recipientRef, ')
          ..write('status: $status, ')
          ..write('providerMessageId: $providerMessageId, ')
          ..write('failureCode: $failureCode, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GuardianDatabase extends GeneratedDatabase {
  _$GuardianDatabase(QueryExecutor e) : super(e);
  $GuardianDatabaseManager get managers => $GuardianDatabaseManager(this);
  late final $LocalContactsTable localContacts = $LocalContactsTable(this);
  late final $LocalAlertsTable localAlerts = $LocalAlertsTable(this);
  late final $LocalSafeZonesTable localSafeZones = $LocalSafeZonesTable(this);
  late final $LocalCheckInsTable localCheckIns = $LocalCheckInsTable(this);
  late final $LocalLocationLogTable localLocationLog =
      $LocalLocationLogTable(this);
  late final $LocalMeshBeaconsTable localMeshBeacons =
      $LocalMeshBeaconsTable(this);
  late final $LocalIncidentsTable localIncidents = $LocalIncidentsTable(this);
  late final $LocalIncidentEventsTable localIncidentEvents =
      $LocalIncidentEventsTable(this);
  late final $LocalOutboxOperationsTable localOutboxOperations =
      $LocalOutboxOperationsTable(this);
  late final $LocalDeliveryAttemptsTable localDeliveryAttempts =
      $LocalDeliveryAttemptsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localContacts,
        localAlerts,
        localSafeZones,
        localCheckIns,
        localLocationLog,
        localMeshBeacons,
        localIncidents,
        localIncidentEvents,
        localOutboxOperations,
        localDeliveryAttempts
      ];
}

typedef $$LocalContactsTableCreateCompanionBuilder = LocalContactsCompanion
    Function({
  Value<int> id,
  required String contactUid,
  required String name,
  required String phone,
  Value<String> relationship,
  Value<bool> isPrimary,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<bool> pendingSync,
});
typedef $$LocalContactsTableUpdateCompanionBuilder = LocalContactsCompanion
    Function({
  Value<int> id,
  Value<String> contactUid,
  Value<String> name,
  Value<String> phone,
  Value<String> relationship,
  Value<bool> isPrimary,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<bool> pendingSync,
});

class $$LocalContactsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalContactsTable> {
  $$LocalContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactUid => $composableBuilder(
      column: $table.contactUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relationship => $composableBuilder(
      column: $table.relationship, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => ColumnFilters(column));
}

class $$LocalContactsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalContactsTable> {
  $$LocalContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactUid => $composableBuilder(
      column: $table.contactUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relationship => $composableBuilder(
      column: $table.relationship,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
      column: $table.isPrimary, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => ColumnOrderings(column));
}

class $$LocalContactsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalContactsTable> {
  $$LocalContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contactUid => $composableBuilder(
      column: $table.contactUid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get relationship => $composableBuilder(
      column: $table.relationship, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => column);
}

class $$LocalContactsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$GuardianDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()> {
  $$LocalContactsTableTableManager(
      _$GuardianDatabase db, $LocalContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> contactUid = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String> relationship = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<bool> pendingSync = const Value.absent(),
          }) =>
              LocalContactsCompanion(
            id: id,
            contactUid: contactUid,
            name: name,
            phone: phone,
            relationship: relationship,
            isPrimary: isPrimary,
            createdAt: createdAt,
            syncedAt: syncedAt,
            pendingSync: pendingSync,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String contactUid,
            required String name,
            required String phone,
            Value<String> relationship = const Value.absent(),
            Value<bool> isPrimary = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<bool> pendingSync = const Value.absent(),
          }) =>
              LocalContactsCompanion.insert(
            id: id,
            contactUid: contactUid,
            name: name,
            phone: phone,
            relationship: relationship,
            isPrimary: isPrimary,
            createdAt: createdAt,
            syncedAt: syncedAt,
            pendingSync: pendingSync,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalContactsTable, LocalContact>(table),
                    BaseReferences<_$GuardianDatabase, $LocalContactsTable,
                        LocalContact>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalContactsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$GuardianDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()>;
typedef $$LocalAlertsTableCreateCompanionBuilder = LocalAlertsCompanion
    Function({
  required String alertId,
  required String userId,
  required String source,
  required String status,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<double?> accuracy,
  Value<String?> customMessage,
  required DateTime startedAt,
  Value<DateTime?> resolvedAt,
  Value<bool> smsSent,
  Value<int> smsCount,
  Value<bool> syncedToCloud,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LocalAlertsTableUpdateCompanionBuilder = LocalAlertsCompanion
    Function({
  Value<String> alertId,
  Value<String> userId,
  Value<String> source,
  Value<String> status,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<double?> accuracy,
  Value<String?> customMessage,
  Value<DateTime> startedAt,
  Value<DateTime?> resolvedAt,
  Value<bool> smsSent,
  Value<int> smsCount,
  Value<bool> syncedToCloud,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalAlertsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get alertId => $composableBuilder(
      column: $table.alertId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customMessage => $composableBuilder(
      column: $table.customMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get smsSent => $composableBuilder(
      column: $table.smsSent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get smsCount => $composableBuilder(
      column: $table.smsCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAlertsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get alertId => $composableBuilder(
      column: $table.alertId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customMessage => $composableBuilder(
      column: $table.customMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get smsSent => $composableBuilder(
      column: $table.smsSent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get smsCount => $composableBuilder(
      column: $table.smsCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAlertsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalAlertsTable> {
  $$LocalAlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get alertId =>
      $composableBuilder(column: $table.alertId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<String> get customMessage => $composableBuilder(
      column: $table.customMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
      column: $table.resolvedAt, builder: (column) => column);

  GeneratedColumn<bool> get smsSent =>
      $composableBuilder(column: $table.smsSent, builder: (column) => column);

  GeneratedColumn<int> get smsCount =>
      $composableBuilder(column: $table.smsCount, builder: (column) => column);

  GeneratedColumn<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAlertsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalAlertsTable,
    LocalAlert,
    $$LocalAlertsTableFilterComposer,
    $$LocalAlertsTableOrderingComposer,
    $$LocalAlertsTableAnnotationComposer,
    $$LocalAlertsTableCreateCompanionBuilder,
    $$LocalAlertsTableUpdateCompanionBuilder,
    (
      LocalAlert,
      BaseReferences<_$GuardianDatabase, $LocalAlertsTable, LocalAlert>
    ),
    LocalAlert,
    PrefetchHooks Function()> {
  $$LocalAlertsTableTableManager(_$GuardianDatabase db, $LocalAlertsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> alertId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<double?> accuracy = const Value.absent(),
            Value<String?> customMessage = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<bool> smsSent = const Value.absent(),
            Value<int> smsCount = const Value.absent(),
            Value<bool> syncedToCloud = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAlertsCompanion(
            alertId: alertId,
            userId: userId,
            source: source,
            status: status,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            customMessage: customMessage,
            startedAt: startedAt,
            resolvedAt: resolvedAt,
            smsSent: smsSent,
            smsCount: smsCount,
            syncedToCloud: syncedToCloud,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String alertId,
            required String userId,
            required String source,
            required String status,
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<double?> accuracy = const Value.absent(),
            Value<String?> customMessage = const Value.absent(),
            required DateTime startedAt,
            Value<DateTime?> resolvedAt = const Value.absent(),
            Value<bool> smsSent = const Value.absent(),
            Value<int> smsCount = const Value.absent(),
            Value<bool> syncedToCloud = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAlertsCompanion.insert(
            alertId: alertId,
            userId: userId,
            source: source,
            status: status,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            customMessage: customMessage,
            startedAt: startedAt,
            resolvedAt: resolvedAt,
            smsSent: smsSent,
            smsCount: smsCount,
            syncedToCloud: syncedToCloud,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalAlertsTable, LocalAlert>(table),
                    BaseReferences<_$GuardianDatabase, $LocalAlertsTable,
                        LocalAlert>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAlertsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalAlertsTable,
    LocalAlert,
    $$LocalAlertsTableFilterComposer,
    $$LocalAlertsTableOrderingComposer,
    $$LocalAlertsTableAnnotationComposer,
    $$LocalAlertsTableCreateCompanionBuilder,
    $$LocalAlertsTableUpdateCompanionBuilder,
    (
      LocalAlert,
      BaseReferences<_$GuardianDatabase, $LocalAlertsTable, LocalAlert>
    ),
    LocalAlert,
    PrefetchHooks Function()>;
typedef $$LocalSafeZonesTableCreateCompanionBuilder = LocalSafeZonesCompanion
    Function({
  Value<int> id,
  required String name,
  required double latitude,
  required double longitude,
  Value<double> radiusMeters,
  Value<String> type,
  Value<bool> alertOnExit,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});
typedef $$LocalSafeZonesTableUpdateCompanionBuilder = LocalSafeZonesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<double> latitude,
  Value<double> longitude,
  Value<double> radiusMeters,
  Value<String> type,
  Value<bool> alertOnExit,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});

class $$LocalSafeZonesTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalSafeZonesTable> {
  $$LocalSafeZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get radiusMeters => $composableBuilder(
      column: $table.radiusMeters, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get alertOnExit => $composableBuilder(
      column: $table.alertOnExit, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSafeZonesTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalSafeZonesTable> {
  $$LocalSafeZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get radiusMeters => $composableBuilder(
      column: $table.radiusMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get alertOnExit => $composableBuilder(
      column: $table.alertOnExit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalSafeZonesTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalSafeZonesTable> {
  $$LocalSafeZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get radiusMeters => $composableBuilder(
      column: $table.radiusMeters, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get alertOnExit => $composableBuilder(
      column: $table.alertOnExit, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalSafeZonesTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalSafeZonesTable,
    LocalSafeZone,
    $$LocalSafeZonesTableFilterComposer,
    $$LocalSafeZonesTableOrderingComposer,
    $$LocalSafeZonesTableAnnotationComposer,
    $$LocalSafeZonesTableCreateCompanionBuilder,
    $$LocalSafeZonesTableUpdateCompanionBuilder,
    (
      LocalSafeZone,
      BaseReferences<_$GuardianDatabase, $LocalSafeZonesTable, LocalSafeZone>
    ),
    LocalSafeZone,
    PrefetchHooks Function()> {
  $$LocalSafeZonesTableTableManager(
      _$GuardianDatabase db, $LocalSafeZonesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSafeZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSafeZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSafeZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double> radiusMeters = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<bool> alertOnExit = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              LocalSafeZonesCompanion(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            type: type,
            alertOnExit: alertOnExit,
            isActive: isActive,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required double latitude,
            required double longitude,
            Value<double> radiusMeters = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<bool> alertOnExit = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              LocalSafeZonesCompanion.insert(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            type: type,
            alertOnExit: alertOnExit,
            isActive: isActive,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalSafeZonesTable, LocalSafeZone>(table),
                    BaseReferences<_$GuardianDatabase, $LocalSafeZonesTable,
                        LocalSafeZone>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSafeZonesTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalSafeZonesTable,
    LocalSafeZone,
    $$LocalSafeZonesTableFilterComposer,
    $$LocalSafeZonesTableOrderingComposer,
    $$LocalSafeZonesTableAnnotationComposer,
    $$LocalSafeZonesTableCreateCompanionBuilder,
    $$LocalSafeZonesTableUpdateCompanionBuilder,
    (
      LocalSafeZone,
      BaseReferences<_$GuardianDatabase, $LocalSafeZonesTable, LocalSafeZone>
    ),
    LocalSafeZone,
    PrefetchHooks Function()>;
typedef $$LocalCheckInsTableCreateCompanionBuilder = LocalCheckInsCompanion
    Function({
  Value<int> id,
  required String title,
  required DateTime scheduledAt,
  Value<DateTime?> confirmedAt,
  Value<String> status,
  Value<int> escalationMinutes,
  Value<bool> escalated,
  Value<String?> location,
});
typedef $$LocalCheckInsTableUpdateCompanionBuilder = LocalCheckInsCompanion
    Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> scheduledAt,
  Value<DateTime?> confirmedAt,
  Value<String> status,
  Value<int> escalationMinutes,
  Value<bool> escalated,
  Value<String?> location,
});

class $$LocalCheckInsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get confirmedAt => $composableBuilder(
      column: $table.confirmedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get escalationMinutes => $composableBuilder(
      column: $table.escalationMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get escalated => $composableBuilder(
      column: $table.escalated, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));
}

class $$LocalCheckInsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get confirmedAt => $composableBuilder(
      column: $table.confirmedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get escalationMinutes => $composableBuilder(
      column: $table.escalationMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get escalated => $composableBuilder(
      column: $table.escalated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));
}

class $$LocalCheckInsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalCheckInsTable> {
  $$LocalCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => column);

  GeneratedColumn<DateTime> get confirmedAt => $composableBuilder(
      column: $table.confirmedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get escalationMinutes => $composableBuilder(
      column: $table.escalationMinutes, builder: (column) => column);

  GeneratedColumn<bool> get escalated =>
      $composableBuilder(column: $table.escalated, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);
}

class $$LocalCheckInsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalCheckInsTable,
    LocalCheckIn,
    $$LocalCheckInsTableFilterComposer,
    $$LocalCheckInsTableOrderingComposer,
    $$LocalCheckInsTableAnnotationComposer,
    $$LocalCheckInsTableCreateCompanionBuilder,
    $$LocalCheckInsTableUpdateCompanionBuilder,
    (
      LocalCheckIn,
      BaseReferences<_$GuardianDatabase, $LocalCheckInsTable, LocalCheckIn>
    ),
    LocalCheckIn,
    PrefetchHooks Function()> {
  $$LocalCheckInsTableTableManager(
      _$GuardianDatabase db, $LocalCheckInsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime> scheduledAt = const Value.absent(),
            Value<DateTime?> confirmedAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> escalationMinutes = const Value.absent(),
            Value<bool> escalated = const Value.absent(),
            Value<String?> location = const Value.absent(),
          }) =>
              LocalCheckInsCompanion(
            id: id,
            title: title,
            scheduledAt: scheduledAt,
            confirmedAt: confirmedAt,
            status: status,
            escalationMinutes: escalationMinutes,
            escalated: escalated,
            location: location,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required DateTime scheduledAt,
            Value<DateTime?> confirmedAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> escalationMinutes = const Value.absent(),
            Value<bool> escalated = const Value.absent(),
            Value<String?> location = const Value.absent(),
          }) =>
              LocalCheckInsCompanion.insert(
            id: id,
            title: title,
            scheduledAt: scheduledAt,
            confirmedAt: confirmedAt,
            status: status,
            escalationMinutes: escalationMinutes,
            escalated: escalated,
            location: location,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalCheckInsTable, LocalCheckIn>(table),
                    BaseReferences<_$GuardianDatabase, $LocalCheckInsTable,
                        LocalCheckIn>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCheckInsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalCheckInsTable,
    LocalCheckIn,
    $$LocalCheckInsTableFilterComposer,
    $$LocalCheckInsTableOrderingComposer,
    $$LocalCheckInsTableAnnotationComposer,
    $$LocalCheckInsTableCreateCompanionBuilder,
    $$LocalCheckInsTableUpdateCompanionBuilder,
    (
      LocalCheckIn,
      BaseReferences<_$GuardianDatabase, $LocalCheckInsTable, LocalCheckIn>
    ),
    LocalCheckIn,
    PrefetchHooks Function()>;
typedef $$LocalLocationLogTableCreateCompanionBuilder
    = LocalLocationLogCompanion Function({
  Value<int> id,
  required double latitude,
  required double longitude,
  required double accuracy,
  Value<double?> altitude,
  Value<double?> speed,
  Value<double?> heading,
  required String provider,
  Value<DateTime> timestamp,
});
typedef $$LocalLocationLogTableUpdateCompanionBuilder
    = LocalLocationLogCompanion Function({
  Value<int> id,
  Value<double> latitude,
  Value<double> longitude,
  Value<double> accuracy,
  Value<double?> altitude,
  Value<double?> speed,
  Value<double?> heading,
  Value<String> provider,
  Value<DateTime> timestamp,
});

class $$LocalLocationLogTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalLocationLogTable> {
  $$LocalLocationLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get altitude => $composableBuilder(
      column: $table.altitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get heading => $composableBuilder(
      column: $table.heading, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$LocalLocationLogTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalLocationLogTable> {
  $$LocalLocationLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracy => $composableBuilder(
      column: $table.accuracy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get altitude => $composableBuilder(
      column: $table.altitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get heading => $composableBuilder(
      column: $table.heading, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$LocalLocationLogTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalLocationLogTable> {
  $$LocalLocationLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get heading =>
      $composableBuilder(column: $table.heading, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$LocalLocationLogTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalLocationLogTable,
    LocalLocationLogData,
    $$LocalLocationLogTableFilterComposer,
    $$LocalLocationLogTableOrderingComposer,
    $$LocalLocationLogTableAnnotationComposer,
    $$LocalLocationLogTableCreateCompanionBuilder,
    $$LocalLocationLogTableUpdateCompanionBuilder,
    (
      LocalLocationLogData,
      BaseReferences<_$GuardianDatabase, $LocalLocationLogTable,
          LocalLocationLogData>
    ),
    LocalLocationLogData,
    PrefetchHooks Function()> {
  $$LocalLocationLogTableTableManager(
      _$GuardianDatabase db, $LocalLocationLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLocationLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLocationLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLocationLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double> accuracy = const Value.absent(),
            Value<double?> altitude = const Value.absent(),
            Value<double?> speed = const Value.absent(),
            Value<double?> heading = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              LocalLocationLogCompanion(
            id: id,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            altitude: altitude,
            speed: speed,
            heading: heading,
            provider: provider,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required double latitude,
            required double longitude,
            required double accuracy,
            Value<double?> altitude = const Value.absent(),
            Value<double?> speed = const Value.absent(),
            Value<double?> heading = const Value.absent(),
            required String provider,
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              LocalLocationLogCompanion.insert(
            id: id,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            altitude: altitude,
            speed: speed,
            heading: heading,
            provider: provider,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalLocationLogTable, LocalLocationLogData>(
                        table),
                    BaseReferences<_$GuardianDatabase, $LocalLocationLogTable,
                        LocalLocationLogData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalLocationLogTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalLocationLogTable,
    LocalLocationLogData,
    $$LocalLocationLogTableFilterComposer,
    $$LocalLocationLogTableOrderingComposer,
    $$LocalLocationLogTableAnnotationComposer,
    $$LocalLocationLogTableCreateCompanionBuilder,
    $$LocalLocationLogTableUpdateCompanionBuilder,
    (
      LocalLocationLogData,
      BaseReferences<_$GuardianDatabase, $LocalLocationLogTable,
          LocalLocationLogData>
    ),
    LocalLocationLogData,
    PrefetchHooks Function()>;
typedef $$LocalMeshBeaconsTableCreateCompanionBuilder
    = LocalMeshBeaconsCompanion Function({
  required String beaconId,
  required String userHash,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> hopCount,
  Value<int> maxHops,
  Value<bool> forwarded,
  Value<bool> relayedToCloud,
  Value<DateTime> receivedAt,
  required DateTime expiresAt,
  Value<int> rowid,
});
typedef $$LocalMeshBeaconsTableUpdateCompanionBuilder
    = LocalMeshBeaconsCompanion Function({
  Value<String> beaconId,
  Value<String> userHash,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<int> hopCount,
  Value<int> maxHops,
  Value<bool> forwarded,
  Value<bool> relayedToCloud,
  Value<DateTime> receivedAt,
  Value<DateTime> expiresAt,
  Value<int> rowid,
});

class $$LocalMeshBeaconsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalMeshBeaconsTable> {
  $$LocalMeshBeaconsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get beaconId => $composableBuilder(
      column: $table.beaconId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userHash => $composableBuilder(
      column: $table.userHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hopCount => $composableBuilder(
      column: $table.hopCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxHops => $composableBuilder(
      column: $table.maxHops, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get forwarded => $composableBuilder(
      column: $table.forwarded, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get relayedToCloud => $composableBuilder(
      column: $table.relayedToCloud,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnFilters(column));
}

class $$LocalMeshBeaconsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalMeshBeaconsTable> {
  $$LocalMeshBeaconsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get beaconId => $composableBuilder(
      column: $table.beaconId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userHash => $composableBuilder(
      column: $table.userHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hopCount => $composableBuilder(
      column: $table.hopCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxHops => $composableBuilder(
      column: $table.maxHops, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get forwarded => $composableBuilder(
      column: $table.forwarded, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get relayedToCloud => $composableBuilder(
      column: $table.relayedToCloud,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
      column: $table.expiresAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalMeshBeaconsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalMeshBeaconsTable> {
  $$LocalMeshBeaconsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get beaconId =>
      $composableBuilder(column: $table.beaconId, builder: (column) => column);

  GeneratedColumn<String> get userHash =>
      $composableBuilder(column: $table.userHash, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get hopCount =>
      $composableBuilder(column: $table.hopCount, builder: (column) => column);

  GeneratedColumn<int> get maxHops =>
      $composableBuilder(column: $table.maxHops, builder: (column) => column);

  GeneratedColumn<bool> get forwarded =>
      $composableBuilder(column: $table.forwarded, builder: (column) => column);

  GeneratedColumn<bool> get relayedToCloud => $composableBuilder(
      column: $table.relayedToCloud, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$LocalMeshBeaconsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalMeshBeaconsTable,
    LocalMeshBeacon,
    $$LocalMeshBeaconsTableFilterComposer,
    $$LocalMeshBeaconsTableOrderingComposer,
    $$LocalMeshBeaconsTableAnnotationComposer,
    $$LocalMeshBeaconsTableCreateCompanionBuilder,
    $$LocalMeshBeaconsTableUpdateCompanionBuilder,
    (
      LocalMeshBeacon,
      BaseReferences<_$GuardianDatabase, $LocalMeshBeaconsTable,
          LocalMeshBeacon>
    ),
    LocalMeshBeacon,
    PrefetchHooks Function()> {
  $$LocalMeshBeaconsTableTableManager(
      _$GuardianDatabase db, $LocalMeshBeaconsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMeshBeaconsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMeshBeaconsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMeshBeaconsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> beaconId = const Value.absent(),
            Value<String> userHash = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int> hopCount = const Value.absent(),
            Value<int> maxHops = const Value.absent(),
            Value<bool> forwarded = const Value.absent(),
            Value<bool> relayedToCloud = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<DateTime> expiresAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalMeshBeaconsCompanion(
            beaconId: beaconId,
            userHash: userHash,
            latitude: latitude,
            longitude: longitude,
            hopCount: hopCount,
            maxHops: maxHops,
            forwarded: forwarded,
            relayedToCloud: relayedToCloud,
            receivedAt: receivedAt,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String beaconId,
            required String userHash,
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<int> hopCount = const Value.absent(),
            Value<int> maxHops = const Value.absent(),
            Value<bool> forwarded = const Value.absent(),
            Value<bool> relayedToCloud = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            required DateTime expiresAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalMeshBeaconsCompanion.insert(
            beaconId: beaconId,
            userHash: userHash,
            latitude: latitude,
            longitude: longitude,
            hopCount: hopCount,
            maxHops: maxHops,
            forwarded: forwarded,
            relayedToCloud: relayedToCloud,
            receivedAt: receivedAt,
            expiresAt: expiresAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalMeshBeaconsTable, LocalMeshBeacon>(table),
                    BaseReferences<_$GuardianDatabase, $LocalMeshBeaconsTable,
                        LocalMeshBeacon>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalMeshBeaconsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalMeshBeaconsTable,
    LocalMeshBeacon,
    $$LocalMeshBeaconsTableFilterComposer,
    $$LocalMeshBeaconsTableOrderingComposer,
    $$LocalMeshBeaconsTableAnnotationComposer,
    $$LocalMeshBeaconsTableCreateCompanionBuilder,
    $$LocalMeshBeaconsTableUpdateCompanionBuilder,
    (
      LocalMeshBeacon,
      BaseReferences<_$GuardianDatabase, $LocalMeshBeaconsTable,
          LocalMeshBeacon>
    ),
    LocalMeshBeacon,
    PrefetchHooks Function()>;
typedef $$LocalIncidentsTableCreateCompanionBuilder = LocalIncidentsCompanion
    Function({
  Value<int> id,
  required String type,
  required String description,
  required double latitude,
  required double longitude,
  Value<String?> address,
  Value<bool> anonymous,
  Value<bool> syncedToCloud,
  Value<DateTime> createdAt,
});
typedef $$LocalIncidentsTableUpdateCompanionBuilder = LocalIncidentsCompanion
    Function({
  Value<int> id,
  Value<String> type,
  Value<String> description,
  Value<double> latitude,
  Value<double> longitude,
  Value<String?> address,
  Value<bool> anonymous,
  Value<bool> syncedToCloud,
  Value<DateTime> createdAt,
});

class $$LocalIncidentsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentsTable> {
  $$LocalIncidentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get anonymous => $composableBuilder(
      column: $table.anonymous, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalIncidentsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentsTable> {
  $$LocalIncidentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get anonymous => $composableBuilder(
      column: $table.anonymous, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalIncidentsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentsTable> {
  $$LocalIncidentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<bool> get anonymous =>
      $composableBuilder(column: $table.anonymous, builder: (column) => column);

  GeneratedColumn<bool> get syncedToCloud => $composableBuilder(
      column: $table.syncedToCloud, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalIncidentsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalIncidentsTable,
    LocalIncident,
    $$LocalIncidentsTableFilterComposer,
    $$LocalIncidentsTableOrderingComposer,
    $$LocalIncidentsTableAnnotationComposer,
    $$LocalIncidentsTableCreateCompanionBuilder,
    $$LocalIncidentsTableUpdateCompanionBuilder,
    (
      LocalIncident,
      BaseReferences<_$GuardianDatabase, $LocalIncidentsTable, LocalIncident>
    ),
    LocalIncident,
    PrefetchHooks Function()> {
  $$LocalIncidentsTableTableManager(
      _$GuardianDatabase db, $LocalIncidentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalIncidentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalIncidentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalIncidentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<bool> anonymous = const Value.absent(),
            Value<bool> syncedToCloud = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              LocalIncidentsCompanion(
            id: id,
            type: type,
            description: description,
            latitude: latitude,
            longitude: longitude,
            address: address,
            anonymous: anonymous,
            syncedToCloud: syncedToCloud,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String type,
            required String description,
            required double latitude,
            required double longitude,
            Value<String?> address = const Value.absent(),
            Value<bool> anonymous = const Value.absent(),
            Value<bool> syncedToCloud = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              LocalIncidentsCompanion.insert(
            id: id,
            type: type,
            description: description,
            latitude: latitude,
            longitude: longitude,
            address: address,
            anonymous: anonymous,
            syncedToCloud: syncedToCloud,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalIncidentsTable, LocalIncident>(table),
                    BaseReferences<_$GuardianDatabase, $LocalIncidentsTable,
                        LocalIncident>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalIncidentsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalIncidentsTable,
    LocalIncident,
    $$LocalIncidentsTableFilterComposer,
    $$LocalIncidentsTableOrderingComposer,
    $$LocalIncidentsTableAnnotationComposer,
    $$LocalIncidentsTableCreateCompanionBuilder,
    $$LocalIncidentsTableUpdateCompanionBuilder,
    (
      LocalIncident,
      BaseReferences<_$GuardianDatabase, $LocalIncidentsTable, LocalIncident>
    ),
    LocalIncident,
    PrefetchHooks Function()>;
typedef $$LocalIncidentEventsTableCreateCompanionBuilder
    = LocalIncidentEventsCompanion Function({
  required String eventId,
  required String incidentId,
  required String eventType,
  required String incidentState,
  required String actorType,
  Value<String?> actorId,
  Value<String> payloadJson,
  required DateTime occurredAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LocalIncidentEventsTableUpdateCompanionBuilder
    = LocalIncidentEventsCompanion Function({
  Value<String> eventId,
  Value<String> incidentId,
  Value<String> eventType,
  Value<String> incidentState,
  Value<String> actorType,
  Value<String?> actorId,
  Value<String> payloadJson,
  Value<DateTime> occurredAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalIncidentEventsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentEventsTable> {
  $$LocalIncidentEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get incidentState => $composableBuilder(
      column: $table.incidentState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorType => $composableBuilder(
      column: $table.actorType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalIncidentEventsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentEventsTable> {
  $$LocalIncidentEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get incidentState => $composableBuilder(
      column: $table.incidentState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorType => $composableBuilder(
      column: $table.actorType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalIncidentEventsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalIncidentEventsTable> {
  $$LocalIncidentEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get incidentState => $composableBuilder(
      column: $table.incidentState, builder: (column) => column);

  GeneratedColumn<String> get actorType =>
      $composableBuilder(column: $table.actorType, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalIncidentEventsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalIncidentEventsTable,
    LocalIncidentEvent,
    $$LocalIncidentEventsTableFilterComposer,
    $$LocalIncidentEventsTableOrderingComposer,
    $$LocalIncidentEventsTableAnnotationComposer,
    $$LocalIncidentEventsTableCreateCompanionBuilder,
    $$LocalIncidentEventsTableUpdateCompanionBuilder,
    (
      LocalIncidentEvent,
      BaseReferences<_$GuardianDatabase, $LocalIncidentEventsTable,
          LocalIncidentEvent>
    ),
    LocalIncidentEvent,
    PrefetchHooks Function()> {
  $$LocalIncidentEventsTableTableManager(
      _$GuardianDatabase db, $LocalIncidentEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalIncidentEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalIncidentEventsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalIncidentEventsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> eventId = const Value.absent(),
            Value<String> incidentId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<String> incidentState = const Value.absent(),
            Value<String> actorType = const Value.absent(),
            Value<String?> actorId = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalIncidentEventsCompanion(
            eventId: eventId,
            incidentId: incidentId,
            eventType: eventType,
            incidentState: incidentState,
            actorType: actorType,
            actorId: actorId,
            payloadJson: payloadJson,
            occurredAt: occurredAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String eventId,
            required String incidentId,
            required String eventType,
            required String incidentState,
            required String actorType,
            Value<String?> actorId = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            required DateTime occurredAt,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalIncidentEventsCompanion.insert(
            eventId: eventId,
            incidentId: incidentId,
            eventType: eventType,
            incidentState: incidentState,
            actorType: actorType,
            actorId: actorId,
            payloadJson: payloadJson,
            occurredAt: occurredAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalIncidentEventsTable, LocalIncidentEvent>(
                        table),
                    BaseReferences<
                        _$GuardianDatabase,
                        $LocalIncidentEventsTable,
                        LocalIncidentEvent>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalIncidentEventsTableProcessedTableManager = ProcessedTableManager<
    _$GuardianDatabase,
    $LocalIncidentEventsTable,
    LocalIncidentEvent,
    $$LocalIncidentEventsTableFilterComposer,
    $$LocalIncidentEventsTableOrderingComposer,
    $$LocalIncidentEventsTableAnnotationComposer,
    $$LocalIncidentEventsTableCreateCompanionBuilder,
    $$LocalIncidentEventsTableUpdateCompanionBuilder,
    (
      LocalIncidentEvent,
      BaseReferences<_$GuardianDatabase, $LocalIncidentEventsTable,
          LocalIncidentEvent>
    ),
    LocalIncidentEvent,
    PrefetchHooks Function()>;
typedef $$LocalOutboxOperationsTableCreateCompanionBuilder
    = LocalOutboxOperationsCompanion Function({
  required String operationId,
  required String aggregateType,
  required String aggregateId,
  required String operationType,
  required String payloadJson,
  Value<String?> dependencyId,
  Value<String> status,
  Value<int> attemptCount,
  Value<DateTime> nextAttemptAt,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LocalOutboxOperationsTableUpdateCompanionBuilder
    = LocalOutboxOperationsCompanion Function({
  Value<String> operationId,
  Value<String> aggregateType,
  Value<String> aggregateId,
  Value<String> operationType,
  Value<String> payloadJson,
  Value<String?> dependencyId,
  Value<String> status,
  Value<int> attemptCount,
  Value<DateTime> nextAttemptAt,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalOutboxOperationsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalOutboxOperationsTable> {
  $$LocalOutboxOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dependencyId => $composableBuilder(
      column: $table.dependencyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalOutboxOperationsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalOutboxOperationsTable> {
  $$LocalOutboxOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationType => $composableBuilder(
      column: $table.operationType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dependencyId => $composableBuilder(
      column: $table.dependencyId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalOutboxOperationsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalOutboxOperationsTable> {
  $$LocalOutboxOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get aggregateType => $composableBuilder(
      column: $table.aggregateType, builder: (column) => column);

  GeneratedColumn<String> get aggregateId => $composableBuilder(
      column: $table.aggregateId, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
      column: $table.operationType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get dependencyId => $composableBuilder(
      column: $table.dependencyId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalOutboxOperationsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalOutboxOperationsTable,
    LocalOutboxOperation,
    $$LocalOutboxOperationsTableFilterComposer,
    $$LocalOutboxOperationsTableOrderingComposer,
    $$LocalOutboxOperationsTableAnnotationComposer,
    $$LocalOutboxOperationsTableCreateCompanionBuilder,
    $$LocalOutboxOperationsTableUpdateCompanionBuilder,
    (
      LocalOutboxOperation,
      BaseReferences<_$GuardianDatabase, $LocalOutboxOperationsTable,
          LocalOutboxOperation>
    ),
    LocalOutboxOperation,
    PrefetchHooks Function()> {
  $$LocalOutboxOperationsTableTableManager(
      _$GuardianDatabase db, $LocalOutboxOperationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalOutboxOperationsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalOutboxOperationsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalOutboxOperationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> operationId = const Value.absent(),
            Value<String> aggregateType = const Value.absent(),
            Value<String> aggregateId = const Value.absent(),
            Value<String> operationType = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String?> dependencyId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalOutboxOperationsCompanion(
            operationId: operationId,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            operationType: operationType,
            payloadJson: payloadJson,
            dependencyId: dependencyId,
            status: status,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String operationId,
            required String aggregateType,
            required String aggregateId,
            required String operationType,
            required String payloadJson,
            Value<String?> dependencyId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<DateTime> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalOutboxOperationsCompanion.insert(
            operationId: operationId,
            aggregateType: aggregateType,
            aggregateId: aggregateId,
            operationType: operationType,
            payloadJson: payloadJson,
            dependencyId: dependencyId,
            status: status,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalOutboxOperationsTable,
                        LocalOutboxOperation>(table),
                    BaseReferences<
                        _$GuardianDatabase,
                        $LocalOutboxOperationsTable,
                        LocalOutboxOperation>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalOutboxOperationsTableProcessedTableManager
    = ProcessedTableManager<
        _$GuardianDatabase,
        $LocalOutboxOperationsTable,
        LocalOutboxOperation,
        $$LocalOutboxOperationsTableFilterComposer,
        $$LocalOutboxOperationsTableOrderingComposer,
        $$LocalOutboxOperationsTableAnnotationComposer,
        $$LocalOutboxOperationsTableCreateCompanionBuilder,
        $$LocalOutboxOperationsTableUpdateCompanionBuilder,
        (
          LocalOutboxOperation,
          BaseReferences<_$GuardianDatabase, $LocalOutboxOperationsTable,
              LocalOutboxOperation>
        ),
        LocalOutboxOperation,
        PrefetchHooks Function()>;
typedef $$LocalDeliveryAttemptsTableCreateCompanionBuilder
    = LocalDeliveryAttemptsCompanion Function({
  required String attemptId,
  required String incidentId,
  required String channel,
  required String recipientRef,
  required String status,
  Value<String?> providerMessageId,
  Value<String?> failureCode,
  required DateTime queuedAt,
  required DateTime updatedAt,
  Value<DateTime?> acknowledgedAt,
  Value<int> rowid,
});
typedef $$LocalDeliveryAttemptsTableUpdateCompanionBuilder
    = LocalDeliveryAttemptsCompanion Function({
  Value<String> attemptId,
  Value<String> incidentId,
  Value<String> channel,
  Value<String> recipientRef,
  Value<String> status,
  Value<String?> providerMessageId,
  Value<String?> failureCode,
  Value<DateTime> queuedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> acknowledgedAt,
  Value<int> rowid,
});

class $$LocalDeliveryAttemptsTableFilterComposer
    extends Composer<_$GuardianDatabase, $LocalDeliveryAttemptsTable> {
  $$LocalDeliveryAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get attemptId => $composableBuilder(
      column: $table.attemptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipientRef => $composableBuilder(
      column: $table.recipientRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerMessageId => $composableBuilder(
      column: $table.providerMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get failureCode => $composableBuilder(
      column: $table.failureCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get acknowledgedAt => $composableBuilder(
      column: $table.acknowledgedAt,
      builder: (column) => ColumnFilters(column));
}

class $$LocalDeliveryAttemptsTableOrderingComposer
    extends Composer<_$GuardianDatabase, $LocalDeliveryAttemptsTable> {
  $$LocalDeliveryAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get attemptId => $composableBuilder(
      column: $table.attemptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get channel => $composableBuilder(
      column: $table.channel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipientRef => $composableBuilder(
      column: $table.recipientRef,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerMessageId => $composableBuilder(
      column: $table.providerMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get failureCode => $composableBuilder(
      column: $table.failureCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get acknowledgedAt => $composableBuilder(
      column: $table.acknowledgedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalDeliveryAttemptsTableAnnotationComposer
    extends Composer<_$GuardianDatabase, $LocalDeliveryAttemptsTable> {
  $$LocalDeliveryAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get incidentId => $composableBuilder(
      column: $table.incidentId, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<String> get recipientRef => $composableBuilder(
      column: $table.recipientRef, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get providerMessageId => $composableBuilder(
      column: $table.providerMessageId, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
      column: $table.failureCode, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get acknowledgedAt => $composableBuilder(
      column: $table.acknowledgedAt, builder: (column) => column);
}

class $$LocalDeliveryAttemptsTableTableManager extends RootTableManager<
    _$GuardianDatabase,
    $LocalDeliveryAttemptsTable,
    LocalDeliveryAttempt,
    $$LocalDeliveryAttemptsTableFilterComposer,
    $$LocalDeliveryAttemptsTableOrderingComposer,
    $$LocalDeliveryAttemptsTableAnnotationComposer,
    $$LocalDeliveryAttemptsTableCreateCompanionBuilder,
    $$LocalDeliveryAttemptsTableUpdateCompanionBuilder,
    (
      LocalDeliveryAttempt,
      BaseReferences<_$GuardianDatabase, $LocalDeliveryAttemptsTable,
          LocalDeliveryAttempt>
    ),
    LocalDeliveryAttempt,
    PrefetchHooks Function()> {
  $$LocalDeliveryAttemptsTableTableManager(
      _$GuardianDatabase db, $LocalDeliveryAttemptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDeliveryAttemptsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDeliveryAttemptsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDeliveryAttemptsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> attemptId = const Value.absent(),
            Value<String> incidentId = const Value.absent(),
            Value<String> channel = const Value.absent(),
            Value<String> recipientRef = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> providerMessageId = const Value.absent(),
            Value<String?> failureCode = const Value.absent(),
            Value<DateTime> queuedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> acknowledgedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDeliveryAttemptsCompanion(
            attemptId: attemptId,
            incidentId: incidentId,
            channel: channel,
            recipientRef: recipientRef,
            status: status,
            providerMessageId: providerMessageId,
            failureCode: failureCode,
            queuedAt: queuedAt,
            updatedAt: updatedAt,
            acknowledgedAt: acknowledgedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String attemptId,
            required String incidentId,
            required String channel,
            required String recipientRef,
            required String status,
            Value<String?> providerMessageId = const Value.absent(),
            Value<String?> failureCode = const Value.absent(),
            required DateTime queuedAt,
            required DateTime updatedAt,
            Value<DateTime?> acknowledgedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalDeliveryAttemptsCompanion.insert(
            attemptId: attemptId,
            incidentId: incidentId,
            channel: channel,
            recipientRef: recipientRef,
            status: status,
            providerMessageId: providerMessageId,
            failureCode: failureCode,
            queuedAt: queuedAt,
            updatedAt: updatedAt,
            acknowledgedAt: acknowledgedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalDeliveryAttemptsTable,
                        LocalDeliveryAttempt>(table),
                    BaseReferences<
                        _$GuardianDatabase,
                        $LocalDeliveryAttemptsTable,
                        LocalDeliveryAttempt>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalDeliveryAttemptsTableProcessedTableManager
    = ProcessedTableManager<
        _$GuardianDatabase,
        $LocalDeliveryAttemptsTable,
        LocalDeliveryAttempt,
        $$LocalDeliveryAttemptsTableFilterComposer,
        $$LocalDeliveryAttemptsTableOrderingComposer,
        $$LocalDeliveryAttemptsTableAnnotationComposer,
        $$LocalDeliveryAttemptsTableCreateCompanionBuilder,
        $$LocalDeliveryAttemptsTableUpdateCompanionBuilder,
        (
          LocalDeliveryAttempt,
          BaseReferences<_$GuardianDatabase, $LocalDeliveryAttemptsTable,
              LocalDeliveryAttempt>
        ),
        LocalDeliveryAttempt,
        PrefetchHooks Function()>;

class $GuardianDatabaseManager {
  final _$GuardianDatabase _db;
  $GuardianDatabaseManager(this._db);
  $$LocalContactsTableTableManager get localContacts =>
      $$LocalContactsTableTableManager(_db, _db.localContacts);
  $$LocalAlertsTableTableManager get localAlerts =>
      $$LocalAlertsTableTableManager(_db, _db.localAlerts);
  $$LocalSafeZonesTableTableManager get localSafeZones =>
      $$LocalSafeZonesTableTableManager(_db, _db.localSafeZones);
  $$LocalCheckInsTableTableManager get localCheckIns =>
      $$LocalCheckInsTableTableManager(_db, _db.localCheckIns);
  $$LocalLocationLogTableTableManager get localLocationLog =>
      $$LocalLocationLogTableTableManager(_db, _db.localLocationLog);
  $$LocalMeshBeaconsTableTableManager get localMeshBeacons =>
      $$LocalMeshBeaconsTableTableManager(_db, _db.localMeshBeacons);
  $$LocalIncidentsTableTableManager get localIncidents =>
      $$LocalIncidentsTableTableManager(_db, _db.localIncidents);
  $$LocalIncidentEventsTableTableManager get localIncidentEvents =>
      $$LocalIncidentEventsTableTableManager(_db, _db.localIncidentEvents);
  $$LocalOutboxOperationsTableTableManager get localOutboxOperations =>
      $$LocalOutboxOperationsTableTableManager(_db, _db.localOutboxOperations);
  $$LocalDeliveryAttemptsTableTableManager get localDeliveryAttempts =>
      $$LocalDeliveryAttemptsTableTableManager(_db, _db.localDeliveryAttempts);
}
