// Drives a real /bin/sh.
@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/mcp/application/mcp_command_job.dart';
import 'package:serlink/features/mcp/data/command_output_store.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';

void main() {
  test('a real sh accepts a 200 KiB source line and retains output beyond terminal history', () async {
    final root = await Directory.systemTemp.createTemp('serlink-command-test-');
    addTearDown(() => root.delete(recursive: true));
    final process = await Process.start('/bin/sh', [
      '-s',
    ], workingDirectory: root.path);
    final store = await CommandOutputStore.create();
    final job = McpCommandJob(
      id: 'local',
      sessionId: SessionId('local'),
      process: _LocalProcess(process),
      output: store,
      commandBytes: 200000,
      cwd: root.path,
      display: (_) {},
    );
    addTearDown(job.dispose);
    final source =
        '#${'x' * 200000}\nprintf "first-中文🙂\n"\nprintf "stderr-first\n" >&2\nsleep 0.5\n'
        'i=0; while [ "\$i" -lt 12000 ]; do printf "row-%05d\n" "\$i"; i=\$((i+1)); done\nprintf "tail-marker\n"\nexit 7\n';
    job.start(source, validateInput: () {});
    final initial = await job.read(wait: const Duration(milliseconds: 100));
    expect(initial['finished'], isFalse);
    var cursor = 0;
    final all = StringBuffer();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Map<String, Object?> page;
    do {
      if (DateTime.now().isAfter(deadline)) fail('command did not finish');
      page = await job.read(
        cursor: cursor,
        maxChars: 8191,
        wait: const Duration(milliseconds: 100),
      );
      all.write(page['output']);
      cursor = page['nextCursor'] as int;
    } while (page['finished'] != true || page['hasMore'] == true);
    expect(page['exitCode'], 7);
    expect(page['state'], 'exited');
    expect(page['outputTruncated'], isFalse);
    expect(all.toString(), contains('first-中文🙂'));
    expect(all.toString(), contains('stderr-first'));
    expect(all.toString(), contains('row-00000'));
    expect(all.toString(), contains('row-11999'));
    expect(all.toString(), contains('tail-marker'));
  });

  test(
    'channel closure does not finish until buffered output and stderr drain',
    () async {
      final process = _Process();
      final job = McpCommandJob(
        id: 'drain',
        sessionId: SessionId('s'),
        process: process,
        output: await CommandOutputStore.create(),
        commandBytes: 4,
        cwd: null,
        display: (_) {},
      );
      addTearDown(job.dispose);
      job.start('true', validateInput: () {});
      process.doneCompleter.complete();
      await Future<void>.delayed(Duration.zero);
      expect((await job.read())['finished'], isFalse);
      process.out.add(utf8.encode('buffered🙂'));
      process.err.add(utf8.encode('late error'));
      await process.out.close();
      await process.err.close();
      for (var i = 0; i < 100 && !job.finished; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final page = await job.read();
      expect(page['finished'], isTrue);
      expect(page['exitCode'], isNull);
      expect(page['state'], 'closed');
      expect(page['output'], contains('buffered🙂'));
      expect(page['output'], contains('late error'));
    },
  );

  test(
    'a page decrypted during exit still advertises every unread tail character',
    () async {
      final process = _Process();
      final store = _PausedStore();
      final job = McpCommandJob(
        id: 'race',
        sessionId: SessionId('s'),
        process: process,
        output: store,
        commandBytes: 4,
        cwd: null,
        display: (_) {},
      );
      job.start('true', validateInput: () {});
      final reading = job.read();
      await store.started.future;
      store.length = 10;
      await process.out.close();
      await process.err.close();
      process.doneCompleter.complete();
      for (var i = 0; i < 100 && !job.finished; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(job.finished, isTrue);
      store.resume.complete();
      final page = await reading;
      expect(page['finished'], isTrue);
      expect(page['hasMore'], isTrue);
      expect(page['nextCursor'], 0);
      expect(page['totalChars'], 10);
      await job.dispose();
    },
  );

  test('original long source remains paginated and is distinct from output cursors', () async {
    final process = _Process();
    final job = McpCommandJob(
      id: 'source',
      sessionId: SessionId('s'),
      process: process,
      output: await CommandOutputStore.create(),
      commandBytes: 60000,
      cwd: null,
      display: (_) {},
    );
    addTearDown(job.dispose);
    final source = 'echo 中文🙂; ' * 10000;
    job.start(source, validateInput: () {});
    final all = StringBuffer();
    var cursor = 0;
    do {
      final page = await job.read(
        cursor: cursor,
        maxChars: 4097,
        commandSource: true,
      );
      expect(page['view'], 'command');
      all.write(page['output']);
      cursor = page['nextCursor'] as int;
      if (page['hasMore'] == false) break;
    } while (true);
    expect(all.toString(), source);
  });

  test(
    'an interrupt request is not falsely reported as process exit',
    () async {
      final process = _Process();
      final job = McpCommandJob(
        id: 'cancel',
        sessionId: SessionId('s'),
        process: process,
        output: await CommandOutputStore.create(),
        commandBytes: 5,
        cwd: null,
        display: (_) {},
      );
      addTearDown(job.dispose);
      job.start('sleep', validateInput: () {});
      await job.cancel();
      expect((await job.read())['state'], 'cancel_requested');
      expect(job.finished, isFalse);
      expect(process.interrupts, 1);
    },
  );
}

class _LocalProcess implements SshCommandProcess {
  _LocalProcess(this.process) {
    done = process.exitCode.then((code) {
      exitCode = code;
    });
  }
  final Process process;
  @override
  late final Future<void> done;
  @override
  int? exitCode;
  @override
  String? get exitSignal => null;
  @override
  Stream<List<int>> get stdout => process.stdout;
  @override
  Stream<List<int>> get stderr => process.stderr;
  @override
  Future<void> write(List<int> bytes) async {
    process.stdin.add(bytes);
    await process.stdin.flush();
  }

  @override
  Future<void> closeInput() => process.stdin.close();
  @override
  Future<void> interrupt() async {
    process.kill(ProcessSignal.sigint);
  }

  @override
  Future<void> close() async {
    process.kill();
  }
}

class _Process implements SshCommandProcess {
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final doneCompleter = Completer<void>();
  int interrupts = 0;
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<void> get done => doneCompleter.future;
  @override
  int? get exitCode => null;
  @override
  String? get exitSignal => null;
  @override
  Future<void> write(List<int> bytes) async {}
  @override
  Future<void> closeInput() async {}
  @override
  Future<void> interrupt() async {
    interrupts++;
  }

  @override
  Future<void> close() async {
    if (!doneCompleter.isCompleted) doneCompleter.complete();
    if (!out.isClosed) await out.close();
    if (!err.isClosed) await err.close();
  }
}

class _PausedStore implements CommandOutputStore {
  final started = Completer<void>();
  final resume = Completer<void>();
  @override
  int length = 0;
  @override
  int get maxBytes => 65536;
  @override
  bool get truncated => false;
  @override
  Future<void> append(String text) async {
    length += text.length;
  }

  @override
  Future<
    ({String text, int cursor, int nextCursor, int totalChars, bool hasMore})
  >
  read({required int cursor, int maxChars = 65536}) async {
    started.complete();
    await resume.future;
    return (text: '', cursor: 0, nextCursor: 0, totalChars: 0, hasMore: false);
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
