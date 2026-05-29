import 'dart:async';
import 'dart:convert';

import 'package:xterm/xterm.dart';

import '../../ssh/application/ssh_session_service.dart';
import 'terminal_paste_guard.dart';

class TerminalAdapter {
  TerminalAdapter({
    required Terminal terminal,
    required SshShellSession session,
    MultilinePasteConfirmation? confirmMultilinePaste,
  }) : this._(
         terminal,
         session,
         TerminalPasteGuard(confirmMultilinePaste: confirmMultilinePaste),
       );

  TerminalAdapter._(this._terminal, this._session, this._pasteGuard);

  final Terminal _terminal;
  final SshShellSession _session;
  final TerminalPasteGuard _pasteGuard;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  final StringBuffer _pendingTerminalWrite = StringBuffer();
  Timer? _terminalWriteTimer;
  void Function(String data)? _previousOutput;
  void Function(int width, int height, int pixelWidth, int pixelHeight)?
  _previousResize;
  bool _attached = false;

  void attach() {
    if (_attached) {
      return;
    }
    _attached = true;
    _previousOutput = _terminal.onOutput;
    _previousResize = _terminal.onResize;

    _terminal.onOutput = (data) {
      unawaited(_handleOutput(data));
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      unawaited(
        _session.resize(
          columns: width,
          rows: height,
          pixelWidth: pixelWidth,
          pixelHeight: pixelHeight,
        ),
      );
      _previousResize?.call(width, height, pixelWidth, pixelHeight);
    };

    _stdoutSubscription = _session.stdout.listen(_writeBytesToTerminal);
    _stderrSubscription = _session.stderr.listen(_writeBytesToTerminal);
  }

  Future<void> resize({
    required int columns,
    required int rows,
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) async {
    _terminal.resize(columns, rows, pixelWidth, pixelHeight);
  }

  void sendInput(String data) {
    if (!_attached) {
      return;
    }
    unawaited(_session.write(utf8.encode(data)));
  }

  Future<void> close() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _flushPendingTerminalWrite();
    if (_attached) {
      _terminal.onOutput = _previousOutput;
      _terminal.onResize = _previousResize;
      _attached = false;
    }
    await _session.close();
  }

  Future<void> _handleOutput(String data) async {
    if (!await _pasteGuard.allow(data) || !_attached) {
      return;
    }
    await _session.write(utf8.encode(data));
    if (_attached) {
      _previousOutput?.call(data);
    }
  }

  void _writeBytesToTerminal(List<int> bytes) {
    if (!_attached) {
      return;
    }
    _pendingTerminalWrite.write(utf8.decode(bytes, allowMalformed: true));
    _terminalWriteTimer ??= Timer(Duration.zero, _flushPendingTerminalWrite);
  }

  void _flushPendingTerminalWrite() {
    _terminalWriteTimer?.cancel();
    _terminalWriteTimer = null;
    if (!_attached || _pendingTerminalWrite.isEmpty) {
      _pendingTerminalWrite.clear();
      return;
    }
    final text = _pendingTerminalWrite.toString();
    _pendingTerminalWrite.clear();
    _terminal.write(text);
  }
}
