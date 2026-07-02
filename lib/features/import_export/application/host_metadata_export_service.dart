import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';

class HostMetadataExportBundle {
  const HostMetadataExportBundle({
    required this.formatVersion,
    required this.exportedAt,
    required this.hosts,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final List<HostMetadataExportRecord> hosts;

  Map<String, Object?> toJson() {
    return {
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'hosts': [for (final host in hosts) host.toJson()],
    };
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory HostMetadataExportBundle.fromJson(Map<String, Object?> json) {
    return HostMetadataExportBundle(
      formatVersion: json['formatVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      hosts: [
        for (final value in json['hosts'] as List<Object?>)
          HostMetadataExportRecord.fromJson(value as Map<String, Object?>),
      ],
    );
  }

  factory HostMetadataExportBundle.fromBytes(List<int> bytes) {
    return HostMetadataExportBundle.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
    );
  }
}

class HostMetadataExportRecord {
  const HostMetadataExportRecord({
    required this.hostId,
    required this.displayName,
    required this.hostname,
    required this.username,
    required this.port,
    required this.authKinds,
    required this.tags,
    required this.trustState,
    required this.startupCommands,
    required this.remoteSessionSettings,
    required this.jumpHosts,
    required this.connectionSettings,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.lastConnectedAt,
  });

  final String hostId;
  final String displayName;
  final String hostname;
  final String username;
  final int port;
  final List<String> authKinds;
  final List<String> tags;
  final String trustState;
  final List<String> startupCommands;
  final Map<String, Object?> remoteSessionSettings;
  final List<HostMetadataExportJumpHost> jumpHosts;
  final Map<String, Object?> connectionSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final DateTime? lastConnectedAt;

  Map<String, Object?> toJson() {
    return {
      'hostId': hostId,
      'displayName': displayName,
      'hostname': hostname,
      'username': username,
      'port': port,
      'authKinds': authKinds,
      'tags': tags,
      'trustState': trustState,
      'startupCommands': startupCommands,
      'remoteSessionSettings': remoteSessionSettings,
      'jumpHosts': [for (final host in jumpHosts) host.toJson()],
      'connectionSettings': connectionSettings,
      'groupId': groupId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toUtc().toIso8601String(),
    };
  }

  factory HostMetadataExportRecord.fromJson(Map<String, Object?> json) {
    return HostMetadataExportRecord(
      hostId: json['hostId'] as String,
      displayName: json['displayName'] as String,
      hostname: json['hostname'] as String,
      username: json['username'] as String,
      port: json['port'] as int,
      authKinds: [
        for (final value in json['authKinds'] as List<Object?>) value as String,
      ],
      tags: [
        for (final value in json['tags'] as List<Object?>) value as String,
      ],
      trustState: json['trustState'] as String,
      startupCommands: [
        for (final value in json['startupCommands'] as List<Object?>)
          value as String,
      ],
      remoteSessionSettings: switch (json['remoteSessionSettings']) {
        final Map<Object?, Object?> value => Map<String, Object?>.from(value),
        _ => const HostRemoteSessionSettings().toJson(),
      },
      jumpHosts: [
        for (final value in json['jumpHosts'] as List<Object?>)
          HostMetadataExportJumpHost.fromJson(value as Map<String, Object?>),
      ],
      connectionSettings: Map<String, Object?>.from(
        json['connectionSettings'] as Map<Object?, Object?>,
      ),
      groupId: json['groupId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastConnectedAt: switch (json['lastConnectedAt']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
    );
  }
}

class HostMetadataExportJumpHost {
  const HostMetadataExportJumpHost({
    required this.hostId,
    required this.displayName,
  });

  final String hostId;
  final String displayName;

  Map<String, Object?> toJson() {
    return {'hostId': hostId, 'displayName': displayName};
  }

  factory HostMetadataExportJumpHost.fromJson(Map<String, Object?> json) {
    return HostMetadataExportJumpHost(
      hostId: json['hostId'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

class HostMetadataExportService {
  HostMetadataExportService({required HostRepository hosts}) : this._(hosts);

  HostMetadataExportService._(this._hosts);

  final HostRepository _hosts;

  Future<HostMetadataExportBundle> export({
    List<HostId>? selectedHostIds,
  }) async {
    final hosts = await _hosts.list();
    hosts.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    final selectedIds = selectedHostIds?.toSet();
    final exportHosts = selectedIds == null
        ? hosts
        : [
            for (final host in hosts)
              if (selectedIds.contains(host.id)) host,
          ];
    final namesById = {for (final host in hosts) host.id: host.displayName};
    return HostMetadataExportBundle(
      formatVersion: 1,
      exportedAt: DateTime.now().toUtc(),
      hosts: [
        for (final host in exportHosts) _toRecord(host, namesById: namesById),
      ],
    );
  }

  HostMetadataExportRecord _toRecord(
    HostConfig host, {
    required Map<HostId, String> namesById,
  }) {
    final authKinds = [for (final kind in host.authKinds) kind.name]..sort();
    final tags = host.tags.toList()..sort();
    return HostMetadataExportRecord(
      hostId: host.id.value,
      displayName: host.displayName,
      hostname: host.hostname,
      username: host.username,
      port: host.port,
      authKinds: authKinds,
      tags: tags,
      trustState: host.trustState.name,
      startupCommands: List<String>.unmodifiable(host.startupCommands),
      remoteSessionSettings: host.remoteSessionSettings.toJson(),
      jumpHosts: [
        for (final jumpHostId in host.jumpHostIds)
          HostMetadataExportJumpHost(
            hostId: jumpHostId.value,
            displayName: namesById[jumpHostId] ?? jumpHostId.value,
          ),
      ],
      connectionSettings: host.connectionSettings.toJson(),
      groupId: host.groupId,
      createdAt: host.createdAt,
      updatedAt: host.updatedAt,
      lastConnectedAt: host.lastConnectedAt,
    );
  }
}
