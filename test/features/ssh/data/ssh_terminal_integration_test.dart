import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/core/security/secret_bytes.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/ssh/data/dartssh2_ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/terminal/application/terminal_adapter.dart';
import 'package:serlink/features/terminal/application/terminal_zmodem_transfer.dart';
import 'package:xterm/xterm.dart';

void main() {
  final root = Platform.environment['SERLINK_SSH_FIXTURE'];
  group(
    'SSH protocol and terminal interoperability',
    () {
      late Map<String, dynamic> fixture;
      setUpAll(() {
        fixture =
            jsonDecode(File('$root/fixture.json').readAsStringSync())
                as Map<String, dynamic>;
      });

      ConnectionProfileSnapshot profile(
        String cipher, {
        List<SshAuthMethod>? auth,
        bool jump = false,
      }) {
        final methods =
            auth ??
            [
              SshPasswordAuth(
                password: SecretBytes(utf8.encode('fixture-only')),
              ),
            ];
        return ConnectionProfileSnapshot(
          sessionId: SessionId('interop-$cipher'),
          hostId: HostId('fixture'),
          hostname: '127.0.0.1',
          port: fixture['ports'][cipher] as int,
          username: 'serlink-test',
          authMethods: methods,
          jumpHosts: jump
              ? [
                  SshJumpHostSnapshot(
                    hostId: HostId('jump'),
                    hostname: '127.0.0.1',
                    port: fixture['ports']['gcm'] as int,
                    username: 'serlink-test',
                    authMethods: methods,
                  ),
                ]
              : [],
        );
      }

      DartSsh2SessionService service() => DartSsh2SessionService(
        confirmHostKey: (prompt) async {
          expect(prompt.fingerprint, fixture['fingerprint']);
          return HostKeyDecision.trustOnce;
        },
      );

      for (final cipher in ['gcm', 'chacha', 'ctr', 'cbc']) {
        for (final zmodem in [false, true]) {
          test(
            '$cipher shell, Unicode, stderr, resize, burst and exit (zmodem=$zmodem)',
            () async {
              final ssh = service();
              final shell = await ssh.openShell(profile(cipher));
              final terminal = Terminal(maxLines: 5000)..resize(100, 30);
              final adapter = TerminalAdapter(
                terminal: terminal,
                session: shell,
                zmodemTransferHandler: zmodem ? const _NoopZModem() : null,
              );
              adapter.attach();
              addTearDown(adapter.close);
              await _waitFor(terminal, 'fixture-ready');
              terminal.textInput('unicode\n');
              await _waitFor(terminal, '中文🙂');
              await _waitFor(terminal, 'stderr-ok');
              terminal.resize(132, 43);
              await Future<void>.delayed(const Duration(milliseconds: 150));
              terminal.textInput('size\n');
              await _waitFor(terminal, 'size:132x43');
              terminal.textInput('burst\n');
              await _waitFor(terminal, 'line-2999');
              expect(terminal.buffer.getText(), contains('line-0000'));
              expect(
                await ssh.probeShell(sessionId: profile(cipher).sessionId),
                isTrue,
              );
              terminal.textInput('exit\n');
              await shell.done.timeout(const Duration(seconds: 5));
              await _waitFor(terminal, 'fixture-exit');
            },
          );
        }
      }

      test('private key and keyboard interactive authentication', () async {
        for (final methods in <List<SshAuthMethod>>[
          [
            SshPrivateKeyAuth(
              privateKeyPem: SecretBytes(
                await File('$root/user_key').readAsBytes(),
              ),
            ),
          ],
          [
            SshKeyboardInteractiveAuth(
              responses: [SecretBytes(utf8.encode('fixture-only'))],
            ),
          ],
        ]) {
          await service().testConnection(profile('gcm', auth: methods));
        }
      });

      test('rejects invalid authentication and rejected host keys', () async {
        await expectLater(
          service().openShell(
            profile(
              'gcm',
              auth: [
                SshPasswordAuth(password: SecretBytes(utf8.encode('wrong'))),
              ],
            ),
          ),
          throwsA(isA<SSHAuthFailError>()),
        );
        await expectLater(
          DartSsh2SessionService(
            confirmHostKey: (_) async => HostKeyDecision.cancel,
          ).openShell(profile('gcm')),
          throwsA(isA<SSHAuthAbortError>()),
        );
      });

      test(
        'OpenSSH PTY executes commands and receives window changes',
        () async {
          final settings = jsonDecode(
            await File('$root/openssh.json').readAsString(),
          );
          final ssh = DartSsh2SessionService(
            confirmHostKey: (prompt) async {
              expect(prompt.fingerprint, settings['fingerprint']);
              return HostKeyDecision.trustOnce;
            },
          );
          final shell = await ssh.openShell(
            ConnectionProfileSnapshot(
              sessionId: SessionId('openssh'),
              hostId: HostId('openssh-fixture'),
              hostname: '127.0.0.1',
              port: settings['port'] as int,
              username: settings['username'] as String,
              authMethods: [
                SshPrivateKeyAuth(
                  privateKeyPem: SecretBytes(
                    await File('$root/user_key').readAsBytes(),
                  ),
                ),
              ],
            ),
          );
          final terminal = Terminal();
          final adapter = TerminalAdapter(
            terminal: terminal,
            session: shell,
            zmodemTransferHandler: const _NoopZModem(),
          )..attach();
          addTearDown(adapter.close);
          terminal.textInput(
            "printf '\\116\\101\\124\\111\\126\\105\\137\\117\\113\\n'\r",
          );
          await _waitFor(terminal, 'NATIVE_OK');
          terminal.resize(132, 43);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          terminal.textInput('stty size\r');
          await _waitFor(terminal, '43 132');
          terminal.textInput('exit\r');
          await shell.done.timeout(const Duration(seconds: 5));
        },
        skip: root == null || !File('$root/openssh.json').existsSync()
            ? 'Optional isolated OpenSSH fixture is not running.'
            : false,
      );

      test('jump host forwards a second authenticated shell', () async {
        final shell = await service().openShell(profile('ctr', jump: true));
        final terminal = Terminal();
        final adapter = TerminalAdapter(terminal: terminal, session: shell)
          ..attach();
        addTearDown(adapter.close);
        await _waitFor(terminal, 'fixture-ready');
        terminal.textInput('through-jump\n');
        await _waitFor(terminal, 'echo:through-jump');
      });

      test('production SFTP service opens, transfers and closes', () async {
        final sftp = await service().openSftp(profile('gcm'));
        try {
          await sftp.writeTextFile(
            '/workspace/service.txt',
            '中文 service round trip',
          );
          expect(
            (await sftp.readTextPreview('/workspace/service.txt')).text,
            '中文 service round trip',
          );
          await sftp.deleteFile('/workspace/service.txt');
        } finally {
          await sftp.close();
        }
      });

      test(
        'transport loss completes the shell and permits reconnect',
        () async {
          final ssh = service();
          final shell = await ssh.openShell(profile('gcm'));
          final terminal = Terminal();
          final adapter = TerminalAdapter(terminal: terminal, session: shell)
            ..attach();
          addTearDown(adapter.close);
          await _waitFor(terminal, 'fixture-ready');
          terminal.textInput('drop\n');
          await shell.done.timeout(const Duration(seconds: 5));
          expect(
            await ssh.probeShell(sessionId: profile('gcm').sessionId),
            isFalse,
          );
          await ssh.testConnection(profile('gcm'));
        },
      );
    },
    skip: root == null
        ? 'Start test/fixtures/ssh/server.py and set SERLINK_SSH_FIXTURE.'
        : false,
  );
}

Future<void> _waitFor(Terminal terminal, String text) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!terminal.buffer.getText().contains(text)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Terminal did not receive $text');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _NoopZModem implements TerminalZModemTransferHandler {
  const _NoopZModem();
  @override
  Future<bool> receiveOffer(ZModemOffer offer) async => false;
  @override
  Future<Iterable<ZModemOffer>> requestFiles() async => [];
}
