import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../platform/secret_store.dart';
import 'command_decision_guard.dart';

class McpCommandApprovalSettings {
  const McpCommandApprovalSettings({this.bypass = false, this.revision = ''});

  final bool bypass;
  final String revision;
}

/// User-owned, device-local policy. MCP tools cannot enable bypass themselves.
class McpCommandApproval {
  McpCommandApproval(this.secrets);

  final SecretStore secrets;
  static const storageKey = SecretRef('serlink.mcp.command-approval.v1');
  Future<void> _pending = Future<void>.value();
  int _generation = 0;

  /// Changes synchronously when a save starts, before secure-storage awaits.
  int get generation => _generation;

  Future<McpCommandApprovalSettings> read() async {
    try {
      await _pending.timeout(const Duration(seconds: 10));
      final bytes = await secrets
          .read(storageKey)
          .timeout(const Duration(seconds: 10));
      if (bytes == null) return const McpCommandApprovalSettings();
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
      );
    } on Object {
      throw const CommandDecisionException('command_approval_unavailable');
    }
  }

  Future<void> saveBypass(bool bypass) {
    _generation += 1;
    final result = _pending.then(
      (_) => secrets.write(
        storageKey,
        utf8.encode(
          jsonEncode({'bypass': bypass, 'revision': const Uuid().v4()}),
        ),
      ),
    );
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
  static void validateInput(String command, {required bool rawInput}) {
    if (command.trim().isEmpty ||
        command.contains(RegExp(r'[\x00-\x09\x0b\x0c\x0e-\x1f\x7f]')) ||
        (rawInput && !command.endsWith('\n') && !command.endsWith('\r'))) {
      throw const CommandDecisionException('command_input_requires_exec');
    }
    if (utf8.encode(command).length > CommandDecisionGuard.maxCommandBytes) {
      throw const CommandDecisionException('command_guard_input_too_large');
    }
  }
}
