import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';

void main() {
  late SerlinkDatabase database;
  late InMemoryVaultService vault;

  setUp(() async {
    database = SerlinkDatabase(NativeDatabase.memory());
    vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
    await vault.initialize(passphrase: 'good passphrase');
  });

  tearDown(() async {
    await database.close();
  });

  test('persists and filters encrypted record envelopes', () async {
    final repository = DriftVaultRecordRepository(database);
    final password = await vault.encryptRecord(
      id: VaultRecordId('identity-password'),
      type: 'identity.password',
      plaintext: utf8.encode('secret-password'),
    );
    final host = await vault.encryptRecord(
      id: VaultRecordId('host-production'),
      type: 'host',
      plaintext: utf8.encode('hostname=bastion.internal'),
    );

    await repository.upsert(password);
    await repository.upsert(host);

    final restored = await repository.read(password.id);
    expect(restored, isNotNull);
    expect(
      await vault.decryptRecord(restored!),
      utf8.encode('secret-password'),
    );
    expect(await repository.list(type: 'identity.password'), hasLength(1));
    expect(await repository.list(), hasLength(2));
  });

  test('persists vault header json', () async {
    final headerStore = DriftVaultHeaderStore(database);
    final initialized = vault.header;
    expect(initialized, isNotNull);

    await headerStore.save(initialized!);
    final restored = await headerStore.read();

    expect(restored, isNotNull);
    expect(restored!.schemaVersion, initialized.schemaVersion);
    expect(restored.passphraseCiphertext, initialized.passphraseCiphertext);

    await headerStore.clear();

    expect(await headerStore.read(), isNull);
  });
}
