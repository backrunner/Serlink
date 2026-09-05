import 'dart:convert';
import 'dart:io';

/// How the Serlink MCP entry looks inside one agent's config file.
enum AgentConfigStatus {
  /// No `serlink` entry yet.
  notInstalled,

  /// A `serlink` entry exists and points at the current helper/path.
  installed,

  /// A `serlink` entry exists but with stale content (e.g. an old path).
  outdated,
}

/// One supported agent CLI/tool whose MCP client config Serlink can write.
enum AgentConfigKind { json, toml }

class AgentConfigTarget {
  const AgentConfigTarget({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.configPath,
    required this.markerDirectory,
    this.serversKey = 'mcpServers',
    required this.buildEntry,
  });

  final String id;
  final String displayName;
  final AgentConfigKind kind;

  /// Absolute path of the agent's MCP config file.
  final String configPath;

  /// Directory the agent creates once installed; used for detection when the
  /// config file does not exist yet.
  final String markerDirectory;

  /// JSON key holding the server map (`mcpServers` for most agents, `mcp`
  /// for opencode). Ignored for TOML targets.
  final String serversKey;

  /// The Serlink MCP entry for this agent's config format.
  final Map<String, Object?> Function(String helperPath) buildEntry;
}

/// Thrown when an existing config file cannot be merged safely (e.g. it is
/// not valid JSON). The file is left untouched.
class AgentConfigInstallException implements Exception {
  const AgentConfigInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Writes the Serlink MCP server entry into the config files of agent tools
/// already installed on the machine (direct/DMG builds only; sandboxed App
/// Store builds cannot touch other apps' config files).
///
/// Supported agents and their config formats:
/// - Claude Code: `~/.claude.json` (`mcpServers`)
/// - Cursor: `~/.cursor/mcp.json` (`mcpServers`)
/// - Windsurf: `~/.codeium/windsurf/mcp_config.json` (`mcpServers`)
/// - Codex: `~/.codex/config.toml` (`[mcp_servers.serlink]`)
class AgentConfigInstaller {
  AgentConfigInstaller({String? homeDirectory})
    : _homeDirectory =
          homeDirectory ?? Platform.environment['HOME'] ?? '';

  final String _homeDirectory;

  static Map<String, Object?> _typedStdioEntry(String helperPath) {
    return {'type': 'stdio', 'command': helperPath};
  }

  static Map<String, Object?> _plainStdioEntry(String helperPath) {
    return {'command': helperPath};
  }

  static Map<String, Object?> _opencodeEntry(String helperPath) {
    return {
      'type': 'local',
      'command': [helperPath],
      'enabled': true,
    };
  }

  /// All known agent config locations, whether or not the agent is present.
  List<AgentConfigTarget> get knownTargets {
    final home = _homeDirectory;
    if (home.isEmpty) {
      return const [];
    }
    return [
      AgentConfigTarget(
        id: 'claude-code',
        displayName: 'Claude Code',
        kind: AgentConfigKind.json,
        configPath: '$home/.claude.json',
        markerDirectory: '$home/.claude',
        buildEntry: _typedStdioEntry,
      ),
      AgentConfigTarget(
        id: 'cursor',
        displayName: 'Cursor',
        kind: AgentConfigKind.json,
        configPath: '$home/.cursor/mcp.json',
        markerDirectory: '$home/.cursor',
        buildEntry: _typedStdioEntry,
      ),
      AgentConfigTarget(
        id: 'windsurf',
        displayName: 'Windsurf',
        kind: AgentConfigKind.json,
        configPath: '$home/.codeium/windsurf/mcp_config.json',
        markerDirectory: '$home/.codeium/windsurf',
        buildEntry: _typedStdioEntry,
      ),
      AgentConfigTarget(
        id: 'kimi-code',
        displayName: 'Kimi Code',
        kind: AgentConfigKind.json,
        configPath: '$home/.kimi-code/mcp.json',
        markerDirectory: '$home/.kimi-code',
        buildEntry: _plainStdioEntry,
      ),
      AgentConfigTarget(
        id: 'opencode',
        displayName: 'opencode',
        kind: AgentConfigKind.json,
        configPath: '$home/.config/opencode/opencode.json',
        markerDirectory: '$home/.config/opencode',
        serversKey: 'mcp',
        buildEntry: _opencodeEntry,
      ),
      AgentConfigTarget(
        id: 'codex',
        displayName: 'Codex',
        kind: AgentConfigKind.toml,
        configPath: '$home/.codex/config.toml',
        markerDirectory: '$home/.codex',
        buildEntry: _typedStdioEntry,
      ),
    ];
  }

  /// Targets whose agent appears to be installed: the config file exists, or
  /// the agent's own directory does (the tool has been set up but has no MCP
  /// config yet).
  List<AgentConfigTarget> detectInstalledAgents() {
    return [
      for (final target in knownTargets)
        if (File(target.configPath).existsSync() ||
            Directory(target.markerDirectory).existsSync())
          target,
    ];
  }

  AgentConfigStatus statusFor(
    AgentConfigTarget target, {
    required String helperPath,
  }) {
    final file = File(target.configPath);
    if (!file.existsSync()) {
      return AgentConfigStatus.notInstalled;
    }
    final content = file.readAsStringSync();
    return switch (target.kind) {
      AgentConfigKind.json => _jsonStatus(target, content, helperPath),
      AgentConfigKind.toml => _tomlStatus(content, helperPath),
    };
  }

