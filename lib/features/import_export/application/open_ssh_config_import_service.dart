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

  OpenSshConfigImportResult preview(String contents) {
    final warnings = <OpenSshConfigImportWarning>[];
    final entries = <OpenSshConfigImportEntry>[];
    var skippedHosts = 0;
    _OpenSshHostBlock? currentBlock;

    void flushCurrentBlock() {
      final block = currentBlock;
      if (block == null) {
        return;
      }
      final importableAliases = [
        for (final alias in block.aliases)
          if (!_isPatternAlias(alias)) alias,
      ];
      skippedHosts += block.aliases.length - importableAliases.length;
      if (importableAliases.length != block.aliases.length) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: block.lineNumber,
            code: 'ssh_config.host_pattern_unsupported',
            message:
                'Host block on line ${block.lineNumber} contains wildcard or negated patterns.',
          ),
        );
      }
      for (final alias in importableAliases) {
        entries.add(
          OpenSshConfigImportEntry(
            alias: alias,
            hostname: block.hostname ?? alias,
            username: block.username,
            port: block.port ?? 22,
            identityFiles: List<String>.unmodifiable(block.identityFiles),
            certificateFiles: List<String>.unmodifiable(block.certificateFiles),
            proxyJump: block.proxyJump,
          ),
        );
      }
    }

    final lines = contents.split('\n');
    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      final tokens = _tokenizeConfigLine(lines[index]);
      if (tokens.isEmpty) {
        continue;
      }
      final keyword = tokens.first.toLowerCase();
      final values = tokens.skip(1).toList(growable: false);
      if (keyword == 'host') {
        flushCurrentBlock();
        if (values.isEmpty) {
          skippedHosts += 1;
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: lineNumber,
              code: 'ssh_config.host_empty',
              message: 'Host block on line $lineNumber has no aliases.',
            ),
          );
          currentBlock = null;
          continue;
        }
        currentBlock = _OpenSshHostBlock(
          aliases: values,
          lineNumber: lineNumber,
        );
        continue;
      }

      final block = currentBlock;
      if (block == null) {
        continue;
      }
      if (values.isEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: lineNumber,
            code: 'ssh_config.directive_empty',
            message: 'Directive ${tokens.first} on line $lineNumber is empty.',
          ),
        );
        continue;
      }
      switch (keyword) {
        case 'hostname':
          block.hostname = values.first;
        case 'user':
          block.username = values.first;
        case 'port':
          final port = int.tryParse(values.first);
          if (port == null || port <= 0 || port > 65535) {
            warnings.add(
              OpenSshConfigImportWarning(
                lineNumber: lineNumber,
                code: 'ssh_config.port_invalid',
                message: 'Port on line $lineNumber is invalid.',
              ),
            );
          } else {
            block.port = port;
          }
        case 'identityfile':
          block.identityFiles.add(values.join(' '));
        case 'certificatefile':
          block.certificateFiles.add(values.join(' '));
        case 'proxyjump':
          block.proxyJump = values.join(' ');
        default:
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: lineNumber,
              code: 'ssh_config.directive_unsupported',
              message:
                  'Directive ${tokens.first} on line $lineNumber is not imported yet.',
            ),
          );
      }
    }
    flushCurrentBlock();

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
    final importedIdentityFiles = <String, IdentityId>{};
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
      final identityIds = await _resolveIdentityFiles(
        entry.identityFiles,
        configSourcePath: configSourcePath,
        importedIdentityFiles: importedIdentityFiles,
        alias: entry.alias,
        username: username,
        warnings: warnings,
      );
      identitiesImported += identityIds.length;
      importPlans.add(
        _OpenSshConfigImportPlan(
          entry: entry,
          username: username,
          hostId: hostId,
          identityIds: identityIds,
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
          authKinds: plan.identityIds.isEmpty
              ? const {}
              : const {HostAuthKind.privateKey},
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
  });

  final OpenSshConfigImportEntry entry;
  final String username;
  final HostId hostId;
  final List<IdentityId> identityIds;
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
}

extension on OpenSshConfigImportService {
  Future<List<IdentityId>> _resolveIdentityFiles(
    List<String> identityFiles, {
    required String? configSourcePath,
    required Map<String, IdentityId> importedIdentityFiles,
    required String alias,
    required String username,
    required List<OpenSshConfigImportWarning> warnings,
  }) async {
    if (identityFiles.isEmpty) {
      return const [];
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
      return const [];
    }

    final identityIds = <IdentityId>[];
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
      final existingIdentityId = importedIdentityFiles[resolvedPath];
      if (existingIdentityId != null) {
        identityIds.add(existingIdentityId);
        continue;
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

      final now = _now().toUtc();
      final identityId = IdentityId(_uuid.v4());
      final secretRecordId = VaultRecordId('secret:${identityId.value}');
      final envelope = await vault.encryptRecord(
        id: secretRecordId,
        type: 'identity_secret',
        plaintext: IdentitySecretMaterial(
          privateKeyPem: privateKeyPem,
        ).toBytes(),
      );
      await records.upsert(envelope);
      await identities.save(
        IdentityConfig(
          id: identityId,
          displayName: '$alias ${p.basename(resolvedPath)}',
          kind: IdentityKind.privateKey,
          usernameHint: username,
          secretRecordId: secretRecordId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      importedIdentityFiles[resolvedPath] = identityId;
      identityIds.add(identityId);
    }
    return List<IdentityId>.unmodifiable(identityIds);
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
