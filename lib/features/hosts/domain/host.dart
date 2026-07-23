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

enum HostRemoteSessionManager { auto, tmux, screen }

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
    required this.createdAt,
    this.sftpDefaultDirectory = '/',
    this.lastConnectedAt,
    this.writeBackToSshConfig = false,
  });

  final HostId id;
  final String displayName;
  final String hostname;
  final String username;
  final int port;
  final Set<HostAuthKind> authKinds;
  final Set<String> tags;
  final HostTrustState trustState;
  final DateTime createdAt;
  final String sftpDefaultDirectory;
  final DateTime? lastConnectedAt;
  final bool writeBackToSshConfig;
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
    this.sftpDefaultDirectory = '/',
    this.portForwarding = const HostPortForwardingSettings(),
    this.connectionSettings = const HostConnectionSettings(),
    this.remoteSessionSettings = const HostRemoteSessionSettings(),
    this.groupId,
    this.lastConnectedAt,
    this.writeBackToSshConfig = false,
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
  final String sftpDefaultDirectory;
  final HostPortForwardingSettings portForwarding;
  final HostConnectionSettings connectionSettings;
  final HostRemoteSessionSettings remoteSessionSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId;
  final DateTime? lastConnectedAt;
  final bool writeBackToSshConfig;

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
      createdAt: createdAt,
      sftpDefaultDirectory: sftpDefaultDirectory,
      lastConnectedAt: lastConnectedAt,
      writeBackToSshConfig: writeBackToSshConfig,
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
      'sftpDefaultDirectory': sftpDefaultDirectory,
      'portForwarding': portForwarding.toJson(),
      'connectionSettings': connectionSettings.toJson(),
      'remoteSessionSettings': remoteSessionSettings.toJson(),
      'groupId': groupId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toUtc().toIso8601String(),
      'writeBackToSshConfig': writeBackToSshConfig,
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
      sftpDefaultDirectory: _remoteDirectoryFromJson(
        json['sftpDefaultDirectory'],
      ),
      portForwarding: switch (json['portForwarding']) {
        final Map<Object?, Object?> value =>
          HostPortForwardingSettings.fromJson(Map<String, Object?>.from(value)),
        _ => const HostPortForwardingSettings(),
      },
      connectionSettings: switch (json['connectionSettings']) {
        final Map<Object?, Object?> value => HostConnectionSettings.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => const HostConnectionSettings(),
      },
      remoteSessionSettings: switch (json['remoteSessionSettings']) {
        final Map<Object?, Object?> value => HostRemoteSessionSettings.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => const HostRemoteSessionSettings(),
      },
      groupId: json['groupId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastConnectedAt: switch (json['lastConnectedAt']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      writeBackToSshConfig: json['writeBackToSshConfig'] == true,
    );
  }
}

class HostRemoteSessionSettings {
  const HostRemoteSessionSettings({
    this.enabled = false,
    this.manager = HostRemoteSessionManager.auto,
    this.sessionName = 'serlink',
    this.createIfMissing = true,
    this.fallbackToShell = true,
  });

  final bool enabled;
  final HostRemoteSessionManager manager;
  final String sessionName;
  final bool createIfMissing;
  final bool fallbackToShell;

  bool get isDefault => this == const HostRemoteSessionSettings();

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'manager': manager.name,
      'sessionName': sessionName,
      'createIfMissing': createIfMissing,
      'fallbackToShell': fallbackToShell,
    };
  }

  factory HostRemoteSessionSettings.fromJson(Map<String, Object?> json) {
    return HostRemoteSessionSettings(
      enabled: _boolFromJson(json['enabled'], fallback: false),
      manager: _remoteSessionManagerFromJson(json['manager']),
      sessionName: _stringFromJson(json['sessionName'], fallback: 'serlink'),
      createIfMissing: _boolFromJson(json['createIfMissing'], fallback: true),
      fallbackToShell: _boolFromJson(json['fallbackToShell'], fallback: true),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostRemoteSessionSettings &&
        other.enabled == enabled &&
        other.manager == manager &&
        other.sessionName == sessionName &&
        other.createIfMissing == createIfMissing &&
        other.fallbackToShell == fallbackToShell;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      manager,
      sessionName,
      createIfMissing,
      fallbackToShell,
    );
  }
}

class HostPortForwardingSettings {
  const HostPortForwardingSettings({
    this.localForwards = const [],
    this.remoteForwards = const [],
    this.dynamicForwards = const [],
  });

  final List<HostLocalPortForward> localForwards;
  final List<HostRemotePortForward> remoteForwards;
  final List<HostDynamicPortForward> dynamicForwards;

  bool get isEmpty =>
      localForwards.isEmpty &&
      remoteForwards.isEmpty &&
      dynamicForwards.isEmpty;

  Map<String, Object?> toJson() {
    return {
      'localForwards': [for (final forward in localForwards) forward.toJson()],
      'remoteForwards': [
        for (final forward in remoteForwards) forward.toJson(),
      ],
      'dynamicForwards': [
        for (final forward in dynamicForwards) forward.toJson(),
      ],
    };
  }

