import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:xterm/xterm.dart';

import '../../ssh/application/ssh_session_service.dart';
import 'terminal_paste_guard.dart';
import 'terminal_zmodem_transfer.dart';

typedef _TerminalResize = ({
  int columns,
  int rows,
  int pixelWidth,
  int pixelHeight,
});

class TerminalAdapter {
  TerminalAdapter({
    required Terminal terminal,
    required SshShellSession session,
    MultilinePasteConfirmation? confirmMultilinePaste,
    TerminalZModemTransferHandler? zmodemTransferHandler,
  }) : this._(
         terminal,
         session,
         TerminalPasteGuard(confirmMultilinePaste: confirmMultilinePaste),
         zmodemTransferHandler,
       );

  TerminalAdapter._(
    this._terminal,
    this._session,
    this._pasteGuard,
    this._zmodemTransferHandler,
  );

  final Terminal _terminal;
  final SshShellSession _session;
  final TerminalPasteGuard _pasteGuard;
  final TerminalZModemTransferHandler? _zmodemTransferHandler;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  ZModemMux? _zmodemMux;
  _SshShellSessionSink? _zmodemStdin;
  final StringBuffer _pendingTerminalWrite = StringBuffer();
  Timer? _terminalWriteTimer;
  Timer? _resizeTimer;
  _TerminalResize? _pendingResize;
  _TerminalResize? _lastSentResize;
  void Function(String data)? _previousOutput;
  void Function(int width, int height, int pixelWidth, int pixelHeight)?
  _previousResize;
  bool _attached = false;
  static const _defaultColumns = 80;
  static const _defaultRows = 24;
  static const _resizeDebounceDuration = Duration(milliseconds: 80);

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
      _scheduleResize(
        columns: width,
        rows: height,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      );
      _previousResize?.call(width, height, pixelWidth, pixelHeight);
    };

    if (_zmodemTransferHandler == null) {
      _stdoutSubscription = _session.stdout.listen(_writeBytesToTerminal);
    } else {
      _attachZModemMux();
    }
    _stderrSubscription = _session.stderr.listen(_writeBytesToTerminal);
    _syncPreAttachedTerminalSize();
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
    _writeInput(data);
  }

  Future<void> close() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    await _zmodemStdin?.close();
    _zmodemMux = null;
    _zmodemStdin = null;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _pendingResize = null;
    _flushPendingTerminalWrite();
    if (_attached) {
      _terminal.onOutput = _previousOutput;
      _terminal.onResize = _previousResize;
      _attached = false;
    }
    await _session.close();
  }

  void _attachZModemMux() {
    final stdin = _SshShellSessionSink(_session);
    _zmodemStdin = stdin;
    _zmodemMux =
        ZModemMux(stdin: stdin, stdout: _session.stdout.map(_asUint8List))
          ..onTerminalInput = _writeTextToTerminal
          ..onFileOffer = _handleZModemFileOffer
          ..onFileRequest = _handleZModemFileRequest;
  }

  void _scheduleResize({
    required int columns,
    required int rows,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    if (!_attached || columns <= 0 || rows <= 0) {
      return;
    }
    final next = (
      columns: columns,
      rows: rows,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
    if (next == _lastSentResize) {
      _pendingResize = null;
      _resizeTimer?.cancel();
      _resizeTimer = null;
      return;
    }
    _pendingResize = next;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeDebounceDuration, _flushPendingResize);
  }

  void _syncPreAttachedTerminalSize() {
    if (_terminal.viewWidth == _defaultColumns &&
        _terminal.viewHeight == _defaultRows &&
        _terminal.pixelWidth == 0 &&
        _terminal.pixelHeight == 0) {
      return;
    }
    _sendResize(
      columns: _terminal.viewWidth,
      rows: _terminal.viewHeight,
      pixelWidth: _terminal.pixelWidth,
      pixelHeight: _terminal.pixelHeight,
    );
  }

  void _flushPendingResize() {
    _resizeTimer?.cancel();
    _resizeTimer = null;
    final resize = _pendingResize;
    _pendingResize = null;
    if (!_attached || resize == null || resize == _lastSentResize) {
      return;
    }
    _sendResize(
      columns: resize.columns,
      rows: resize.rows,
      pixelWidth: resize.pixelWidth,
      pixelHeight: resize.pixelHeight,
    );
  }

  void _sendResize({
    required int columns,
    required int rows,
    required int pixelWidth,
    required int pixelHeight,
  }) {
    if (!_attached || columns <= 0 || rows <= 0) {
      return;
    }
    final resize = (
      columns: columns,
      rows: rows,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
    if (resize == _lastSentResize) {
      return;
    }
    _lastSentResize = resize;
    try {
      unawaited(
        _session
            .resize(
              columns: resize.columns,
              rows: resize.rows,
              pixelWidth: resize.pixelWidth,
              pixelHeight: resize.pixelHeight,
            )
            .catchError((Object _) {}),
      );
    } on Object {
      // Resize races can happen while a shell is exiting; the terminal buffer
      // should keep rendering even if the backing session rejects the resize.
    }
  }

  Future<void> _handleOutput(String data) async {
    if (!await _pasteGuard.allow(data) || !_attached) {
      return;
    }
    _writeInput(data);
    if (_attached) {
      _previousOutput?.call(data);
    }
  }

  void _writeInput(String data) {
    final mux = _zmodemMux;
    if (mux == null) {
      unawaited(_session.write(utf8.encode(data)));
      return;
    }
    mux.terminalWrite(data);
  }

  void _handleZModemFileOffer(ZModemOffer offer) {
    final handler = _zmodemTransferHandler;
    if (handler == null) {
      offer.skip();
      return;
    }
    _writeZModemStatus('ZMODEM receive requested: ${offer.info.pathname}');
    unawaited(
      handler
          .receiveOffer(offer)
          .then((received) {
            if (received) {
              _writeZModemStatus(
                'ZMODEM receive finished: ${offer.info.pathname}',
              );
            } else {
              _writeZModemStatus(
                'ZMODEM receive canceled: ${offer.info.pathname}',
              );
            }
          })
          .catchError((Object error) {
            _writeZModemStatus('ZMODEM receive failed: $error');
          }),
    );
  }

  Future<Iterable<ZModemOffer>> _handleZModemFileRequest() async {
    final handler = _zmodemTransferHandler;
    if (handler == null) {
      return const [];
    }
    try {
      final offers = (await handler.requestFiles()).toList(growable: false);
      if (offers.isEmpty) {
        _writeZModemStatus('ZMODEM send canceled.');
      } else {
        _writeZModemStatus('ZMODEM sending ${offers.length} file(s).');
      }
      return offers;
    } on Object catch (error) {
      _writeZModemStatus('ZMODEM send failed: $error');
      return const [];
    }
  }

  void _writeZModemStatus(String message) {
    _writeTextToTerminal('\r\n$message\r\n');
  }

  void _writeBytesToTerminal(List<int> bytes) {
    if (!_attached) {
      return;
    }
    _writeTextToTerminal(utf8.decode(bytes, allowMalformed: true));
  }

  void _writeTextToTerminal(String text) {
    if (!_attached) {
      return;
    }
    _pendingTerminalWrite.write(text);
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

Uint8List _asUint8List(List<int> bytes) {
  if (bytes case final Uint8List typedBytes) {
    return typedBytes;
  }
  return Uint8List.fromList(bytes);
}

class _SshShellSessionSink implements StreamSink<List<int>> {
  _SshShellSessionSink(this._session);

  final SshShellSession _session;
  Future<void> _pendingWrite = Future<void>.value();
  var _closed = false;

  @override
  Future<void> get done => _pendingWrite;

  @override
  void add(List<int> data) {
    if (_closed) {
      return;
    }
    final bytes = Uint8List.fromList(data);
    final write = _session.write(bytes);
    _pendingWrite = Future.wait<void>([_pendingWrite, write]);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
    await _pendingWrite;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> close() async {
    _closed = true;
    await _pendingWrite;
  }
}
