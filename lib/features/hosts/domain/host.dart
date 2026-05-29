import '../../../core/ids/entity_id.dart';

enum HostTrustState { unknown, trusted, changed }

enum HostAuthKind {
  password,
  privateKey,
  keyboardInteractive,
  sshAgent,
  openSshCertificate,
  hardwareKey,
}

class HostSummary {
  const HostSummary({
    required this.id,
    required this.displayName,
    required this.hostname,
    required this.username,
    required this.port,
    required this.authKinds,
    required this.tags,
    required this.trustState,
    this.lastConnectedAt,
  });

  final HostId id;
  final String displayName;
  final String hostname;
  final String username;
  final int port;
  final Set<HostAuthKind> authKinds;
  final Set<String> tags;
  final HostTrustState trustState;
  final DateTime? lastConnectedAt;
}

class HostConfig {
  const HostConfig({
    required this.id,
    required this.displayName,
    required this.hostname,
    required this.username,
    required this.port,
    required this.authKinds,
    required this.tags,
    required this.trustState,
    required this.identityIds,
    required this.startupCommands,
    required this.jumpHostIds,
    required this.createdAt,
    required this.updatedAt,
    this.connectionSettings = const HostConnectionSettings(),
    this.groupId,
    this.lastConnectedAt,
  });

  final HostId id;
  final String displayName;
  final String hostname;
  final String username;
  final int port;
  final Set<HostAuthKind> authKinds;
  final Set<String> tags;
  final HostTrustState trustState;
  final List<IdentityId> identityIds;
  final List<String> startupCommands;
  final List<HostId> jumpHostIds;
  final HostConnectionSettings connectionSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final DateTime? lastConnectedAt;

  HostSummary toSummary() {
    return HostSummary(
      id: id,
      displayName: displayName,
      hostname: hostname,
      username: username,
      port: port,
      authKinds: authKinds,
      tags: tags,
      trustState: trustState,
      lastConnectedAt: lastConnectedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'displayName': displayName,
      'hostname': hostname,
      'username': username,
      'port': port,
      'authKinds': [for (final kind in authKinds) kind.name],
      'tags': [for (final tag in tags) tag],
      'trustState': trustState.name,
      'identityIds': [for (final identityId in identityIds) identityId.value],
      'startupCommands': startupCommands,
      'jumpHostIds': [for (final hostId in jumpHostIds) hostId.value],
      'connectionSettings': connectionSettings.toJson(),
      'groupId': groupId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toUtc().toIso8601String(),
    };
  }

  factory HostConfig.fromJson(Map<String, Object?> json) {
    return HostConfig(
      id: HostId(json['id'] as String),
      displayName: json['displayName'] as String,
      hostname: json['hostname'] as String,
      username: json['username'] as String,
      port: json['port'] as int,
      authKinds: {
        for (final value in json['authKinds'] as List<Object?>)
          HostAuthKind.values.byName(value as String),
      },
      tags: {
        for (final value in json['tags'] as List<Object?>) value as String,
      },
      trustState: HostTrustState.values.byName(json['trustState'] as String),
      identityIds: [
        for (final value in json['identityIds'] as List<Object?>)
          IdentityId(value as String),
      ],
      startupCommands: [
        for (final value in json['startupCommands'] as List<Object?>)
          value as String,
      ],
      jumpHostIds: [
        for (final value in json['jumpHostIds'] as List<Object?>)
          HostId(value as String),
      ],
      connectionSettings: switch (json['connectionSettings']) {
        final Map<Object?, Object?> value => HostConnectionSettings.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => const HostConnectionSettings(),
      },
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

class HostConnectionSettings {
  const HostConnectionSettings({
    this.connectTimeoutSeconds = 20,
    this.keepAliveIntervalSeconds = 10,
    this.reconnectAttempts = 0,
    this.reconnectBackoffSeconds = 5,
  });

  final int connectTimeoutSeconds;
  final int keepAliveIntervalSeconds;
  final int reconnectAttempts;
  final int reconnectBackoffSeconds;

  Duration get connectTimeout => Duration(seconds: connectTimeoutSeconds);

  Duration? get keepAliveInterval => keepAliveIntervalSeconds <= 0
      ? null
      : Duration(seconds: keepAliveIntervalSeconds);

  Duration get reconnectBackoff => Duration(seconds: reconnectBackoffSeconds);

  Map<String, Object?> toJson() {
    return {
      'connectTimeoutSeconds': connectTimeoutSeconds,
      'keepAliveIntervalSeconds': keepAliveIntervalSeconds,
      'reconnectAttempts': reconnectAttempts,
      'reconnectBackoffSeconds': reconnectBackoffSeconds,
    };
  }

  factory HostConnectionSettings.fromJson(Map<String, Object?> json) {
    return HostConnectionSettings(
      connectTimeoutSeconds: _intFromJson(
        json['connectTimeoutSeconds'],
        fallback: 20,
      ),
      keepAliveIntervalSeconds: _intFromJson(
        json['keepAliveIntervalSeconds'],
        fallback: 10,
      ),
      reconnectAttempts: _intFromJson(json['reconnectAttempts'], fallback: 0),
      reconnectBackoffSeconds: _intFromJson(
        json['reconnectBackoffSeconds'],
        fallback: 5,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostConnectionSettings &&
        other.connectTimeoutSeconds == connectTimeoutSeconds &&
        other.keepAliveIntervalSeconds == keepAliveIntervalSeconds &&
        other.reconnectAttempts == reconnectAttempts &&
        other.reconnectBackoffSeconds == reconnectBackoffSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      connectTimeoutSeconds,
      keepAliveIntervalSeconds,
      reconnectAttempts,
      reconnectBackoffSeconds,
    );
  }
}

int _intFromJson(Object? value, {required int fallback}) {
  return switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };
}
