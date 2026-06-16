import 'dart:convert';

import '../../vault/application/vault_service.dart';
import '../domain/sync_provider.dart';
import 'sync_run_service.dart';

class RemoteVaultDiscovery {
  const RemoteVaultDiscovery({required this.header, required this.manifest});

  final VaultHeader header;
  final RemoteManifest manifest;
}

class RemoteVaultDiscoveryService {
  const RemoteVaultDiscoveryService(this._provider);

  static const headerRef = RemoteObjectRef('vault/header.json');

  final SyncProvider _provider;

  Future<RemoteVaultDiscovery?> discover() async {
    final manifest = await _provider.readManifest();
    if (manifest == null) {
      return null;
    }
    final resetMarker = await _readResetMarker();
    if (resetMarker?.vaultId == manifest.vaultId) {
      return null;
    }
    if (manifest.protocolVersion > 1) {
      throw const SyncRunException(
        'sync.remote_protocol_unsupported',
        'Remote sync data was written by a newer Serlink version.',
      );
    }

    final headerRefs = await _provider.listRecordObjects(prefix: 'vault/');
    if (!headerRefs.any((ref) => ref.path == headerRef.path)) {
      throw const SyncRunException(
        'sync.remote_header_missing',
        'Remote vault header is missing.',
      );
    }

    final header = await _readHeader();
    if (manifest.vaultId != syncVaultId(header)) {
      throw const SyncRunException(
        'sync.remote_manifest_wrong_vault',
        'Remote sync data belongs to another vault.',
      );
    }
    return RemoteVaultDiscovery(header: header, manifest: manifest);
  }

  Future<VaultHeader> _readHeader() async {
    try {
      return VaultHeader.fromJson(
        jsonDecode(utf8.decode(await _provider.readObject(headerRef)))
            as Map<String, Object?>,
      );
    } on SyncRunException {
      rethrow;
    } on Object {
      throw const SyncRunException(
        'sync.remote_header_invalid',
        'Remote vault header is invalid or corrupted.',
      );
    }
  }

  Future<RemoteResetMarker?> _readResetMarker() async {
    try {
      return RemoteResetMarker.fromBytes(
        await _provider.readObject(resetMarkerRef),
      );
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        return null;
      }
      rethrow;
    }
  }
}
