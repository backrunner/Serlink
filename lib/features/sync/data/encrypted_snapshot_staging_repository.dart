import 'package:drift/drift.dart';

import '../../../database/serlink_database.dart';
import '../application/encrypted_snapshot_staging.dart';
import '../application/sync_run_service.dart';
import '../domain/sync_provider.dart';

class EncryptedSnapshotStagingRepository {
  EncryptedSnapshotStagingRepository(this._database);

  final SerlinkDatabase _database;

  Future<void> save(StagedEncryptedSnapshot snapshot) async {
    final providerKind = syncProviderKindName(snapshot.providerKind);
    await _database.transaction(() async {
      await clear(
        providerKind: snapshot.providerKind,
        vaultId: snapshot.vaultId,
      );
      await _database.customStatement(
        '''
INSERT INTO sync_staged_snapshots (
  provider_kind,
  vault_id,
  manifest,
  manifest_fingerprint,
  protocol_version,
  header_path,
  completed_at
) VALUES (?, ?, ?, ?, ?, ?, ?)
''',
        [
          providerKind,
          snapshot.vaultId,
          Uint8List.fromList(snapshot.manifestBytes),
          snapshot.manifestFingerprint,
          snapshot.manifest.protocolVersion,
          snapshot.manifest.headerPath,
          snapshot.completedAt.toUtc().toIso8601String(),
        ],
      );
      for (final entry in snapshot.objects.entries) {
        await _database.customStatement(
          '''
INSERT INTO sync_staged_objects (provider_kind, vault_id, path, bytes)
VALUES (?, ?, ?, ?)
''',
          [
            providerKind,
            snapshot.vaultId,
            entry.key,
            Uint8List.fromList(entry.value),
          ],
        );
      }
    });
  }

  Future<StagedEncryptedSnapshot?> read({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    final providerKindName = syncProviderKindName(providerKind);
    final snapshotRows = await _database
        .customSelect(
          '''
SELECT manifest, manifest_fingerprint, completed_at
FROM sync_staged_snapshots
WHERE provider_kind = ? AND vault_id = ?
''',
          variables: [Variable(providerKindName), Variable(vaultId)],
          readsFrom: const {},
        )
        .get();
    if (snapshotRows.isEmpty) {
      return null;
    }
    final row = snapshotRows.single;
    final manifestBytes = List<int>.unmodifiable(
      row.read<Uint8List>('manifest'),
    );
    final manifest = RemoteManifest.fromBytes(manifestBytes);
    final objectRows = await _database
        .customSelect(
          '''
SELECT path, bytes
FROM sync_staged_objects
WHERE provider_kind = ? AND vault_id = ?
ORDER BY path ASC
''',
          variables: [Variable(providerKindName), Variable(vaultId)],
          readsFrom: const {},
        )
        .get();
    return StagedEncryptedSnapshot(
      providerKind: providerKind,
      vaultId: vaultId,
      manifest: manifest,
      manifestBytes: manifestBytes,
      manifestFingerprint: row.read<String>('manifest_fingerprint'),
      objects: {
        for (final objectRow in objectRows)
          objectRow.read<String>('path'): List<int>.unmodifiable(
            objectRow.read<Uint8List>('bytes'),
          ),
      },
      completedAt: DateTime.parse(row.read<String>('completed_at')).toUtc(),
    );
  }

  Future<void> clear({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    await _database.transaction(() async {
      await _database.customStatement(
        '''
DELETE FROM sync_staged_objects
WHERE provider_kind = ? AND vault_id = ?
''',
        [syncProviderKindName(providerKind), vaultId],
      );
      await _database.customStatement(
        '''
DELETE FROM sync_staged_snapshots
WHERE provider_kind = ? AND vault_id = ?
''',
        [syncProviderKindName(providerKind), vaultId],
      );
    });
  }
}

class PendingRemoteReset {
  const PendingRemoteReset({
    required this.providerKind,
    required this.vaultId,
    required this.marker,
    required this.updatedAt,
  });

  final SyncProviderKind providerKind;
  final String vaultId;
  final RemoteResetMarker marker;
  final DateTime updatedAt;
}

class PendingRemoteResetRepository {
  PendingRemoteResetRepository(this._database);

  final SerlinkDatabase _database;

  Future<void> save({
    required SyncProviderKind providerKind,
    required RemoteResetMarker marker,
  }) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database.customStatement(
        '''
DELETE FROM sync_staged_objects
WHERE provider_kind = ? AND vault_id = ?
''',
        [syncProviderKindName(providerKind), marker.vaultId],
      );
      await _database.customStatement(
        '''
DELETE FROM sync_staged_snapshots
WHERE provider_kind = ? AND vault_id = ?
''',
        [syncProviderKindName(providerKind), marker.vaultId],
      );
      await _database.customStatement(
        '''
INSERT OR REPLACE INTO sync_pending_resets (
  provider_kind,
  vault_id,
  marker,
  reset_at,
  updated_at
) VALUES (?, ?, ?, ?, ?)
''',
        [
          syncProviderKindName(providerKind),
          marker.vaultId,
          Uint8List.fromList(marker.toBytes()),
          marker.resetAt.toUtc().toIso8601String(),
          now.toIso8601String(),
        ],
      );
    });
  }

  Future<PendingRemoteReset?> read({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    final rows = await _database
        .customSelect(
          '''
SELECT marker, updated_at
FROM sync_pending_resets
WHERE provider_kind = ? AND vault_id = ?
''',
          variables: [
            Variable(syncProviderKindName(providerKind)),
            Variable(vaultId),
          ],
          readsFrom: const {},
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return PendingRemoteReset(
      providerKind: providerKind,
      vaultId: vaultId,
      marker: RemoteResetMarker.fromBytes(row.read<Uint8List>('marker')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    );
  }

  Future<void> clear({
    required SyncProviderKind providerKind,
    required String vaultId,
  }) async {
    await _database.customStatement(
      '''
DELETE FROM sync_pending_resets
WHERE provider_kind = ? AND vault_id = ?
''',
      [syncProviderKindName(providerKind), vaultId],
    );
  }
}

class CloudKitSyncShadowSettings {
  const CloudKitSyncShadowSettings({
    required this.vaultId,
    required this.enabled,
    required this.updatedAt,
  });

  final String vaultId;
  final bool enabled;
  final DateTime updatedAt;
}

class CloudKitSyncShadowSettingsStore {
  CloudKitSyncShadowSettingsStore(this._database);

  final SerlinkDatabase _database;

  Future<void> save({required String vaultId, required bool enabled}) async {
    await _database.customStatement(
      '''
INSERT OR REPLACE INTO cloudkit_sync_shadow_settings (
  vault_id,
  enabled,
  updated_at
) VALUES (?, ?, ?)
''',
      [vaultId, enabled ? 1 : 0, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<CloudKitSyncShadowSettings?> read(String vaultId) async {
    final rows = await _database
        .customSelect(
          '''
SELECT enabled, updated_at
FROM cloudkit_sync_shadow_settings
WHERE vault_id = ?
''',
          variables: [Variable(vaultId)],
          readsFrom: const {},
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return CloudKitSyncShadowSettings(
      vaultId: vaultId,
      enabled: row.read<int>('enabled') != 0,
      updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    );
  }

  Future<void> delete(String vaultId) async {
    await _database.customStatement(
      '''
DELETE FROM cloudkit_sync_shadow_settings
WHERE vault_id = ?
''',
      [vaultId],
    );
  }
}
