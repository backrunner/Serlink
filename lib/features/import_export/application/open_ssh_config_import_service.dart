import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';
import '../../identities/application/identity_repository.dart';
import '../../identities/domain/identity.dart';
import '../../identities/domain/identity_secret.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';

class OpenSshConfigImportWarning {
  const OpenSshConfigImportWarning({
    required this.lineNumber,
    required this.code,
    required this.message,
  });

  final int lineNumber;
  final String code;
  final String message;
}

class OpenSshConfigImportEntry {
  const OpenSshConfigImportEntry({
    required this.alias,
    required this.hostname,
    required this.username,
    required this.port,
    required this.identityFiles,
    required this.certificateFiles,
    required this.proxyJump,
  });

  final String alias;
  final String hostname;
  final String? username;
  final int port;
  final List<String> identityFiles;
  final List<String> certificateFiles;
  final String? proxyJump;
}

class OpenSshConfigImportResult {
  const OpenSshConfigImportResult({
    required this.entries,
    required this.skippedHosts,
    required this.warnings,
  });

  final List<OpenSshConfigImportEntry> entries;
  final int skippedHosts;
  final List<OpenSshConfigImportWarning> warnings;
}

class OpenSshConfigApplyResult {
  const OpenSshConfigApplyResult({
    required this.preview,
    required this.hostsCreated,
    required this.hostsSkipped,
    required this.duplicateHosts,
    required this.missingUsernames,
    required this.identitiesImported,
    required this.warnings,
  });

  final OpenSshConfigImportResult preview;
  final int hostsCreated;
  final int hostsSkipped;
  final int duplicateHosts;
  final int missingUsernames;
  final int identitiesImported;
  final List<OpenSshConfigImportWarning> warnings;
}

class OpenSshConfigImportService {
  static const _maxIncludeDepth = 8;

  OpenSshConfigImportService({
    HostRepository? hosts,
    IdentityRepository? identities,
    VaultRecordRepository? records,
    VaultService? vault,
    Uuid? uuid,
    DateTime Function()? now,
  }) : this._(
         hosts,
         identities,
         records,
         vault,
         uuid ?? const Uuid(),
         now ?? DateTime.now,
       );

  OpenSshConfigImportService._(
    this._hosts,
    this._identities,
    this._records,
    this._vault,
    this._uuid,
    this._now,
  );

  final HostRepository? _hosts;
  final IdentityRepository? _identities;
  final VaultRecordRepository? _records;
  final VaultService? _vault;
  final Uuid _uuid;
  final DateTime Function() _now;

