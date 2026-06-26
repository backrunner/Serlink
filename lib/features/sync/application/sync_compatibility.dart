import 'dart:convert';

import '../../vault/application/vault_service.dart';
import '../domain/sync_provider.dart';
import 'sync_exceptions.dart';

const supportedRemoteSyncProtocolVersion = 1;
const supportedVaultSchemaVersion = 1;
const legacyRemoteVaultHeaderRef = RemoteObjectRef('vault/header.json');

const remoteSyncVersionUnsupportedMessage =
    'Remote sync data was written by a newer Serlink version. Update Serlink before syncing, or turn sync off on this device.';

void validateRemoteManifestProtocol(RemoteManifest manifest) {
  if (manifest.protocolVersion > supportedRemoteSyncProtocolVersion) {
    throw const SyncRunException(
      'sync.remote_protocol_unsupported',
      remoteSyncVersionUnsupportedMessage,
    );
  }
}

void validateRemoteVaultHeaderSchema(VaultHeader header) {
  if (header.schemaVersion > supportedVaultSchemaVersion) {
    throw const SyncRunException(
      'sync.remote_vault_schema_unsupported',
      remoteSyncVersionUnsupportedMessage,
    );
  }
}

Future<VaultHeader> readRemoteVaultHeader(
  SyncProvider provider,
  RemoteManifest manifest,
) async {
  final headerRef = remoteVaultHeaderRefFor(manifest);
  try {
    final header = VaultHeader.fromJson(
      jsonDecode(utf8.decode(await provider.readObject(headerRef)))
          as Map<String, Object?>,
    ).copyWith(localUnlockProtectors: const []);
    validateRemoteVaultHeaderSchema(header);
    return header;
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

RemoteObjectRef remoteVaultHeaderRefFor(RemoteManifest manifest) {
  final path = manifest.headerPath;
  if (path == null) {
    return legacyRemoteVaultHeaderRef;
  }
  if (!_isSafeRemoteVaultHeaderPath(path)) {
    throw const SyncRunException(
      'sync.remote_header_invalid',
      'Remote vault header path is invalid.',
    );
  }
  return RemoteObjectRef(path);
}

Future<void> ensureRemoteSyncCompatibleForEnable(SyncProvider provider) async {
  final manifest = await provider.readManifest();
  if (manifest == null) {
    return;
  }
  validateRemoteManifestProtocol(manifest);
  await readRemoteVaultHeader(provider, manifest);
}

bool _isSafeRemoteVaultHeaderPath(String path) {
  if (path == legacyRemoteVaultHeaderRef.path) {
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
