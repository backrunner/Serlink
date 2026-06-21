import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/sync_provider.dart';
import 'sync_delete_tombstone_repository.dart';
import 'sync_device_service.dart';
import 'sync_field_merge_service.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.recordsUploaded,
    this.recordsDownloaded = 0,
    this.recordsUnchanged = 0,
    required this.headerUploaded,
    required this.completedAt,
    this.writerDevice,
    this.remoteDevice,
  });

  final int recordsUploaded;
  final int recordsDownloaded;
  final int recordsUnchanged;
  final bool headerUploaded;
  final DateTime completedAt;
  final SyncDeviceMetadata? writerDevice;
  final SyncDeviceMetadata? remoteDevice;
}

class SyncRecordConflict {
  const SyncRecordConflict({
    required this.id,
    required this.type,
    required this.localRevision,
    required this.remoteRevision,
    this.fieldSet,
  });

  final VaultRecordId id;
  final String type;
  final String localRevision;
  final String remoteRevision;
  final SyncConflictFieldSet? fieldSet;
}

class SyncPullResult {
  const SyncPullResult({
    required this.recordsDownloaded,
    required this.recordsUnchanged,
    required this.conflicts,
    this.remoteDevice,
    this.remoteManifest,
  });

  final int recordsDownloaded;
  final int recordsUnchanged;
  final List<SyncRecordConflict> conflicts;
  final SyncDeviceMetadata? remoteDevice;
  final RemoteManifest? remoteManifest;

  bool get hasConflicts => conflicts.isNotEmpty;
}

class SyncMergedConflict {
  const SyncMergedConflict({required this.conflict, required this.mergedJson});

  final SyncRecordConflict conflict;
  final Map<String, Object?> mergedJson;
}

enum SyncConflictResolution { keepLocal, useRemote }

enum _SyncConflictPolicy { report, useRemote, useLatest }

enum _RecordSource { local, remote }

class RemoteResetMarker {
  const RemoteResetMarker({
    required this.vaultId,
    required this.resetAt,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String vaultId;
  final DateTime resetAt;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'vaultId': vaultId,
      'resetAt': resetAt.toUtc().toIso8601String(),
    };
  }

  factory RemoteResetMarker.fromJson(Map<String, Object?> json) {
    return RemoteResetMarker(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      vaultId: json['vaultId'] as String,
      resetAt: DateTime.parse(json['resetAt'] as String),
    );
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory RemoteResetMarker.fromBytes(List<int> bytes) {
    try {
      return RemoteResetMarker.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
      );
    } on Object {
      throw const SyncRunException(
        'sync.remote_reset_marker_invalid',
        'Remote vault reset marker is invalid.',
      );
    }
  }
}

class SyncRunException implements Exception {
  const SyncRunException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SyncRunException($code): $message';
}

class SyncRunService {
  const SyncRunService({
    required VaultService vault,
    required VaultRecordRepository records,
    SyncDeviceService? devices,
    SyncFieldMergeService? fieldMerge,
    Future<bool> Function()? localDataHealthy,
  }) : this._(
         vault,
         records,
         devices,
         fieldMerge ?? const SyncFieldMergeService(),
         localDataHealthy,
       );

  const SyncRunService._(
    this._vault,
    this._records,
    this._devices,
    this._fieldMerge,
    this._localDataHealthy,
  );

  final VaultService _vault;
  final VaultRecordRepository _records;
  final SyncDeviceService? _devices;
  final SyncFieldMergeService _fieldMerge;
  final Future<bool> Function()? _localDataHealthy;

