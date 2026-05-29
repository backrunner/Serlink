import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';

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
      settings: EncryptedSyncSettingsRepository(vault: vault, records: records),
      secrets: secrets,
    );
  });

  test(
    'saves WebDAV settings encrypted and stores password in secret store',
    () async {
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

      final envelopes = await records.list(
        type: EncryptedSyncSettingsRepository.recordType,
      );
      expect(envelopes, hasLength(1));
      final serializedEnvelope = jsonEncode(envelopes.single.toJson());
      expect(serializedEnvelope, isNot(contains('server-password')));
      expect(serializedEnvelope, isNot(contains('dav.example.test')));

      final restored = await service.readWebDav();
      expect(restored!.endpoint.host, 'dav.example.test');
      expect(restored.username, 'ops');
      expect(restored.pinnedCertificateFingerprint, isNull);
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
}
