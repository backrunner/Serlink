import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/local_terminal_service.dart';

void main() {
  group('defaultLocalShellProfile', () {
    test('uses SHELL on Unix when the executable exists', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'linux',
        environment: const {
          'SHELL': '/usr/local/bin/fish',
          'HOME': '/home/ops',
          'PATH': '/usr/local/bin:/usr/bin',
          'TERM': 'xterm-256color',
          'SERLINK_SECRET': 'redacted',
        },
        fileExists: (path) => path == '/usr/local/bin/fish',
      );

      expect(profile.executable, '/usr/local/bin/fish');
      expect(profile.workingDirectory, '/home/ops');
      expect(profile.environment['SHELL'], '/usr/local/bin/fish');
      expect(profile.environment['PATH'], '/usr/local/bin:/usr/bin');
      expect(profile.environment.containsKey('SERLINK_SECRET'), isFalse);
    });

    test('falls back to bash on Unix when SHELL is missing', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'macos',
        environment: const {'HOME': '/Users/ops'},
        fileExists: (path) => path == '/bin/bash',
      );

      expect(profile.executable, '/bin/bash');
      expect(profile.workingDirectory, '/Users/ops');
    });

    test('uses ComSpec and user profile on Windows', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'ComSpec': r'C:\Windows\System32\cmd.exe',
          'USERPROFILE': r'C:\Users\ops',
          'PATH': r'C:\Windows\System32',
        },
      );

      expect(profile.executable, r'C:\Windows\System32\cmd.exe');
      expect(profile.workingDirectory, r'C:\Users\ops');
      expect(profile.environment['ComSpec'], r'C:\Windows\System32\cmd.exe');
    });

    test('throws a local terminal exception when no Unix shell exists', () {
      expect(
        () => defaultLocalShellProfile(
          operatingSystem: 'linux',
          environment: const {},
          fileExists: (_) => false,
        ),
        throwsA(
          isA<LocalTerminalException>().having(
            (error) => error.code,
            'code',
            'local_terminal.shell_missing',
          ),
        ),
      );
    });
  });
}
