import 'dart:convert';

import '../../../platform/secret_store.dart';
import '../../hosts/domain/host.dart';

/// Device-local MCP metadata policy. Credentials never form part of this DTO.
class McpHostVisibility {
  McpHostVisibility(this.secrets);

  final SecretStore secrets;
  static const storageKey = SecretRef('serlink.mcp.strict-host-privacy.v1');
  Future<void> _pending = Future<void>.value();

  Future<bool> readStrict() async {
    await _pending;
    final bytes = await secrets.read(storageKey);
    if (bytes == null) return false;
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! bool) {
      throw const FormatException('Invalid MCP privacy setting');
    }
    return value;
  }

  Future<void> saveStrict(bool value) {
    final result = _pending.then(
      (_) => secrets.write(storageKey, utf8.encode(jsonEncode(value))),
    );
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Map<String, Object?> describe(
    HostConfig host, {
    required bool strict,
  }) {
    if (strict) return {'id': host.id.value, 'displayName': host.displayName};
    // Explicitly exclude identity references and secret records. Never serialize
    // a resolved connection profile or credential through this endpoint.
    return {
      'id': host.id.value,
      'displayName': host.displayName,
      'hostname': host.hostname,
      'port': host.port,
      'username': host.username,
      'authKinds': [for (final kind in host.authKinds) kind.name],
      'tags': host.tags.toList()..sort(),
      'groupId': host.groupId,
      'trustState': host.trustState.name,
      'sftpDefaultDirectory': host.sftpDefaultDirectory,
      'jumpHostIds': [for (final id in host.jumpHostIds) id.value],
      'portForwarding': host.portForwarding.toJson(),
      'connectionSettings': host.connectionSettings.toJson(),
      'remoteSessionSettings': host.remoteSessionSettings.toJson(),
      'writeBackToSshConfig': host.writeBackToSshConfig,
      'createdAt': host.createdAt.toUtc().toIso8601String(),
      'updatedAt': host.updatedAt.toUtc().toIso8601String(),
      'lastConnectedAt': host.lastConnectedAt?.toUtc().toIso8601String(),
    };
  }
}
