import 'dart:async';

import '../../../platform/platform_capabilities.dart';
import '../../vault/application/vault_service.dart';
import '../data/encrypted_snapshot_staging_repository.dart';
import '../domain/sync_provider.dart';
import 'encrypted_snapshot_staging.dart';
import 'sync_run_service.dart';

class CloudKitEncryptedSnapshotPrefetchController {
  CloudKitEncryptedSnapshotPrefetchController({
    required this.capabilities,
    required this.cloudKitAvailable,
    required this.providerFactory,
    required this.staging,
    required this.pendingResets,
    required this.shadowSettings,
    required this.shouldAcceptSnapshot,
    this.maxObjects = 10000,
    this.maxBytes = 256 * 1024 * 1024,
  });

  final PlatformCapabilities capabilities;
  final Future<bool> Function() cloudKitAvailable;
  final SyncProvider Function() providerFactory;
  final EncryptedSnapshotStagingRepository staging;
  final PendingRemoteResetRepository pendingResets;
  final CloudKitSyncShadowSettingsStore shadowSettings;
  final bool Function(String vaultId) shouldAcceptSnapshot;
  final int maxObjects;
  final int maxBytes;

  bool _running = false;
  bool _rerunRequested = false;
  VaultHeader? _latestHeader;
  VaultState _latestVaultState = VaultState.uninitialized;

  bool get isRunning => _running;

  void request({required VaultHeader? header, required VaultState vaultState}) {
    if (!_canPrefetch(header: header, vaultState: vaultState)) {
      return;
    }
    _latestHeader = header;
    _latestVaultState = vaultState;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    var retriedManifestChange = false;
    try {
      do {
        _rerunRequested = false;
        final header = _latestHeader;
        if (!_canPrefetch(header: header, vaultState: _latestVaultState)) {
          return;
        }
        final vaultId = syncVaultId(header!);
        if (!shouldAcceptSnapshot(vaultId)) {
          return;
        }
        final result = await _prefetchOnce(header);
        if (result == _PrefetchResult.manifestChanged) {
          if (retriedManifestChange) {
            _rerunRequested = false;
          } else {
            retriedManifestChange = true;
            _rerunRequested = true;
          }
        } else if (_rerunRequested) {
          retriedManifestChange = false;
        }
      } while (_rerunRequested);
    } on Object {
      // Locked prefetch is best-effort. Unlock and auto-sync will retry through
      // the normal authenticated path when CloudKit is transiently unavailable.
    } finally {
      _running = false;
    }
  }

  Future<_PrefetchResult> _prefetchOnce(VaultHeader header) async {
    final vaultId = syncVaultId(header);
    if (!await cloudKitAvailable()) {
      return _PrefetchResult.skipped;
    }
    final shadow = await shadowSettings.read(vaultId);
    if (shadow?.enabled == false) {
      return _PrefetchResult.skipped;
    }
    final provider = providerFactory();
    final resetMarker = await _readResetMarker(provider);
    if (resetMarker?.vaultId == vaultId) {
      final latestShadow = await shadowSettings.read(vaultId);
      if (latestShadow?.enabled == false) {
        return _PrefetchResult.skipped;
      }
      if (!shouldAcceptSnapshot(vaultId)) {
        return _PrefetchResult.skipped;
      }
      await pendingResets.save(
        providerKind: SyncProviderKind.cloudKit,
        marker: resetMarker!,
      );
      return _PrefetchResult.saved;
    }
    final manifest = await provider.readManifest();
    if (manifest == null ||
        manifest.vaultId != vaultId ||
        manifest.protocolVersion > 1 ||
        manifest.headerPath == null) {
      return _PrefetchResult.skipped;
    }
    final objectPaths = await _objectPaths(provider, manifest);
    if (objectPaths.length > maxObjects) {
      return _PrefetchResult.skipped;
    }
    final objects = <String, List<int>>{};
    var totalBytes = manifest.toBytes().length;
    for (final path in objectPaths) {
      final bytes = await provider.readObject(RemoteObjectRef(path));
      totalBytes += bytes.length;
      if (totalBytes > maxBytes) {
        return _PrefetchResult.skipped;
      }
      objects[path] = List<int>.unmodifiable(bytes);
    }
    final after = await provider.readManifest();
    if (after == null ||
        manifestFingerprint(after) != manifestFingerprint(manifest)) {
      return _PrefetchResult.manifestChanged;
    }
    final latestShadow = await shadowSettings.read(vaultId);
    if (latestShadow?.enabled == false) {
      return _PrefetchResult.skipped;
    }
    if (!shouldAcceptSnapshot(vaultId)) {
      return _PrefetchResult.skipped;
    }
    await staging.save(
      StagedEncryptedSnapshot(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: vaultId,
        manifest: manifest,
        manifestBytes: manifest.toBytes(),
        manifestFingerprint: manifestFingerprint(manifest),
        objects: objects,
        completedAt: DateTime.now().toUtc(),
      ),
    );
    return _PrefetchResult.saved;
  }

  Future<List<String>> _objectPaths(
    SyncProvider provider,
    RemoteManifest manifest,
  ) async {
    final paths = <String>{};
    if (manifest.headerPath case final headerPath?) {
      paths.add(headerPath);
    }
    if (manifest.snapshotObjectPaths.isNotEmpty) {
      paths.addAll(manifest.snapshotObjectPaths);
    } else {
      for (final ref in await provider.listRecordObjects(prefix: 'records/')) {
        paths.add(ref.path);
      }
    }
    return paths.toList()..sort();
  }

  Future<RemoteResetMarker?> _readResetMarker(SyncProvider provider) async {
    try {
      return RemoteResetMarker.fromBytes(
        await provider.readObject(resetMarkerRef),
      );
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        return null;
      }
      rethrow;
    }
  }

  bool _canPrefetch({
    required VaultHeader? header,
    required VaultState vaultState,
  }) {
    return capabilities.cloudKitSync &&
        header != null &&
        vaultState == VaultState.locked;
  }
}

enum _PrefetchResult { skipped, saved, manifestChanged }
