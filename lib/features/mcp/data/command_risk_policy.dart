import '../domain/command_risk.dart';

/// Assesses the risk of shell commands an MCP agent wants to run.
///
/// This is deliberately NOT a full shell parser. Commands are normalized
/// (trimmed, whitespace collapsed) and matched against an ordered list of
/// rules; the first matching rule wins. It does not resolve variables,
/// aliases, quotes, command substitution, or escaping tricks, so it must be
/// treated as a safety net layered on top of user confirmation, not as a
/// sandbox.
///
/// Rule order: [additionalSafePatterns] (session allowlist) first, then
/// blocked rules, then needsConfirm rules. Anything unmatched is safe.
class CommandRiskPolicy {
  CommandRiskPolicy({List<RegExp> additionalSafePatterns = const []})
    : additionalSafePatterns = List.unmodifiable(additionalSafePatterns);

  /// Per-session allowlist: commands matching any of these are assessed
  /// [CommandRiskLevel.safe] before any other rule is considered.
  final List<RegExp> additionalSafePatterns;

  CommandRiskAssessment assess(String command) {
    final normalized = command.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return CommandRiskAssessment(
        level: CommandRiskLevel.safe,
        command: command,
      );
    }
    for (final pattern in additionalSafePatterns) {
      if (pattern.hasMatch(normalized)) {
        return CommandRiskAssessment(
          level: CommandRiskLevel.safe,
          command: command,
        );
      }
    }
    for (final rule in _rules) {
      if (rule.matches(normalized)) {
        return CommandRiskAssessment(
          level: rule.level,
          matchedRule: rule.id,
          command: command,
        );
      }
    }
    return CommandRiskAssessment(level: CommandRiskLevel.safe, command: command);
  }
}

class _Rule {
  const _Rule(this.id, this.level, this._matcher);

  final String id;
  final CommandRiskLevel level;
  final bool Function(String command) _matcher;

  bool matches(String command) => _matcher(command);

  static _Rule regex(String id, CommandRiskLevel level, String pattern) {
    final regex = RegExp(pattern);
    return _Rule(id, level, regex.hasMatch);
  }
}

// Matched against the normalized command (trimmed, whitespace collapsed).
// Blocked rules come first; the first matching rule decides the outcome.
final List<_Rule> _rules = [
  // --- Blocked: never allowed, no user override. ---
  _Rule.regex(
    'dd_to_disk_device',
    CommandRiskLevel.blocked,
    r'\bdd\b[^|;&]*\bof=/dev/(rdisk|sd|nvme|disk|hd|mmcblk)',
  ),
  _Rule.regex(
    'redirect_to_disk_device',
    CommandRiskLevel.blocked,
    r'>\s*/dev/(rdisk|sd|nvme|disk|hd|mmcblk)',
  ),
  _Rule.regex(
    'mkfs',
    CommandRiskLevel.blocked,
    r'\bmkfs(\.\w+)?\b',
  ),
  _Rule.regex(
    'fork_bomb',
    CommandRiskLevel.blocked,
    r':\(\)\s*\{\s*:\|:&\s*\}\s*;\s*:',
  ),

  // --- Needs confirmation. ---
  _Rule('rm_recursive_force', CommandRiskLevel.needsConfirm, _isRmRecursiveForce),
  _Rule.regex(
    'system_power',
    CommandRiskLevel.needsConfirm,
    r'\b(shutdown|reboot|halt|poweroff)\b|\binit\s+[06]\b',
  ),
  _Rule(
    'recursive_perm_change_on_system_dir',
    CommandRiskLevel.needsConfirm,
    _isRecursivePermChangeOnSystemDir,
  ),
  _Rule.regex(
    'kill_all',
    CommandRiskLevel.needsConfirm,
    r'\bkill\s+(-9\s+-1|-1\s+-9)\b|\bkillall\b[^|;&]*\s-9\b',
  ),
  _Rule.regex(
    'pipe_remote_content_to_shell',
    CommandRiskLevel.needsConfirm,
    r'\b(curl|wget)\b[^|]*\|\s*(sudo\s+)?(sh|bash|zsh|dash|ksh|fish|python\d*|perl|ruby)\b',
  ),
  _Rule.regex(
    'dd_general',
    CommandRiskLevel.needsConfirm,
    r'\bdd\b',
  ),
  _Rule.regex(
    'eval_remote_content',
    CommandRiskLevel.needsConfirm,
    r'\beval\b[^|;&]*\$\(\s*(curl|wget)\b|>\([^)]*\)',
  ),
  _Rule.regex(
    'git_push_force',
    CommandRiskLevel.needsConfirm,
    r'\bgit\s+push\b[^|;&]*(--force\b|-f\b|--force-with-lease\b)',
  ),
  _Rule.regex(
    'overwrite_shell_config',
    CommandRiskLevel.needsConfirm,
    r'(^|[^>])>\s*(~?/[\w./-]*)?\.(bashrc|zshrc|bash_profile|bash_login|zprofile|profile)\b',
  ),
  _Rule.regex(
    'user_account_change',
    CommandRiskLevel.needsConfirm,
    r'\b(useradd|userdel|usermod|passwd)\b',
  ),
  _Rule.regex(
    'iptables_flush',
    CommandRiskLevel.needsConfirm,
    r'\biptables\b[^|;&]*\s-F\b',
  ),
  _Rule.regex(
    'systemctl_destructive',
    CommandRiskLevel.needsConfirm,
    r'\bsystemctl\s+(stop|disable|mask)\b',
  ),
  _Rule.regex(
    'crontab_remove',
    CommandRiskLevel.needsConfirm,
    r'\bcrontab\s+-[\w-]*r\b',
  ),
];

bool _isRmRecursiveForce(String command) {
  final match = RegExp(r'\brm\s+([^|;&]*)').firstMatch(command);
  if (match == null) {
    return false;
  }
  var recursive = false;
  var force = false;
  for (final flagMatch in RegExp(r'--?[\w-]+').allMatches(match.group(1)!)) {
    final flag = flagMatch.group(0)!;
    if (flag.startsWith('--')) {
      if (flag == '--recursive') {
        recursive = true;
      } else if (flag == '--force') {
        force = true;
      }
    } else {
      if (flag.contains('r') || flag.contains('R')) {
        recursive = true;
      }
      if (flag.contains('f')) {
        force = true;
      }
    }
  }
  return recursive && force;
}

bool _isRecursivePermChangeOnSystemDir(String command) {
  final match = RegExp(r'\b(?:chmod|chown)\s+([^|;&]*)').firstMatch(command);
  if (match == null) {
    return false;
  }
  final args = match.group(1)!;
  if (!RegExp(r'(^|\s)-[\w-]*R[\w-]*(\s|$)').hasMatch(args)) {
    return false;
  }
  const systemDirs = [
    '/',
    '/etc',
    '/usr',
    '/bin',
    '/sbin',
    '/var',
    '/boot',
    '/lib',
    '/lib64',
    '/opt',
    '/System',
  ];
  for (final token in args.split(' ')) {
    if (token.isEmpty || token.startsWith('-')) {
      continue;
    }
    // Skip permission/mode arguments such as 755 or u+x.
    if (RegExp(r'^[0-7]{3,4}$').hasMatch(token) ||
        RegExp(r'^[ugoa]*[+=-][rwxXst]+$').hasMatch(token)) {
      continue;
    }
    for (final dir in systemDirs) {
      if (token == dir || (dir != '/' && token.startsWith('$dir/'))) {
        return true;
      }
    }
  }
  return false;
}
