part of 'open_ssh_config_import_service.dart';

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