  OpenSshConfigImportResult preview(
    String contents, {
    String? configSourcePath,
  }) {
    final warnings = <OpenSshConfigImportWarning>[];
    final blocks = <_OpenSshHostBlock>[
      _OpenSshHostBlock(aliases: const ['*'], lineNumber: 0),
    ];
    var skippedHosts = 0;
    var currentBlock = blocks.single;
    final lines = _expandConfigLines(
      contents,
      configSourcePath: configSourcePath,
      warnings: warnings,
    );

    for (final line in lines) {
      final tokens = line.tokens;
      final keyword = tokens.first.toLowerCase();
      final values = tokens.skip(1).toList(growable: false);
      if (keyword == 'host') {
        if (values.isEmpty) {
          skippedHosts += 1;
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: line.lineNumber,
              code: 'ssh_config.host_empty',
              message: 'Host block on line ${line.lineNumber} has no aliases.',
            ),
          );
          currentBlock = _OpenSshHostBlock(
            aliases: const [],
            lineNumber: line.lineNumber,
          );
          continue;
        }
        currentBlock = _OpenSshHostBlock(
          aliases: values,
          lineNumber: line.lineNumber,
        );
        blocks.add(currentBlock);
        _addPatternWarnings(currentBlock, warnings);
        skippedHosts += currentBlock.skippedImportAliasCount;
        continue;
      }
      if (keyword == 'match') {
        currentBlock = _OpenSshHostBlock(
          aliases: const [],
          lineNumber: line.lineNumber,
        );
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: line.lineNumber,
            code: 'ssh_config.match_unsupported',
            message:
                'Match block on line ${line.lineNumber} is not imported because its conditions are evaluated dynamically by OpenSSH.',
          ),
        );
        continue;
      }

      if (values.isEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: line.lineNumber,
            code: 'ssh_config.directive_empty',
            message:
                'Directive ${tokens.first} on line ${line.lineNumber} is empty.',
          ),
        );
        continue;
      }
      switch (keyword) {
        case 'hostname':
          currentBlock.hostname ??= values.first;
        case 'user':
          currentBlock.username ??= values.first;
        case 'port':
          final port = int.tryParse(values.first);
          if (port == null || port <= 0 || port > 65535) {
            warnings.add(
              OpenSshConfigImportWarning(
                lineNumber: line.lineNumber,
                code: 'ssh_config.port_invalid',
                message: 'Port on line ${line.lineNumber} is invalid.',
              ),
            );
          } else {
            currentBlock.port ??= port;
          }
        case 'identityfile':
          currentBlock.identityFiles.add(values.join(' '));
        case 'certificatefile':
          currentBlock.certificateFiles.add(values.join(' '));
        case 'proxyjump':
          currentBlock.proxyJump ??= values.join(' ');
        case 'proxycommand':
          currentBlock.proxyCommand ??= values.join(' ');
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: line.lineNumber,
              code: 'ssh_config.proxy_command_unsupported',
              message:
                  'ProxyCommand on line ${line.lineNumber} is not imported because Serlink will not execute commands from SSH config.',
            ),
          );
        case 'identityagent':
          currentBlock.identityAgent ??= values.join(' ');
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: line.lineNumber,
              code: 'ssh_config.identity_agent_unsupported',
              message:
                  'IdentityAgent on line ${line.lineNumber} is not imported because SSH agent authentication is not enabled for this release.',
            ),
          );
        case 'userknownhostsfile' || 'globalknownhostsfile':
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: line.lineNumber,
              code: 'ssh_config.known_hosts_file_unsupported',
              message:
                  'Directive ${tokens.first} on line ${line.lineNumber} is not imported. Import known_hosts files separately from Settings.',
            ),
          );
        default:
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: line.lineNumber,
              code: 'ssh_config.directive_unsupported',
              message:
                  'Directive ${tokens.first} on line ${line.lineNumber} is not imported yet.',
            ),
          );
      }
    }

    final entries = <OpenSshConfigImportEntry>[];
    final seenAliases = <String>{};
    for (final block in blocks) {
      for (final alias in block.importableAliases) {
        final key = alias.toLowerCase();
        if (!seenAliases.add(key)) {
          continue;
        }
        final effective = _OpenSshEffectiveHost(alias);
        for (final candidate in blocks) {
          if (candidate.matchesAlias(alias)) {
            effective.apply(candidate);
          }
        }
        entries.add(effective.toEntry());
      }
    }

    return OpenSshConfigImportResult(
      entries: List<OpenSshConfigImportEntry>.unmodifiable(entries),
      skippedHosts: skippedHosts,
      warnings: List<OpenSshConfigImportWarning>.unmodifiable(warnings),
    );
  }

  Future<OpenSshConfigApplyResult> applyPreview(
    OpenSshConfigImportResult preview, {
    String? defaultUsername,
    String? configSourcePath,
  }) async {
    final hosts = _hosts;
    if (hosts == null) {
      throw const OpenSshConfigImportException(
        'ssh_config.host_repository_missing',
        'Host repository is required to import OpenSSH config hosts.',
      );
    }
    final existingHosts = await hosts.list();
    final warnings = [...preview.warnings];
    var hostsCreated = 0;
    var duplicateHosts = 0;
    var missingUsernames = 0;
    var identitiesImported = 0;
    final existingJumpHosts = _existingJumpHostLookup(existingHosts);
    final importedJumpHosts = <String, HostId>{};
    final importedIdentityFiles = <String, _ImportedOpenSshIdentity>{};
    final importPlans = <_OpenSshConfigImportPlan>[];

    for (final entry in preview.entries) {
      if (_hasDuplicate(entry, existingHosts)) {
        duplicateHosts += 1;
        continue;
      }
      final username = (entry.username ?? defaultUsername ?? '').trim();
      if (username.isEmpty) {
        missingUsernames += 1;
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.username_missing',
            message: 'Host ${entry.alias} does not specify a username.',
          ),
        );
        continue;
      }
      final hostId = HostId(_uuid.v4());
      importedJumpHosts[entry.alias.toLowerCase()] = hostId;
      final identities = await _resolveIdentityFiles(
        entry.identityFiles,
        certificateFiles: entry.certificateFiles,
        configSourcePath: configSourcePath,
        importedIdentityFiles: importedIdentityFiles,
        alias: entry.alias,
        username: username,
        warnings: warnings,
      );
      identitiesImported += identities.importedCount;
      importPlans.add(
        _OpenSshConfigImportPlan(
          entry: entry,
          username: username,
          hostId: hostId,
          identityIds: identities.identityIds,
          authKinds: identities.authKinds,
        ),
      );
    }

    for (final plan in importPlans) {
      final jumpResolution = _resolveProxyJump(
        plan.entry.proxyJump,
        existingJumpHosts: existingJumpHosts,
        importedJumpHosts: importedJumpHosts,
      );
      if (jumpResolution.unresolvedAliases.isNotEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.proxy_jump_unresolved',
            message:
                'Host ${plan.entry.alias} references unresolved ProxyJump target'
                '${jumpResolution.unresolvedAliases.length == 1 ? '' : 's'}: '
                '${jumpResolution.unresolvedAliases.join(', ')}.',
          ),
        );
      }
      final now = _now().toUtc();
      await hosts.save(
        HostConfig(
          id: plan.hostId,
          displayName: plan.entry.alias,
          hostname: plan.entry.hostname,
          username: plan.username,
          port: plan.entry.port,
          authKinds: plan.authKinds,
          tags: const {'imported'},
          trustState: HostTrustState.unknown,
          identityIds: plan.identityIds,
          startupCommands: const [],
          jumpHostIds: jumpResolution.hostIds,
          createdAt: now,
          updatedAt: now,
        ),
      );
      hostsCreated += 1;
    }

    return OpenSshConfigApplyResult(
      preview: preview,
      hostsCreated: hostsCreated,
      hostsSkipped: duplicateHosts + missingUsernames,
      duplicateHosts: duplicateHosts,
      missingUsernames: missingUsernames,
      identitiesImported: identitiesImported,
      warnings: List<OpenSshConfigImportWarning>.unmodifiable(warnings),
    );
  }
}