  Future<RemoteResetMarker?> readRemoteResetMarker(
    SyncProvider provider,
  ) async {
    final header = _vault.header;
    if (header == null) {
      return null;
    }
    try {
      final marker = RemoteResetMarker.fromBytes(
        await provider.readObject(resetMarkerRef),
      );
      return marker.vaultId == syncVaultId(header) ? marker : null;
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        return null;
      }
      rethrow;
    }
  }

  Future<bool> isRemoteReset(SyncProvider provider) async {
    return await readRemoteResetMarker(provider) != null;
  }

  Future<void> publishRemoteReset(SyncProvider provider) async {
    final header = _vault.header;
    if (header == null) {
      throw const SyncRunException(
        'sync.vault_header_missing',
        'Vault header is missing.',
      );
    }
    final manifest = await provider.readManifest();
    if (manifest == null || manifest.vaultId != syncVaultId(header)) {
      return;
    }
    await provider.writeObject(
      resetMarkerRef,
      RemoteResetMarker(
        vaultId: syncVaultId(header),
        resetAt: DateTime.now().toUtc(),
      ).toBytes(),
    );
    await _clearRemoteSnapshot(provider);
  }

  Future<SyncRunResult> syncEncryptedSnapshot(
    SyncProvider provider, {
    bool reportConflicts = false,
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _syncEncryptedSnapshotOnce(
          provider,
          reportConflicts: reportConflicts,
        );
      } on SyncProviderException catch (error) {
        if (attempt == 0 && _isRemoteManifestWriteConflict(error)) {
          continue;
        }
        rethrow;
      }
    }
    throw const SyncRunException(
      'sync.provider.conflict',
      'Remote sync data changed while syncing.',
    );
  }

  Future<SyncRunResult> _syncEncryptedSnapshotOnce(
    SyncProvider provider, {
    required bool reportConflicts,
  }) async {
    if (await isRemoteReset(provider)) {
      throw const SyncRunException(
        'sync.remote_vault_reset',
        'Remote vault was reset.',
      );
    }
    final pull = await pullEncryptedSnapshot(
      provider,
      missingManifestOk: true,
      reportConflicts: reportConflicts,
    );
    if (pull.hasConflicts) {
      throw SyncRunConflictException(pull.conflicts);
    }
    final localDeviceRegistered = await _localSyncDeviceRegistered();
    if (localDeviceRegistered &&
        pull.remoteManifest != null &&
        await _remoteSnapshotMatchesLocal(provider, pull.remoteManifest!)) {
      return SyncRunResult(
        recordsUploaded: 0,
        recordsDownloaded: pull.recordsDownloaded,
        recordsUnchanged: pull.recordsUnchanged,
        headerUploaded: false,
        completedAt: DateTime.now().toUtc(),
        remoteDevice: pull.remoteDevice,
      );
    }
    final push = await _pushEncryptedSnapshot(
      provider,
      pruneRemote: true,
      expectedRemoteManifest: pull.remoteManifest,
    );
    return SyncRunResult(
      recordsUploaded: push.recordsUploaded,
      recordsDownloaded: pull.recordsDownloaded,
      recordsUnchanged: pull.recordsUnchanged,
      headerUploaded: push.headerUploaded,
      completedAt: push.completedAt,
      writerDevice: push.writerDevice,
      remoteDevice: pull.remoteDevice,
    );
  }

  Future<SyncPullResult> pullEncryptedSnapshot(
    SyncProvider provider, {
    bool missingManifestOk = false,
    bool reportConflicts = false,
  }) {
    return _pullEncryptedSnapshot(
      provider,
      missingManifestOk: missingManifestOk,
      conflictPolicy: reportConflicts
          ? _SyncConflictPolicy.report
          : _SyncConflictPolicy.useLatest,
    );
  }

  Future<SyncPullResult> _pullEncryptedSnapshot(
    SyncProvider provider, {
    bool missingManifestOk = false,
    _SyncConflictPolicy conflictPolicy = _SyncConflictPolicy.report,
  }) async {
    _ensureUnlocked();
    if (await isRemoteReset(provider)) {
      throw const SyncRunException(
        'sync.remote_vault_reset',
        'Remote vault was reset.',
      );
    }
    final manifest = await provider.readManifest();
    if (manifest == null) {
      if (missingManifestOk) {
        return const SyncPullResult(
          recordsDownloaded: 0,
          recordsUnchanged: 0,
          conflicts: [],
        );
      }
      throw const SyncRunException(
        'sync.remote_manifest_missing',
        'Remote sync manifest is missing.',
      );
    }
    _validateRemoteManifestIdentity(manifest);

    final manifestData = await _decryptManifest(manifest);
    final recordEntries = _manifestRecords(manifestData);
    final recordEntriesById = {
      for (final entry in recordEntries) entry.id: entry,
    };
    final remoteDevice = _manifestWriterDevice(manifestData);
    final localTombstones = await _localTombstones();
    final tombstonesToDelete = <VaultRecordId>{};
    final conflicts = <SyncRecordConflict>[];
    final remoteTombstones = <SyncDeleteTombstone>[];
    var downloaded = 0;
    var unchanged = 0;

    for (final entry in recordEntries) {
      final remoteEnvelope = await _readRemoteEnvelope(provider, entry.ref);
      _validateRemoteEnvelopeEntry(remoteEnvelope, entry);

      if (remoteEnvelope.type ==
          EncryptedSyncDeleteTombstoneRepository.recordType) {
        final tombstone = await _decodeTombstone(
          remoteEnvelope,
          source: _RecordSource.remote,
        );
        remoteTombstones.add(tombstone);
        final localEnvelope = await _records.read(remoteEnvelope.id);
        if (localEnvelope == null ||
            localEnvelope.revision != remoteEnvelope.revision) {
          await _records.upsert(remoteEnvelope);
          downloaded += 1;
        } else {
          unchanged += 1;
        }
        continue;
      }

      final localTombstone = localTombstones[remoteEnvelope.id];
      if (localTombstone != null) {
        final remoteModifiedAt = await _recordModifiedAt(
          remoteEnvelope,
          source: _RecordSource.remote,
          provider: provider,
          manifestEntriesById: recordEntriesById,
        );
        if (remoteModifiedAt != null &&
            remoteModifiedAt.isAfter(localTombstone.deletedAt)) {
          tombstonesToDelete.add(tombstoneRecordId(remoteEnvelope.id));
          await _records.upsert(remoteEnvelope);
          downloaded += 1;
        } else {
          unchanged += 1;
        }
        continue;
      }

      final localEnvelope = await _records.read(remoteEnvelope.id);
      if (localEnvelope == null) {
        await _records.upsert(remoteEnvelope);
        downloaded += 1;
        continue;
      }
      if (localEnvelope.revision == remoteEnvelope.revision) {
        unchanged += 1;
        continue;
      }
      if (_shouldAutoResolveMetadataConflict(remoteEnvelope.type)) {
        if (await _remoteRecordWins(
          localEnvelope: localEnvelope,
          remoteEnvelope: remoteEnvelope,
          provider: provider,
          manifestEntriesById: recordEntriesById,
        )) {
          await _records.upsert(remoteEnvelope);
          downloaded += 1;
        } else {
          unchanged += 1;
        }
        continue;
      }
      if (conflictPolicy == _SyncConflictPolicy.useRemote) {
        await _records.upsert(remoteEnvelope);
        downloaded += 1;
        continue;
      }
      if (conflictPolicy == _SyncConflictPolicy.useLatest) {
        if (await _remoteRecordWins(
          localEnvelope: localEnvelope,
          remoteEnvelope: remoteEnvelope,
          provider: provider,
          manifestEntriesById: recordEntriesById,
        )) {
          await _records.upsert(remoteEnvelope);
          downloaded += 1;
        } else {
          unchanged += 1;
        }
        continue;
      }
      conflicts.add(
        SyncRecordConflict(
          id: remoteEnvelope.id,
          type: remoteEnvelope.type,
          localRevision: localEnvelope.revision,
          remoteRevision: remoteEnvelope.revision,
          fieldSet: await _buildFieldSet(
            recordId: remoteEnvelope.id,
            recordType: remoteEnvelope.type,
            localEnvelope: localEnvelope,
            remoteEnvelope: remoteEnvelope,
          ),
        ),
      );
    }

    for (final tombstone in remoteTombstones) {
      final localEnvelope = await _records.read(tombstone.targetRecordId);
      if (localEnvelope == null) {
        continue;
      }
      final localModifiedAt = await _recordModifiedAt(
        localEnvelope,
        source: _RecordSource.local,
      );
      if (localModifiedAt == null ||
          !localModifiedAt.isAfter(tombstone.deletedAt)) {
        await _records.delete(tombstone.targetRecordId);
      } else {
        tombstonesToDelete.add(tombstoneRecordId(tombstone.targetRecordId));
      }
    }
    for (final tombstoneRecordId in tombstonesToDelete) {
      await _records.delete(tombstoneRecordId);
    }

    return SyncPullResult(
      recordsDownloaded: downloaded,
      recordsUnchanged: unchanged,
      conflicts: conflicts,
      remoteDevice: remoteDevice,
      remoteManifest: manifest,
    );
  }

  Future<SyncRunResult> resolveConflicts(
    SyncProvider provider,
    SyncConflictResolution resolution, {
    List<SyncRecordConflict> acceptedConflicts = const [],
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return switch (resolution) {
          SyncConflictResolution.keepLocal => _keepLocalThenPush(
            provider,
            acceptedConflicts: acceptedConflicts,
          ),
          SyncConflictResolution.useRemote => _useRemoteThenPush(provider),
        };
      } on SyncProviderException catch (error) {
        if (attempt == 0 && _isRemoteManifestWriteConflict(error)) {
          continue;
        }
        rethrow;
      }
    }
    throw const SyncRunException(
      'sync.provider.conflict',
      'Remote sync data changed while syncing.',
    );
  }

  Future<SyncRunResult> applyMergedConflicts(
    SyncProvider provider, {
    required List<SyncMergedConflict> merges,
  }) async {
    if (merges.isEmpty) {
      throw const SyncRunException(
        'sync.conflict_merge_empty',
        'No sync conflicts were selected for merge.',
      );
    }
    for (var attempt = 0; attempt < 2; attempt += 1) {
      final originals = <VaultRecordId, VaultRecordEnvelope>{};
      try {
        final pull = await _pullEncryptedSnapshot(
          provider,
          conflictPolicy: _SyncConflictPolicy.report,
        );
        final unresolved = _unacceptedConflicts(pull.conflicts, [
          for (final merge in merges) merge.conflict,
        ]);
        if (unresolved.isNotEmpty) {
          throw SyncRunConflictException(unresolved);
        }
        for (final merge in merges) {
          final original = await _records.read(merge.conflict.id);
          if (original == null) {
            throw const SyncRunException(
              'sync.conflict.record_missing',
              'Conflicting record no longer exists locally.',
            );
          }
          originals.putIfAbsent(original.id, () => original);
          final updated = await _vault.encryptRecord(
            id: original.id,
            type: original.type,
            plaintext: utf8.encode(jsonEncode(merge.mergedJson)),
          );
          await _records.upsert(updated);
        }
        final push = await _pushEncryptedSnapshot(
          provider,
          pruneRemote: true,
          expectedRemoteManifest: pull.remoteManifest,
        );
        return SyncRunResult(
          recordsUploaded: push.recordsUploaded,
          recordsDownloaded: pull.recordsDownloaded,
          recordsUnchanged: pull.recordsUnchanged,
          headerUploaded: push.headerUploaded,
          completedAt: push.completedAt,
          writerDevice: push.writerDevice,
          remoteDevice: pull.remoteDevice,
        );
      } on SyncProviderException catch (error) {
        await _restoreOriginalRecords(originals);
        if (attempt == 0 && _isRemoteManifestWriteConflict(error)) {
          continue;
        }
        rethrow;
      } on Object {
        await _restoreOriginalRecords(originals);
        rethrow;
      }
    }
    throw const SyncRunException(
      'sync.provider.conflict',
      'Remote sync data changed while syncing.',
    );
  }

  Future<SyncRunResult> _useRemoteThenPush(SyncProvider provider) async {
    final pull = await _pullEncryptedSnapshot(
      provider,
      conflictPolicy: _SyncConflictPolicy.useRemote,
    );
    final push = await _pushEncryptedSnapshot(
      provider,
      pruneRemote: true,
      expectedRemoteManifest: pull.remoteManifest,
    );
    return SyncRunResult(
      recordsUploaded: push.recordsUploaded,
      recordsDownloaded: pull.recordsDownloaded,
      recordsUnchanged: pull.recordsUnchanged,
      headerUploaded: push.headerUploaded,
      completedAt: push.completedAt,
      writerDevice: push.writerDevice,
      remoteDevice: pull.remoteDevice,
    );
  }

  Future<SyncRunResult> _keepLocalThenPush(
    SyncProvider provider, {
    required List<SyncRecordConflict> acceptedConflicts,
  }) async {
    final pull = await _pullEncryptedSnapshot(
      provider,
      conflictPolicy: _SyncConflictPolicy.report,
    );
    final unresolved = _unacceptedConflicts(pull.conflicts, acceptedConflicts);
    if (unresolved.isNotEmpty) {
      throw SyncRunConflictException(unresolved);
    }
    final push = await _pushEncryptedSnapshot(
      provider,
      pruneRemote: true,
      expectedRemoteManifest: pull.remoteManifest,
    );
    return SyncRunResult(
      recordsUploaded: push.recordsUploaded,
      recordsDownloaded: pull.recordsDownloaded,
      recordsUnchanged: pull.recordsUnchanged,
      headerUploaded: push.headerUploaded,
      completedAt: push.completedAt,
      writerDevice: push.writerDevice,
      remoteDevice: pull.remoteDevice,
    );
  }

  Future<SyncRunResult> pushEncryptedSnapshot(SyncProvider provider) async {
    return _pushEncryptedSnapshot(
      provider,
      pruneRemote: true,
      expectedRemoteManifest: await provider.readManifest(),
    );
  }

  Future<SyncRunResult> publishInitialEncryptedSnapshot(
    SyncProvider provider,
  ) async {
    return _pushEncryptedSnapshot(
      provider,
      pruneRemote: true,
      expectedRemoteManifest: null,
      cleanupPartialRemoteObjectsOnFailure: true,
    );
  }

  Future<SyncRunResult> _pushEncryptedSnapshot(
    SyncProvider provider, {
    required bool pruneRemote,
    RemoteManifest? expectedRemoteManifest,
    bool cleanupPartialRemoteObjectsOnFailure = false,
  }) async {
    final header = _vault.header;
    if (header == null) {
      throw const SyncRunException(
        'sync.vault_header_missing',
        'Vault header is missing.',
      );
    }
    _ensureUnlocked();
    if (await isRemoteReset(provider)) {
      throw const SyncRunException(
        'sync.remote_vault_reset',
        'Remote vault was reset.',
      );
    }

    final writerDevice = await _devices?.touchLocalDevice();
    final envelopes = await _records.list();
    final manifestRecords = <Map<String, Object?>>[];
    final desiredRecordPaths = <String>{};
    final uploadedRefs = <RemoteObjectRef>[];
    final vaultId = syncVaultId(header);
    final headerRef = RemoteObjectRef(_headerObjectPath(vaultId));
    try {
      for (final envelope in envelopes) {
        final ref = RemoteObjectRef(
          _recordObjectPath(envelope.id.value, envelope.revision),
        );
        await _writeUploadedObject(
          provider,
          ref,
          utf8.encode(jsonEncode(envelope.toJson())),
        );
        uploadedRefs.add(ref);
        desiredRecordPaths.add(ref.path);
        manifestRecords.add({
          'id': envelope.id.value,
          'type': envelope.type,
          'revision': envelope.revision,
          'path': ref.path,
        });
      }

      await _writeUploadedObject(
        provider,
        headerRef,
        utf8.encode(jsonEncode(_syncHeaderForRemote(header).toJson())),
      );
      uploadedRefs.add(headerRef);

      final manifestPlaintext = utf8.encode(
        jsonEncode({
          'schemaVersion': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'headerPath': headerRef.path,
          if (writerDevice != null) 'writerDevice': writerDevice.toJson(),
          'records': manifestRecords,
        }),
      );
      final manifestEnvelope = await _vault.encryptRecord(
        id: _manifestRecordId,
        type: 'sync_manifest',
        plaintext: manifestPlaintext,
      );
      await provider.writeManifestIfUnchanged(
        RemoteManifest(
          vaultId: vaultId,
          protocolVersion: 1,
          headerPath: headerRef.path,
          encryptedPayload: utf8.encode(jsonEncode(manifestEnvelope.toJson())),
          snapshotObjectPaths: [
            headerRef.path,
            ...desiredRecordPaths.toList()..sort(),
          ],
        ),
        expectedRemoteManifest,
      );
    } catch (_) {
      if (cleanupPartialRemoteObjectsOnFailure) {
        await _cleanupUploadedRemoteObjectsBestEffort(provider, uploadedRefs);
      }
      rethrow;
    }

    if (pruneRemote) {
      await _prunePreviousRemoteRecords(
        provider,
        previousManifest: expectedRemoteManifest,
        desiredRecordPaths: desiredRecordPaths,
      );
    }

    return SyncRunResult(
      recordsUploaded: envelopes.length,
      headerUploaded: true,
      completedAt: DateTime.now().toUtc(),
      writerDevice: writerDevice,
    );
  }

  Future<void> _prunePreviousRemoteRecords(
    SyncProvider provider, {
    required RemoteManifest? previousManifest,
    required Set<String> desiredRecordPaths,
  }) async {
    if (previousManifest == null) {
      return;
    }
    final previousRecordPaths = await _manifestRecordPathsForPrune(
      previousManifest,
    );
    if (previousRecordPaths == null) {
      return;
    }
    for (final path in previousRecordPaths.difference(desiredRecordPaths)) {
      await _deleteRemoteObjectIfExists(provider, RemoteObjectRef(path));
    }
  }

  Future<Set<String>?> _manifestRecordPathsForPrune(
    RemoteManifest manifest,
  ) async {
    try {
      final manifestData = await _decryptManifest(manifest);
      return {
        for (final entry in _manifestRecords(manifestData))
          if (entry.ref.path.startsWith('records/')) entry.ref.path,
      };
    } on Object {
      return null;
    }
  }

  Future<void> _clearRemoteSnapshot(SyncProvider provider) async {
    for (final prefix in const ['records/', 'vault/']) {
      final refs = await provider.listRecordObjects(prefix: prefix);
      for (final ref in refs) {
        if (ref.path == resetMarkerRef.path) {
          continue;
        }
        await _deleteRemoteObjectIfExists(provider, ref);
      }
    }
    await _deleteRemoteObjectIfExists(provider, _manifestRef);
  }

  Future<void> _deleteRemoteObjectIfExists(
    SyncProvider provider,
    RemoteObjectRef ref,
  ) async {
    try {
      await provider.deleteObject(ref);
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        return;
      }
      rethrow;
    }
  }

  Future<void> _writeUploadedObject(
    SyncProvider provider,
    RemoteObjectRef ref,
    List<int> bytes,
  ) {
    return provider.writeObject(ref, bytes);
  }

  Future<void> _cleanupUploadedRemoteObjectsBestEffort(
    SyncProvider provider,
    List<RemoteObjectRef> refs,
  ) async {
    for (final ref in refs.reversed) {
      try {
        await _deleteRemoteObjectIfExists(provider, ref);
      } on Object {
        // Keep the original upload/manifest error visible to callers.
      }
    }
  }

  Future<void> _restoreOriginalRecords(
    Map<VaultRecordId, VaultRecordEnvelope> originals,
  ) async {
    for (final original in originals.values) {
      await _records.upsert(original);
    }
  }

  Future<SyncRunResult> pushEncryptedSnapshotForRepair(
    SyncProvider provider,
  ) async {
    await _ensureLocalDataHealthyForRepair();
    return _retryOnRemoteManifestConflict(() async {
      return _pushEncryptedSnapshot(
        provider,
        pruneRemote: true,
        expectedRemoteManifest: await provider.readManifest(),
      );
    });
  }

  Future<SyncRunResult> restoreLocalFromRemoteForRepair(
    SyncProvider provider,
  ) async {
    return _retryOnRemoteManifestConflict(() async {
      final pull = await _pullEncryptedSnapshot(
        provider,
        conflictPolicy: _SyncConflictPolicy.useRemote,
      );
      final push = await _pushEncryptedSnapshot(
        provider,
        pruneRemote: true,
        expectedRemoteManifest: pull.remoteManifest,
      );
      return SyncRunResult(
        recordsUploaded: push.recordsUploaded,
        recordsDownloaded: pull.recordsDownloaded,
        recordsUnchanged: pull.recordsUnchanged,
        headerUploaded: push.headerUploaded,
        completedAt: push.completedAt,
        writerDevice: push.writerDevice,
        remoteDevice: pull.remoteDevice,
      );
    });
  }

  Future<Map<String, Object?>> _decryptManifest(RemoteManifest manifest) async {
    try {
      final envelope = VaultRecordEnvelope.fromJson(
        jsonDecode(utf8.decode(manifest.encryptedPayload))
            as Map<String, Object?>,
      );
      final plaintext = await _vault.decryptRecord(envelope);
      return jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>;
    } on SyncRunException {
      rethrow;
    } on Object {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync manifest is invalid or corrupted.',
      );
    }
  }

  Future<bool> _remoteSnapshotMatchesLocal(
    SyncProvider provider,
    RemoteManifest manifest,
  ) async {
    final header = _vault.header;
    if (header == null) {
      return false;
    }
    final headerPath = manifest.headerPath;
    if (headerPath == null) {
      return false;
    }
    final remoteHeader = await _readRemoteHeader(provider, headerPath);
    if (remoteHeader == null) {
      return false;
    }
    if (!_sameHeader(_syncHeaderForRemote(header), remoteHeader)) {
      return false;
    }
    final manifestData = await _decryptManifest(manifest);
    final remoteRecords = _manifestRecords(manifestData);
    final localRecords = await _records.list();
    if (remoteRecords.length != localRecords.length) {
      return false;
    }
    final remoteById = {for (final entry in remoteRecords) entry.id: entry};
    for (final local in localRecords) {
      final remote = remoteById[local.id];
      if (remote == null ||
          remote.type != local.type ||
          remote.revision != local.revision) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _localSyncDeviceRegistered() async {
    final devices = _devices;
    if (devices == null) {
      return true;
    }
    return await devices.readLocalDevice() != null;
  }

  Future<VaultHeader?> _readRemoteHeader(
    SyncProvider provider,
    String headerPath,
  ) async {
    try {
      return VaultHeader.fromJson(
        jsonDecode(
              utf8.decode(
                await provider.readObject(RemoteObjectRef(headerPath)),
              ),
            )
            as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }

  void _validateRemoteManifestIdentity(RemoteManifest manifest) {
    if (manifest.protocolVersion > 1) {
      throw const SyncRunException(
        'sync.remote_protocol_unsupported',
        'Remote sync data was written by a newer Serlink version.',
      );
    }
    final header = _vault.header;
    if (header == null) {
      throw const SyncRunException(
        'sync.vault_header_missing',
        'Vault header is missing.',
      );
    }
    if (manifest.vaultId != syncVaultId(header)) {
      throw const SyncRunException(
        'sync.remote_manifest_wrong_vault',
        'Remote sync data belongs to another vault.',
      );
    }
  }

  List<_ManifestRecordEntry> _manifestRecords(Map<String, Object?> manifest) {
    final rawRecords = manifest['records'];
    if (rawRecords is! List<Object?>) {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync manifest is invalid.',
      );
    }
    try {
      return [
        for (final rawRecord in rawRecords)
          _ManifestRecordEntry.fromJson(
            Map<String, Object?>.from(rawRecord as Map<Object?, Object?>),
          ),
      ];
    } on Object {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync manifest is invalid.',
      );
    }
  }

  SyncDeviceMetadata? _manifestWriterDevice(Map<String, Object?> manifest) {
    final rawDevice = manifest['writerDevice'];
    if (rawDevice == null) {
      return null;
    }
    if (rawDevice is! Map<Object?, Object?>) {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync manifest is invalid.',
      );
    }
    try {
      return SyncDeviceMetadata.fromJson(Map<String, Object?>.from(rawDevice));
    } on Object {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync manifest is invalid.',
      );
    }
  }

  void _ensureUnlocked() {
    if (_vault.state != VaultState.unlocked) {
      throw const SyncRunException(
        'sync.vault_locked',
        'Unlock the vault before syncing.',
      );
    }
  }

  Future<void> _ensureLocalDataHealthyForRepair() async {
    final check = _localDataHealthy;
    if (check == null || await check()) {
      return;
    }
    throw const SyncRunException(
      'sync.local_unhealthy',
      'Local vault data needs recovery before rebuilding remote sync.',
    );
  }

  Future<Map<VaultRecordId, SyncDeleteTombstone>> _localTombstones() async {
    final envelopes = await _records.list(
      type: EncryptedSyncDeleteTombstoneRepository.recordType,
    );
    final tombstones = <VaultRecordId, SyncDeleteTombstone>{};
    for (final envelope in envelopes) {
      final tombstone = await _decodeTombstone(
        envelope,
        source: _RecordSource.local,
      );
      tombstones[tombstone.targetRecordId] = tombstone;
    }
    return tombstones;
  }

  Future<VaultRecordEnvelope> _readRemoteEnvelope(
    SyncProvider provider,
    RemoteObjectRef ref,
  ) async {
    try {
      return VaultRecordEnvelope.fromJson(
        jsonDecode(utf8.decode(await provider.readObject(ref)))
            as Map<String, Object?>,
      );
    } on SyncRunException {
      rethrow;
    } on Object {
      throw const SyncRunException(
        'sync.remote_manifest_invalid',
        'Remote sync record is invalid or corrupted.',
      );
    }
  }

  void _validateRemoteEnvelopeEntry(
    VaultRecordEnvelope envelope,
    _ManifestRecordEntry entry,
  ) {
    if (envelope.id != entry.id ||
        envelope.type != entry.type ||
        envelope.revision != entry.revision) {
      throw const SyncRunException(
        'sync.remote_manifest_mismatch',
        'Remote sync manifest does not match its record objects.',
      );
    }
  }

  Future<SyncDeleteTombstone> _decodeTombstone(
    VaultRecordEnvelope envelope, {
    required _RecordSource source,
  }) async {
    try {
      final plaintext = await _vault.decryptRecord(envelope);
      return SyncDeleteTombstone.fromJson(
        jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
      );
    } on VaultException {
      throw SyncRunException(
        source == _RecordSource.remote
            ? 'sync.remote_manifest_invalid'
            : 'sync.local_unhealthy',
        source == _RecordSource.remote
            ? 'Remote sync tombstone is invalid or corrupted.'
            : 'Local vault data needs recovery before syncing.',
      );
    } on FormatException {
      throw SyncRunException(
        source == _RecordSource.remote
            ? 'sync.remote_manifest_invalid'
            : 'sync.local_unhealthy',
        source == _RecordSource.remote
            ? 'Remote sync tombstone is invalid.'
            : 'Local tombstone data needs recovery before syncing.',
      );
    } on TypeError {
      throw SyncRunException(
        source == _RecordSource.remote
            ? 'sync.remote_manifest_invalid'
            : 'sync.local_unhealthy',
        source == _RecordSource.remote
            ? 'Remote sync tombstone is invalid.'
            : 'Local tombstone data needs recovery before syncing.',
      );
    }
  }

  Future<bool> _remoteRecordWins({
    required VaultRecordEnvelope localEnvelope,
    required VaultRecordEnvelope remoteEnvelope,
    required SyncProvider provider,
    required Map<VaultRecordId, _ManifestRecordEntry> manifestEntriesById,
  }) async {
    final localModifiedAt = await _recordModifiedAt(
      localEnvelope,
      source: _RecordSource.local,
    );
    final remoteModifiedAt = await _recordModifiedAt(
      remoteEnvelope,
      source: _RecordSource.remote,
      provider: provider,
      manifestEntriesById: manifestEntriesById,
    );
    if (remoteModifiedAt != null && localModifiedAt != null) {
      return remoteModifiedAt.isAfter(localModifiedAt);
    }
    if (remoteModifiedAt != null) {
      return true;
    }
    if (localModifiedAt != null) {
      return false;
    }
    return true;
  }

  Future<DateTime?> _recordModifiedAt(
    VaultRecordEnvelope envelope, {
    required _RecordSource source,
    SyncProvider? provider,
    Map<VaultRecordId, _ManifestRecordEntry>? manifestEntriesById,
  }) async {
    try {
      final plaintext = await _vault.decryptRecord(envelope);
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map<String, Object?>) {
        return _relatedRecordModifiedAt(
          envelope,
          source: source,
          provider: provider,
          manifestEntriesById: manifestEntriesById,
        );
      }
      return _timestampFromRecordJson(decoded) ??
          await _relatedRecordModifiedAt(
            envelope,
            source: source,
            provider: provider,
            manifestEntriesById: manifestEntriesById,
          );
    } on VaultException {
      throw SyncRunException(
        source == _RecordSource.remote
            ? 'sync.remote_manifest_invalid'
            : 'sync.local_unhealthy',
        source == _RecordSource.remote
            ? 'Remote sync record is invalid or corrupted.'
            : 'Local vault data needs recovery before syncing.',
      );
    } on FormatException {
      return _relatedRecordModifiedAt(
        envelope,
        source: source,
        provider: provider,
        manifestEntriesById: manifestEntriesById,
      );
    } on TypeError {
      return _relatedRecordModifiedAt(
        envelope,
        source: source,
        provider: provider,
        manifestEntriesById: manifestEntriesById,
      );
    }
  }

  Future<DateTime?> _relatedRecordModifiedAt(
    VaultRecordEnvelope envelope, {
    required _RecordSource source,
    SyncProvider? provider,
    Map<VaultRecordId, _ManifestRecordEntry>? manifestEntriesById,
  }) async {
    final relatedId = _relatedTimestampRecordId(envelope);
    if (relatedId == null) {
      return null;
    }

    final relatedEnvelope = switch (source) {
      _RecordSource.local => await _records.read(relatedId),
      _RecordSource.remote => await _readRemoteRelatedEnvelope(
        provider: provider,
        manifestEntriesById: manifestEntriesById,
        id: relatedId,
      ),
    };
    if (relatedEnvelope == null) {
      return null;
    }
    return _recordModifiedAt(
      relatedEnvelope,
      source: source,
      provider: provider,
      manifestEntriesById: manifestEntriesById,
    );
  }

  Future<VaultRecordEnvelope?> _readRemoteRelatedEnvelope({
    required SyncProvider? provider,
    required Map<VaultRecordId, _ManifestRecordEntry>? manifestEntriesById,
    required VaultRecordId id,
  }) async {
    if (provider == null || manifestEntriesById == null) {
      return null;
    }
    final entry = manifestEntriesById[id];
    if (entry == null) {
      return null;
    }
    final envelope = await _readRemoteEnvelope(provider, entry.ref);
    _validateRemoteEnvelopeEntry(envelope, entry);
    return envelope;
  }

  Future<SyncConflictFieldSet?> _buildFieldSet({
    required VaultRecordId recordId,
    required String recordType,
    required VaultRecordEnvelope localEnvelope,
    required VaultRecordEnvelope remoteEnvelope,
  }) async {
    try {
      final localJson =
          jsonDecode(utf8.decode(await _vault.decryptRecord(localEnvelope)))
              as Map<String, Object?>;
      final remoteJson =
          jsonDecode(utf8.decode(await _vault.decryptRecord(remoteEnvelope)))
              as Map<String, Object?>;
      return _fieldMerge.inspect(
        recordType: recordType,
        recordId: recordId,
        localJson: localJson,
        remoteJson: remoteJson,
      );
    } on Object {
      return null;
    }
  }
}

