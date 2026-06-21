import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sync/application/encrypted_snapshot_staging.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/encrypted_snapshot_staging_repository.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';

void main() {
  late SerlinkDatabase database;
  late EncryptedSnapshotStagingRepository staging;
  late PendingRemoteResetRepository resets;
  late CloudKitSyncShadowSettingsStore shadow;

  setUp(() {
    database = SerlinkDatabase(NativeDatabase.memory());
    staging = EncryptedSnapshotStagingRepository(database);
    resets = PendingRemoteResetRepository(database);
    shadow = CloudKitSyncShadowSettingsStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a staged encrypted snapshot', () async {
    final manifest = RemoteManifest(
      vaultId: 'vault-1',
      protocolVersion: 1,
      headerPath: 'vault/headers/vault-1.json',
      encryptedPayload: [1, 2, 3],
      snapshotObjectPaths: const [
        'vault/headers/vault-1.json',
        'records/host%3A1-rev.json',
      ],
    );
    final snapshot = StagedEncryptedSnapshot(
      providerKind: SyncProviderKind.cloudKit,
      vaultId: 'vault-1',
      manifest: manifest,
      manifestBytes: manifest.toBytes(),
      manifestFingerprint: manifestFingerprint(manifest),
      objects: const {
        'vault/headers/vault-1.json': [4, 5],
        'records/host%3A1-rev.json': [6, 7],
      },
      completedAt: DateTime.utc(2026, 6, 21, 10),
    );

    await staging.save(snapshot);
    final restored = await staging.read(
      providerKind: SyncProviderKind.cloudKit,
      vaultId: 'vault-1',
    );

    expect(restored, isNotNull);
    expect(restored!.manifestFingerprint, manifestFingerprint(manifest));
    expect(restored.manifest.snapshotObjectPaths, manifest.snapshotObjectPaths);
    expect(restored.objects['records/host%3A1-rev.json'], [6, 7]);

    final provider = StagedSnapshotSyncProvider(restored);
    expect(await provider.readManifest(), isNotNull);
    expect(
      await provider.readObject(
        const RemoteObjectRef('vault/headers/vault-1.json'),
      ),
      [4, 5],
    );
    await expectLater(
      provider.writeObject(const RemoteObjectRef('records/new.json'), [1]),
      throwsA(isA<SyncProviderException>()),
    );
  });

  test('pending reset clears staged snapshot for the same vault', () async {
    final manifest = RemoteManifest(
      vaultId: 'vault-1',
      protocolVersion: 1,
      encryptedPayload: [1],
    );
    await staging.save(
      StagedEncryptedSnapshot(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: 'vault-1',
        manifest: manifest,
        manifestBytes: manifest.toBytes(),
        manifestFingerprint: manifestFingerprint(manifest),
        objects: const {
          'records/a.json': [1],
        },
        completedAt: DateTime.utc(2026),
      ),
    );

    await resets.save(
      providerKind: SyncProviderKind.cloudKit,
      marker: RemoteResetMarker(
        vaultId: 'vault-1',
        resetAt: DateTime.utc(2026, 6, 21),
      ),
    );

    expect(
      await staging.read(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: 'vault-1',
      ),
      isNull,
    );
    expect(
      (await resets.read(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: 'vault-1',
      ))?.marker.vaultId,
      'vault-1',
    );
  });

  test('cloudkit shadow settings round trip enabled state', () async {
    await shadow.save(vaultId: 'vault-1', enabled: false);

    final disabled = await shadow.read('vault-1');
    expect(disabled?.enabled, isFalse);

    await shadow.save(vaultId: 'vault-1', enabled: true);
    final enabled = await shadow.read('vault-1');
    expect(enabled?.enabled, isTrue);

    await shadow.delete('vault-1');
    expect(await shadow.read('vault-1'), isNull);
  });
}