class OpenSshConfigImportException implements Exception {
  const OpenSshConfigImportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'OpenSshConfigImportException($code): $message';
}

class _OpenSshConfigLine {
  const _OpenSshConfigLine({required this.tokens, required this.lineNumber});

  final List<String> tokens;
  final int lineNumber;
}

List<_OpenSshConfigLine> _expandConfigLines(
  String contents, {
  required String? configSourcePath,
  required List<OpenSshConfigImportWarning> warnings,
  Set<String>? visitedConfigPaths,
  int depth = 0,
}) {
  if (depth > OpenSshConfigImportService._maxIncludeDepth) {
    warnings.add(
      const OpenSshConfigImportWarning(
        lineNumber: 0,
        code: 'ssh_config.include_too_deep',
        message: 'OpenSSH Include nesting is too deep.',
      ),
    );
    return const [];
  }

  final visited = {
    ...?visitedConfigPaths,
    if (configSourcePath != null) p.normalize(configSourcePath),
  };
  final expanded = <_OpenSshConfigLine>[];
  final lines = contents.split('\n');
  for (var index = 0; index < lines.length; index += 1) {
    final lineNumber = index + 1;
    final tokens = _tokenizeConfigLine(lines[index]);
    if (tokens.isEmpty) {
      continue;
    }
    final keyword = tokens.first.toLowerCase();
    final values = tokens.skip(1).toList(growable: false);
    if (keyword != 'include') {
      expanded.add(_OpenSshConfigLine(tokens: tokens, lineNumber: lineNumber));
      continue;
    }
    if (values.isEmpty) {
      warnings.add(
        OpenSshConfigImportWarning(
          lineNumber: lineNumber,
          code: 'ssh_config.include_empty',
          message: 'Include directive on line $lineNumber is empty.',
        ),
      );
      continue;
    }
    for (final includePattern in values) {
      final includePaths = _resolveIncludePaths(
        includePattern,
        configSourcePath: configSourcePath,
      );
      if (includePaths == null) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: lineNumber,
            code: 'ssh_config.include_unresolved',
            message:
                'Include $includePattern on line $lineNumber cannot be resolved without the config file path.',
          ),
        );
        continue;
      }
      if (includePaths.isEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: lineNumber,
            code: 'ssh_config.include_not_found',
            message:
                'Include $includePattern on line $lineNumber did not match any readable config files.',
          ),
        );
        continue;
      }
      for (final includePath in includePaths) {
        final normalized = p.normalize(includePath);
        if (visited.contains(normalized)) {
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: lineNumber,
              code: 'ssh_config.include_cycle',
              message:
                  'Include $includePattern on line $lineNumber creates a config include cycle.',
            ),
          );
          continue;
        }
        try {
          expanded.addAll(
            _expandConfigLines(
              File(normalized).readAsStringSync(),
              configSourcePath: normalized,
              warnings: warnings,
              visitedConfigPaths: visited,
              depth: depth + 1,
            ),
          );
        } on Object {
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: lineNumber,
              code: 'ssh_config.include_unreadable',
              message:
                  'Include $includePattern on line $lineNumber could not be read.',
            ),
          );
        }
      }
    }
  }
  return expanded;
}

