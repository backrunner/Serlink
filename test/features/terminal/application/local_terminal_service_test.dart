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

    test(
      'passes the session environment except Serlink variables on Linux',
      () {
        final profile = defaultLocalShellProfile(
          operatingSystem: 'linux',
          environment: const {
            'SHELL': '/bin/bash',
            'HOME': '/home/ops',
            'PATH': '/usr/bin',
            'SSH_AUTH_SOCK': '/run/user/1000/keyring/ssh',
            'XDG_RUNTIME_DIR': '/run/user/1000',
            'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
            'WAYLAND_DISPLAY': 'wayland-0',
            'SERLINK_DISTRIBUTION': 'direct',
            'DESKTOP_STARTUP_ID': 'serlink-1',
            'XDG_ACTIVATION_TOKEN': 'token',
          },
          fileExists: (path) => path == '/bin/bash',
        );

        expect(profile.environment, const {
          'SHELL': '/bin/bash',
          'HOME': '/home/ops',
          'PATH': '/usr/bin',
          'SSH_AUTH_SOCK': '/run/user/1000/keyring/ssh',
          'XDG_RUNTIME_DIR': '/run/user/1000',
          'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/run/user/1000/bus',
          'WAYLAND_DISPLAY': 'wayland-0',
        });
      },
    );

    test('uses login zsh on macOS even when SHELL points elsewhere', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'macos',
        environment: const {
          'SHELL': '/usr/local/bin/fish',
          'HOME': '/Users/ops',
        },
        fileExists: (path) =>
            path == '/bin/zsh' || path == '/usr/local/bin/fish',
      );

      expect(profile.executable, '/bin/zsh');
      expect(profile.arguments, const ['-l', '-i']);
      expect(profile.workingDirectory, '/Users/ops');
      expect(profile.environment['SHELL'], '/bin/zsh');
    });

    test('falls back to bash on Unix when SHELL is missing', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'linux',
        environment: const {'HOME': '/Users/ops'},
        fileExists: (path) => path == '/bin/bash',
      );

      expect(profile.executable, '/bin/bash');
      expect(profile.workingDirectory, '/Users/ops');
    });

    test('falls back to ComSpec on Windows without PowerShell', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'ComSpec': r'C:\Windows\System32\cmd.exe',
          'USERPROFILE': r'C:\Users\ops',
          'PATH': r'C:\Windows\System32',
        },
        fileExists: (_) => false,
      );

      expect(profile.executable, r'C:\Windows\System32\cmd.exe');
      expect(profile.arguments, isEmpty);
      expect(profile.workingDirectory, r'C:\Users\ops');
      expect(profile.environment['ComSpec'], r'C:\Windows\System32\cmd.exe');
    });

    test('prefers PowerShell 7 from Program Files on Windows', () {
      const pwsh = r'C:\Program Files\PowerShell\7\pwsh.exe';
      const windowsPowerShell =
          r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'SystemRoot': r'C:\Windows',
          'ProgramFiles': r'C:\Program Files\',
          'ComSpec': r'C:\Windows\System32\cmd.exe',
          'USERPROFILE': r'C:\Users\张三',
        },
        fileExists: (path) => path == pwsh || path == windowsPowerShell,
      );

      expect(profile.executable, pwsh);
      expect(profile.arguments, const ['-NoLogo']);
      expect(profile.workingDirectory, r'C:\Users\张三');
    });

    test('finds PowerShell 7 on PATH on Windows', () {
      const pwsh = r'D:\Tools\pwsh\pwsh.exe';
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'SystemRoot': r'C:\Windows',
          'Path': r'C:\Windows\System32;"D:\Tools\pwsh\";',
        },
        fileExists: (path) => path == pwsh,
      );

      expect(profile.executable, pwsh);
    });

    test('uses Windows PowerShell when PowerShell 7 is missing', () {
      const windowsPowerShell =
          r'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe';
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'windir': r'C:\WINDOWS',
          'HOMEDRIVE': 'C:',
          'HOMEPATH': r'\Users\ops',
        },
        fileExists: (path) => path == windowsPowerShell,
      );

      expect(profile.executable, windowsPowerShell);
      expect(profile.arguments, const ['-NoLogo']);
      expect(profile.workingDirectory, r'C:\Users\ops');
    });

    test('passes the user environment except Serlink variables on Windows', () {
      final profile = defaultLocalShellProfile(
        operatingSystem: 'windows',
        environment: const {
          'APPDATA': r'C:\Users\ops\AppData\Roaming',
          'TEMP': r'C:\Users\ops\AppData\Local\Temp',
          'PSModulePath': r'C:\Program Files\WindowsPowerShell\Modules',
          'JAVA_HOME': r'C:\Java',
          'Serlink_Secret': 'redacted',
          'SERLINK_DISTRIBUTION': 'direct',
          '=C:': r'C:\Users\ops',
        },
        fileExists: (_) => false,
      );

      expect(profile.environment, const {
        'APPDATA': r'C:\Users\ops\AppData\Roaming',
        'TEMP': r'C:\Users\ops\AppData\Local\Temp',
        'PSModulePath': r'C:\Program Files\WindowsPowerShell\Modules',
        'JAVA_HOME': r'C:\Java',
      });
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
