import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/import_export/application/open_ssh_certificate_import_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  late InMemoryVaultService vault;
  late InMemoryVaultRecordRepository records;
  late EncryptedIdentityRepository identities;
  late OpenSshCertificateImportService service;

  setUp(() async {
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'passphrase');
    records = InMemoryVaultRecordRepository();
    identities = EncryptedIdentityRepository(vault: vault, records: records);
    service = OpenSshCertificateImportService(
      identities: identities,
      records: records,
      vault: vault,
      now: () => DateTime.utc(2026, 5, 28, 10),
    );
  });

  test('previews valid OpenSSH certificate public key line', () {
    final preview = service.preview(
      const OpenSshCertificateImportDraft(
        privateKeyPem: _privateKey,
        certificateText:
            'ssh-ed25519-cert-v01@openssh.com aGVsbG8= deploy@example',
      ),
    );

    expect(preview.algorithm, 'ssh-ed25519-cert-v01@openssh.com');
    expect(preview.comment, 'deploy@example');
    expect(preview.warnings, isEmpty);
  });

  test('rejects invalid certificate and private key formats', () {
    expect(
      () => service.preview(
        const OpenSshCertificateImportDraft(
          privateKeyPem: 'not a key',
          certificateText:
              'ssh-ed25519-cert-v01@openssh.com aGVsbG8= deploy@example',
        ),
      ),
      throwsA(
        isA<OpenSshCertificateImportException>().having(
          (error) => error.code,
          'code',
          'openssh_certificate.private_key_invalid',
        ),
      ),
    );

    expect(
      () => service.preview(
        const OpenSshCertificateImportDraft(
          privateKeyPem: _privateKey,
          certificateText: 'ssh-ed25519 aGVsbG8= deploy@example',
        ),
      ),
      throwsA(
        isA<OpenSshCertificateImportException>().having(
          (error) => error.code,
          'code',
          'openssh_certificate.format_invalid',
        ),
      ),
    );
  });

  test('imports certificate identity and encrypted secret material', () async {
    final identity = await service.importIdentity(
      const OpenSshCertificateImportDraft(
        privateKeyPem: _privateKey,
        privateKeyPassphrase: 'secret-passphrase',
        certificateText:
            'ssh-ed25519-cert-v01@openssh.com aGVsbG8= deploy@example',
        usernameHint: 'deploy',
      ),
    );

    expect(identity.kind, IdentityKind.openSshCertificate);
    expect(identity.displayName, 'Certificate deploy@example');
    expect(identity.usernameHint, 'deploy');
    expect(identity.certificatePrincipal, 'deploy@example');

    final stored = await identities.read(identity.id);
    expect(stored!.secretRecordId, identity.secretRecordId);

    final serializedRecords = jsonEncode([
      for (final record in await records.list()) record.toJson(),
    ]);
    expect(serializedRecords, isNot(contains('secret-passphrase')));
    expect(serializedRecords, isNot(contains('deploy@example')));
    expect(serializedRecords, isNot(contains('OPENSSH PRIVATE KEY')));

    final secretEnvelope = await records.read(identity.secretRecordId!);
    final secretPlaintext = utf8.decode(
      await vault.decryptRecord(secretEnvelope!),
    );
    expect(secretPlaintext, contains('ssh-ed25519-cert-v01@openssh.com'));
    expect(secretPlaintext, contains('secret-passphrase'));
  });
}

const _privateKey = '''
-----BEGIN OPENSSH PRIVATE KEY-----
abc
-----END OPENSSH PRIVATE KEY-----
''';
