import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../../platform/secret_store.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import 'sync_delete_tombstone_repository.dart';

class SyncDeviceMetadata {
  const SyncDeviceMetadata({
    required this.id,
    required this.displayName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String id;
  final String displayName;
  final String platform;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  SyncDeviceMetadata copyWith({
    String? displayName,
    String? platform,
    DateTime? lastSeenAt,
  }) {
    return SyncDeviceMetadata(
      id: id,
      displayName: displayName ?? this.displayName,
      platform: platform ?? this.platform,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'platform': platform,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
    };
  }

  factory SyncDeviceMetadata.fromJson(Map<String, Object?> json) {
    return SyncDeviceMetadata(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
    );
  }
}

abstract interface class SyncDeviceRepository {
  Future<SyncDeviceMetadata?> read(String id);
  Future<void> save(SyncDeviceMetadata device);
  Future<List<SyncDeviceMetadata>> list();
  Future<void> delete(String id);
}

class EncryptedSyncDeviceRepository implements SyncDeviceRepository {
  EncryptedSyncDeviceRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedSyncDeviceRepository._(this._vault, this._records);

  static const recordType = 'sync_device';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<SyncDeviceMetadata?> read(String id) async {
    final envelope = await _records.read(_deviceRecordId(id));
    if (envelope == null) {
      return null;
    }
    final plaintext = await _vault.decryptRecord(envelope);
    return SyncDeviceMetadata.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }

  @override
  Future<void> save(SyncDeviceMetadata device) async {
    final envelope = await _vault.encryptRecord(
      id: _deviceRecordId(device.id),
      type: recordType,
      plaintext: utf8.encode(jsonEncode(device.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<List<SyncDeviceMetadata>> list() async {
    final envelopes = await _records.list(type: recordType);
    final devices = <SyncDeviceMetadata>[];
    for (final envelope in envelopes) {
      final plaintext = await _vault.decryptRecord(envelope);
      devices.add(
        SyncDeviceMetadata.fromJson(
          jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
        ),
      );
    }
    devices.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return byName == 0 ? a.id.compareTo(b.id) : byName;
    });
    return devices;
  }

  @override
  Future<void> delete(String id) async {
    await _records.delete(_deviceRecordId(id));
  }
}

class SyncDeviceException implements Exception {
  const SyncDeviceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SyncDeviceException($code): $message';
}

typedef SyncDeviceDisplayNameResolver = Future<String?> Function();

class SyncDeviceService {
  SyncDeviceService({
    required SyncDeviceRepository devices,
    required SecretStore secrets,
    SyncDeleteTombstoneRepository? tombstones,
    Uuid? uuid,
    DateTime Function()? now,
    String? displayName,
    SyncDeviceDisplayNameResolver? displayNameResolver,
    String Function()? fallbackHostname,
    String? platform,
  }) : this._(
         devices,
         secrets,
         tombstones,
         uuid ?? const Uuid(),
         now ?? DateTime.now,
         displayName,
         displayNameResolver,
         fallbackHostname ?? (() => Platform.localHostname),
         platform,
       );

  SyncDeviceService._(
    this._devices,
    this._secrets,
    this._tombstones,
    this._uuid,
    this._now,
    this._displayName,
    this._displayNameResolver,
    this._fallbackHostname,
    this._platform,
  );

  static const _localDeviceIdRef = SecretRef('sync:device:id');

  final SyncDeviceRepository _devices;
  final SecretStore _secrets;
  final SyncDeleteTombstoneRepository? _tombstones;
  final Uuid _uuid;
  final DateTime Function() _now;
  final String? _displayName;
  final SyncDeviceDisplayNameResolver? _displayNameResolver;
  final String Function() _fallbackHostname;
  final String? _platform;

  Future<SyncDeviceMetadata?> readLocalDevice() async {
    final id = await _readLocalDeviceId();
    return id == null ? null : _devices.read(id);
  }

  Future<SyncDeviceMetadata> touchLocalDevice({String? displayName}) async {
    final id = await _readOrCreateLocalDeviceId();
    await _ensureLocalDeviceNotRevoked(id);
    final existing = await _devices.read(id);
    final now = _now().toUtc();
    final resolvedDisplayName = await _resolveDisplayName(
      requested: displayName,
      existing: existing?.displayName,
    );
    final device =
        existing?.copyWith(
          displayName: resolvedDisplayName,
          platform: _platformName,
          lastSeenAt: now,
        ) ??
        SyncDeviceMetadata(
          id: id,
          displayName: resolvedDisplayName,
          platform: _platformName,
          createdAt: now,
          lastSeenAt: now,
        );
    await _devices.save(device);
    return device;
  }

  Future<List<SyncDeviceMetadata>> listKnownDevices() {
    return _devices.list();
  }

  Future<void> deleteKnownDevice(String id) async {
    final localDeviceId = await _readLocalDeviceId();
    if (id == localDeviceId) {
      throw const SyncDeviceException(
        'sync.device.delete_local_blocked',
        'This device is the current device and cannot be removed.',
      );
    }
    await _tombstones?.save(
      SyncDeleteTombstone(
        targetRecordId: _deviceRecordId(id),
        targetRecordType: EncryptedSyncDeviceRepository.recordType,
        deletedAt: _now().toUtc(),
      ),
    );
    await _devices.delete(id);
  }

  Future<SyncDeviceMetadata> rotateLocalDeviceRegistration({
    String? displayName,
  }) async {
    final localDeviceId = await _readLocalDeviceId();
    final existing = localDeviceId == null
        ? null
        : await _devices.read(localDeviceId);
    final now = _now().toUtc();
    if (localDeviceId != null) {
      await _tombstones?.save(
        SyncDeleteTombstone(
          targetRecordId: _deviceRecordId(localDeviceId),
          targetRecordType: EncryptedSyncDeviceRepository.recordType,
          deletedAt: now,
        ),
      );
      await _devices.delete(localDeviceId);
      await _secrets.delete(_localDeviceIdRef);
    }
    return touchLocalDevice(
      displayName: displayName ?? _preservedDisplayName(existing?.displayName),
    );
  }

  Future<void> _ensureLocalDeviceNotRevoked(String id) async {
    final tombstones = await _tombstones?.list();
    if (tombstones == null) {
      return;
    }
    final localRecordId = _deviceRecordId(id);
    for (final tombstone in tombstones) {
      if (tombstone.targetRecordId == localRecordId &&
          tombstone.targetRecordType ==
              EncryptedSyncDeviceRepository.recordType) {
        throw const SyncDeviceException(
          'sync.device.revoked',
          'This device has been removed from encrypted sync. Re-enable sync with a new device registration.',
        );
      }
    }
  }

  Future<String?> _readLocalDeviceId() async {
    final value = await _secrets.read(_localDeviceIdRef);
    if (value == null) {
      return null;
    }
    return utf8.decode(value);
  }

  Future<String> _readOrCreateLocalDeviceId() async {
    final existing = await _readLocalDeviceId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = _uuid.v4();
    await _secrets.write(_localDeviceIdRef, utf8.encode(id));
    return id;
  }

  Future<String> _resolveDisplayName({
    required String? requested,
    required String? existing,
  }) async {
    final requestedName = _usableDisplayName(requested);
    if (requestedName != null) {
      return requestedName;
    }
    final configuredName = _usableDisplayName(_displayName);
    if (configuredName != null) {
      return configuredName;
    }
    final existingName = _usableDisplayName(existing);
    if (existingName != null && !_isFallbackDisplayName(existingName)) {
      return existingName;
    }
    final resolvedName = _usableDisplayName(await _displayNameResolver?.call());
    if (resolvedName != null) {
      return resolvedName;
    }
    final hostname = _usableDisplayName(_fallbackHostname());
    if (hostname != null) {
      return hostname;
    }
    return existingName ?? 'This device';
  }

  String get _platformName => _platform ?? Platform.operatingSystem;
}

String? _preservedDisplayName(String? value) {
  final displayName = _usableDisplayName(value);
  return displayName == null || _isFallbackDisplayName(displayName)
      ? null
      : displayName;
}

String? _usableDisplayName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final lower = trimmed.toLowerCase();
  if (lower == 'localhost' ||
      lower == 'localhost.localdomain' ||
      lower == '127.0.0.1' ||
      lower == '::1') {
    return null;
  }
  return trimmed;
}

bool _isFallbackDisplayName(String value) {
  return value.trim().toLowerCase() == 'this device';
}

VaultRecordId syncDeviceRecordId(String id) => VaultRecordId('sync:device:$id');

VaultRecordId _deviceRecordId(String id) => syncDeviceRecordId(id);