DateTime? _timestampFromRecordJson(Map<String, Object?> json) {
  for (final key in const [
    'updatedAt',
    'deletedAt',
    'lastSeenAt',
    'createdAt',
  ]) {
    final value = json[key];
    if (value is! String) {
      continue;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  return null;
}

VaultRecordId? _relatedTimestampRecordId(VaultRecordEnvelope envelope) {
  if (envelope.type != 'identity_secret') {
    return null;
  }
  const secretPrefix = 'secret:';
  if (!envelope.id.value.startsWith(secretPrefix)) {
    return null;
  }
  final identityId = envelope.id.value.substring(secretPrefix.length);
  if (identityId.isEmpty) {
    return null;
  }
  return VaultRecordId('identity:$identityId');
}

class SyncRunConflictException extends SyncRunException {
  SyncRunConflictException(this.conflicts)
    : super(
        'sync.conflict',
        '${conflicts.length} sync conflict${conflicts.length == 1 ? '' : 's'} need review.',
      );

  final List<SyncRecordConflict> conflicts;
}

class _ManifestRecordEntry {
  const _ManifestRecordEntry({
    required this.id,
    required this.type,
    required this.revision,
    required this.ref,
  });

  final VaultRecordId id;
  final String type;
  final String revision;
  final RemoteObjectRef ref;

  factory _ManifestRecordEntry.fromJson(Map<String, Object?> json) {
    return _ManifestRecordEntry(
      id: VaultRecordId(json['id'] as String),
      type: json['type'] as String,
      revision: json['revision'] as String,
      ref: RemoteObjectRef(json['path'] as String),
    );
  }
}

bool _isRemoteManifestWriteConflict(SyncProviderException error) {
  return error.code == 'sync.provider.conflict' ||
      error.code == 'sync.cloudkit.conflict';
}

bool _shouldAutoResolveMetadataConflict(String type) {
  return type == EncryptedSyncDeviceRepository.recordType;
}

Future<T> _retryOnRemoteManifestConflict<T>(Future<T> Function() action) async {
  for (var attempt = 0; attempt < 2; attempt += 1) {
    try {
      return await action();
    } on SyncProviderException catch (error) {
      if (attempt == 0 && _isRemoteManifestWriteConflict(error)) {
        continue;
      }
      rethrow;
    }
  }
  throw const SyncRunException(
    'sync.provider.conflict',
    'Remote sync data changed while syncing.',
  );
}

VaultHeader _syncHeaderForRemote(VaultHeader header) {
  return header.copyWith(localUnlockProtectors: const []);
}

bool _sameHeader(VaultHeader a, VaultHeader b) {
  return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}

String _recordObjectPath(String recordId, String revision) {
  return 'records/${Uri.encodeComponent(recordId)}-${Uri.encodeComponent(revision)}.json';
}

String _headerObjectPath(String vaultId) {
  return 'vault/headers/${Uri.encodeComponent(vaultId)}.json';
}

String syncVaultId(VaultHeader header) {
  return base64Url.encode(header.passphraseSalt).replaceAll('=', '');
}

final _manifestRecordId = VaultRecordId('sync:manifest');
const _manifestRef = RemoteObjectRef('manifest.json');
const resetMarkerRef = RemoteObjectRef('vault/reset.json');

List<SyncRecordConflict> _unacceptedConflicts(
  List<SyncRecordConflict> conflicts,
  List<SyncRecordConflict> acceptedConflicts,
) {
  final acceptedRemoteRevisions = {
    for (final conflict in acceptedConflicts)
      '${conflict.id.value}\u0000${conflict.remoteRevision}',
  };
  return [
    for (final conflict in conflicts)
      if (!acceptedRemoteRevisions.contains(
        '${conflict.id.value}\u0000${conflict.remoteRevision}',
      ))
        conflict,
  ];
}
