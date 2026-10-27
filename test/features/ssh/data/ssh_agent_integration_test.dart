// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/security/secret_bytes.dart';
import 'package:serlink/features/identities/domain/identity_agent.dart';
import 'package:serlink/features/ssh/data/dartssh2_ssh_session_service.dart';
import 'package:serlink/features/ssh/data/ssh_agent_client.dart';
import 'package:serlink/features/ssh/data/ssh_agent_discovery.dart';
import 'package:serlink/features/ssh/application/ssh_agent_identity_catalog.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';

void main() {
  test(
    'OpenSSH agent signs Ed25519/RSA keys and matching CA certificates',
    () async {
      final root = await Directory('/tmp').createTemp('serlink-agent-');
      Process? agent;
      addTearDown(() async {
        agent?.kill();
        if (agent != null) await agent.exitCode;
        await root.delete(recursive: true);
      });
      Future<void> command(String executable, List<String> args) async {
        final result = await Process.run(
          executable,
          args,
          environment: {'SSH_AUTH_SOCK': '${root.path}/agent.sock'},
        );
        if (result.exitCode != 0) fail('$executable failed: ${result.stderr}');
      }

      await command('ssh-keygen', [
        '-q',
        '-t',
        'ed25519',
        '-N',
        '',
        '-f',
        '${root.path}/ca',
      ]);
      agent = await Process.start('ssh-agent', [
        '-D',
        '-a',
        '${root.path}/agent.sock',
      ]);
      agent.stdout.drain<void>();
      agent.stderr.drain<void>();
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!await File('${root.path}/agent.sock').exists()) {
        if (DateTime.now().isAfter(deadline)) fail('ssh-agent did not start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      for (final type in ['ed25519', 'rsa']) {
        final path = '${root.path}/$type';
        await command('ssh-keygen', [
          '-q',
          '-t',
          type,
          '-b',
          '3072',
          '-N',
          '',
          '-f',
          path,
        ]);
        await command('ssh-keygen', [
          '-q',
          '-s',
          '${root.path}/ca',
          '-I',
          'serlink-test',
          '-n',
          'test',
          '-V',
          '-1m:+1h',
          '$path.pub',
        ]);
        await command('ssh-add', [path]);
        final publicLine = await File('$path.pub').readAsString();
        final choices = await loadSshAgentIdentities('${root.path}/agent.sock');
        expect(
          choices.any(
            (choice) =>
                choice.publicKey.split(' ').take(2).join(' ') ==
                publicLine.trim().split(' ').take(2).join(' '),
          ),
          isTrue,
        );
        expect(
          choices.every((choice) => choice.fingerprint.startsWith('SHA256:')),
          isTrue,
        );
        final publicBlob = base64Decode(publicLine.trim().split(' ')[1]);
        final certificate = await File('$path-cert.pub').readAsString();
        // Remove the source private key: all subsequent signatures must use IPC.
        await File(path).delete();
        final config = IdentityAgentConfig(
          socketPath: '${root.path}/agent.sock',
          publicKey: publicLine,
        );
        final plain = DartSsh2AuthMaterial.fromAuthMethods([
          SshAgentAuth(agent: config),
        ]);
        final certified = DartSsh2AuthMaterial.fromAuthMethods([
          SshOpenSshCertificateAuth(
            certificate: SecretBytes(utf8.encode(certificate)),
            agent: config,
          ),
        ]);
        final automatic = await DartSsh2AuthMaterial.loadAuthMethods(
          [SshAgentAuth(agent: IdentityAgentConfig(publicKey: publicLine))],
          discoverAgents: () => SshAgentDiscovery(
            environment: {'HOME': root.path},
            systemEndpoint: () async => null,
          ).discover(),
        );
        final automaticCertificate = await DartSsh2AuthMaterial.loadAuthMethods(
          [
            SshOpenSshCertificateAuth(
              certificate: SecretBytes(utf8.encode(certificate)),
              agent: const IdentityAgentConfig(),
            ),
          ],
          discoverAgents: () => SshAgentDiscovery(
            environment: {'HOME': root.path},
            systemEndpoint: () async => null,
          ).discover(),
        );
        final data = Uint8List.fromList(
          utf8.encode('serlink-agent-interoperability'),
        );
        for (final material in [
          plain,
          certified,
          automatic,
          automaticCertificate,
        ]) {
          expect(material.identities, isNotEmpty);
          for (final identity in material.identities) {
            final signature = await identity.sign(data);
            final valid = type == 'ed25519'
                ? SSHEd25519PublicKey.decode(
                    publicBlob,
                  ).verify(data, SSHEd25519Signature.decode(signature.encode()))
                : SSHRsaPublicKey.decode(publicBlob)
                      .verify(data, SSHRsaSignature.decode(signature.encode()));
            expect(valid, isTrue);
            expect(identity.shouldProbe, isTrue);
          }
        }
        expect(
          certified.identities.first.type,
          type == 'rsa'
              ? 'rsa-sha2-256-cert-v01@openssh.com'
              : 'ssh-ed25519-cert-v01@openssh.com',
        );
      }
      expect(
        const LocalSshAgentClient(socketPath: '/missing/agent.sock')
            .listIdentities,
        throwsA(isA<SshAgentException>()),
      );
    },
    skip:
        Platform.environment['SERLINK_TEST_LOCAL_AGENT'] != '1' ||
        !(Platform.isMacOS || Platform.isLinux),
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
