import 'package:path/path.dart' as p;

import 'command_approval_scope.dart';

/// A user-approved group of recognizable project operations in one isolated
/// shell working directory. Ownership/lifetime belong to the agent session.
/// This checks literal paths, not remote symlinks or executable implementations;
/// it is an approval convenience for trusted projects, not a filesystem sandbox.
class CommandTaskScope {
  const CommandTaskScope._(this.directory);

  final String directory;

  static CommandTaskScope? fromCommand(String command, String? cwd) {
    if (cwd == null ||
        !p.posix.isAbsolute(cwd) ||
        p.posix.normalize(cwd) != cwd ||
        cwd.split('/').where((s) => s.isNotEmpty).length < 2 ||
        cwd.split('/').any((s) => s.startsWith('.')) ||
        {
          '/etc',
          '/dev',
          '/proc',
          '/sys',
          '/bin',
          '/sbin',
          '/usr',
          '/System',
          '/Library',
        }.any((root) => cwd == root || p.posix.isWithin(root, cwd))) {
      return null;
    }
    final scope = CommandTaskScope._(cwd);
    return scope.matches(command) ? scope : null;
  }

  bool matches(String command) {
    final steps = literalShellSteps(command);
    return steps != null &&
        steps.every(
          (step) => step.outputPaths.every(_within) && _accepts(step.words),
        );
  }

  bool _within(String path) {
    if (path.isEmpty || path == '-' || path.contains('~')) return false;
    // Do not authorize traversal, hidden/credential paths, or a root target.
    if (path
        .split('/')
        .any((part) => part == '..' || (part.startsWith('.') && part != '.'))) {
      return false;
    }
    final resolved = p.posix.normalize(
      p.posix.isAbsolute(path) ? path : p.posix.join(directory, path),
    );
    return resolved == directory || p.posix.isWithin(directory, resolved);
  }

  bool _accepts(List<String> words) {
    final executable = words.first.split('/').last;
    // Do not grant a project-local executable the privileges of a system tool.
    if (words.first != executable &&
        words.first != '/bin/$executable' &&
        words.first != '/usr/bin/$executable') {
      return false;
    }
    final args = words.skip(1).toList();
    if (isLiteralReadCommand(words)) {
      if (executable == 'git') {
        final index = gitSubcommandIndex(words);
        if (index == null ||
            !{
              'status',
              'diff',
              'log',
              'show',
              'ls-files',
              'ls-tree',
              'rev-parse',
              'rev-list',
            }.contains(words[index])) {
          return false;
        }
      }
      if (executable == 'echo' || executable == 'printf') return true;
      if (executable == 'pwd') return args.isEmpty;
      final options = _readOptions[executable];
      if (options == null) return false;
      // Unknown options can consume paths or delegate execution. Only explicit
      // options are eligible; every other operand must remain in the project.
      return args.every(
        (arg) => arg.startsWith('-') ? options.contains(arg) : _within(arg),
      );
    }
    final paths = literalFileWritePaths(words);
    return paths != null && paths.every(_within);
  }
}

/// All path operands of a small set of literal file operations. No recursive
/// copies, force flags, scripts, environment wrappers or custom executables.
/// For cp the last operand is the destination; all operands need task checks.
List<String>? literalFileWritePaths(List<String> words) {
  final executable = words.first.split('/').last;
  if (words.first != executable &&
      words.first != '/bin/$executable' &&
      words.first != '/usr/bin/$executable') {
    return null;
  }
  final options = _writeOptions[executable];
  if (options == null) return null;
  final paths = <String>[];
  var parseOptions = true;
  for (final arg in words.skip(1)) {
    if (parseOptions && arg == '--') {
      parseOptions = false;
    } else if (parseOptions && arg.startsWith('-')) {
      if (!options.contains(arg)) return null;
    } else {
      paths.add(arg);
    }
  }
  return paths.length >= (executable == 'cp' ? 2 : 1) ? paths : null;
}

const _writeOptions = {
  'cp': {'-n', '--no-clobber'},
  'mkdir': {'-p', '--parents'},
  'touch': <String>{},
  'tee': {'-a', '--append'},
};

const _readOptions = {
  'ls': {'--', '-a', '-l', '-la', '-al', '-h', '-lh', '-lah', '-1', '-d', '-R'},
  'cat': {'--', '-n', '-b', '-s', '-v', '-e', '-t'},
  'head': {'--', '-n', '-c', '-q', '-v'},
  'tail': {'--', '-n', '-c', '-q', '-v'},
  'wc': {'--', '-l', '-w', '-c', '-m', '-L'},
  'rg': {'--', '-n', '-i', '-l', '-w', '-x', '-F', '-e', '--files', '--count'},
  'grep': {'--', '-n', '-i', '-l', '-w', '-x', '-F', '-E', '-e', '-c'},
  'sed': {'-n'},
  'find': {
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
    '-print',
    '-print0',
    '-empty',
    '-readable',
    '-writable',
    '-executable',
  },
  'git': {
    '--',
    '-C',
    '--no-pager',
    '--literal-pathspecs',
    '--no-optional-locks',
    '--short',
    '-s',
    '--porcelain',
    '--name-only',
    '--stat',
    '--oneline',
  },
};