List<String> _tokenizeConfigLine(String line) {
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

bool _isPatternAlias(String alias) {
  return alias == '*' ||
      alias.startsWith('!') ||
      alias.contains('*') ||
      alias.contains('?');
}

void _addPatternWarnings(
  _OpenSshHostBlock block,
  List<OpenSshConfigImportWarning> warnings,
) {
  if (!block.hasUnsupportedImportPattern) {
    return;
  }
  warnings.add(
    OpenSshConfigImportWarning(
      lineNumber: block.lineNumber,
      code: 'ssh_config.host_pattern_unsupported',
      message:
          'Host block on line ${block.lineNumber} contains wildcard or negated patterns; Serlink uses them only for inheritance and does not import them as concrete hosts.',
    ),
  );
}

bool _hostPatternMatches(String pattern, String alias) {
  if (pattern == '*') {
    return true;
  }
  if (!pattern.contains('*') && !pattern.contains('?')) {
    return pattern.toLowerCase() == alias.toLowerCase();
  }
  final escaped = RegExp.escape(
    pattern,
  ).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
  return RegExp('^$escaped\$', caseSensitive: false).hasMatch(alias);
}

bool _hasDuplicate(
  OpenSshConfigImportEntry entry,
  List<HostConfig> existingHosts,
) {
  return existingHosts.any(
    (host) =>
        host.hostname.toLowerCase() == entry.hostname.toLowerCase() &&
        host.port == entry.port,
  );
}

Map<String, HostId> _existingJumpHostLookup(List<HostConfig> existingHosts) {
  return {
    for (final host in existingHosts) host.displayName.toLowerCase(): host.id,
    for (final host in existingHosts) host.hostname.toLowerCase(): host.id,
  };
}

_ProxyJumpResolution _resolveProxyJump(
  String? proxyJump, {
  required Map<String, HostId> existingJumpHosts,
  required Map<String, HostId> importedJumpHosts,
}) {
  final aliases = _parseProxyJumpAliases(proxyJump);
  if (aliases.isEmpty) {
    return const _ProxyJumpResolution(hostIds: [], unresolvedAliases: []);
  }
  final hostIds = <HostId>[];
  final unresolvedAliases = <String>[];
  for (final alias in aliases) {
    final key = alias.toLowerCase();
    final hostId = importedJumpHosts[key] ?? existingJumpHosts[key];
    if (hostId == null) {
      unresolvedAliases.add(alias);
      continue;
    }
    if (!hostIds.contains(hostId)) {
      hostIds.add(hostId);
    }
  }
  return _ProxyJumpResolution(
    hostIds: List<HostId>.unmodifiable(hostIds),
    unresolvedAliases: List<String>.unmodifiable(unresolvedAliases),
  );
}

List<String> _parseProxyJumpAliases(String? proxyJump) {
  final value = proxyJump?.trim();
  if (value == null || value.isEmpty || value.toLowerCase() == 'none') {
    return const [];
  }
  return [for (final part in value.split(',')) ?_proxyJumpHostAlias(part)];
}

String? _proxyJumpHostAlias(String value) {
  var host = value.trim();
  if (host.isEmpty) {
    return null;
  }
  final userSeparator = host.lastIndexOf('@');
  if (userSeparator != -1) {
    host = host.substring(userSeparator + 1);
  }
  if (host.startsWith('[')) {
    final endBracket = host.indexOf(']');
    if (endBracket > 1) {
      return host.substring(1, endBracket);
    }
  }
  final colonCount = ':'.allMatches(host).length;
  if (colonCount == 1) {
    return host.substring(0, host.indexOf(':'));
  }
  return host;
}

class _ProxyJumpResolution {
  const _ProxyJumpResolution({
    required this.hostIds,
    required this.unresolvedAliases,
  });

  final List<HostId> hostIds;
  final List<String> unresolvedAliases;
}

class _OpenSshConfigImportPlan {
  const _OpenSshConfigImportPlan({
    required this.entry,
    required this.username,
    required this.hostId,
    required this.identityIds,
    required this.authKinds,
  });

  final OpenSshConfigImportEntry entry;
  final String username;
  final HostId hostId;
  final List<IdentityId> identityIds;
  final Set<HostAuthKind> authKinds;
}

class _OpenSshHostBlock {
  _OpenSshHostBlock({required this.aliases, required this.lineNumber});

  final List<String> aliases;
  final int lineNumber;
  String? hostname;
  String? username;
  int? port;
  final List<String> identityFiles = [];
  final List<String> certificateFiles = [];
  String? proxyJump;
  String? proxyCommand;
  String? identityAgent;

  List<String> get importableAliases {
    return [
      for (final alias in aliases)
        if (!_isPatternAlias(alias) && alias != '*') alias,
    ];
  }

  int get skippedImportAliasCount {
    return aliases
        .where((alias) => _isPatternAlias(alias) && alias != '*')
        .length;
  }

  bool get hasUnsupportedImportPattern {
    return aliases.any((alias) => _isPatternAlias(alias) && alias != '*');
  }

  bool matchesAlias(String alias) {
    var matchedPositive = false;
    for (final pattern in aliases) {
      if (pattern.startsWith('!')) {
        final negated = pattern.substring(1);
        if (_hostPatternMatches(negated, alias)) {
          return false;
        }
        continue;
      }
      if (_hostPatternMatches(pattern, alias)) {
        matchedPositive = true;
      }
    }
    return matchedPositive;
  }
}

class _OpenSshEffectiveHost {
  _OpenSshEffectiveHost(this.alias);

  final String alias;
  String? hostname;
  String? username;
  int? port;
  final List<String> identityFiles = [];
  final List<String> certificateFiles = [];
  String? proxyJump;

  void apply(_OpenSshHostBlock block) {
    hostname ??= block.hostname;
    username ??= block.username;
    port ??= block.port;
    proxyJump ??= block.proxyJump;
    for (final identityFile in block.identityFiles) {
      if (!identityFiles.contains(identityFile)) {
        identityFiles.add(identityFile);
      }
    }
    for (final certificateFile in block.certificateFiles) {
      if (!certificateFiles.contains(certificateFile)) {
        certificateFiles.add(certificateFile);
      }
    }
  }

  OpenSshConfigImportEntry toEntry() {
    return OpenSshConfigImportEntry(
      alias: alias,
      hostname: hostname ?? alias,
      username: username,
      port: port ?? 22,
      identityFiles: List<String>.unmodifiable(identityFiles),
      certificateFiles: List<String>.unmodifiable(certificateFiles),
      proxyJump: proxyJump,
    );
  }
}

class _OpenSshIdentityResolution {
  const _OpenSshIdentityResolution({
    required this.identityIds,
    required this.authKinds,
    required this.importedCount,
  });

  const _OpenSshIdentityResolution.empty()
    : identityIds = const [],
      authKinds = const {},
      importedCount = 0;

  final List<IdentityId> identityIds;
  final Set<HostAuthKind> authKinds;
  final int importedCount;
}

class _ImportedOpenSshIdentity {
  const _ImportedOpenSshIdentity({required this.id, required this.authKind});

  final IdentityId id;
  final HostAuthKind authKind;
}

extension on OpenSshConfigImportService {
  Future<_OpenSshIdentityResolution> _resolveIdentityFiles(
    List<String> identityFiles, {
    required List<String> certificateFiles,
    required String? configSourcePath,
    required Map<String, _ImportedOpenSshIdentity> importedIdentityFiles,
    required String alias,
    required String username,
    required List<OpenSshConfigImportWarning> warnings,
  }) async {
    if (identityFiles.isEmpty) {
      if (certificateFiles.isNotEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.certificate_file_without_identity',
            message:
                'Host $alias references CertificateFile without IdentityFile; import the certificate manually or add the paired private key.',
          ),
        );
      }
      return const _OpenSshIdentityResolution.empty();
    }
    final identities = _identities;
    final records = _records;
    final vault = _vault;
    if (identities == null || records == null || vault == null) {
      warnings.add(
        OpenSshConfigImportWarning(
          lineNumber: 0,
          code: 'ssh_config.identity_file_pending',
          message:
              'Host $alias references identity files; import credentials separately.',
        ),
      );
      return const _OpenSshIdentityResolution.empty();
    }

    final identityIds = <IdentityId>[];
    final authKinds = <HostAuthKind>{};
    var importedCount = 0;
    final certificatePairing = _certificatePairing(
      identityFiles: identityFiles,
      certificateFiles: certificateFiles,
      alias: alias,
      warnings: warnings,
    );
    for (final identityFile in identityFiles) {
      final resolvedPath = _resolveIdentityPath(
        identityFile,
        configSourcePath: configSourcePath,
      );
      if (resolvedPath == null) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_unresolved',
            message:
                'Host $alias references $identityFile; provide the config file path to import it automatically.',
          ),
        );
        continue;
      }
      final certificateFile = certificatePairing[identityFile];
      final resolvedCertificatePath = certificateFile == null
          ? null
          : _resolveIdentityPath(
              certificateFile,
              configSourcePath: configSourcePath,
            );
      if (certificateFile != null && resolvedCertificatePath == null) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.certificate_file_unresolved',
            message:
                'Host $alias references $certificateFile; provide the config file path to import it automatically.',
          ),
        );
      }
      final file = File(resolvedPath);
      if (!await file.exists()) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_missing',
            message:
                'Host $alias references missing identity file $identityFile.',
          ),
        );
        continue;
      }
      final privateKeyPem = (await file.readAsString()).trim();
      if (!_looksLikePrivateKey(privateKeyPem)) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_invalid',
            message:
                'Host $alias references $identityFile, but it is not an OpenSSH or PEM private key.',
          ),
        );
        continue;
      }
      var identityKind = IdentityKind.privateKey;
      var hostAuthKind = HostAuthKind.privateKey;
      String? certificateText;
      if (certificateFile != null && resolvedCertificatePath != null) {
        final certificate = File(resolvedCertificatePath);
        if (!await certificate.exists()) {
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: 0,
              code: 'ssh_config.certificate_file_missing',
              message:
                  'Host $alias references missing certificate file $certificateFile.',
            ),
          );
        } else {
          final candidate = _normalizeCertificateText(
            await certificate.readAsString(),
          );
          if (!_looksLikeOpenSshCertificate(candidate)) {
            warnings.add(
              OpenSshConfigImportWarning(
                lineNumber: 0,
                code: 'ssh_config.certificate_file_invalid',
                message:
                    'Host $alias references $certificateFile, but it is not an OpenSSH certificate public key line.',
              ),
            );
          } else {
            certificateText = candidate;
            identityKind = IdentityKind.openSshCertificate;
            hostAuthKind = HostAuthKind.openSshCertificate;
          }
        }
      }
      final cacheKey = _identityImportCacheKey(
        resolvedPath,
        certificateText == null ? null : resolvedCertificatePath,
      );
      final existingIdentity = importedIdentityFiles[cacheKey];
      if (existingIdentity != null) {
        identityIds.add(existingIdentity.id);
        authKinds.add(existingIdentity.authKind);
        continue;
      }

      final now = _now().toUtc();
      final identityId = IdentityId(_uuid.v4());
      final secretRecordId = VaultRecordId('secret:${identityId.value}');
      final envelope = await vault.encryptRecord(
        id: secretRecordId,
        type: 'identity_secret',
        plaintext: IdentitySecretMaterial(
          privateKeyPem: privateKeyPem,
          openSshCertificate: certificateText,
        ).toBytes(),
      );
      await records.upsert(envelope);
      await identities.save(
        IdentityConfig(
          id: identityId,
          displayName: certificateText == null
              ? '$alias ${p.basename(resolvedPath)}'
              : '$alias ${p.basename(resolvedCertificatePath ?? resolvedPath)}',
          kind: identityKind,
          usernameHint: username,
          secretRecordId: secretRecordId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      importedIdentityFiles[cacheKey] = _ImportedOpenSshIdentity(
        id: identityId,
        authKind: hostAuthKind,
      );
      identityIds.add(identityId);
      authKinds.add(hostAuthKind);
      importedCount += 1;
    }
    return _OpenSshIdentityResolution(
      identityIds: List<IdentityId>.unmodifiable(identityIds),
      authKinds: Set<HostAuthKind>.unmodifiable(authKinds),
      importedCount: importedCount,
    );
  }
}