  /// Merges the stdio MCP entry pointing at [helperPath] into the target's
  /// config file, creating the file (and parent directories) when missing.
  /// The previous content is backed up to `<config>.serlink-backup` on the
  /// first write.
  Future<void> install(
    AgentConfigTarget target, {
    required String helperPath,
  }) async {
    final file = File(target.configPath);
    await file.parent.create(recursive: true);
    final existed = file.existsSync();
    final previous = existed ? await file.readAsString() : '';
    if (existed) {
      final backup = File('${target.configPath}.serlink-backup');
      if (!backup.existsSync()) {
        await backup.writeAsString(previous);
      }
    }
    final next = switch (target.kind) {
      AgentConfigKind.json => _mergeJson(target, previous, helperPath),
      AgentConfigKind.toml => _mergeToml(previous, helperPath),
    };
    // Write-then-rename so readers never observe a truncated config, even if
    // two installs race.
    final temp = File('${target.configPath}.serlink-tmp');
    await temp.writeAsString(next);
    await temp.rename(target.configPath);
  }

  AgentConfigStatus _jsonStatus(
    AgentConfigTarget target,
    String content,
    String helperPath,
  ) {
    Object? decoded;
    try {
      decoded = content.trim().isEmpty ? null : jsonDecode(content);
    } on Object {
      // Unreadable config: treat as not installed so the UI offers a write,
      // which will surface the parse error on attempt.
      return AgentConfigStatus.notInstalled;
    }
    if (decoded is! Map<String, Object?>) {
      return AgentConfigStatus.notInstalled;
    }
    final servers = decoded[target.serversKey];
    if (servers is! Map<String, Object?>) {
      return AgentConfigStatus.notInstalled;
    }
    final entry = servers['serlink'];
    if (entry is! Map<String, Object?>) {
      return AgentConfigStatus.notInstalled;
    }
    return _canonicalJson(entry) == _canonicalJson(target.buildEntry(helperPath))
        ? AgentConfigStatus.installed
        : AgentConfigStatus.outdated;
  }

  /// JSON encoding with recursively sorted keys, so two entries compare equal
  /// regardless of key order.
  static String _canonicalJson(Object? value) {
    return jsonEncode(switch (value) {
      final Map<String, Object?> map => {
        for (final key in map.keys.toList()..sort())
          key: switch (map[key]) {
            final Map<String, Object?> child => jsonDecode(
              _canonicalJson(child),
            ),
            final List<Object?> list => [
              for (final item in list)
                item is Map<String, Object?>
                    ? jsonDecode(_canonicalJson(item))
                    : item,
            ],
            final other => other,
          },
      },
      final other => other,
    });
  }
  AgentConfigStatus _tomlStatus(String content, String helperPath) {
    final section = _tomlSection(content);
    if (section == null) {
      return AgentConfigStatus.notInstalled;
    }
    final commandPattern = RegExp(
      '''^command\\s*=\\s*["']${RegExp.escape(helperPath)}["']\\s*\$''',
      multiLine: true,
    );
    return commandPattern.hasMatch(section)
        ? AgentConfigStatus.installed
        : AgentConfigStatus.outdated;
  }

  String _mergeJson(
    AgentConfigTarget target,
    String previous,
    String helperPath,
  ) {
    Map<String, Object?> root;
    if (previous.trim().isEmpty) {
      root = <String, Object?>{};
    } else {
      final decoded = jsonDecode(previous);
      if (decoded is! Map<String, Object?>) {
        throw const AgentConfigInstallException(
          'Config file is not a JSON object.',
        );
      }
      root = Map<String, Object?>.from(decoded);
    }
    final servers = root[target.serversKey];
    final mergedServers = servers is Map<String, Object?>
        ? Map<String, Object?>.from(servers)
        : <String, Object?>{};
    mergedServers['serlink'] = target.buildEntry(helperPath);
    root[target.serversKey] = mergedServers;
    return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
  }

  static final RegExp _tomlSectionHeader = RegExp(
    r'^\[mcp_servers\.serlink\]\s*$',
    multiLine: true,
  );

  /// Returns the body of the `[mcp_servers.serlink]` TOML section, or null
  /// when the section is absent.
  String? _tomlSection(String content) {
    final header = _tomlSectionHeader.firstMatch(content);
    if (header == null) {
      return null;
    }
    final rest = content.substring(header.end);
    final nextHeader = RegExp(r'^\[', multiLine: true).firstMatch(rest);
    return nextHeader == null ? rest : rest.substring(0, nextHeader.start);
  }

  String _mergeToml(String previous, String helperPath) {
    final section =
        '[mcp_servers.serlink]\ncommand = "$helperPath"\n';
    final header = _tomlSectionHeader.firstMatch(previous);
    if (header == null) {
      final separator = previous.trim().isEmpty
          ? ''
          : previous.endsWith('\n')
          ? '\n'
          : '\n\n';
      return '$previous$separator$section';
    }
    final rest = previous.substring(header.end);
    final nextHeader = RegExp(r'^\[', multiLine: true).firstMatch(rest);
    final before = previous.substring(0, header.start);
    final after = nextHeader == null ? '' : rest.substring(nextHeader.start);
    final buffer = StringBuffer(before.trimRight());
    if (buffer.isNotEmpty) {
      buffer.write('\n\n');
    }
    buffer.write(section);
    if (after.trim().isNotEmpty) {
      buffer.write('\n$after');
    }
    return buffer.toString();
  }
}
