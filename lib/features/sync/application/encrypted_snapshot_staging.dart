import 'dart:convert';

import '../domain/sync_provider.dart';
import 'sync_run_service.dart';

class StagedEncryptedSnapshot {
  const StagedEncryptedSnapshot({
    required this.providerKind,
    required this.vaultId,
    required this.manifest,
    required this.manifestBytes,
    required this.manifestFingerprint,
    required this.objects,
    required this.completedAt,
  });

  final SyncProviderKind providerKind;
  final String vaultId;
  final RemoteManifest manifest;
  final List<int> manifestBytes;
  final String manifestFingerprint;
  final Map<String, List<int>> objects;
  final DateTime completedAt;
}

class StagedSnapshotSyncProvider implements SyncProvider {
  StagedSnapshotSyncProvider(this.snapshot);

  final StagedEncryptedSnapshot snapshot;

  @override
  Future<ProviderCapabilities> capabilities() async {
    return ProviderCapabilities(
      kind: snapshot.providerKind,
      supportsConditionalWrites: false,
      requiresTls: snapshot.providerKind == SyncProviderKind.webDav,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    return snapshot.manifest;
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) async {
    throw const SyncProviderException(
      'sync.staged_snapshot.read_only',
      'Staged sync snapshot is read-only.',
    );
  }

  @override
  Future<void> writeManifestIfUnchanged(
    RemoteManifest manifest,
    RemoteManifest? expectedCurrent,
  ) async {
    throw const SyncProviderException(
      'sync.staged_snapshot.read_only',
      'Staged sync snapshot is read-only.',
    );
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    return [
      for (final path in snapshot.objects.keys)
        if (prefix == null || path.startsWith(prefix)) RemoteObjectRef(path),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    final bytes = snapshot.objects[ref.path];
    if (bytes == null) {
      throw const SyncProviderException(
        'sync.provider.not_found',
        'Staged sync object was not found.',
      );
    }
    return bytes;
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    throw const SyncProviderException(
      'sync.staged_snapshot.read_only',
      'Staged sync snapshot is read-only.',
    );
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    throw const SyncProviderException(
      'sync.staged_snapshot.read_only',
      'Staged sync snapshot is read-only.',
    );
  }
}

String manifestFingerprint(RemoteManifest manifest) {
  return base64Url.encode(manifest.toBytes()).replaceAll('=', '');
}

String syncProviderKindName(SyncProviderKind kind) {
  return switch (kind) {
    SyncProviderKind.local => 'local',
    SyncProviderKind.webDav => 'webdav',
    SyncProviderKind.cloudKit => 'cloudkit',
    SyncProviderKind.iCloudDrive => 'icloud_drive',
  };
}

SyncProviderKind syncProviderKindFromName(String name) {
  return switch (name) {
    'local' => SyncProviderKind.local,
    'webdav' => SyncProviderKind.webDav,
    'cloudkit' => SyncProviderKind.cloudKit,
    'icloud_drive' => SyncProviderKind.iCloudDrive,
    _ => throw const SyncRunException(
      'sync.staged_snapshot_provider_invalid',
      'Staged sync provider is invalid.',
    ),
  };
}
