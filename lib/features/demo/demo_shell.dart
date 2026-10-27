import 'dart:async';
import 'dart:convert';

import '../ssh/application/ssh_session_service.dart';
import 'demo_file_system.dart';

/// A small interactive shell simulator. It never invokes Process or a socket.
class DemoShell implements SshShellSession {
  DemoShell(this.files) {
    _output = StreamController<List<int>>(
      onListen: () {
        _emit(
          'Serlink offline demo — simulated terminal and SFTP\r\n'
          'Type help for commands. No connection to a real server.\r\n\r\n',
        );
        _prompt();
      },
    );
  }
  final DemoFileSystem files;
  late final StreamController<List<int>> _output;
  final Completer<void> _closed = Completer<void>();
  late final _decoder = utf8.decoder.startChunkedConversion(
    _DemoTextSink(_handle),
  );
  String _cwd = DemoFileSystem.home;
  String _line = '';
  String _escape = '';
  bool _lastWasCR = false;
  final List<String> _history = [];
  int _historyIndex = 0;
  @override
  Stream<List<int>> get stdout => _output.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<void> get done => _closed.future;
  void _emit(String text) {
    if (!_closed.isCompleted) _output.add(utf8.encode(text));
  }

  void _prompt() => _emit(
    'reviewer@offline-demo:${_cwd == DemoFileSystem.home ? '~' : _cwd}\$ ',
  );
  @override
  Future<void> write(List<int> bytes) async {
    if (!_closed.isCompleted) _decoder.add(bytes);
  }

