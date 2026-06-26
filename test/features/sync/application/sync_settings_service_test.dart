import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
import 'package:serlink/features/sync/application/sync_record_scope.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late InMemorySecretStore secrets;
  late SyncSettingsService service;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    secrets = InMemorySecretStore();
    service = SyncSettingsService(
      settings: _InMemorySyncSettingsRepository(),
      cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
      secrets: secrets,
    );
  });

  test('saves WebDAV settings outside the encrypted vault', () async {
    final settings = await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'https://dav.example.test/remote.php/dav',
        username: 'ops',
        password: 'server-password',
        basePath: 'serlink-sync',
      ),
    );

    expect(settings.endpoint.scheme, 'https');
    expect(settings.basePath, '/serlink-sync');

    final storedPassword = await secrets.read(settings.passwordRef);
    expect(utf8.decode(storedPassword!), 'server-password');

    expect(await records.read(webDavSyncSettingsRecordId), isNull);

    final restored = await service.readWebDav();
    expect(restored!.endpoint.host, 'dav.example.test');
    expect(restored.username, 'ops');
    expect(restored.pinnedCertificateFingerprint, isNull);
  });

  test(
    'saves WebDAV setting without an initialized or unlocked vault',
    () async {
      final lockedVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await lockedVault.initialize(passphrase: 'passphrase');
      await lockedVault.lock();
      final lockedService = SyncSettingsService(
        settings: _InMemorySyncSettingsRepository(),
        cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
        secrets: secrets,
      );

      await lockedService.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav.example.test',
          username: 'ops',
          password: 'server-password',
          enabled: false,
        ),
      );

      expect((await lockedService.readWebDav())!.enabled, isFalse);
      expect(lockedVault.state, VaultState.locked);

      final uninitializedVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final uninitializedService = SyncSettingsService(
        settings: _InMemorySyncSettingsRepository(),
        cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
        secrets: secrets,
      );

      await uninitializedService.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav2.example.test',
          username: 'deploy',
          password: 'server-password',
        ),
      );

      expect(
        (await uninitializedService.readWebDav())!.endpoint.host,
        'dav2.example.test',
      );
      expect(uninitializedVault.state, VaultState.uninitialized);
    },
  );

  test(
    'migrates legacy encrypted WebDAV setting into local settings',
    () async {
      final legacy = EncryptedSyncSettingsRepository(
        vault: vault,
        records: records,
      );
      final local = _InMemorySyncSettingsRepository();
      await legacy.saveWebDav(
        WebDavSyncSettings(
          endpoint: Uri.parse('https://dav.example.test'),
          username: 'ops',
          basePath: '/serlink',
          passwordRef: const SecretRef('sync:webdav:password'),
          allowInsecureHttp: false,
          enabled: true,
          updatedAt: DateTime.utc(2026, 6, 26, 12),
        ),
      );
      final migratingService = SyncSettingsService(
        settings: MigratingWebDavSyncSettingsRepository(
          primary: local,
          legacy: legacy,
        ),
        cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
        secrets: secrets,
      );

      final migrated = await migratingService.readWebDav();

      expect(migrated!.endpoint.host, 'dav.example.test');
      expect((await local.readWebDav())!.enabled, isTrue);
      expect(await records.read(webDavSyncSettingsRecordId), isNull);
    },
  );

  test(
    'updates metadata without replacing password when password is blank',
    () async {
      final initial = await service.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav.example.test',
          username: 'ops',
          password: 'first-password',
        ),
      );

      final updated = await service.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav2.example.test',
          username: 'deploy',
          password: '',
          enabled: false,
        ),
      );

      expect(updated.passwordRef, initial.passwordRef);
      expect(updated.endpoint.host, 'dav2.example.test');
      expect(updated.enabled, isFalse);
      expect(
        utf8.decode((await secrets.read(initial.passwordRef))!),
        'first-password',
      );
    },
  );

  test(
    'preserves pinned WebDAV certificate for the same HTTPS endpoint',
    () async {
      await service.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav.example.test',
          username: 'ops',
          password: 'first-password',
        ),
      );
      await service.trustWebDavCertificate(
        WebDavTlsCertificateDetails(
          endpoint: Uri.parse('https://dav.example.test'),
          fingerprint: 'SHA256:abc',
          algorithm: 'SHA256',
          subject: 'CN=dav.example.test',
          issuer: 'CN=Local CA',
          validFrom: DateTime.utc(2026),
          validUntil: DateTime.utc(2027),
          reason: 'untrusted',
        ),
      );

      final updated = await service.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'https://dav.example.test/remote.php/dav',
          username: 'ops',
          password: '',
          basePath: '/serlink',
        ),
      );

      expect(updated.pinnedCertificateFingerprint, 'SHA256:abc');
    },
  );

  test('clears pinned certificate when endpoint host changes', () async {
    await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'https://dav.example.test',
        username: 'ops',
        password: 'first-password',
      ),
    );
    await service.trustWebDavCertificate(
      WebDavTlsCertificateDetails(
        endpoint: Uri.parse('https://dav.example.test'),
        fingerprint: 'SHA256:abc',
        algorithm: 'SHA256',
        subject: 'CN=dav.example.test',
        issuer: 'CN=Local CA',
        validFrom: DateTime.utc(2026),
        validUntil: DateTime.utc(2027),
        reason: 'untrusted',
      ),
    );

    final updated = await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'https://other.example.test',
        username: 'ops',
        password: '',
      ),
    );

    expect(updated.pinnedCertificateFingerprint, isNull);
  });

  test('rejects HTTP WebDAV unless explicitly allowed', () async {
    await expectLater(
      service.saveWebDav(
        const WebDavSyncSettingsDraft(
          endpoint: 'http://dav.example.test',
          username: 'ops',
          password: 'server-password',
        ),
      ),
      throwsA(
        isA<SyncSettingsException>().having(
          (error) => error.code,
          'code',
          'sync.webdav.insecure_http',
        ),
      ),
    );

    final settings = await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'http://dav.example.test',
        username: 'ops',
        password: 'server-password',
        allowInsecureHttp: true,
      ),
    );

    expect(settings.allowInsecureHttp, isTrue);
  });

  test('delete removes settings and stored password', () async {
    final settings = await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'https://dav.example.test',
        username: 'ops',
        password: 'server-password',
      ),
    );

    await service.deleteWebDav();

    expect(await service.readWebDav(), isNull);
    expect(await secrets.read(settings.passwordRef), isNull);
  });

  test(
    'saves and reads CloudKit settings outside the encrypted vault',
    () async {
      final saved = await service.saveCloudKit(true);
      expect(saved.enabled, isTrue);

      final restored = await service.readCloudKit();
      expect(restored!.enabled, isTrue);

      expect(await records.read(cloudKitSyncSettingsRecordId), isNull);

      await service.deleteCloudKit();
      expect((await service.readCloudKit())!.enabled, isTrue);
    },
  );

  test(
    'saves CloudKit setting without an initialized or unlocked vault',
    () async {
      final lockedVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final settings = await lockedVault.initialize(passphrase: 'passphrase');
      await lockedVault.lock();
      final cloudKitSettings = _InMemoryCloudKitSyncSettingsRepository();
      final lockedService = SyncSettingsService(
        settings: EncryptedSyncSettingsRepository(
          vault: lockedVault,
          records: InMemoryVaultRecordRepository(),
        ),
        cloudKitSettings: cloudKitSettings,
        secrets: secrets,
      );

      await lockedService.saveCloudKit(false);

      expect((await lockedService.readCloudKit())!.enabled, isFalse);
      expect(lockedVault.state, VaultState.locked);

      final uninitializedVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final uninitializedService = SyncSettingsService(
        settings: EncryptedSyncSettingsRepository(
          vault: uninitializedVault,
          records: InMemoryVaultRecordRepository(),
        ),
        cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
        secrets: secrets,
      );

      await uninitializedService.saveCloudKit(false);

      expect((await uninitializedService.readCloudKit())!.enabled, isFalse);
      expect(uninitializedVault.state, VaultState.uninitialized);
      expect(settings.header, isNotNull);
    },
  );

  test(
    'migrates legacy encrypted CloudKit setting into local settings',
    () async {
      final legacy = EncryptedSyncSettingsRepository(
        vault: vault,
        records: records,
      );
      final cloudKitSettings = _InMemoryCloudKitSyncSettingsRepository();
      await legacy.saveCloudKit(
        CloudKitSyncSettings(
          enabled: false,
          updatedAt: DateTime.utc(2026, 6, 25, 12),
        ),
      );
      final migratingService = SyncSettingsService(
        settings: legacy,
        cloudKitSettings: MigratingCloudKitSyncSettingsRepository(
          primary: cloudKitSettings,
          legacy: legacy,
        ),
        secrets: secrets,
      );

      final migrated = await migratingService.readCloudKit();

      expect(migrated!.enabled, isFalse);
      expect((await cloudKitSettings.readCloudKit())!.enabled, isFalse);
      expect(await records.read(cloudKitSyncSettingsRecordId), isNull);
    },
  );

  test('defaults CloudKit sync to enabled when available', () async {
    final settings = await service.readCloudKit();
    expect(settings!.enabled, isTrue);
  });

  test('CloudKit sync default is absent when unavailable', () async {
    final unavailableService = SyncSettingsService(
      settings: EncryptedSyncSettingsRepository(vault: vault, records: records),
      cloudKitSettings: _InMemoryCloudKitSyncSettingsRepository(),
      secrets: secrets,
      cloudKitAvailable: false,
    );

    expect(await unavailableService.readCloudKit(), isNull);
  });

  test('CloudKitSyncSettings round-trips through JSON', () {
    final original = CloudKitSyncSettings(
      enabled: true,
      updatedAt: DateTime.utc(2026, 5, 31, 12),
    );
    final restored = CloudKitSyncSettings.fromJson(original.toJson());
    expect(restored.enabled, original.enabled);
    expect(restored.updatedAt, original.updatedAt);
  });

  test('activeSyncProvider defaults to CloudKit when available', () async {
    expect(
      (await (await service.activeSyncProvider())!.capabilities()).kind,
      SyncProviderKind.cloudKit,
    );
  });

  test('activeSyncProvider prefers CloudKit over WebDAV', () async {
    await service.saveWebDav(
      const WebDavSyncSettingsDraft(
        endpoint: 'https://dav.example.test',
        username: 'ops',
        password: 'server-password',
      ),
    );
    expect(
      (await (await service.activeSyncProvider())!.capabilities()).kind,
      SyncProviderKind.cloudKit,
    );

    await service.saveCloudKit(false);
    expect(
      (await (await service.activeSyncProvider())!.capabilities()).kind,
      SyncProviderKind.webDav,
    );

    await service.saveCloudKit(true);
    expect(
      (await (await service.activeSyncProvider())!.capabilities()).kind,
      SyncProviderKind.cloudKit,
    );
  });

  test(
    'activeSyncProvider is null when providers are explicitly disabled',
    () async {
      await service.saveCloudKit(false);
      expect(await service.activeSyncProvider(), isNull);
    },
  );
}

class _InMemoryCloudKitSyncSettingsRepository
    implements CloudKitSyncSettingsRepository {
  CloudKitSyncSettings? _settings;

  @override
  Future<CloudKitSyncSettings?> readCloudKit() async => _settings;

  @override
  Future<void> saveCloudKit(CloudKitSyncSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> deleteCloudKit() async {
    _settings = null;
  }
}

class _InMemorySyncSettingsRepository implements SyncSettingsRepository {
  WebDavSyncSettings? _webDav;

  @override
  Future<WebDavSyncSettings?> readWebDav() async => _webDav;

  @override
  Future<void> saveWebDav(WebDavSyncSettings settings) async {
    _webDav = settings;
  }

  @override
  Future<void> deleteWebDav() async {
    _webDav = null;
  }
}
