import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../platform/secret_store.dart';
import 'command_decision_guard.dart';

class McpCommandApprovalSettings {
  const McpCommandApprovalSettings({
    this.bypass = false,
    this.revision = '',
    this.timeoutSeconds = 60,
  });

  static const timeoutOptions = [30, 60, 120, 300, 600];

  final bool bypass;
  final String revision;
  final int timeoutSeconds;

  Duration get timeout => Duration(seconds: timeoutSeconds);
}

/// User-owned, device-local policy. MCP tools cannot enable bypass themselves.
class McpCommandApproval {
  McpCommandApproval(this.secrets);

  final SecretStore secrets;
  static const storageKey = SecretRef('serlink.mcp.command-approval.v1');
  static const timeoutStorageKey = SecretRef(
    'serlink.mcp.command-approval-timeout.v1',
  );
  Future<void> _pending = Future<void>.value();
  int _generation = 0;

  /// Changes synchronously when a save starts, before secure-storage awaits.
  int get generation => _generation;

  Future<McpCommandApprovalSettings> read() async {
    try {
      await _pending.timeout(const Duration(seconds: 10));
      return await _readStored();
    } on Object {
      throw const CommandDecisionException('command_approval_unavailable');
    }
  }

  Future<McpCommandApprovalSettings> _readStored() async {
    final timeoutBytes = await secrets
        .read(timeoutStorageKey)
        .timeout(const Duration(seconds: 10));
    final savedTimeout = timeoutBytes == null
        ? null
        : int.tryParse(utf8.decode(timeoutBytes));
    final timeoutSeconds =
        McpCommandApprovalSettings.timeoutOptions.contains(savedTimeout)
        ? savedTimeout!
        : 60;
    final bytes = await secrets
        .read(storageKey)
        .timeout(const Duration(seconds: 10));
    if (bytes == null) {
      return McpCommandApprovalSettings(timeoutSeconds: timeoutSeconds);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map ||
        value['bypass'] is! bool ||
        value['revision'] is! String ||
        (value['revision'] as String).isEmpty) {
      throw const FormatException('Invalid command approval setting');
    }
    return McpCommandApprovalSettings(
      bypass: value['bypass'] as bool,
      revision: value['revision'] as String,
      timeoutSeconds: timeoutSeconds,
    );
  }

  Future<void> saveBypass(bool bypass) {
    _generation += 1;
    return _enqueueSave(
      () => secrets.write(
        storageKey,
        utf8.encode(
          jsonEncode({'bypass': bypass, 'revision': const Uuid().v4()}),
        ),
      ),
    );
  }

  Future<void> saveTimeout(int seconds) {
    if (!McpCommandApprovalSettings.timeoutOptions.contains(seconds)) {
      throw ArgumentError.value(seconds, 'seconds', 'Unsupported timeout');
    }
    // A deadline preference must not revoke in-flight command permits.
    return _enqueueSave(
      () => secrets.write(timeoutStorageKey, utf8.encode(seconds.toString())),
    );
  }

  Future<void> _enqueueSave(Future<void> Function() save) {
    final result = _pending.then((_) => save());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> validate(McpCommandApprovalSettings settings) async {
    if ((await read()).revision != settings.revision) {
      throw const CommandDecisionException('command_approval_changed');
    }
  }

  /// A terminal accepts edits/history as well as text. Never automatically
  /// submit input that was assessed separately from the bytes preceding it.
  static void validateInput(
    String command, {
    required bool rawInput,
    bool script = false,
  }) {
    if (command.trim().isEmpty ||
        command.contains(
          RegExp(
            script
                ? r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'
                : r'[\x00-\x09\x0b\x0c\x0e-\x1f\x7f]',
          ),
        ) ||
        (rawInput && !command.endsWith('\n') && !command.endsWith('\r'))) {
      throw const CommandDecisionException('command_input_requires_exec');
    }
    if (utf8.encode(command).length > CommandDecisionGuard.maxCommandBytes) {
      throw const CommandDecisionException('command_guard_input_too_large');
    }
  }
}