String? _resolveIdentityPath(
  String identityFile, {
  required String? configSourcePath,
}) {
  final expanded = _expandHome(identityFile.trim());
  if (expanded.isEmpty) {
    return null;
  }
  if (p.isAbsolute(expanded)) {
    return p.normalize(expanded);
  }
  if (configSourcePath == null || configSourcePath.trim().isEmpty) {
    return null;
  }
  return p.normalize(p.join(p.dirname(configSourcePath), expanded));
}

List<String>? _resolveIncludePaths(
  String includePattern, {
  required String? configSourcePath,
}) {
  final expanded = _expandHome(includePattern.trim());
  if (expanded.isEmpty) {
    return const [];
  }
  if (!p.isAbsolute(expanded) &&
      (configSourcePath == null || configSourcePath.trim().isEmpty)) {
    return null;
  }
  final pattern = p.normalize(
    p.isAbsolute(expanded)
        ? expanded
        : p.join(p.dirname(configSourcePath!), expanded),
  );
  if (!_hasGlob(pattern)) {
    return File(pattern).existsSync() ? [pattern] : const [];
  }

  final baseDir = _globBaseDirectory(pattern);
  final directory = Directory(baseDir);
  if (!directory.existsSync()) {
    return const [];
  }
  final regex = _globPathRegex(pattern);
  final matches = <String>[];
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final normalized = p.normalize(entity.path);
    if (regex.hasMatch(normalized)) {
      matches.add(normalized);
    }
  }
  matches.sort();
  return List<String>.unmodifiable(matches);
}