  void _handle(String input) {
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      if (_escape.isNotEmpty) {
        _escape += char;
        if (_escape == '\x1b[') continue;
        if (_escape == '\x1b[A' || _escape == '\x1b[B') {
          _historyIndex = (_historyIndex + (_escape.endsWith('A') ? -1 : 1))
              .clamp(0, _history.length);
          _line = _historyIndex == _history.length
              ? ''
              : _history[_historyIndex];
          _emit('\r\x1b[2K');
          _prompt();
          _emit(_line);
        }
        _escape = '';
        continue;
      }
      if (rune == 27) {
        _escape = char;
        continue;
      }
      if (char == '\n' && _lastWasCR) {
        _lastWasCR = false;
        continue;
      }
      _lastWasCR = char == '\r';
      if (char == '\r' || char == '\n') {
        _emit('\r\n');
        final line = _line;
        _line = '';
        if (line.trim().isNotEmpty) {
          _history.add(line);
          _historyIndex = _history.length;
        }
        try {
          final result = run(line);
          if (result.isNotEmpty) {
            _emit('${result.replaceAll('\n', '\r\n')}\r\n');
          }
        } on Object catch (error) {
          _emit('demo: $error\r\n');
        }
        if (!_closed.isCompleted) _prompt();
      } else if (rune == 3) {
        _line = '';
        _emit('^C\r\n');
        _prompt();
      } else if (rune == 12) {
        _emit('\x1b[2J\x1b[H');
        _prompt();
        _emit(_line);
      } else if (rune == 127 || rune == 8) {
        if (_line.isNotEmpty) {
          _line = String.fromCharCodes(
            _line.runes.take(_line.runes.length - 1),
          );
          _emit('\b \b');
        }
      } else if (rune >= 32) {
        if (_line.length < 8192) {
          _line += char;
          _emit(char);
        }
      }
    }
  }

  String run(String command) {
    // Intentionally no shell expansion, subprocesses or network execution.
    final tokens = RegExp(r'''"([^"]*)"|'([^']*)'|(\S+)''')
        .allMatches(command)
        .map((m) => m[1] ?? m[2] ?? m[3]!)
        .toList();
    if (tokens.isEmpty) return '';
    final name = tokens.first;
    final args = tokens.skip(1).toList();
    String path([int index = 0]) =>
        files.resolve(args.length > index ? args[index] : '.', _cwd);
    switch (name) {
      case 'help':
        return 'Offline simulation commands:\nhelp, pwd, ls [-la] [path], cd [path], cat <file>, echo <text> [> file],\nmkdir <path>, touch <file>, mv <source> <target>, cp <source> <target>,\nrm [-r] <path>, whoami, hostname, uname, date, uptime, df, clear, exit\n\nSFTP supports preview/edit, folders, rename, permissions, upload and download.\nUse the private review-server details for real SSH and port forwarding.';
      case 'pwd':
        return _cwd;
      case 'whoami':
        return 'reviewer';
      case 'hostname':
        return 'offline-demo';
      case 'uname':
        return args.contains('-a')
            ? 'Linux offline-demo 6.8.0 x86_64 (simulated)'
            : 'Linux (simulated)';
      case 'date':
        return DateTime.now().toUtc().toIso8601String();
      case 'uptime':
        return 'up 2 days, 1 user, load average: 0.08, 0.05, 0.02 (simulated)';
      case 'df':
        return 'Filesystem     Size   Used  Available  Mounted on\ndemo-memory    16M    ${files.files.values.fold<int>(0, (n, b) => n + b.length)}B   (simulated) /';
      case 'clear':
        _emit('\x1b[2J\x1b[H');
        return '';
      case 'exit':
        unawaited(close());
        return '';
      case 'cd':
        final next = args.isEmpty || args.first == '~'
            ? DemoFileSystem.home
            : path();
        if (!files.directories.contains(next)) return 'cd: no such directory';
        _cwd = next;
        return '';
      case 'ls':
        final destination =
            args.where((a) => !a.startsWith('-')).firstOrNull ?? '.';
        final entries = files.list(files.resolve(destination, _cwd));
        return entries
            .where(
              (e) =>
                  !e.isHidden ||
                  args.any((a) => a.startsWith('-') && a.contains('a')),
            )
            .map(
              (e) => args.any((a) => a.startsWith('-') && a.contains('l'))
                  ? '${e.type.name == 'directory' ? 'd' : '-'}${e.permissions?.symbolic ?? 'rw-r--r--'} reviewer reviewer ${e.size} ${e.name}'
                  : '${e.name}${e.type.name == 'directory' ? '/' : ''}',
            )
            .join('\n');
      case 'cat':
        return utf8
            .decode(files.read(path()), allowMalformed: true)
            .trimRight();
      case 'echo':
        final redirect = args.indexOf('>');
        if (redirect >= 0 && redirect + 1 < args.length) {
          files.write(
            files.resolve(args[redirect + 1], _cwd),
            utf8.encode('${args.take(redirect).join(' ')}\n'),
          );
          return '';
        }
        return args.join(' ');
      case 'mkdir':
        if (args.isEmpty) return 'usage: mkdir <path>';
        files.mkdir(path());
        return '';
      case 'touch':
        if (args.isEmpty) return 'usage: touch <path>';
        files.write(path(), files.files[path()] ?? []);
        return '';
      case 'mv':
        if (args.length != 2) return 'usage: mv <source> <target>';
        files.rename(path(), path(1));
        return '';
      case 'cp':
        if (args.length != 2) return 'usage: cp <source> <target>';
        files.write(path(1), files.read(path()));
        return '';
      case 'rm':
        final targets = args.where((a) => !a.startsWith('-')).toList();
        if (targets.isEmpty) return 'usage: rm [-r] <path>';
        for (final target in targets) {
          files.remove(
            files.resolve(target, _cwd),
            recursive: args.any((a) => a.startsWith('-') && a.contains('r')),
          );
        }
        return '';
      default:
        return '$name: unavailable in the offline simulator. Type help or use the real review server.';
    }
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {}
  @override
  Future<void> close() async {
    if (_closed.isCompleted) return;
    _closed.complete();
    unawaited(_output.close());
  }
}

class _DemoTextSink implements Sink<String> {
  _DemoTextSink(this.callback);
  final void Function(String) callback;
  @override
  void add(String data) => callback(data);
  @override
  void close() {}
}
