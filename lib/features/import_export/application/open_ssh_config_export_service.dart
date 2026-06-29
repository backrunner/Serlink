import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';

class OpenSshConfigExportBundle {
  const OpenSshConfigExportBundle({
    required this.exportedAt,
    required this.hostCount,
    required this.contents,
  });

  final DateTime exportedAt;
  final int hostCount;
  final String contents;

  List<int> toBytes() => utf8.encode(contents);
}

class OpenSshConfigExportService {
  OpenSshConfigExportService({
    required HostRepository hosts,
    DateTime Function()? now,
  }) : this._(hosts, now ?? DateTime.now);

  OpenSshConfigExportService._(this._hosts, this._now);

  final HostRepository _hosts;
  final DateTime Function() _now;

  Future<OpenSshConfigExportBundle> export({
    List<HostId>? selectedHostIds,
  }) async {
    final hosts = await _hosts.list();
    hosts.sort(_compareHosts);
    final exportHosts = _expandExportHosts(hosts, selectedHostIds);
    final aliases = _buildAliases(exportHosts);
    final exportedHostIds = exportHosts.map((host) => host.id).toSet();
    final exportedAt = _now().toUtc();
    final lines = <String>[
      '# Serlink OpenSSH config export',
      '# Credentials are not included.',
      '# Exported at ${exportedAt.toIso8601String()}',
      '',
    ];

    for (final host in exportHosts) {
      final alias = aliases[host.id]!;
      final displayName = _singleLine(host.displayName);
      final tags = host.tags.toList()..sort();
      lines.add('# Serlink display name: $displayName');
      if (tags.isNotEmpty) {
        lines.add('# Tags: ${tags.join(', ')}');
      }
      final unresolvedJumpHosts = [
        for (final jumpHostId in host.jumpHostIds)
          if (!exportedHostIds.contains(jumpHostId))
            _singleLine(jumpHostId.value),
      ];
      if (unresolvedJumpHosts.isNotEmpty) {
        lines.add(
          '# Unresolved jump host ids: ${unresolvedJumpHosts.join(', ')}',
        );
      }
      lines.add('Host $alias');
      lines.add('  HostName ${_singleLine(host.hostname)}');
      if (host.username.trim().isNotEmpty) {
        lines.add('  User ${_singleLine(host.username)}');
      }
      if (host.port > 0 && host.port != 22) {
        lines.add('  Port ${host.port}');
      }
      lines.add(
        '  ConnectTimeout ${host.connectionSettings.connectTimeoutSeconds}',
      );
      if (host.connectionSettings.keepAliveIntervalSeconds > 0) {
        lines.add(
          '  ServerAliveInterval ${host.connectionSettings.keepAliveIntervalSeconds}',
        );
      }
      final proxyJump = _proxyJumpAliases(host.jumpHostIds, aliases);
      if (proxyJump.isNotEmpty) {
        lines.add('  ProxyJump $proxyJump');
      }
      for (final forward in host.portForwarding.localForwards) {
        lines.add(
          '  LocalForward ${forward.localPort} '
          '${_singleLine(forward.remoteHost)}:${forward.remotePort}',
        );
      }
      for (final forward in host.portForwarding.remoteForwards) {
        lines.add(
          '  RemoteForward ${_singleLine(forward.bindHost)}:'
          '${forward.bindPort} ${_singleLine(forward.localHost)}:'
          '${forward.localPort}',
        );
      }
      for (final forward in host.portForwarding.dynamicForwards) {
        lines.add(
          '  DynamicForward ${_singleLine(forward.bindHost)}:'
          '${forward.bindPort}',
        );
      }
      lines.add('');
    }

    return OpenSshConfigExportBundle(
      exportedAt: exportedAt,
      hostCount: exportHosts.length,
      contents: '${lines.join('\n').trimRight()}\n',
    );
  }

  List<HostConfig> _expandExportHosts(
    List<HostConfig> hosts,
    List<HostId>? selectedHostIds,
  ) {
    if (selectedHostIds == null) {
      return hosts;
    }
    final selectedIds = selectedHostIds.toSet();
    final byId = {for (final host in hosts) host.id: host};
    final included = <HostId>{};
    final queue = <HostId>[
      for (final host in hosts)
        if (selectedIds.contains(host.id)) host.id,
    ];

    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!included.add(id)) {
        continue;
      }
      final host = byId[id];
      if (host == null) {
        continue;
      }
      for (final jumpHostId in host.jumpHostIds) {
        if (byId.containsKey(jumpHostId) && !included.contains(jumpHostId)) {
          queue.add(jumpHostId);
        }
      }
    }

    return [
      for (final host in hosts)
        if (included.contains(host.id)) host,
    ];
  }
}

int _compareHosts(HostConfig left, HostConfig right) {
  final nameComparison = left.displayName.toLowerCase().compareTo(
    right.displayName.toLowerCase(),
  );
  if (nameComparison != 0) {
    return nameComparison;
  }
  return left.id.value.compareTo(right.id.value);
}

Map<HostId, String> _buildAliases(List<HostConfig> hosts) {
  final aliases = <HostId, String>{};
  final used = <String>{};
  for (final host in hosts) {
    final alias = _uniqueAlias(
      _baseAliasFor(host),
      used,
      fallback: 'host-${host.id.value}',
    );
    aliases[host.id] = alias;
  }
  return aliases;
}

String _baseAliasFor(HostConfig host) {
  for (final candidate in [host.displayName, host.hostname, host.id.value]) {
    final alias = _sanitizeAlias(candidate);
    if (alias.isNotEmpty) {
      return alias;
    }
  }
  return '';
}

String _sanitizeAlias(String value) {
  var alias = value.toLowerCase().trim();
  alias = alias.replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');
  alias = alias.replaceAll(RegExp(r'-{2,}'), '-');
  alias = alias.replaceAll(RegExp(r'^[._-]+'), '');
  alias = alias.replaceAll(RegExp(r'[._-]+$'), '');
  if (alias == '*' || alias == '?') {
    return '';
  }
  return alias;
}

String _uniqueAlias(String base, Set<String> used, {required String fallback}) {
  var alias = base.isEmpty ? fallback : base;
  if (used.add(alias)) {
    return alias;
  }

  var suffix = 2;
  while (true) {
    final candidate = '$alias-$suffix';
    if (used.add(candidate)) {
      return candidate;
    }
    suffix += 1;
  }
}

String _proxyJumpAliases(
  List<HostId> jumpHostIds,
  Map<HostId, String> aliases,
) {
  final resolved = <String>[];
  for (final jumpHostId in jumpHostIds) {
    final alias = aliases[jumpHostId];
    if (alias != null && !resolved.contains(alias)) {
      resolved.add(alias);
    }
  }
  return resolved.join(',');
}

String _singleLine(String value) {
  return value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}