  factory HostPortForwardingSettings.fromJson(Map<String, Object?> json) {
    return HostPortForwardingSettings(
      localForwards: [
        for (final value in _listFromJson(json['localForwards']))
          if (value is Map<Object?, Object?>)
            HostLocalPortForward.fromJson(Map<String, Object?>.from(value)),
      ],
      remoteForwards: [
        for (final value in _listFromJson(json['remoteForwards']))
          if (value is Map<Object?, Object?>)
            HostRemotePortForward.fromJson(Map<String, Object?>.from(value)),
      ],
      dynamicForwards: [
        for (final value in _listFromJson(json['dynamicForwards']))
          if (value is Map<Object?, Object?>)
            HostDynamicPortForward.fromJson(Map<String, Object?>.from(value)),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostPortForwardingSettings &&
        _listEquals(other.localForwards, localForwards) &&
        _listEquals(other.remoteForwards, remoteForwards) &&
        _listEquals(other.dynamicForwards, dynamicForwards);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(localForwards),
      Object.hashAll(remoteForwards),
      Object.hashAll(dynamicForwards),
    );
  }
}

class HostLocalPortForward {
  const HostLocalPortForward({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
  });

  final int localPort;
  final String remoteHost;
  final int remotePort;

  Map<String, Object?> toJson() {
    return {
      'localPort': localPort,
      'remoteHost': remoteHost,
      'remotePort': remotePort,
    };
  }

  factory HostLocalPortForward.fromJson(Map<String, Object?> json) {
    return HostLocalPortForward(
      localPort: _intFromJson(json['localPort'], fallback: 0),
      remoteHost: _stringFromJson(json['remoteHost'], fallback: '127.0.0.1'),
      remotePort: _intFromJson(json['remotePort'], fallback: 0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostLocalPortForward &&
        other.localPort == localPort &&
        other.remoteHost == remoteHost &&
        other.remotePort == remotePort;
  }

  @override
  int get hashCode => Object.hash(localPort, remoteHost, remotePort);
}

class HostRemotePortForward {
  const HostRemotePortForward({
    required this.bindHost,
    required this.bindPort,
    required this.localHost,
    required this.localPort,
  });

  final String bindHost;
  final int bindPort;
  final String localHost;
  final int localPort;

  Map<String, Object?> toJson() {
    return {
      'bindHost': bindHost,
      'bindPort': bindPort,
      'localHost': localHost,
      'localPort': localPort,
    };
  }

  factory HostRemotePortForward.fromJson(Map<String, Object?> json) {
    return HostRemotePortForward(
      bindHost: _stringFromJson(json['bindHost'], fallback: '127.0.0.1'),
      bindPort: _intFromJson(json['bindPort'], fallback: 0),
      localHost: _stringFromJson(json['localHost'], fallback: '127.0.0.1'),
      localPort: _intFromJson(json['localPort'], fallback: 0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostRemotePortForward &&
        other.bindHost == bindHost &&
        other.bindPort == bindPort &&
        other.localHost == localHost &&
        other.localPort == localPort;
  }

  @override
  int get hashCode => Object.hash(bindHost, bindPort, localHost, localPort);
}

class HostDynamicPortForward {
  const HostDynamicPortForward({
    required this.bindHost,
    required this.bindPort,
  });

  final String bindHost;
  final int bindPort;

  Map<String, Object?> toJson() {
    return {'bindHost': bindHost, 'bindPort': bindPort};
  }

  factory HostDynamicPortForward.fromJson(Map<String, Object?> json) {
    return HostDynamicPortForward(
      bindHost: _stringFromJson(json['bindHost'], fallback: '127.0.0.1'),
      bindPort: _intFromJson(json['bindPort'], fallback: 0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HostDynamicPortForward &&
        other.bindHost == bindHost &&
        other.bindPort == bindPort;
  }

  @override
  int get hashCode => Object.hash(bindHost, bindPort);
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

String _remoteDirectoryFromJson(Object? value) {
  if (value is! String) {
    return '/';
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('/')) {
    return '/';
  }
  final segments = <String>[];
  for (final segment in trimmed.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}

int _intFromJson(Object? value, {required int fallback}) {
  return switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };
}

String _stringFromJson(Object? value, {required String fallback}) {
  return value is String ? value : fallback;
}

bool _boolFromJson(Object? value, {required bool fallback}) {
  return value is bool ? value : fallback;
}

HostRemoteSessionManager _remoteSessionManagerFromJson(Object? value) {
  if (value is String) {
    for (final manager in HostRemoteSessionManager.values) {
      if (manager.name == value) {
        return manager;
      }
    }
  }
  return HostRemoteSessionManager.auto;
}

List<Object?> _listFromJson(Object? value) {
  return value is List<Object?> ? value : const [];
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
