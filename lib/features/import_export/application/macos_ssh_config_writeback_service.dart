import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/ids/entity_id.dart';
import '../../../core/logging/offline_diagnostic_logger.dart';
import '../../../core/security/local_file_security.dart';
import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';

class SshConfigWritebackRegistration {
  const SshConfigWritebackRegistration({
    required this.alias,
    required this.sourcePath,
    required this.managed,
  });

  final String alias;
  final String sourcePath;
  final bool managed;

  Map<String, Object?> toJson() {
    return {'alias': alias, 'sourcePath': sourcePath, 'managed': managed};
  }

  factory SshConfigWritebackRegistration.fromJson(Map<String, Object?> json) {
    return SshConfigWritebackRegistration(
      alias: json['alias'] as String,
      sourcePath: json['sourcePath'] as String,
      managed: json['managed'] == true,
    );
  }
}

abstract interface class SshConfigWritebackRegistry {
  Future<Map<String, SshConfigWritebackRegistration>> read();
  Future<void> save(Map<String, SshConfigWritebackRegistration> entries);
}

class FileSshConfigWritebackRegistry implements SshConfigWritebackRegistry {
  const FileSshConfigWritebackRegistry();

  @override
  Future<Map<String, SshConfigWritebackRegistration>> read() async {
    final file = await _registryFile();
    if (!await file.exists()) {
      return {};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return {};
    }
    if (decoded is! Map<Object?, Object?>) {
      return {};
    }
    final rawHosts = decoded['hosts'];
    if (rawHosts is! Map<Object?, Object?>) {
      return {};
    }
    final result = <String, SshConfigWritebackRegistration>{};
    for (final entry in rawHosts.entries) {
      if (entry.key is! String || entry.value is! Map<Object?, Object?>) {
        continue;
      }
      try {
        result[entry.key! as String] = SshConfigWritebackRegistration.fromJson(
          Map<String, Object?>.from(entry.value! as Map),
        );
      } on Object {
        continue;
      }
    }
    return result;
  }

  @override
  Future<void> save(Map<String, SshConfigWritebackRegistration> entries) async {
    final file = await _registryFile();
    final sortedIds = entries.keys.toList()..sort();
    await _writeFileAtomically(
      file,
      jsonEncode({
        'hosts': {for (final id in sortedIds) id: entries[id]!.toJson()},
      }),
    );
  }

  Future<File> _registryFile() async {
    final appDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(appDir.path, 'Serlink'));
    await LocalFileSecurity.preparePrivateDirectory(directory);
    return File(p.join(directory.path, 'ssh-config-writeback.json'));
  }
}

abstract interface class SshConfigFileStore {
  Future<String?> read(String path);
  Future<void> writeAtomically(
    String path,
    String contents, {
    required String? expectedContents,
  });
}

class LocalSshConfigFileStore implements SshConfigFileStore {
  const LocalSshConfigFileStore();

  @override
  Future<String?> read(String path) async {
    final file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> writeAtomically(
    String path,
    String contents, {
    required String? expectedContents,
  }) async {
    final destination = await _resolvedWriteDestination(path);
    await _writeFileAtomically(
      destination,
      contents,
      expectedFile: File(path),
      expectedContents: expectedContents,
    );
  }
}

class MacOsSshConfigWritebackResult {
  const MacOsSshConfigWritebackResult({
    required this.hostsWritten,
    required this.hostsRemoved,
    required this.filesChanged,
  });

  final int hostsWritten;
  final int hostsRemoved;
  final int filesChanged;
}

class MacOsSshConfigWritebackService {
  MacOsSshConfigWritebackService({
    required HostRepository hosts,
    required SshConfigWritebackRegistry registry,
    required SshConfigFileStore files,
    required String configPath,
    DiagnosticLogger logger = const NoopDiagnosticLogger(),
  }) : this._(hosts, registry, files, p.normalize(configPath), logger);

  MacOsSshConfigWritebackService._(
    this._hosts,
    this._registry,
    this._files,
    this._configPath,
    this._logger,
  );

  final HostRepository _hosts;
  final SshConfigWritebackRegistry _registry;
  final SshConfigFileStore _files;
  final String _configPath;
  final DiagnosticLogger _logger;

