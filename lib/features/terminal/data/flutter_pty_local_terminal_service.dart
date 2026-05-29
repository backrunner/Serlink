import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

import '../../ssh/application/ssh_session_service.dart';
import '../application/local_terminal_service.dart';

typedef PtyFactory =
    Pty Function(
      String executable, {
      List<String> arguments,
      String? workingDirectory,
      Map<String, String>? environment,
      int rows,
      int columns,
    });

class FlutterPtyLocalTerminalService implements LocalTerminalService {
  const FlutterPtyLocalTerminalService({this.profileResolver, this.ptyFactory});

  final LocalShellProfile Function()? profileResolver;
  final PtyFactory? ptyFactory;

  @override
  Future<SshShellSession> openShell({int columns = 80, int rows = 24}) async {
    final profile = (profileResolver ?? defaultLocalShellProfile)();
    try {
      final pty = (ptyFactory ?? Pty.start)(
        profile.executable,
        arguments: profile.arguments,
        workingDirectory: profile.workingDirectory,
        environment: profile.environment,
        rows: rows,
        columns: columns,
      );
      return FlutterPtyShellSession(pty);
    } on LocalTerminalException {
      rethrow;
    } on Object catch (error) {
      throw LocalTerminalException(
        'local_terminal.start_failed',
        'Local terminal could not start: $error',
      );
    }
  }
}

class FlutterPtyShellSession implements SshShellSession {
  FlutterPtyShellSession(Pty pty) : _pty = pty;

  final Pty _pty;
  bool _closed = false;

  @override
  Future<void> get done => _pty.exitCode.then<void>((_) {});

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => _pty.output;

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _pty.kill(ProcessSignal.sighup);
    if (await _waitForExit(const Duration(milliseconds: 250))) {
      return;
    }
    _pty.kill(ProcessSignal.sigterm);
    if (await _waitForExit(const Duration(milliseconds: 250))) {
      return;
    }
    _pty.kill(ProcessSignal.sigkill);
    await _waitForExit(const Duration(milliseconds: 750));
  }

  Future<bool> _waitForExit(Duration timeout) async {
    try {
      await done.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    if (!_closed) {
      _pty.resize(rows, columns);
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!_closed) {
      _pty.write(Uint8List.fromList(bytes));
    }
  }
}
