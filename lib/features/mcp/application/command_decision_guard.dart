import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../platform/secret_store.dart';
import '../domain/command_decision.dart';

/// Public settings intentionally omit the API key. All state stays device-local.
class CommandDecisionSettings {
  const CommandDecisionSettings({
    this.enabled = false,
    this.model = 'jev-1.13.0',
    this.hasApiKey = false,
    this.revision = '',
    this.dataSharingConsent = false,
  });

  final bool enabled;
  final String model;
  final bool hasApiKey;
  final String revision;
  final bool dataSharingConsent;
}

class CommandDecisionException implements Exception {
  const CommandDecisionException(this.code);
  final String code;
  @override
  String toString() => code;
}

class CommandDecisionPermit {
  const CommandDecisionPermit(this.revision);
  final String revision;
}

class _Configuration {
  const _Configuration(this.settings, this.apiKey);
  final CommandDecisionSettings settings;
  final String apiKey;
}

/// Secure configuration and execution gate. The model is replaceable without
/// giving a provider access to the terminal, vault, host metadata or SSH keys.
class CommandDecisionGuard {
  CommandDecisionGuard({
    required SecretStore secrets,
    required CommandDecisionModel model,
    this.timeout = const Duration(seconds: 10),
  }) : // Named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _secrets = secrets,
       // ignore: prefer_initializing_formals
       _model = model;

  static const secretRef = SecretRef('serlink.mcp.command-decision.v1');
  static const maxCommandBytes = 8192;
  static const dataSharingConsentVersion = 1;
  final SecretStore _secrets;
  final CommandDecisionModel _model;
  final Duration timeout;
  Future<void> _pendingSave = Future<void>.value();
  int _generation = 0;

  /// Lets the final synchronous send gate detect edits during other awaits.
  int get generation => _generation;

  Future<CommandDecisionSettings> readSettings() async =>
      (await _readConfiguration()).settings;

  Future<_Configuration> _readConfiguration() async {
    await _pendingSave;
    return _load();
  }

  Future<_Configuration> _load() async {
    final bytes = await _secrets.read(secretRef);
    if (bytes == null) {
      return const _Configuration(CommandDecisionSettings(), '');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map ||
        decoded['enabled'] is! bool ||
        decoded['model'] is! String ||
        decoded['apiKey'] is! String ||
        decoded['revision'] is! String ||
        !isValidModel(decoded['model'] as String) ||
        (decoded['revision'] as String).isEmpty) {
      throw const CommandDecisionException('command_guard_unavailable');
    }
    final key = decoded['apiKey'] as String;
    return _Configuration(
      CommandDecisionSettings(
        enabled: decoded['enabled'] as bool,
        model: decoded['model'] as String,
        hasApiKey: key.isNotEmpty,
        revision: decoded['revision'] as String,
        dataSharingConsent:
            decoded['dataSharingConsentVersion'] == dataSharingConsentVersion,
      ),
      key,
    );
  }

  static bool isValidModel(String model) =>
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,127}$').hasMatch(model);

  Future<void> saveSettings({
    required bool enabled,
    required String model,
    String? apiKey,
    bool removeApiKey = false,
    bool? dataSharingConsent,
  }) {
    _generation += 1;
    final result = _pendingSave.then((_) async {
      final previous = await _load();
      final name = model.trim();
      final consent =
          !removeApiKey &&
          (dataSharingConsent ?? previous.settings.dataSharingConsent);
      final key = removeApiKey
          ? ''
          : (apiKey?.trim().isNotEmpty == true
                ? apiKey!.trim()
                : previous.apiKey);
      if (!isValidModel(name) ||
          (key.length > 4096 || key.contains(RegExp(r'[\r\n]'))) ||
          (enabled && key.isEmpty)) {
        throw const CommandDecisionException(
          'command_guard_invalid_configuration',
        );
      }
      if (enabled && !consent) {
        throw const CommandDecisionException('command_guard_consent_required');
      }
      await _secrets.write(
        secretRef,
        utf8.encode(
          jsonEncode({
            'enabled': enabled,
            'model': name,
            'apiKey': key,
            'revision': const Uuid().v4(),
            'dataSharingConsentVersion': consent
                ? dataSharingConsentVersion
                : 0,
          }),
        ),
      );
    });
    _pendingSave = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<CommandDecisionPermit> check({
    required String command,
    bool rawInput = false,
    bool hasUnsubmittedInput = false,
  }) async {
    try {
      final config = await _readConfiguration().timeout(timeout);
      final settings = config.settings;
      if (!settings.enabled) return CommandDecisionPermit(settings.revision);
      if (!settings.dataSharingConsent) {
        throw const CommandDecisionException('command_guard_consent_required');
      }
      if (!settings.hasApiKey) {
        throw const CommandDecisionException('command_guard_unavailable');
      }
      if (hasUnsubmittedInput) {
        throw const CommandDecisionException('command_input_reset_required');
      }
      // Control/history editing and partial submissions cannot be reconstructed
      // reliably in arbitrary shells and TUIs. Require whole checked commands.
      if (command.contains(RegExp(r'[\x00-\x09\x0b\x0c\x0e-\x1f\x7f]')) ||
          (rawInput && !command.endsWith('\n') && !command.endsWith('\r'))) {
        throw const CommandDecisionException('command_input_requires_exec');
      }
      if (utf8.encode(command).length > maxCommandBytes) {
        throw const CommandDecisionException('command_guard_input_too_large');
      }
      if (command.trim().isEmpty) {
        // A bare Enter can repeat a command or accept a destructive prompt.
        throw const CommandDecisionException('command_input_requires_exec');
      }
      final decision = await _model
          .assess(
            command: command,
            model: settings.model,
            apiKey: config.apiKey,
          )
          .timeout(timeout);
      if (decision != CommandDecision.safe) {
        throw CommandDecisionException(
          decision == CommandDecision.dangerous
              ? 'command_model_blocked'
              : 'command_model_uncertain',
        );
      }
      return CommandDecisionPermit(settings.revision);
    } on CommandDecisionException {
      rethrow;
    } on Object {
      throw const CommandDecisionException('command_guard_unavailable');
    }
  }

  /// No result can authorize input after a key, model or enablement change.
  Future<void> validate(CommandDecisionPermit permit) async {
    try {
      if ((await readSettings().timeout(timeout)).revision != permit.revision) {
        throw const CommandDecisionException('command_guard_changed');
      }
    } on CommandDecisionException {
      rethrow;
    } on Object {
      throw const CommandDecisionException('command_guard_unavailable');
    }
  }
}
