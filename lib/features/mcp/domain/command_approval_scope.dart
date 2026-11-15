/// A shell argv prefix, never a substring or a regular expression. Only used
/// after local risk rules and the optional decision model have passed.
class CommandApprovalScope {
  CommandApprovalScope._(this.words, {required this.exact});

  final List<String> words;
  final bool exact;

  String get label => '${words.map(_quote).join(' ')}${exact ? '' : ' …'}';

  bool matches(String command) {
    final commands = literalShellCommands(command);
    if (commands == null || commands.length != 1) return false;
    final candidate = commands.single;
    return (exact
            ? candidate.length == words.length
            : candidate.length >= words.length) &&
        List.generate(
          words.length,
          (i) => candidate[i] == words[i],
        ).every((v) => v);
  }

  static CommandApprovalScope? fromCommand(String command) {
    final commands = literalShellCommands(command);
    if (commands == null || commands.length != 1) return null;
    final words = commands.single;
    final executable = words.first.split('/').last;
    if (words.first.contains('=') ||
        {
          'sudo',
          'env',
          'command',
          'builtin',
          'exec',
          'eval',
          'source',
          '.',
        }.contains(executable)) {
      return null;
    }
    final gitIndex = gitSubcommandIndex(words);
    if (executable == 'git' && gitIndex != null) {
      // Branch creation has a different scope from worktree checkout/restore.
      final create = {'checkout', 'switch'}.contains(words[gitIndex]);
      return CommandApprovalScope._(
        List.unmodifiable(words.take(create ? words.length : gitIndex + 1)),
        exact: create,
      );
    }
    if (_knownPath(words.first) && _argumentOnlyTools.contains(executable)) {
      return CommandApprovalScope._(
        List.unmodifiable(words.take(1)),
        exact: false,
      );
    }
    if ({
          'cargo',
          'docker',
          'podman',
          'kubectl',
          'systemctl',
          'npm',
          'pnpm',
          'yarn',
          'go',
          'flutter',
          'dart',
        }.contains(executable) &&
        words.length > 1 &&
        !words[1].startsWith('-')) {
      final length =
          {'npm', 'pnpm', 'yarn'}.contains(executable) && words[1] == 'run'
          ? (words.length > 2 ? 3 : words.length)
          : 2;
      return CommandApprovalScope._(
        List.unmodifiable(words.take(length)),
        exact: false,
      );
    }
    // Unknown programs receive an exact argv grant, never a broad executable grant.
    return CommandApprovalScope._(List.unmodifiable(words), exact: true);
  }

  static String _quote(String word) =>
      RegExp(r'^[a-zA-Z0-9_./:@%+=,-]+$').hasMatch(word)
      ? word
      : "'${word.replaceAll("'", "'\\''")}'";
}

const _argumentOnlyTools = {
  'ls',
  'pwd',
  'cat',
  'head',
  'tail',
  'wc',
  'rg',
  'grep',
  'egrep',
  'fgrep',
  'echo',
  'printf',
  'cut',
  'tr',
  'du',
  'df',
  'stat',
  'which',
  'type',
  'uname',
  'id',
  'whoami',
  'ps',
  'lsof',
  'readlink',
  'realpath',
};

bool _knownPath(String command) =>
    !command.split('/').any((part) => part == '.' || part == '..') &&
    (!command.contains('/') ||
        command.startsWith('/bin/') ||
        command.startsWith('/usr/bin/') ||
        command.startsWith('/usr/local/bin/') ||
        command.startsWith('/opt/homebrew/bin/'));

bool isLiteralReadCommand(List<String> words) {
  final executable = words.first.split('/').last;
  if (!_knownPath(words.first)) return false;
  if (executable == 'sed') {
    // Only a print address, never sed's e/w commands or a script file.
    return words.length >= 3 &&
        words[1] == '-n' &&
        RegExp(r'^(?:[0-9]+|\$)?(?:,(?:[0-9]+|\$))?p$').hasMatch(words[2]) &&
        words.skip(3).every((w) => !w.startsWith('-'));
  }
  if (executable == 'find') return _isLiteralFind(words);
  if (executable == 'printf' &&
      words.skip(1).any((w) => w == '-v' || w.startsWith('-v'))) {
    return false;
  }
  if (_argumentOnlyTools.contains(executable)) {
    // ripgrep can delegate preprocessing to an arbitrary executable.
    return executable != 'rg' ||
        !words.any(
          (w) =>
              w == '--pre' ||
              w.startsWith('--pre=') ||
              w == '--hostname-bin' ||
              w.startsWith('--hostname-bin='),
        );
  }
  if (executable != 'git') return false;
  final index = gitSubcommandIndex(words);
  if (index == null) return false;
  final subcommand = words[index];
  final args = words.skip(index + 1).toList();
  if (words.any(
    (w) =>
        w == '--ext-diff' ||
        w == '--textconv' ||
        w == '--output' ||
        w.startsWith('--output=') ||
        w == '--exec' ||
        w.startsWith('--exec='),
  )) {
    return false;
  }
  if ({
    'status',
    'diff',
    'log',
    'show',
    'ls-files',
    'ls-tree',
    'rev-parse',
    'rev-list',
  }.contains(subcommand)) {
    return true;
  }
  if ((subcommand == 'checkout' && args.firstOrNull == '-b') ||
      (subcommand == 'switch' && args.firstOrNull == '-c')) {
    return args.length >= 2 &&
        args.length <= 3 &&
        args.skip(1).every((w) => !w.startsWith('-'));
  }
  return subcommand == 'restore' &&
      args.contains('--staged') &&
      !args.any(
        (w) =>
            w == '--worktree' ||
            (w.startsWith('-') && !w.startsWith('--') && w.contains('W')),
      );
}

