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

part 'open_ssh_config_import_parser.dart';
part 'open_ssh_config_import_models.dart';
part 'open_ssh_config_identity_import.dart';

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
