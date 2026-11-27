// Runs on a real Linux desktop (CI: ubuntu under Xvfb) against the vendored
// flutter_pty Unix backend:
//   flutter test integration_test/linux_local_terminal_test.dart -d linux
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/terminal/application/local_terminal_service.dart';
import 'package:serlink/features/terminal/data/flutter_pty_local_terminal_service.dart';

const _timeout = Duration(seconds: 60);
final _ansi = RegExp(
  r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)|\x1B[@-_]',
);

class _Transcript {
  _Transcript(SshShellSession session) {
    _subscription = session.stdout.listen((bytes) {
      _raw.addAll(bytes);
      _changed.add(null);
    });
  }

  final _raw = <int>[];
  final _changed = StreamController<void>.broadcast();
  late final StreamSubscription<List<int>> _subscription;

  String get text => utf8
      .decode(_raw, allowMalformed: true)
      .replaceAll(_ansi, '')
      .replaceAll('\r', '')
      .replaceAll('\n', '');

  Future<void> waitFor(String expected) async {
    final deadline = DateTime.now().add(_timeout);
    while (!text.contains(expected)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        fail('Timed out waiting for "$expected". Output so far:\n$text');
      }
      await _changed.stream.first.timeout(
        remaining,
        onTimeout: () =>
            fail('Timed out waiting for "$expected". Output so far:\n$text'),
      );
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changed.close();
  }
}

Future<void> _runAndExpect(
  LocalShellProfile Function()? profile,
  String command,
  String expected, {
  int columns = 220,
  int rows = 40,
}) async {
  final service = FlutterPtyLocalTerminalService(profileResolver: profile);
  final session = await service.openShell(columns: columns, rows: rows);
  final transcript = _Transcript(session);
  try {
    await session.write(utf8.encode('$command\r'));
    await transcript.waitFor(expected);
  } finally {
    await session.close();
    await session.done.timeout(_timeout);
    await transcript.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip = !Platform.isLinux;

  // The echoed input never contains the joined marker, only its parts.
  testWidgets('default Linux shell runs a command', (tester) async {
    final profile = defaultLocalShellProfile();
    // ignore: avoid_print
    print('Default local shell: ${profile.executable} ${profile.arguments}');
    await _runAndExpect(
      null,
      "printf '%s-%s\\n' serlink default-ok",
      'serlink-default-ok',
    );
  }, skip: skip);

  testWidgets('/bin/sh runs through the pty', (tester) async {
    await _runAndExpect(
      () => LocalShellProfile(
        executable: '/bin/sh',
        environment: Platform.environment,
      ),
      "printf '%s-%s\\n' serlink sh-ok",
      'serlink-sh-ok',
    );
  }, skip: skip);

  testWidgets('the pty honors variables removed from the shell profile', (
    tester,
  ) async {
    // Deliberately omit HOME from the child profile to check the actual
    // environment after fork, even on a Wayland-only desktop.
    expect(Platform.environment['HOME'], isNotEmpty);
    await _runAndExpect(
      () => LocalShellProfile(executable: '/bin/sh', environment: const {}),
      r'printf "%s:%s\n" profile "${HOME-unset}"',
      'profile:unset',
    );
  }, skip: skip);

  testWidgets('the pty reports the requested size', (tester) async {
    await _runAndExpect(
      null,
      r'printf "size=%s\n" "$(stty size)"',
      'size=33 97',
      columns: 97,
      rows: 33,
    );
  }, skip: skip);

  testWidgets('non-ASCII working directory and environment survive', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('serlink-pty-');
    final directory = Directory('${root.path}/serlink-测试-ü');
    await directory.create();
    try {
      final profile = defaultLocalShellProfile();
      final env = {
        ...profile.environment,
        'PROBE_VALUE': 'ünï-测试',
        'LANG': 'C.UTF-8',
      };
      LocalShellProfile resolver() => LocalShellProfile(
        executable: profile.executable,
        arguments: profile.arguments,
        workingDirectory: directory.path,
        environment: env,
      );
      await _runAndExpect(
        resolver,
        r'printf "%s=%s\n" probe "$PROBE_VALUE"',
        'probe=ünï-测试',
      );
      await _runAndExpect(resolver, 'pwd', 'serlink-测试-ü');
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: skip);

  testWidgets('shell exit completes the session', (tester) async {
    final service = FlutterPtyLocalTerminalService();
    final session = await service.openShell();
    final transcript = _Transcript(session);
    try {
      await session.write(utf8.encode('exit\r'));
      await session.done.timeout(_timeout);
      // Resizing after the shell exited must be a no-op.
      await session.resize(columns: 100, rows: 30);
    } finally {
      await session.close();
      await transcript.dispose();
    }
  }, skip: skip);
}