bool _isLiteralFind(List<String> words) {
  var expression = false;
  for (var i = 1; i < words.length; i++) {
    final word = words[i];
    if ({
      '-name',
      '-iname',
      '-path',
      '-ipath',
      '-type',
      '-maxdepth',
      '-mindepth',
      '-size',
      '-mtime',
      '-mmin',
      '-user',
      '-group',
    }.contains(word)) {
      expression = true;
      if (++i >= words.length) return false;
    } else if ({
      '-print',
      '-print0',
      '-empty',
      '-readable',
      '-writable',
      '-executable',
    }.contains(word)) {
      expression = true;
    } else if (word.startsWith('-') || expression) {
      return false;
    }
  }
  return true;
}

/// These explicit flags make replacement impossible without inspecting remote
/// filesystem state (which could change between inspection and execution).
bool isLiteralNonClobberCopy(List<String> words) {
  if (!_knownPath(words.first) || words.first.split('/').last != 'cp') {
    return false;
  }
  var noClobber = false;
  var options = true;
  var paths = 0;
  for (final word in words.skip(1)) {
    if (options && word == '--') {
      options = false;
    } else if (options && {'-n', '--no-clobber'}.contains(word)) {
      noClobber = true;
    } else if (options && word.startsWith('-')) {
      return false;
    } else {
      paths++;
    }
  }
  return noClobber && paths >= 2;
}

/// Recognize only explicit, literal git globals. Preserve -C and its path in
/// the displayed grant so another repository cannot inherit this scope.
int? gitSubcommandIndex(List<String> words) {
  if (words.first.split('/').last != 'git') return null;
  var index = 1;
  while (index < words.length) {
    if ({
      '--no-pager',
      '--literal-pathspecs',
      '--no-optional-locks',
    }.contains(words[index])) {
      index++;
    } else if (words[index] == '-C' && index + 1 < words.length) {
      index += 2;
    } else {
      return words[index].startsWith('-') ? null : index;
    }
  }
  return null;
}

/// A deliberately bounded lexer for literal simple commands. Expansions,
/// redirections, subshells, comments and background execution return null and
/// retain conservative approval behavior. Quoted arguments stay data.
List<List<String>>? literalShellCommands(String source) {
  final steps = literalShellSteps(source);
  if (steps == null || steps.any((step) => step.outputPaths.isNotEmpty)) {
    return null;
  }
  return steps.map((step) => step.words).toList();
}

class LiteralShellStep {
  LiteralShellStep(List<String> words, List<String> outputPaths)
    : words = List.unmodifiable(words),
      outputPaths = List.unmodifiable(outputPaths);

  final List<String> words;
  final List<String> outputPaths;
}

/// As above, additionally representing literal stdout > and >> targets.
/// Input redirection, fd redirection and all expansions remain unsupported.
List<LiteralShellStep>? literalShellSteps(String source) {
  final commands = <LiteralShellStep>[];
  var words = <String>[];
  var outputPaths = <String>[];
  var needsOutputPath = false;
  var word = StringBuffer();
  var active = false;
  String? quote;
  void finishWord() {
    if (active) {
      if (needsOutputPath) {
        outputPaths.add(word.toString());
        needsOutputPath = false;
      } else {
        words.add(word.toString());
      }
    }
    word = StringBuffer();
    active = false;
  }

  void finishCommand() {
    finishWord();
    if (words.isNotEmpty) commands.add(LiteralShellStep(words, outputPaths));
    words = <String>[];
    outputPaths = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (quote == "'") {
      if (c == "'") {
        quote = null;
      } else {
        word.write(c);
      }
      continue;
    }
    if (c == r'\') {
      if (++i >= source.length) return null;
      final next = source[i];
      if (next == '\n') continue;
      if (quote == '"' && !['"', r'$', r'\', '`'].contains(next)) {
        word.write(r'\');
      }
      word.write(next);
      active = true;
      continue;
    }
    if (c == r'$' || c == '`') return null;
    if (quote == '"') {
      if (c == '"') {
        quote = null;
      } else {
        word.write(c);
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      active = true;
      continue;
    }
    if (' \t\r'.contains(c)) {
      finishWord();
      continue;
    }
    if (c == '\n' || c == ';' || c == '|') {
      finishWord();
      if (needsOutputPath) return null;
      if (i + 1 < source.length && source[i + 1] == c && c == '|') i++;
      finishCommand();
      continue;
    }
    if (c == '&') {
      finishWord();
      if (needsOutputPath) return null;
      if (i + 1 >= source.length || source[i + 1] != '&') return null;
      i++;
      finishCommand();
      continue;
    }
    if (c == '>') {
      // Only a distinct stdout operator; do not reinterpret 2> as stdout.
      if (active || needsOutputPath || words.isEmpty) return null;
      if (i + 1 < source.length && source[i + 1] == '>') i++;
      needsOutputPath = true;
      continue;
    }
    if ('<(){}*?[]!'.contains(c) || (c == '#' && !active)) return null;
    word.write(c);
    active = true;
  }
  if (quote != null) return null;
  finishWord();
  if (needsOutputPath) return null;
  finishCommand();
  if (commands.isEmpty || commands.any((step) => step.words.first.isEmpty)) {
    return null;
  }
  return commands;
}
