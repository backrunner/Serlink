import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/application/command_decision_guard.dart';
import 'package:serlink/features/mcp/application/mcp_command_approval.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  test(
    'timeout persists independently without revoking active permits',
    () async {
      final secrets = InMemorySecretStore();
      final policy = McpCommandApproval(secrets);
      expect((await policy.read()).timeoutSeconds, 60);
      // An existing v1 bypass record remains compatible.
      await secrets.write(
        McpCommandApproval.storageKey,
        utf8.encode('{"bypass":true,"revision":"old"}'),
      );
      final before = await policy.read();
      final generation = policy.generation;
      await policy.saveTimeout(600);
      expect(policy.generation, generation);
      await policy.validate(before);
      var restored = await McpCommandApproval(secrets).read();
      expect(restored.timeout, const Duration(minutes: 10));
      expect(restored.bypass, isTrue);
      await Future.wait([policy.saveBypass(false), policy.saveTimeout(120)]);
      restored = await policy.read();
      expect(restored.timeoutSeconds, 120);
      expect(restored.bypass, isFalse);
      expect(() => policy.saveTimeout(0), throwsArgumentError);
      expect(() => policy.saveTimeout(601), throwsArgumentError);
    },
  );

  test(
    'invalid stored timeout falls back and failed save preserves it',
    () async {
      final secrets = _FailingStore();
      final policy = McpCommandApproval(secrets);
      await secrets.write(
        McpCommandApproval.timeoutStorageKey,
        utf8.encode('-1'),
      );
      expect((await policy.read()).timeoutSeconds, 60);
      await policy.saveTimeout(300);
      secrets.failWrite = true;
      await expectLater(policy.saveTimeout(30), throwsStateError);
      expect((await policy.read()).timeoutSeconds, 300);
      secrets.failWrite = false;
      await policy.saveTimeout(30);
      expect((await policy.read()).timeoutSeconds, 30);
    },
  );

  test(
    'default requires approval and bypass survives a service reload',
    () async {
      final secrets = InMemorySecretStore();
      final policy = McpCommandApproval(secrets);
      final standard = await policy.read();
      expect(standard.bypass, isFalse);
      await policy.saveBypass(true);
      final restored = await McpCommandApproval(secrets).read();
      expect(restored.bypass, isTrue);
      await expectLater(policy.validate(standard), throwsA(_changed));
      await policy.saveBypass(false);
      await policy.saveBypass(true);
      // Toggling back does not revive an in-flight authorization.
      await expectLater(policy.validate(restored), throwsA(_changed));
    },
  );

  for (final value in [
    '{',
    'true',
    '{"bypass":true}',
    '{"bypass":"true","revision":"r"}',
    '{"bypass":true,"revision":""}',
  ]) {
    test('corrupt configuration fails closed: $value', () async {
      final secrets = InMemorySecretStore();
      await secrets.write(McpCommandApproval.storageKey, utf8.encode(value));
      await expectLater(
        McpCommandApproval(secrets).read(),
        throwsA(_unavailable),
      );
    });
  }

  test('failed saves retain the old policy and allow later saves', () async {
    final secrets = _FailingStore();
    final policy = McpCommandApproval(secrets);
    secrets.failWrite = true;
    await expectLater(policy.saveBypass(true), throwsStateError);
    expect((await policy.read()).bypass, isFalse);
    secrets.failWrite = false;
    await Future.wait([policy.saveBypass(true), policy.saveBypass(false)]);
    expect((await policy.read()).bypass, isFalse);
    secrets.failRead = true;
    await expectLater(policy.read(), throwsA(_unavailable));
  });

  for (final input in [
    '',
    '\r',
    'rm ',
    'ls\nrm ',
    '\x1b[A\r',
    '\x04',
    'ls\b\r',
    'r\t report.csv\r',
  ]) {
    test('rejects unassessable terminal input ${jsonEncode(input)}', () {
      expect(
        () => McpCommandApproval.validateInput(input, rawInput: true),
        throwsA(isA<CommandDecisionException>()),
      );
    });
  }
}

final _changed = isA<CommandDecisionException>().having(
  (error) => error.code,
  'code',
  'command_approval_changed',
);
final _unavailable = isA<CommandDecisionException>().having(
  (error) => error.code,
  'code',
  'command_approval_unavailable',
);

class _FailingStore extends InMemorySecretStore {
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) {
    if (failRead) throw StateError('read failed');
    return super.read(ref, protection: protection);
  }

  @override
  Future<void> write(
    SecretRef ref,
    List<int> value, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) {
    if (failWrite) throw StateError('write failed');
    expect(protection, SecretProtection.deviceLocal);
    return super.write(ref, value, protection: protection);
  }
}
