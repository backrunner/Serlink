import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/application/command_decision_guard.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';

void main() {
  late InMemorySecretStore store;
  late _Model model;
  late CommandDecisionGuard guard;
  setUp(() {
    store = InMemorySecretStore();
    model = _Model();
    guard = CommandDecisionGuard(
      secrets: store,
      model: model,
      timeout: const Duration(milliseconds: 40),
    );
  });
  Future<void> enable() => guard.saveSettings(
    enabled: true,
    model: 'jev-1.13.0',
    apiKey: 'fixture-key',
    dataSharingConsent: true,
  );

  test(
    'existing settings without a provider keep Jev and its consent',
    () async {
      await enable();
      final record = jsonDecode(
        utf8.decode((await store.read(CommandDecisionGuard.secretRef))!),
      ) as Map;
      record.remove('provider');
      record.remove('accountId');
      record.remove('endpoint');
      await store.write(
        CommandDecisionGuard.secretRef,
        utf8.encode(jsonEncode(record)),
      );
      final settings = await guard.readSettings();
      expect(settings.connection.provider, CommandDecisionProvider.typesafe);
      expect(settings.dataSharingConsent, isTrue);
      await guard.check(command: 'ls');
      expect(model.keys, ['fixture-key']);
    },
  );

  test('switching recipient never reuses a previous key or consent', () async {
    await enable();
    await expectLater(
      guard.saveSettings(
        enabled: true,
        model: 'gemini-decision-1',
        connection: const CommandDecisionConnection(
          provider: CommandDecisionProvider.gemini,
        ),
      ),
      throwsA(_error('command_guard_invalid_configuration')),
    );
    await expectLater(
      guard.saveSettings(
        enabled: true,
        model: 'gemini-decision-1',
        apiKey: 'new-key',
        connection: const CommandDecisionConnection(
          provider: CommandDecisionProvider.gemini,
        ),
      ),
      throwsA(_error('command_guard_consent_required')),
    );
    await guard.saveSettings(
      enabled: false,
      model: 'gemini-decision-1',
      connection: const CommandDecisionConnection(
        provider: CommandDecisionProvider.gemini,
      ),
    );
    final settings = await guard.readSettings();
    expect(settings.hasApiKey, isFalse);
    expect(settings.dataSharingConsent, isFalse);
  });

  test(
    'self-hosted protection needs consent but can omit an API key',
    () async {
      const local = CommandDecisionConnection(
        provider: CommandDecisionProvider.local,
        endpoint: 'http://127.0.0.1:8000/v1/systemone',
      );
      await enable();
      final oldPermit = await guard.check(command: 'ls');
      await expectLater(
        guard.saveSettings(enabled: true, model: 'clef', connection: local),
        throwsA(_error('command_guard_consent_required')),
      );
      await guard.saveSettings(
        enabled: true,
        model: 'clef',
        connection: local,
        dataSharingConsent: true,
      );
      expect((await guard.readSettings()).hasApiKey, isFalse);
      await expectLater(
        guard.validate(oldPermit),
        throwsA(_error('command_guard_changed')),
      );
      await guard.check(command: 'pwd');
      expect(model.keys.last, '');
      expect(model.connections.last.endpoint, local.endpoint);
      await expectLater(
        guard.saveSettings(
          enabled: true,
          model: 'clef',
          connection: const CommandDecisionConnection(
            provider: CommandDecisionProvider.local,
            endpoint: 'http://127.0.0.1:9000/v1/systemone',
          ),
        ),
        throwsA(_error('command_guard_consent_required')),
      );
    },
  );

  for (final provider in ['unknown', 123]) {
    test('unknown provider $provider fails closed', () async {
      await enable();
      final record = jsonDecode(
        utf8.decode((await store.read(CommandDecisionGuard.secretRef))!),
      ) as Map;
      record['provider'] = provider;
      await store.write(
        CommandDecisionGuard.secretRef,
        utf8.encode(jsonEncode(record)),
      );
      await expectLater(
        guard.check(command: 'ls'),
        throwsA(_error('command_guard_unavailable')),
      );
      expect(model.commands, isEmpty);
    });
  }

  test(
    'older Jev-only readers never receive a different provider API key',
    () async {
      await guard.saveSettings(
        enabled: true,
        model: 'gemini-decision-1',
        apiKey: 'google-fixture-key',
        connection: const CommandDecisionConnection(
          provider: CommandDecisionProvider.gemini,
        ),
        dataSharingConsent: true,
      );
      final record = jsonDecode(
        utf8.decode((await store.read(CommandDecisionGuard.secretRef))!),
      ) as Map;
      expect(record['apiKey'], isEmpty);
      expect(record['providerApiKey'], 'google-fixture-key');
      expect((await guard.readSettings()).hasApiKey, isTrue);
      await guard.check(command: 'pwd');
      expect(model.keys, ['google-fixture-key']);
    },
  );

  test(
    'long commands reach the model intact within the 4 MiB budget',
    () async {
      await enable();
      final source = "echo '${'x' * 150000}'";
      await guard.check(command: source);
      expect(model.commands.single, source);
    },
  );

  test('disabled by default, with no paid request', () async {
    final settings = await guard.readSettings();
    expect(settings.enabled, isFalse);
    expect(settings.hasApiKey, isFalse);
    final permit = await guard.check(command: 'ls');
    await guard.validate(permit);
    expect(model.commands, isEmpty);
  });

  test(
    'enabling requires explicit sharing consent before any model call',
    () async {
      await expectLater(
        guard.saveSettings(
          enabled: true,
          model: 'jev-1.13.0',
          apiKey: 'fixture-key',
        ),
        throwsA(_error('command_guard_consent_required')),
      );
      expect((await guard.readSettings()).enabled, false);
      expect(model.commands, isEmpty);
    },
  );

  test('legacy enabled configuration blocks until renewed consent', () async {
    await enable();
    final config = jsonDecode(
      utf8.decode((await store.read(CommandDecisionGuard.secretRef))!),
    ) as Map<String, dynamic>;
    config.remove('dataSharingConsentVersion');
    await store.write(
      CommandDecisionGuard.secretRef,
      utf8.encode(jsonEncode(config)),
    );
    expect((await guard.readSettings()).dataSharingConsent, false);
    await expectLater(
      guard.check(command: 'ls'),
      throwsA(_error('command_guard_consent_required')),
    );
    expect(model.commands, isEmpty);
    await guard.saveSettings(
      enabled: true,
      model: 'jev-1.13.0',
      dataSharingConsent: true,
    );
    await guard.check(command: 'ls');
    expect(model.commands, ['ls']);
  });

  test(
    'withdrawing consent or removing the key prevents further requests',
    () async {
      await enable();
      await guard.saveSettings(
        enabled: false,
        model: 'jev-1.13.0',
        dataSharingConsent: false,
      );
      await guard.check(command: 'ls');
      expect(model.commands, isEmpty);
      await expectLater(
        guard.saveSettings(enabled: true, model: 'jev-1.13.0'),
        throwsA(_error('command_guard_consent_required')),
      );
      await enable();
      await guard.saveSettings(
        enabled: false,
        model: 'jev-1.13.0',
        removeApiKey: true,
      );
      expect((await guard.readSettings()).dataSharingConsent, false);
    },
  );

  test('stores one device-local config, retains and removes the key', () async {
    await enable();
    final restored = CommandDecisionGuard(secrets: store, model: model);
    expect((await restored.readSettings()).enabled, isTrue);
    await restored.saveSettings(enabled: true, model: 'jev-latest', apiKey: '');
    final permit = await restored.check(command: 'ls');
    await restored.validate(permit);
    expect(model.keys, ['fixture-key']);
    expect(model.models, ['jev-latest']);
    await restored.saveSettings(
      enabled: false,
      model: 'jev-latest',
      removeApiKey: true,
    );
    expect((await restored.readSettings()).hasApiKey, isFalse);
    final bytes = await store.read(CommandDecisionGuard.secretRef);
    expect(utf8.decode(bytes!), isNot(contains('fixture-key')));
  });

  test(
    'enabling without a key leaves the previous configuration intact',
    () async {
      await expectLater(
        guard.saveSettings(enabled: true, model: 'jev-latest'),
        throwsA(_error('command_guard_invalid_configuration')),
      );
      expect((await guard.readSettings()).enabled, isFalse);
    },
  );

  for (final decision in [
    CommandDecision.dangerous,
    CommandDecision.uncertain,
  ]) {
    test('$decision is never an execution permit', () async {
      await enable();
      model.decision = decision;
      await expectLater(
        guard.check(command: 'unrecognized payload'),
        throwsA(
          _error(
            decision == CommandDecision.dangerous
                ? 'command_model_blocked'
                : 'command_model_uncertain',
          ),
        ),
      );
    });
  }

  test(
    'provider error and timeout fail closed without exposing its message',
    () async {
      await enable();
      model.failure = StateError('fixture-key echoed command');
      await expectLater(
        guard.check(command: 'ls'),
        throwsA(_error('command_guard_unavailable')),
      );
      model.failure = null;
      model.pending = Completer<CommandDecision>();
      await expectLater(
        guard.check(command: 'ls'),
        throwsA(_error('command_guard_unavailable')),
      );
      model.pending!.complete(CommandDecision.safe);
    },
  );

  test(
    'configuration changes invalidate even a safe or disabled permit',
    () async {
      final disabledPermit = await guard.check(command: 'ls');
      await enable();
      await expectLater(
        guard.validate(disabledPermit),
        throwsA(_error('command_guard_changed')),
      );
      final permit = await guard.check(command: 'ls');
      await guard.saveSettings(
        enabled: true,
        model: 'jev-1.13.0',
        apiKey: 'rotated-key',
      );
      await expectLater(
        guard.validate(permit),
        throwsA(_error('command_guard_changed')),
      );
    },
  );

  test('malformed configuration is not silently treated as disabled', () async {
    await store.write(CommandDecisionGuard.secretRef, utf8.encode('{broken'));
    await expectLater(
      guard.check(command: 'ls'),
      throwsA(_error('command_guard_unavailable')),
    );
    expect(model.commands, isEmpty);
  });

  test(
    'raw partial, control, bare Enter and oversized input never reach model',
    () async {
      await enable();
      for (final input in ['rm ', '\x1b[A\r', '\r', 'yes\ntrailing']) {
        await expectLater(
          guard.check(command: input, rawInput: true),
          throwsA(_error('command_input_requires_exec')),
        );
      }
      await expectLater(
        guard.check(command: 'ls', hasUnsubmittedInput: true),
        throwsA(_error('command_input_reset_required')),
      );
      await expectLater(
        guard.check(
          command: '中' * (CommandDecisionGuard.maxCommandBytes ~/ 3 + 1),
        ),
        throwsA(_error('command_guard_input_too_large')),
      );
      expect(model.commands, isEmpty);
      await guard.check(command: 'ls\r', rawInput: true);
      expect(model.commands, ['ls\r']);
    },
  );
}

TypeMatcher<CommandDecisionException> _error(String code) =>
    isA<CommandDecisionException>().having((error) => error.code, 'code', code);

class _Model implements CommandDecisionModel {
  CommandDecision decision = CommandDecision.safe;
  Object? failure;
  Completer<CommandDecision>? pending;
  final List<String> commands = [];
  final List<String> keys = [];
  final List<String> models = [];
  final List<CommandDecisionConnection> connections = [];
  @override
  Future<CommandDecision> assess({
    required String command,
    required String model,
    required String apiKey,
    CommandDecisionConnection connection = const CommandDecisionConnection(),
  }) async {
    commands.add(command);
    connections.add(connection);
    keys.add(apiKey);
    models.add(model);
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return decision;
  }
}
