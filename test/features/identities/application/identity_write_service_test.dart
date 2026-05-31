import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/application/identity_write_service.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/identities/domain/identity_secret.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('updates credential metadata and password secret material', () async {
    final fixture = await _Fixture.create();
    await fixture.saveIdentity(
      id: IdentityId('ops-password'),
      kind: IdentityKind.password,
      material: const IdentitySecretMaterial(password: 'old-password'),
    );

    final updated = await fixture.service.update(
      IdentityUpdateDraft(
        id: IdentityId('ops-password'),
        displayName: 'Ops Password',
        usernameHint: 'ops',
        password: 'new-password',
      ),
    );

    expect(updated.displayName, 'Ops Password');
    expect(updated.usernameHint, 'ops');
    final stored = await fixture.identities.read(IdentityId('ops-password'));
    expect(stored!.updatedAt, isNot(stored.createdAt));

    final secret = await fixture.service.readSecretMaterial(stored);
    expect(secret!.password, 'new-password');
  });

  test('updates OpenSSH certificate material and principal', () async {
    final fixture = await _Fixture.create();
    await fixture.saveIdentity(
      id: IdentityId('deploy-cert'),
      kind: IdentityKind.openSshCertificate,
      material: const IdentitySecretMaterial(
        privateKeyPem:
            '-----BEGIN OPENSSH PRIVATE KEY-----\nold\n-----END OPENSSH PRIVATE KEY-----',
        openSshCertificate:
            'ssh-ed25519-cert-v01@openssh.com AAAAB3NzaC1yc2EAAAADAQABAAABAQ== old@example',
      ),
    );

    final updated = await fixture.service.update(
      IdentityUpdateDraft(
        id: IdentityId('deploy-cert'),
        displayName: 'Deploy Certificate',
        usernameHint: 'deploy',
        privateKeyPem:
            '-----BEGIN OPENSSH PRIVATE KEY-----\nnew\n-----END OPENSSH PRIVATE KEY-----',
        openSshCertificate:
            'ssh-ed25519-cert-v01@openssh.com AAAAB3NzaC1yc2EAAAADAQABAAABAQ== deploy@example',
      ),
    );

    expect(updated.certificatePrincipal, 'deploy@example');
    final secret = await fixture.service.readSecretMaterial(updated);
    expect(secret!.privateKeyPem, contains('new'));
    expect(secret.openSshCertificate, contains('deploy@example'));
  });

  test('rejects invalid private key without replacing existing secret', () async {
    final fixture = await _Fixture.create();
    await fixture.saveIdentity(
      id: IdentityId('ops-key'),
      kind: IdentityKind.privateKey,
      material: const IdentitySecretMaterial(
        privateKeyPem:
            '-----BEGIN OPENSSH PRIVATE KEY-----\nold\n-----END OPENSSH PRIVATE KEY-----',
      ),
    );
    final before = await fixture.identities.read(IdentityId('ops-key'));

    await expectLater(
      fixture.service.update(
        IdentityUpdateDraft(
          id: IdentityId('ops-key'),
          displayName: 'Ops Key',
          privateKeyPem: 'not a key',
        ),
      ),
      throwsA(
        isA<IdentityWriteException>().having(
          (error) => error.code,
          'code',
          'identity.private_key_invalid',
        ),
      ),
    );

    final after = await fixture.identities.read(IdentityId('ops-key'));
    expect(after!.updatedAt, before!.updatedAt);
    final secret = await fixture.service.readSecretMaterial(after);
    expect(secret!.privateKeyPem, contains('old'));
  });
}

class _Fixture {
  _Fixture({
    required this.vault,
    required this.records,
    required this.identities,
    required this.service,
  });

  final InMemoryVaultService vault;
  final InMemoryVaultRecordRepository records;
  final EncryptedIdentityRepository identities;
  final IdentityWriteService service;

  static Future<_Fixture> create() async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final identities = EncryptedIdentityRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');
    return _Fixture(
      vault: vault,
      records: records,
      identities: identities,
      service: IdentityWriteService(
        identities: identities,
        records: records,
        vault: vault,
      ),
    );
  }

  Future<void> saveIdentity({
    required IdentityId id,
    required IdentityKind kind,
    required IdentitySecretMaterial material,
  }) async {
    final secretRecordId = VaultRecordId('secret:${id.value}');
    await records.upsert(
      await vault.encryptRecord(
        id: secretRecordId,
        type: 'identity_secret',
        plaintext: material.toBytes(),
      ),
    );
    await identities.save(
      IdentityConfig(
        id: id,
        displayName: id.value,
        kind: kind,
        usernameHint: 'old-user',
        secretRecordId: secretRecordId,
        createdAt: DateTime.utc(2026, 5, 28),
        updatedAt: DateTime.utc(2026, 5, 28),
      ),
    );
  }
}
