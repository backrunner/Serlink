import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/ssh/application/host_key_verification_service.dart';
import 'package:serlink/features/ssh/application/known_host_repository.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('saves trusted fingerprint and skips future prompts', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final knownHosts = EncryptedKnownHostRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');

    var promptCount = 0;
    final service = PersistingHostKeyVerificationService(
      knownHosts: knownHosts,
      confirmUnknownHostKey: (prompt) async {
        promptCount += 1;
        return HostKeyDecision.trustAndSave;
      },
    );

    final prompt = _prompt(fingerprint: 'MD5:aa');
    expect(await service.confirmHostKey(prompt), HostKeyDecision.trustAndSave);
    expect(await service.confirmHostKey(prompt), HostKeyDecision.trustAndSave);

    expect(promptCount, 1);
    expect((await knownHosts.read(HostId('host-1')))!.fingerprint, 'MD5:aa');
  });

  test('changed fingerprint includes previous fingerprint in prompt', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final records = InMemoryVaultRecordRepository();
    final knownHosts = EncryptedKnownHostRepository(
      vault: vault,
      records: records,
    );
    await vault.initialize(passphrase: 'good passphrase');
    await knownHosts.save(
      KnownHostRecord(
        hostId: HostId('host-1'),
        hostname: 'bastion.internal',
        port: 22,
        algorithm: 'ssh-ed25519',
        fingerprint: 'MD5:old',
        createdAt: DateTime.utc(2026, 5, 27),
        updatedAt: DateTime.utc(2026, 5, 27),
      ),
    );

    HostKeyPrompt? seenPrompt;
    final service = PersistingHostKeyVerificationService(
      knownHosts: knownHosts,
      confirmUnknownHostKey: (prompt) async {
        seenPrompt = prompt;
        return HostKeyDecision.cancel;
      },
    );

    expect(
      await service.confirmHostKey(_prompt(fingerprint: 'MD5:new')),
      HostKeyDecision.cancel,
    );
    expect(seenPrompt!.previousFingerprint, 'MD5:old');
    expect((await knownHosts.read(HostId('host-1')))!.fingerprint, 'MD5:old');
  });
}

HostKeyPrompt _prompt({required String fingerprint}) {
  return HostKeyPrompt(
    hostId: HostId('host-1'),
    hostname: 'bastion.internal',
    port: 22,
    algorithm: 'ssh-ed25519',
    fingerprint: fingerprint,
  );
}