  Future<MacOsSshConfigWritebackResult> reconcile() async {
    if (_configPath.trim().isEmpty) {
      return const MacOsSshConfigWritebackResult(
        hostsWritten: 0,
        hostsRemoved: 0,
        filesChanged: 0,
      );
    }

    final hosts = await _hosts.list();
    final registrations = await _registry.read();
    final graph = await _SshConfigGraph.load(
      rootPath: _configPath,
      files: _files,
    );
    final hostsById = {for (final host in hosts) host.id.value: host};
    final aliases = _assignAliases(hosts);
    final nextRegistrations = <String, SshConfigWritebackRegistration>{};
    var hostsRemoved = 0;
    var hostsWritten = 0;

    for (final registrationEntry in registrations.entries) {
      final host = hostsById[registrationEntry.key];
      if (host != null && host.writeBackToSshConfig) {
        continue;
      }
      if (graph.removeRegistration(
        hostId: registrationEntry.key,
        registration: registrationEntry.value,
      )) {
        hostsRemoved += 1;
      }
    }

    final writebackHosts =
        hosts.where((host) => host.writeBackToSshConfig).toList()
          ..sort(_compareHostCreationOrder);
    for (final host in writebackHosts) {
      final alias = aliases[host.id]!;
      final previous = registrations[host.id.value];
      final registration = graph.writeHost(
        host: host,
        alias: alias,
        previous: previous,
        aliases: aliases,
      );
      nextRegistrations[host.id.value] = registration;
      hostsWritten += 1;
    }

    try {
      final filesChanged = await graph.commit();
      await _registry.save(nextRegistrations);
      await _logger.record(
        'ssh_config.writeback_completed',
        details: {
          'hostsWritten': hostsWritten,
          'hostsRemoved': hostsRemoved,
          'filesChanged': filesChanged,
        },
      );
      return MacOsSshConfigWritebackResult(
        hostsWritten: hostsWritten,
        hostsRemoved: hostsRemoved,
        filesChanged: filesChanged,
      );
    } on Object catch (error, stackTrace) {
      await _logger.record(
        'ssh_config.writeback_failed',
        level: DiagnosticLogLevel.error,
        details: {'errorType': error.runtimeType.toString()},
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

class _SshConfigGraph {
  _SshConfigGraph._({required this.rootPath, required this.files});

  final String rootPath;
  final SshConfigFileStore files;
  final Map<String, _EditableSshConfigFile> documents = {};

  static Future<_SshConfigGraph> load({
    required String rootPath,
    required SshConfigFileStore files,
  }) async {
    final graph = _SshConfigGraph._(
      rootPath: p.normalize(rootPath),
      files: files,
    );
    await graph._loadPath(graph.rootPath, isRoot: true, visiting: {});
    return graph;
  }

  Future<void> _loadPath(
    String path, {
    required bool isRoot,
    required Set<String> visiting,
  }) async {
    final normalized = p.normalize(path);
    if (documents.containsKey(normalized) || !visiting.add(normalized)) {
      return;
    }
    final contents = await files.read(normalized);
    if (contents == null && !isRoot) {
      visiting.remove(normalized);
      return;
    }
    final document = _EditableSshConfigFile(
      path: normalized,
      contents: contents,
    );
    documents[normalized] = document;
    for (final line in document.lines) {
      final tokens = _tokenizeSshConfigLine(line);
      if (tokens.isEmpty || tokens.first.toLowerCase() != 'include') {
        continue;
      }
      for (final includePattern in tokens.skip(1)) {
        for (final includePath in _resolveWritebackIncludePaths(
          includePattern,
          sourcePath: normalized,
        )) {
          await _loadPath(includePath, isRoot: false, visiting: visiting);
        }
      }
    }
    visiting.remove(normalized);
  }

  SshConfigWritebackRegistration writeHost({
    required HostConfig host,
    required String alias,
    required SshConfigWritebackRegistration? previous,
    required Map<HostId, String> aliases,
  }) {
    _SshHostBlockLocation? location;
    if (previous != null) {
      location = _findAliasInDocument(previous.sourcePath, previous.alias);
      location ??= findAlias(previous.alias);
    }
    location ??= findHostId(host.id.value);
    location ??= findAlias(alias);

    if (previous != null &&
        previous.alias.toLowerCase() != alias.toLowerCase()) {
      final conflicting = findAlias(alias);
      if (conflicting != null &&
          (location == null ||
              conflicting.document.path != location.document.path ||
              conflicting.start != location.start)) {
        throw StateError('SSH config alias $alias already exists.');
      }
    }

    if (location == null) {
      final document = documents[rootPath]!;
      document.prependManagedHost(
        original: const ['Host placeholder'],
        host: host,
        alias: alias,
        aliases: aliases,
      );
      return SshConfigWritebackRegistration(
        alias: alias,
        sourcePath: rootPath,
        managed: true,
      );
    }

    final sourceAlias = _sourceAliasForLocation(
      location: location,
      previousAlias: previous?.alias,
      desiredAlias: alias,
    );
    if (location.document.hasManagedWrapper(
      location: location,
      hostId: host.id.value,
    )) {
      location.document.updateHost(
        location: location,
        previousAlias: sourceAlias,
        host: host,
        alias: alias,
        aliases: aliases,
      );
    } else {
      final original = location.document.detachHost(
        location: location,
        alias: sourceAlias,
      );
      documents[rootPath]!.prependManagedHost(
        original: original,
        host: host,
        alias: alias,
        aliases: aliases,
      );
    }
    return SshConfigWritebackRegistration(
      alias: alias,
      sourcePath: rootPath,
      managed: true,
    );
  }

  bool removeRegistration({
    required String hostId,
    required SshConfigWritebackRegistration registration,
  }) {
    var location = _findAliasInDocument(
      registration.sourcePath,
      registration.alias,
    );
    location ??= findAlias(registration.alias);
    location ??= findHostId(hostId);
    if (location == null) {
      return false;
    }
    final managedHostId =
        registration.managed ||
            location.document.isManagedHost(location: location, hostId: hostId)
        ? hostId
        : null;
    return location.document.removeHost(
      location: location,
      alias: registration.alias,
      managedHostId: managedHostId,
    );
  }

  _SshHostBlockLocation? findAlias(String alias) {
    return _findAliasFromPath(rootPath, alias, visited: {});
  }

  _SshHostBlockLocation? findHostId(String hostId) {
    for (final document in documents.values) {
      final location = document.findHostId(hostId);
      if (location != null) {
        return location;
      }
    }
    return null;
  }

  _SshHostBlockLocation? _findAliasFromPath(
    String path,
    String alias, {
    required Set<String> visited,
  }) {
    final normalized = p.normalize(path);
    if (!visited.add(normalized)) {
      return null;
    }
    final document = documents[normalized];
    if (document == null) {
      return null;
    }
    for (var index = 0; index < document.lines.length; index += 1) {
      final tokens = _tokenizeSshConfigLine(document.lines[index]);
      if (tokens.isEmpty) {
        continue;
      }
      final keyword = tokens.first.toLowerCase();
      if (keyword == 'include') {
        for (final pattern in tokens.skip(1)) {
          for (final includePath in _resolveWritebackIncludePaths(
            pattern,
            sourcePath: normalized,
          )) {
            final included = _findAliasFromPath(
              includePath,
              alias,
              visited: visited,
            );
            if (included != null) {
              return included;
            }
          }
        }
      }
      if (keyword != 'host') {
        continue;
      }
      final aliases = tokens.skip(1).toList(growable: false);
      if (_containsConcreteAlias(aliases, alias)) {
        return _SshHostBlockLocation(
          document: document,
          start: index,
          end: document.hostBlockEnd(index),
          aliases: aliases,
        );
      }
    }
    return null;
  }

  _SshHostBlockLocation? _findAliasInDocument(String path, String alias) {
    final document = documents[p.normalize(path)];
    if (document == null) {
      return null;
    }
    return document.findAlias(alias);
  }

  Future<int> commit() async {
    var changed = 0;
    final ordered = documents.values.toList()
      ..sort((left, right) {
        if (left.path == rootPath) {
          return 1;
        }
        if (right.path == rootPath) {
          return -1;
        }
        return left.path.compareTo(right.path);
      });
    for (final document in ordered) {
      if (!document.dirty) {
        continue;
      }
      await files.writeAtomically(
        document.path,
        document.contents,
        expectedContents: document.originalContents,
      );
      changed += 1;
    }
    return changed;
  }
}

class _EditableSshConfigFile {
  _EditableSshConfigFile({required this.path, required String? contents})
    : originalContents = contents,
      _hadTrailingNewline = contents?.endsWith('\n') ?? false,
      lines = _splitSshConfigLines(contents ?? '');

  final String path;
  final String? originalContents;
  final bool _hadTrailingNewline;
  final List<String> lines;
  bool dirty = false;

  String get contents {
    final joined = lines.join('\n');
    if (joined.isEmpty) {
      return '';
    }
    return _hadTrailingNewline || dirty ? '$joined\n' : joined;
  }

  _SshHostBlockLocation? findAlias(String alias) {
    for (var index = 0; index < lines.length; index += 1) {
      final tokens = _tokenizeSshConfigLine(lines[index]);
      if (tokens.isEmpty || tokens.first.toLowerCase() != 'host') {
        continue;
      }
      final aliases = tokens.skip(1).toList(growable: false);
      if (_containsConcreteAlias(aliases, alias)) {
        return _SshHostBlockLocation(
          document: this,
          start: index,
          end: hostBlockEnd(index),
          aliases: aliases,
        );
      }
    }
    return null;
  }

  _SshHostBlockLocation? findHostId(String hostId) {
    final marker = '# Serlink writeback host $hostId';
    for (var index = 0; index < lines.length; index += 1) {
      final tokens = _tokenizeSshConfigLine(lines[index]);
      if (tokens.isEmpty || tokens.first.toLowerCase() != 'host') {
        continue;
      }
      final end = hostBlockEnd(index);
      if (lines.sublist(index + 1, end).any((line) => line.trim() == marker)) {
        return _SshHostBlockLocation(
          document: this,
          start: index,
          end: end,
          aliases: tokens.skip(1).toList(growable: false),
        );
      }
    }
    return null;
  }

  int hostBlockEnd(int start) {
    for (var index = start + 1; index < lines.length; index += 1) {
      final tokens = _tokenizeSshConfigLine(lines[index]);
      if (tokens.isEmpty) {
        continue;
      }
      final keyword = tokens.first.toLowerCase();
      if (keyword == 'host' || keyword == 'match') {
        return index;
      }
    }
    return lines.length;
  }

  void updateHost({
    required _SshHostBlockLocation location,
    required String previousAlias,
    required HostConfig host,
    required String alias,
    required Map<HostId, String> aliases,
  }) {
    final original = lines.sublist(location.start, location.end);
    final remainingAliases = [
      for (final candidate in location.aliases)
        if (candidate.toLowerCase() != previousAlias.toLowerCase()) candidate,
    ];
    final updated = _renderHostBlock(
      original: original,
      host: host,
      alias: alias,
      aliases: aliases,
    );
    if (remainingAliases.isEmpty) {
      lines.replaceRange(location.start, location.end, updated);
    } else {
      final shared = [...original];
      shared[0] = 'Host ${remainingAliases.join(' ')}';
      lines.replaceRange(location.start, location.end, [
        ...shared,
        if (shared.isNotEmpty && shared.last.trim().isNotEmpty) '',
        ...updated,
      ]);
    }
    dirty = true;
  }

  List<String> detachHost({
    required _SshHostBlockLocation location,
    required String alias,
  }) {
    final original = lines.sublist(location.start, location.end);
    original[0] = 'Host $alias';
    final remainingAliases = [
      for (final candidate in location.aliases)
        if (candidate.toLowerCase() != alias.toLowerCase()) candidate,
    ];
    if (remainingAliases.isEmpty) {
      lines.removeRange(location.start, location.end);
      _collapseBlankLinesNear(location.start);
    } else {
      lines[location.start] = 'Host ${remainingAliases.join(' ')}';
    }
    dirty = true;
    return original;
  }

  void prependManagedHost({
    required List<String> original,
    required HostConfig host,
    required String alias,
    required Map<HostId, String> aliases,
  }) {
    lines.insertAll(0, [
      '# >>> Serlink managed host ${host.id.value}',
      ..._renderHostBlock(
        original: original,
        host: host,
        alias: alias,
        aliases: aliases,
      ),
      '# <<< Serlink managed host ${host.id.value}',
      'Host *',
      if (lines.isNotEmpty) '',
    ]);
    dirty = true;
  }

  bool removeHost({
    required _SshHostBlockLocation location,
    required String alias,
    required String? managedHostId,
  }) {
    if (managedHostId != null) {
      final beginMarker = '# >>> Serlink managed host $managedHostId';
      final endMarker = '# <<< Serlink managed host $managedHostId';
      final markerStart = _findMarkerBackward(location.start, beginMarker);
      final markerEnd = _findMarkerForward(location.start, endMarker);
      if (markerStart != null && markerEnd != null) {
        lines.removeRange(markerStart, markerEnd + 1);
        if (markerStart < lines.length) {
          final tokens = _tokenizeSshConfigLine(lines[markerStart]);
          if (tokens.length == 2 &&
              tokens.first.toLowerCase() == 'host' &&
              tokens.last == '*') {
            lines.removeAt(markerStart);
          }
        }
        while (markerStart < lines.length && lines[markerStart].isEmpty) {
          lines.removeAt(markerStart);
        }
        _collapseBlankLinesNear(markerStart);
        while (lines.isNotEmpty && lines.last.isEmpty) {
          lines.removeLast();
        }
        dirty = true;
        return true;
      }
      final hostMarker = '# Serlink writeback host $managedHostId';
      if (lines
          .sublist(location.start + 1, location.end)
          .any((line) => line.trim() == hostMarker)) {
        lines.removeRange(location.start, location.end);
        _collapseBlankLinesNear(location.start);
        dirty = true;
        return true;
      }
    }

    final remainingAliases = [
      for (final candidate in location.aliases)
        if (candidate.toLowerCase() != alias.toLowerCase()) candidate,
    ];
    if (remainingAliases.length == location.aliases.length) {
      return false;
    }
    if (remainingAliases.isEmpty) {
      lines.removeRange(location.start, location.end);
      _collapseBlankLinesNear(location.start);
    } else {
      lines[location.start] = 'Host ${remainingAliases.join(' ')}';
    }
    dirty = true;
    return true;
  }

  bool isManagedHost({
    required _SshHostBlockLocation location,
    required String hostId,
  }) {
    return _findMarkerBackward(
              location.start,
              '# >>> Serlink managed host $hostId',
            ) !=
            null ||
        lines
            .sublist(location.start + 1, location.end)
            .any((line) => line.trim() == '# Serlink writeback host $hostId');
  }

  bool hasManagedWrapper({
    required _SshHostBlockLocation location,
    required String hostId,
  }) {
    return _findMarkerBackward(
          location.start,
          '# >>> Serlink managed host $hostId',
        ) !=
        null;
  }

  int? _findMarkerBackward(int start, String marker) {
    for (var index = start - 1; index >= 0; index -= 1) {
      final line = lines[index].trim();
      if (line == marker) {
        return index;
      }
      if (line.isNotEmpty) {
        return null;
      }
    }
    return null;
  }

  int? _findMarkerForward(int start, String marker) {
    for (var index = start + 1; index < lines.length; index += 1) {
      final line = lines[index].trim();
      if (line == marker) {
        return index;
      }
      final tokens = _tokenizeSshConfigLine(line);
      if (tokens.isNotEmpty &&
          (tokens.first.toLowerCase() == 'host' ||
              tokens.first.toLowerCase() == 'match')) {
        return null;
      }
    }
    return null;
  }

  void _collapseBlankLinesNear(int index) {
    while (index < lines.length &&
        index > 0 &&
        lines[index].isEmpty &&
        lines[index - 1].isEmpty) {
      lines.removeAt(index);
    }
  }
}

class _SshHostBlockLocation {
  const _SshHostBlockLocation({
    required this.document,
    required this.start,
    required this.end,
    required this.aliases,
  });

  final _EditableSshConfigFile document;
  final int start;
  final int end;
  final List<String> aliases;
}

const _managedDirectiveKeywords = {
  'hostname',
  'user',
  'port',
  'connecttimeout',
  'serveraliveinterval',
  'proxyjump',
  'localforward',
  'remoteforward',
  'dynamicforward',
};

List<String> _renderHostBlock({
  required List<String> original,
  required HostConfig host,
  required String alias,
  required Map<HostId, String> aliases,
}) {
  final preserved = <String>[];
  for (final line in original.skip(1)) {
    if (line.trim().startsWith('# Serlink writeback host ')) {
      continue;
    }
    final tokens = _tokenizeSshConfigLine(line);
    if (tokens.isNotEmpty &&
        _managedDirectiveKeywords.contains(tokens.first.toLowerCase())) {
      continue;
    }
    preserved.add(line);
  }
  while (preserved.isNotEmpty && preserved.first.isEmpty) {
    preserved.removeAt(0);
  }

  final jumpAliases = [for (final id in host.jumpHostIds) ?aliases[id]];
  final directives = <String>[
    '  HostName ${_sshConfigValue(host.hostname)}',
    if (host.username.trim().isNotEmpty)
      '  User ${_sshConfigValue(host.username)}',
    '  Port ${host.port}',
    '  ConnectTimeout ${host.connectionSettings.connectTimeoutSeconds}',
    '  ServerAliveInterval '
        '${host.connectionSettings.keepAliveIntervalSeconds}',
    '  ProxyJump ${jumpAliases.isEmpty ? 'none' : jumpAliases.join(',')}',
    for (final forward in host.portForwarding.localForwards)
      '  LocalForward ${forward.localPort} '
          '${_sshForwardHost(forward.remoteHost)}:${forward.remotePort}',
    for (final forward in host.portForwarding.remoteForwards)
      '  RemoteForward ${_sshForwardHost(forward.bindHost)}:'
          '${forward.bindPort} ${_sshForwardHost(forward.localHost)}:'
          '${forward.localPort}',
    for (final forward in host.portForwarding.dynamicForwards)
      '  DynamicForward ${_sshForwardHost(forward.bindHost)}:'
          '${forward.bindPort}',
  ];
  return [
    'Host $alias',
    '  # Serlink writeback host ${host.id.value}',
    ...directives,
    if (preserved.isNotEmpty) ...['', ...preserved],
  ];
}

Map<HostId, String> _assignAliases(List<HostConfig> hosts) {
  final sorted = hosts.toList()..sort(_compareHostCreationOrder);
  final result = <HostId, String>{};
  final used = <String>{};
  for (final host in sorted) {
    final base = _baseWritebackAlias(host);
    var alias = base;
    var suffix = 2;
    while (!used.add(alias.toLowerCase())) {
      alias = '$base-$suffix';
      suffix += 1;
    }
    result[host.id] = alias;
  }
  return result;
}

int _compareHostCreationOrder(HostConfig left, HostConfig right) {
  final byCreatedAt = left.createdAt.compareTo(right.createdAt);
  return byCreatedAt != 0
      ? byCreatedAt
      : left.id.value.compareTo(right.id.value);
}

String _baseWritebackAlias(HostConfig host) {
  final displayName = host.displayName.trim();
  if (_isSafeConcreteAlias(displayName)) {
    return displayName;
  }
  for (final value in [displayName, host.hostname, host.id.value]) {
    var alias = value.toLowerCase().trim();
    alias = alias.replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');
    alias = alias.replaceAll(RegExp(r'-{2,}'), '-');
    alias = alias.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
    if (_isSafeConcreteAlias(alias)) {
      return alias;
    }
  }
  return 'host-${host.id.value}';
}

bool _isSafeConcreteAlias(String value) {
  return value.isNotEmpty &&
      value != '*' &&
      value != '?' &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);
}

bool _containsConcreteAlias(List<String> aliases, String target) {
  return aliases.any(
    (alias) =>
        _isSafeConcreteAlias(alias) &&
        alias.toLowerCase() == target.toLowerCase(),
  );
}

String _sourceAliasForLocation({
  required _SshHostBlockLocation location,
  required String? previousAlias,
  required String desiredAlias,
}) {
  for (final candidate in [previousAlias, desiredAlias]) {
    if (candidate != null &&
        location.aliases.any(
          (alias) => alias.toLowerCase() == candidate.toLowerCase(),
        )) {
      return candidate;
    }
  }
  return location.aliases.firstWhere(
    _isSafeConcreteAlias,
    orElse: () => desiredAlias,
  );
}

String _sshConfigValue(String value) {
  final singleLine = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (!singleLine.contains(RegExp(r'[\s#"\\]'))) {
    return singleLine;
  }
  final escaped = singleLine.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

String _sshForwardHost(String value) {
  final host = value.replaceAll(RegExp(r'[\r\n\s]+'), '').trim();
  if (host.contains(':') && !(host.startsWith('[') && host.endsWith(']'))) {
    return '[$host]';
  }
  return host;
}

List<String> _splitSshConfigLines(String contents) {
  if (contents.isEmpty) {
    return [];
  }
  final normalized = contents.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

List<String> _tokenizeSshConfigLine(String line) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var escaping = false;
  for (var index = 0; index < line.length; index += 1) {
    final char = line[index];
    if (escaping) {
      buffer.write(char);
      escaping = false;
      continue;
    }
    if (char == r'\') {
      escaping = true;
      continue;
    }
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }
    if (char == '#' && buffer.isEmpty) {
      break;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    buffer.write(char);
  }
  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }
  return tokens;
}

List<String> _resolveWritebackIncludePaths(
  String includePattern, {
  required String sourcePath,
}) {
  var expanded = includePattern.trim();
  final home = Platform.environment['HOME'];
  if (expanded == '~' && home != null) {
    expanded = home;
  } else if (expanded.startsWith('~/') && home != null) {
    expanded = p.join(home, expanded.substring(2));
  }
  if (expanded.isEmpty) {
    return const [];
  }
  final pattern = p.normalize(
    p.isAbsolute(expanded) ? expanded : p.join(p.dirname(sourcePath), expanded),
  );
  if (!pattern.contains('*') && !pattern.contains('?')) {
    return File(pattern).existsSync() ? [pattern] : const [];
  }
  final baseDirectory = _writebackGlobBaseDirectory(pattern);
  final directory = Directory(baseDirectory);
  if (!directory.existsSync()) {
    return const [];
  }
  final regex = _writebackGlobRegex(pattern);
  final matches = <String>[];
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      final path = p.normalize(entity.path);
      if (regex.hasMatch(path)) {
        matches.add(path);
      }
    }
  }
  matches.sort();
  return matches;
}

String _writebackGlobBaseDirectory(String pattern) {
  final parts = p.split(pattern);
  final baseParts = <String>[];
  for (final part in parts) {
    if (part.contains('*') || part.contains('?')) {
      break;
    }
    baseParts.add(part);
  }
  if (baseParts.isEmpty) {
    return p.rootPrefix(pattern).isEmpty ? '.' : p.rootPrefix(pattern);
  }
  return p.joinAll(baseParts);
}

RegExp _writebackGlobRegex(String pattern) {
  final buffer = StringBuffer('^');
  for (var index = 0; index < pattern.length; index += 1) {
    final char = pattern[index];
    if (char == '*') {
      if (index + 1 < pattern.length && pattern[index + 1] == '*') {
        buffer.write('.*');
        index += 1;
      } else {
        buffer.write('[^/]*');
      }
    } else if (char == '?') {
      buffer.write('[^/]');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

Future<File> _resolvedWriteDestination(String path) async {
  final type = await FileSystemEntity.type(path, followLinks: false);
  if (type != FileSystemEntityType.link) {
    return File(path);
  }
  return File(await Link(path).resolveSymbolicLinks());
}

Future<void> _writeFileAtomically(
  File file,
  String contents, {
  File? expectedFile,
  String? expectedContents,
}) async {
  final directory = file.parent;
  await LocalFileSecurity.preparePrivateDirectory(directory);
  final temporary = File(
    '${file.path}.serlink-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temporary.writeAsString(contents, flush: true);
    await LocalFileSecurity.restrictExistingFile(temporary);
    if (expectedFile != null) {
      final current = await expectedFile.exists()
          ? await expectedFile.readAsString()
          : null;
      if (current != expectedContents) {
        throw FileSystemException(
          'SSH config changed while Serlink was updating it.',
          expectedFile.path,
        );
      }
    }
    await temporary.rename(file.path);
    await LocalFileSecurity.restrictExistingFile(file);
  } on Object {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    rethrow;
  }
}
