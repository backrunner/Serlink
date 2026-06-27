import 'dart:async';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/sync_provider.dart';
import 'sync_device_service.dart';
import 'sync_record_scope.dart';

enum VaultRecordChangeKind { upsert, delete }

class VaultRecordChange {
  const VaultRecordChange({required this.kind, required this.id, this.type});

  final VaultRecordChangeKind kind;
  final VaultRecordId id;
  final String? type;
}

class VaultRecordChangeBus {
  final StreamController<VaultRecordChange> _controller =
      StreamController<VaultRecordChange>.broadcast(sync: true);

  Stream<VaultRecordChange> get stream => _controller.stream;

  void notify(VaultRecordChange change) {
    if (!_controller.isClosed) {
      _controller.add(change);
    }
  }

  Future<void> close() async {
    await _controller.close();
  }
}

class NotifyingVaultRecordRepository implements VaultRecordRepository {
  const NotifyingVaultRecordRepository({
    required this.inner,
    required this.changes,
  });

  final VaultRecordRepository inner;
  final VaultRecordChangeBus changes;

  @override
  Future<void> upsert(VaultRecordEnvelope envelope) async {
    await inner.upsert(envelope);
    if (_shouldNotifyRecordChange(envelope.id, envelope.type)) {
      changes.notify(
        VaultRecordChange(
          kind: VaultRecordChangeKind.upsert,
          id: envelope.id,
          type: envelope.type,
        ),
      );
    }
  }

  @override
  Future<VaultRecordEnvelope?> read(VaultRecordId id) {
    return inner.read(id);
  }

  @override
  Future<List<VaultRecordEnvelope>> list({String? type}) {
    return inner.list(type: type);
  }

  @override
  Future<void> delete(VaultRecordId id) async {
    final existing = await inner.read(id);
    await inner.delete(id);
    if (existing != null && _shouldNotifyRecordChange(id, existing.type)) {
      changes.notify(
        VaultRecordChange(
          kind: VaultRecordChangeKind.delete,
          id: id,
          type: existing.type,
        ),
      );
    }
  }

  @override
  Future<void> clear() async {
    final records = await inner.list();
    await inner.clear();
    for (final record in records) {
      if (_shouldNotifyRecordChange(record.id, record.type)) {
        changes.notify(
          VaultRecordChange(
            kind: VaultRecordChangeKind.delete,
            id: record.id,
            type: record.type,
          ),
        );
      }
    }
  }
}

enum AutoSyncPhase { disabled, idle, scheduled, syncing, conflicts, failed }

class AutoSyncStatus {
  const AutoSyncStatus({
    required this.phase,
    this.lastCompletedAt,
    this.lastFailedAt,
    this.lastFailureMessage,
    this.lastFailure,
    this.lastProviderKind,
    this.conflictCount = 0,
    this.recordsUploaded = 0,
    this.recordsDownloaded = 0,
  });

  const AutoSyncStatus.disabled() : this(phase: AutoSyncPhase.disabled);

  final AutoSyncPhase phase;
  final DateTime? lastCompletedAt;
  final DateTime? lastFailedAt;
  final String? lastFailureMessage;
  final Object? lastFailure;
  final SyncProviderKind? lastProviderKind;
  final int conflictCount;
  final int recordsUploaded;
  final int recordsDownloaded;

  bool get enabled => phase != AutoSyncPhase.disabled;

  AutoSyncStatus copyWith({
    AutoSyncPhase? phase,
    DateTime? lastCompletedAt,
    DateTime? lastFailedAt,
    String? lastFailureMessage,
    Object? lastFailure,
    SyncProviderKind? lastProviderKind,
    bool clearFailure = false,
    int? conflictCount,
    int? recordsUploaded,
    int? recordsDownloaded,
  }) {
    return AutoSyncStatus(
      phase: phase ?? this.phase,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastFailedAt: clearFailure ? null : lastFailedAt ?? this.lastFailedAt,
      lastFailureMessage: clearFailure
          ? null
          : lastFailureMessage ?? this.lastFailureMessage,
      lastFailure: clearFailure ? null : lastFailure ?? this.lastFailure,
      lastProviderKind: clearFailure
          ? null
          : lastProviderKind ?? this.lastProviderKind,
      conflictCount: conflictCount ?? this.conflictCount,
      recordsUploaded: recordsUploaded ?? this.recordsUploaded,
      recordsDownloaded: recordsDownloaded ?? this.recordsDownloaded,
    );
  }
}

bool _shouldNotifyRecordChange(VaultRecordId id, String type) {
  return !isLocalOnlySyncRecord(id: id, type: type) &&
      type != EncryptedSyncDeviceRepository.recordType &&
      type != 'sync_tombstone' &&
      type != 'sync_manifest';
}
