import 'dart:async';

import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import 'sync_device_service.dart';

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
    if (_shouldNotifyRecordChange(envelope.type)) {
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
    await inner.delete(id);
    changes.notify(
      VaultRecordChange(kind: VaultRecordChangeKind.delete, id: id),
    );
  }
}

enum AutoSyncPhase { disabled, idle, scheduled, syncing, conflicts, failed }

class AutoSyncStatus {
  const AutoSyncStatus({
    required this.phase,
    this.lastCompletedAt,
    this.lastFailureMessage,
    this.lastFailure,
    this.conflictCount = 0,
    this.recordsUploaded = 0,
    this.recordsDownloaded = 0,
  });

  const AutoSyncStatus.disabled() : this(phase: AutoSyncPhase.disabled);

  final AutoSyncPhase phase;
  final DateTime? lastCompletedAt;
  final String? lastFailureMessage;
  final Object? lastFailure;
  final int conflictCount;
  final int recordsUploaded;
  final int recordsDownloaded;

  bool get enabled => phase != AutoSyncPhase.disabled;

  AutoSyncStatus copyWith({
    AutoSyncPhase? phase,
    DateTime? lastCompletedAt,
    String? lastFailureMessage,
    Object? lastFailure,
    bool clearFailure = false,
    int? conflictCount,
    int? recordsUploaded,
    int? recordsDownloaded,
  }) {
    return AutoSyncStatus(
      phase: phase ?? this.phase,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastFailureMessage: clearFailure
          ? null
          : lastFailureMessage ?? this.lastFailureMessage,
      lastFailure: clearFailure ? null : lastFailure ?? this.lastFailure,
      conflictCount: conflictCount ?? this.conflictCount,
      recordsUploaded: recordsUploaded ?? this.recordsUploaded,
      recordsDownloaded: recordsDownloaded ?? this.recordsDownloaded,
    );
  }
}

bool _shouldNotifyRecordChange(String type) {
  return type != EncryptedSyncDeviceRepository.recordType &&
      type != 'sync_manifest';
}
