import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/terminal/application/terminal_adapter.dart';
import 'package:serlink/features/terminal/application/terminal_zmodem_transfer.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('forwards terminal output to shell session', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    terminal.onOutput?.call('ls -la\r');
    await Future<void>.delayed(Duration.zero);

    expect(utf8.decode(session.writes.single), 'ls -la\r');

    await adapter.close();
  });

  test('does not forward declined multiline paste to shell session', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(
      terminal: terminal,
      session: session,
      confirmMultilinePaste: (_) async => false,
    );

    adapter.attach();
    terminal.onOutput?.call('\x1b[200~ls\npwd\x1b[201~');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.writes, isEmpty);

    await adapter.close();
  });

  test('forwards accepted multiline paste with original delimiters', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    var preview = '';
    final adapter = TerminalAdapter(
      terminal: terminal,
      session: session,
      confirmMultilinePaste: (value) async {
        preview = value;
        return true;
      },
    );

    adapter.attach();
    terminal.onOutput?.call('\x1b[200~ls\npwd\x1b[201~');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(preview, 'ls\npwd');
    expect(utf8.decode(session.writes.single), '\x1b[200~ls\npwd\x1b[201~');

    await adapter.close();
  });

  test('writes stdout and stderr bytes into terminal buffer', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    session.emitStdout(utf8.encode('hello\r\n'));
    session.emitStderr(utf8.encode('warning\r\n'));
    await Future<void>.delayed(Duration.zero);

    final text = terminal.buffer.getText();
    expect(text, contains('hello'));
    expect(text, contains('warning'));

    await adapter.close();
  });

  test(
    'writes stdout through zmodem mux when transfer handler is configured',
    () async {
      final terminal = Terminal();
      final session = _FakeShellSession();
      final adapter = TerminalAdapter(
        terminal: terminal,
        session: session,
        zmodemTransferHandler: const _NoopZModemTransferHandler(),
      );

      adapter.attach();
      session.emitStdout(utf8.encode('hello\r\n'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(terminal.buffer.getText(), contains('hello'));

      await adapter.close();
    },
  );

  test('forwards terminal output through zmodem mux', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(
      terminal: terminal,
      session: session,
      zmodemTransferHandler: const _NoopZModemTransferHandler(),
    );

    adapter.attach();
    terminal.onOutput?.call('pwd\r');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(utf8.decode(session.writes.single), 'pwd\r');

    await adapter.close();
  });

  test('batches burst stdout without dropping terminal output', () async {
    final terminal = Terminal(maxLines: 1000);
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    for (var i = 0; i < 240; i += 1) {
      session.emitStdout(utf8.encode('line-$i\r\n'));
    }
    await Future<void>.delayed(Duration.zero);

    final text = terminal.buffer.getText();
    expect(text, contains('line-0'));
    expect(text, contains('line-239'));

    await adapter.close();
  });

  test('flushes pending terminal output before close', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    session.emitStdout(utf8.encode('last line\r\n'));

    await adapter.close();

    expect(terminal.buffer.getText(), contains('last line'));
  });

  test('forwards resize events and restores callbacks on close', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    var previousResizeCalled = false;
    terminal.onResize = (_, _, _, _) {
      previousResizeCalled = true;
    };
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    terminal.resize(120, 32, 1000, 700);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(previousResizeCalled, isTrue);
    expect(session.resizes.single, (120, 32, 1000, 700));

    await adapter.close();

    expect(session.closed, isTrue);
    previousResizeCalled = false;
    terminal.resize(100, 30);
    expect(previousResizeCalled, isTrue);
    expect(session.resizes, hasLength(1));
  });

  test('coalesces resize bursts before forwarding to shell session', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    terminal.resize(100, 28, 800, 560);
    terminal.resize(105, 29, 840, 580);
    terminal.resize(120, 32, 1000, 700);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(session.resizes, [(120, 32, 1000, 700)]);

    await adapter.close();
  });

  test('ignores repeated resize events with unchanged dimensions', () async {
    final terminal = Terminal();
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    terminal.resize(120, 32, 1000, 700);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    terminal.resize(120, 32, 1000, 700);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(session.resizes, [(120, 32, 1000, 700)]);

    await adapter.close();
  });

  test('syncs terminal size that was measured before attach', () async {
    final terminal = Terminal();
    terminal.resize(110, 30, 900, 600);
    final session = _FakeShellSession();
    final adapter = TerminalAdapter(terminal: terminal, session: session);

    adapter.attach();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(session.resizes, [(110, 30, 900, 600)]);

    await adapter.close();
  });
}

class _NoopZModemTransferHandler implements TerminalZModemTransferHandler {
  const _NoopZModemTransferHandler();

  @override
  Future<bool> receiveOffer(ZModemOffer offer) async {
    offer.skip();
    return false;
  }

  @override
  Future<Iterable<ZModemOffer>> requestFiles() async => const [];
}

class _FakeShellSession implements SshShellSession {
  final StreamController<List<int>> _stdout = StreamController<List<int>>(
    sync: true,
  );
  final StreamController<List<int>> _stderr = StreamController<List<int>>(
    sync: true,
  );
  final Completer<void> _done = Completer<void>();
  final List<List<int>> writes = [];
  final List<(int, int, int, int)> resizes = [];
  bool closed = false;

  void emitStdout(List<int> bytes) {
    _stdout.add(bytes);
  }

  void emitStderr(List<int> bytes) {
    _stderr.add(bytes);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(bytes);
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    resizes.add((columns, rows, pixelWidth ?? 0, pixelHeight ?? 0));
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_done.isCompleted) {
      _done.complete();
    }
    await _stdout.close();
    await _stderr.close();
  }
}
