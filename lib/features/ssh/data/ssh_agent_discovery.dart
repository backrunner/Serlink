import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/logging/offline_diagnostic_logger.dart';
import '../../../platform/ssh_agent_locations.dart';
import 'ssh_agent_client.dart';

typedef SshAgentIdentityQuery = Future<List<SshAgentIdentity>> Function(
  String endpoint,
);

class DiscoveredSshAgent {
  const DiscoveredSshAgent({
    required this.socketPath,
    required this.identities,
    this.isSystem = false,
    this.providerName,
  });

  final String socketPath;
  final List<SshAgentIdentity> identities;
  final bool isSystem;
  final String? providerName;

  String? get providerHint => providerName ?? sshAgentProviderHint(socketPath);
}

/// A location-derived identifier for display only, never a provider adapter.
String? sshAgentProviderHint(String socketPath) {
  if (socketPath.toLowerCase().startsWith(r'\\.\pipe\')) return null;
  final parts = p.split(socketPath);
  if (parts.any((part) => part.startsWith('com.apple.launchd'))) return null;
  for (final folder in ['Group Containers', 'Containers']) {
    final index = parts.indexOf(folder);
    if (index >= 0 && index + 1 < parts.length) {
      return parts[index + 1].replaceFirst(RegExp(r'^[A-Z0-9]{10}\.'), '');
    }
  }
  final file = p.basename(socketPath);
  final named = RegExp(r'^\.?(.+?)[-.]ssh[-.]agent(?:\.sock)?$')
      .firstMatch(file);
  if (named != null) return named.group(1);
  final parent = p
      .basename(p.dirname(socketPath))
      .replaceFirst(RegExp(r'^\.'), '');
  if (parent.isEmpty ||
      parent == '/' ||
      ['t', 'tmp', 'Data', 'ssh', 'pipe'].contains(parent) ||
      socketPath.startsWith(r'\\.\pipe\')) {
    return null;
  }
  return parent;
}

/// Finds sockets by location and file type, then verifies the SSH agent
/// protocol. There are no vendor names, executable commands from config,
/// private-file reads, recursive home scans, or signing requests here.
class SshAgentDiscovery {
  SshAgentDiscovery({
    Map<String, String>? environment,
    String? operatingSystem,
    Future<String?> Function()? systemEndpoint,
    SshAgentIdentityQuery? query,
    Future<SshAgentLocations> Function()? macLocations,
    this._logger = const NoopDiagnosticLogger(),
  }) : _environment = environment ?? Platform.environment,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _systemEndpoint = systemEndpoint ?? _resolveSystemEndpoint,
       _macLocations =
           macLocations ??
           (environment == null
               ? loadMacSshAgentLocations
               : () async => const SshAgentLocations()),
       _query =
           query ??
           ((endpoint) => querySshAgentIdentities(
             endpoint,
             timeout: const Duration(seconds: 1),
           ));

  final Map<String, String> _environment;
  final String _operatingSystem;
  final Future<String?> Function() _systemEndpoint;
  final SshAgentIdentityQuery _query;
  final Future<SshAgentLocations> Function() _macLocations;
  final DiagnosticLogger _logger;

  static Future<String?> _resolveSystemEndpoint() async {
    final environmentPath = Platform.environment['SSH_AUTH_SOCK']?.trim();
    if (environmentPath != null && environmentPath.isNotEmpty) {
      return environmentPath;
    }
    if (Platform.isWindows) return r'\\.\pipe\openssh-ssh-agent';
    if (!Platform.isMacOS) return null;
    final result = await Process.run('/bin/launchctl', [
      'getenv',
      'SSH_AUTH_SOCK',
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  Future<List<DiscoveredSshAgent>> discover() async {
    final candidates = <String, bool>{};
    final canonicalPaths = <String, String>{};
    final names = <String, String>{};
    var deniedDirectories = 0;
    var scannedDirectories = 0;
    var scannedEntries = 0;
    final locations = _operatingSystem == 'macos'
        ? await _macLocations()
        : const SshAgentLocations();
    Future<void> add(String? path, {bool system = false, String? name}) async {
      if (path == null || path.trim().isEmpty || candidates.length >= 32) {
        return;
      }
      path = path.trim();
      if (path.contains('\u0000')) return;
      if (_operatingSystem == 'windows') {
        // Only local OpenSSH-compatible pipes; never UNC/network endpoints.
        if (path.toLowerCase().startsWith(r'\\.\pipe\')) {
          candidates[path] = system;
        }
        return;
      }
      if (!p.isAbsolute(path)) return;
      try {
        if (await FileSystemEntity.type(path) !=
            FileSystemEntityType.unixDomainSock) {
          return;
        }
        final canonical = await File(path).resolveSymbolicLinks();
        final existing = canonicalPaths[canonical];
        if (existing == null) {
          canonicalPaths[canonical] = path;
          candidates[path] = system;
          if (name != null) names[path] = name;
        } else if (name != null) {
          names[existing] = name;
        }
      } on FileSystemException {
        // Unavailable sandbox/container directories are normal.
      }
    }

    final configured = _environment['SSH_AUTH_SOCK']?.trim();
    await add(
      configured == null || configured.isEmpty
          ? await _systemEndpoint()
          : configured,
      system: true,
    );
    if (_operatingSystem != 'windows') {
      final home = locations.home ?? _environment['HOME'];
      // Public application metadata supplies direct IPC locations when a GUI
      // app cannot enumerate a container parent. No provider IDs are hardcoded.
      for (final root in locations.roots.take(512)) {
        for (final file in [
          'agent.sock',
          'ssh-agent.sock',
          'socket.ssh',
          '.${root.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-')}-ssh-agent.sock',
        ]) {
          await add(p.join(root.path, file), name: root.name);
        }
      }
      var remainingEntries = 2400;
      var remainingDirectories = 160;
      final visited = <String, int>{};
      Future<void> scan(String root, int depth) async {
        if (remainingEntries <= 0 ||
            remainingDirectories <= 0 ||
            candidates.length >= 32) {
          return;
        }
        final normalized = p.normalize(root);
        if ((visited[normalized] ?? -1) >= depth) return;
        visited[normalized] = depth;
        try {
          if (await FileSystemEntity.type(root, followLinks: false) !=
              FileSystemEntityType.directory) {
            return;
          }
          remainingDirectories--;
          scannedDirectories++;
          await for (final entity in Directory(root).list(followLinks: false)) {
            if (remainingEntries-- <= 0 || candidates.length >= 32) break;
            scannedEntries++;
            final name = p.basename(entity.path).toLowerCase();
            // Metadata only. Regular files are never opened, even if their
            // names resemble agent sockets or private keys.
            if (name == 'ssh' ||
                name.endsWith('.ssh') ||
                name == 's.gpg-agent.ssh' ||
                (name.contains('agent') &&
                    (name.contains('sock') || name.startsWith('agent.')))) {
              await add(entity.path);
            }
            if (depth > 0 && entity is Directory) {
              await scan(entity.path, depth - 1);
            }
          }
        } on FileSystemException {
          deniedDirectories++;
          // A stale/denied directory must not prevent other candidates.
        }
      }

      if (home != null && home.isNotEmpty) {
        if (_operatingSystem == 'macos') {
          // Probe generic app-container IPC locations, not provider IDs.
          for (final (folder, child) in [
            ('Group Containers', 't'),
            ('Containers', 'Data'),
          ]) {
            try {
              await for (final entity in Directory(
                p.join(home, 'Library', folder),
              ).list(followLinks: false)) {
                if (remainingEntries-- <= 0 || remainingDirectories <= 0) break;
                if (entity is Directory) {
                  await scan(p.join(entity.path, child), 0);
                }
              }
            } on FileSystemException {
              // This directory need not exist on every desktop.
            }
          }
        }
        await scan(home, 0);
        // Only one level inside immediate hidden directories. Deeper data
        // trees are restricted to standard user config/cache/runtime roots.
        try {
          await for (final entity in Directory(home).list(followLinks: false)) {
            if (remainingEntries-- <= 0 || remainingDirectories <= 0) break;
            if (entity is Directory &&
                p.basename(entity.path).startsWith('.')) {
              await scan(entity.path, 0);
            }
          }
        } on FileSystemException {
          /* Home may be unavailable. */
        }
        for (final root in ['.ssh', '.cache', '.config', '.local/share']) {
          await scan(p.join(home, root), 2);
        }
      }
      for (final key in ['XDG_RUNTIME_DIR', 'TMPDIR']) {
        final root = _environment[key];
        // Never search a shared global /tmp or another user's home.
        if (root != null &&
            p.normalize(root) != '/tmp' &&
            p.normalize(root) != '/private/tmp') {
          await scan(root, 2);
        }
      }
    }

    final paths = candidates.keys.toList()
      ..sort((a, b) {
        final priority = (candidates[b]! ? 1 : 0) - (candidates[a]! ? 1 : 0);
        return priority == 0 ? a.compareTo(b) : priority;
      });
    final found = <DiscoveredSshAgent>[];
    // Four concurrent bounded protocol probes, at most 32 candidates.
    for (var offset = 0; offset < paths.length; offset += 4) {
      final batch = await Future.wait([
        for (final path in paths.skip(offset).take(4))
          (() async {
            try {
              return DiscoveredSshAgent(
                socketPath: path,
                identities: await _query(path),
                isSystem: candidates[path]!,
                providerName: names[path],
              );
            } on Object catch (error) {
              await _logger.record(
                'ssh.agent.discovery.candidate_failure',
                details: {
                  'system': candidates[path],
                  'hasProviderMetadata': names.containsKey(path),
                  'errorType': error.runtimeType.toString(),
                  if (error is SocketException)
                    'osErrorCode': error.osError?.errorCode,
                },
              );
              return null;
            }
          })(),
      ]);
      found.addAll(batch.whereType<DiscoveredSshAgent>());
    }
    await _logger.record(
      'ssh.agent.discovery.summary',
      details: {
        'hasEnvironmentHome': _environment['HOME']?.isNotEmpty ?? false,
        'hasNativeHome': locations.home != null,
        'nativeLocations': locations.roots.length,
        'scannedDirectories': scannedDirectories,
        'scannedEntries': scannedEntries,
        'deniedDirectories': deniedDirectories,
        'candidates': candidates.length,
        'availableAgents': found.length,
      },
    );
    return found;
  }
}
