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

  static const legacyHeaderRef = RemoteObjectRef('vault/header.json');

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

    final headerRef = _headerRefFor(manifest);
    final header = await _readHeader(headerRef);
    if (manifest.vaultId != syncVaultId(header)) {
      throw const SyncRunException(
        'sync.remote_manifest_wrong_vault',
        'Remote sync data belongs to another vault.',
      );
    }
    return RemoteVaultDiscovery(header: header, manifest: manifest);
  }

  Future<VaultHeader> _readHeader(RemoteObjectRef headerRef) async {
    try {
      return VaultHeader.fromJson(
        jsonDecode(utf8.decode(await _provider.readObject(headerRef)))
            as Map<String, Object?>,
      );
    } on SyncRunException {
      rethrow;
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        throw const SyncRunException(
          'sync.remote_header_missing',
          'Remote vault header is missing.',
        );
      }
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

  RemoteObjectRef _headerRefFor(RemoteManifest manifest) {
    final path = manifest.headerPath;
    if (path == null) {
      return legacyHeaderRef;
    }
    if (!_isSafeHeaderPath(path)) {
      throw const SyncRunException(
        'sync.remote_header_invalid',
        'Remote vault header path is invalid.',
      );
    }
    return RemoteObjectRef(path);
  }
}

bool _isSafeHeaderPath(String path) {
  if (path == RemoteVaultDiscoveryService.legacyHeaderRef.path) {
    return true;
  }
  if (!path.startsWith('vault/headers/') ||
      !path.endsWith('.json') ||
      path.contains(r'\')) {
    return false;
  }
  final segments = path.split('/');
  return segments.length == 3 &&
      segments.every(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
      );
}