String _expandHome(String path) {
  if (path == '~') {
    return Platform.environment['HOME'] ?? path;
  }
  if (path.startsWith('~/')) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return path;
    }
    return p.join(home, path.substring(2));
  }
  return path;
}

bool _looksLikePrivateKey(String value) {
  return value.contains('BEGIN') &&
      value.contains('PRIVATE KEY') &&
      value.contains('END');
}

bool _hasGlob(String path) => path.contains('*') || path.contains('?');

String _globBaseDirectory(String pattern) {
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
  final joined = p.joinAll(baseParts);
  return joined.isEmpty ? p.current : joined;
}

RegExp _globPathRegex(String pattern) {
  final buffer = StringBuffer('^');
  for (var index = 0; index < pattern.length; index += 1) {
    final char = pattern[index];
    switch (char) {
      case '*':
        buffer.write(r'[^/\\]*');
      case '?':
        buffer.write(r'[^/\\]');
      default:
        buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false);
}

Map<String, String> _certificatePairing({
  required List<String> identityFiles,
  required List<String> certificateFiles,
  required String alias,
  required List<OpenSshConfigImportWarning> warnings,
}) {
  if (certificateFiles.isEmpty || identityFiles.isEmpty) {
    return const {};
  }
  if (identityFiles.length == 1 && certificateFiles.length == 1) {
    return {identityFiles.single: certificateFiles.single};
  }
  if (identityFiles.length == certificateFiles.length) {
    return {
      for (var index = 0; index < identityFiles.length; index += 1)
        identityFiles[index]: certificateFiles[index],
    };
  }
  warnings.add(
    OpenSshConfigImportWarning(
      lineNumber: 0,
      code: 'ssh_config.certificate_file_ambiguous',
      message:
          'Host $alias has ${identityFiles.length} IdentityFile entries and ${certificateFiles.length} CertificateFile entries; import certificate credentials manually.',
    ),
  );
  return const {};
}

String _identityImportCacheKey(
  String identityFilePath,
  String? certificateFilePath,
) {
  return certificateFilePath == null
      ? identityFilePath
      : '$identityFilePath\n$certificateFilePath';
}

String _normalizeCertificateText(String value) {
  return value.trim().split(RegExp(r'\s*\n\s*')).join(' ');
}

bool _looksLikeOpenSshCertificate(String value) {
  final parts = value.split(RegExp(r'\s+'));
  if (parts.length < 2 || !parts.first.endsWith('-cert-v01@openssh.com')) {
    return false;
  }
  try {
    base64Decode(parts[1]);
    return true;
  } on FormatException {
    return false;
  }
}
