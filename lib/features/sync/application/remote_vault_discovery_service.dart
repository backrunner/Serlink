import '../../vault/application/vault_service.dart';
import '../domain/sync_provider.dart';
import 'sync_compatibility.dart';
import 'sync_run_service.dart';

class RemoteVaultDiscovery {
  const RemoteVaultDiscovery({required this.header, required this.manifest});

  final VaultHeader header;
  final RemoteManifest manifest;
}

class RemoteVaultDiscoveryService {
  const RemoteVaultDiscoveryService(this._provider);

  static const legacyHeaderRef = legacyRemoteVaultHeaderRef;

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
    validateRemoteManifestProtocol(manifest);

    final header = await readRemoteVaultHeader(_provider, manifest);
    if (manifest.vaultId != syncVaultId(header)) {
      throw const SyncRunException(
        'sync.remote_manifest_wrong_vault',
        'Remote sync data belongs to another vault.',
      );
    }
    return RemoteVaultDiscovery(header: header, manifest: manifest);
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
