// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/src/ssh_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/identities/domain/identity_agent.dart';
import 'package:serlink/features/ssh/data/dartssh2_ssh_session_service.dart';
import 'package:serlink/features/ssh/data/ssh_agent_client.dart';
import 'package:serlink/features/ssh/data/ssh_agent_discovery.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/platform/ssh_agent_locations.dart';

void main() {
  test('provider display hints come from locations without vendor-specific adapters', () {
    expect(
      sshAgentProviderHint(
        '/home/user/Library/Group Containers/ABCDEFGHIJ.com.example.agent/t/agent.sock',
      ),
      'com.example.agent',
    );
    expect(sshAgentProviderHint('/home/user/.example/agent.sock'), 'example');
    expect(
      sshAgentProviderHint('/home/user/.example-ssh-agent.sock'),
      'example',
    );
    expect(
      sshAgentProviderHint('/var/run/com.apple.launchd.fixture/Listeners'),
      isNull,
    );
    expect(sshAgentProviderHint(r'\\.\pipe\openssh-ssh-agent'), isNull);
  });

  test('an empty system agent does not cause another provider to be silently selected', () async {
    await expectLater(
      DartSsh2AuthMaterial.loadAuthMethods(
        [const SshAgentAuth()],
        discoverAgents: () async => [
          const DiscoveredSshAgent(
            socketPath: '/system.sock',
            identities: [],
            isSystem: true,
          ),
          DiscoveredSshAgent(
            socketPath: '/provider.sock',
            identities: [_identity(1)],
          ),
        ],
      ),
      throwsA(
        isA<UnsupportedSshAuthException>().having(
          (error) => error.code,
          'code',
          'ssh_auth.agent_ambiguous',
        ),
      ),
    );
  });

  if (Platform.isMacOS || Platform.isLinux) {
    test('native app metadata finds an agent without HOME or container-parent enumeration', () async {
      final root = await Directory('/tmp').createTemp('sl-native-');
      addTearDown(() => root.delete(recursive: true));
      final ipc = Directory('${root.path}/protected/Generic.provider/t');
      await ipc.create(recursive: true);
      final agent = await _agent('${ipc.path}/agent.sock', [_identity(4)]);
      addTearDown(agent.close);
      final alias = '${root.path}/system-agent.sock';
      await Link(alias).create(agent.path);
      final parent = Directory('${root.path}/protected');
      await Process.run('chmod', ['111', parent.path]);
      addTearDown(() => Process.run('chmod', ['755', parent.path]));
      final endpoints = await SshAgentDiscovery(
        environment: {'SSH_AUTH_SOCK': alias},
        operatingSystem: 'macos',
        systemEndpoint: () async => null,
        macLocations: () async => SshAgentLocations(
          home: '${root.path}/home',
          roots: [SshAgentLocation(path: ipc.path, name: 'Example Manager')],
        ),
      ).discover();
      expect(endpoints, hasLength(1));
      expect(endpoints.single.socketPath, alias);
      expect(endpoints.single.isSystem, isTrue);
      expect(endpoints.single.providerHint, 'Example Manager');
      expect(agent.requests, [11]);
    });

    test('discovers generic app-container and home sockets, deduplicates links, ignores files', () async {
      final root = await Directory('/tmp').createTemp('sl-agent-');
      addTearDown(() => root.delete(recursive: true));
      final group = Directory(
        '${root.path}/Library/Group Containers/generic.provider/t',
      );
      await group.create(recursive: true);
      final provider = await _agent('${group.path}/agent.sock', [_identity(1)]);
      final other = await _agent('${root.path}/.cache/provider/socket.ssh', [
        _identity(2),
      ]);
      addTearDown(provider.close);
      addTearDown(other.close);
      final alias = '${root.path}/system-agent.sock';
      await Link(alias).create(provider.path);
      await File('${root.path}/.fake-agent.sock').writeAsString('Not a socket');
      final discovery = SshAgentDiscovery(
        environment: {'HOME': root.path, 'SSH_AUTH_SOCK': alias},
        operatingSystem: 'macos',
        systemEndpoint: () async =>
            throw StateError('Environment takes priority'),
      );
      final endpoints = await discovery.discover();
      expect(endpoints, hasLength(2));
      expect(endpoints.first.socketPath, alias);
      expect(endpoints.first.isSystem, isTrue);
      expect(
        endpoints.every((endpoint) => endpoint.identities.length == 1),
        isTrue,
      );
      expect(provider.requests, [11]);
      expect(other.requests, [11]);
    });

    test(
      'identity query handles fragmented frames and closes timed-out sockets',
      () async {
        final root = await Directory('/tmp').createTemp('sl-agent-');
        addTearDown(() => root.delete(recursive: true));
        final valid = await _agent('${root.path}/agent.sock', [
          _identity(1),
        ], fragmented: true);
        final stalled = await _agent(
          '${root.path}/stalled-agent.sock',
          [],
          stalled: true,
        );
        addTearDown(valid.close);
        addTearDown(stalled.close);
        expect(await querySshAgentIdentities(valid.path), hasLength(1));
        await expectLater(
          querySshAgentIdentities(
            stalled.path,
            timeout: const Duration(milliseconds: 80),
          ),
          throwsA(isA<TimeoutException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(stalled.activeSockets, isEmpty);
        expect(stalled.requests, [11]);
      },
    );

    test('discovery skips invalid protocol and stale sockets while retaining empty agents', () async {
      final root = await Directory('/tmp').createTemp('sl-agent-');
      addTearDown(() => root.delete(recursive: true));
      final empty = await _agent('${root.path}/empty-agent.sock', []);
      final invalid = await _agent(
        '${root.path}/invalid-agent.sock',
        [],
        invalid: true,
      );
      final stalled = await _agent(
        '${root.path}/stalled-agent.sock',
        [],
        stalled: true,
      );
      addTearDown(empty.close);
      addTearDown(invalid.close);
      addTearDown(stalled.close);
      final found = await SshAgentDiscovery(
        environment: {'HOME': root.path},
        operatingSystem: 'linux',
        systemEndpoint: () async => null,
        query: (path) => querySshAgentIdentities(
          path,
          timeout: const Duration(milliseconds: 80),
        ),
      ).discover();
      expect(found.map((agent) => agent.socketPath), [empty.path]);
      expect(found.single.identities, isEmpty);
    });
  }

  test('automatic authentication pins a sole available agent', () async {
    final material = await DartSsh2AuthMaterial.loadAuthMethods(
      [const SshAgentAuth()],
      discoverAgents: () async => [
        DiscoveredSshAgent(
          socketPath: '/provider.sock',
          identities: [_identity(1)],
        ),
      ],
      queryIdentities: (_) async =>
          throw StateError('Must use the verified discovery result'),
    );
    expect(
      (material.identities.single as SshAgentKeyPair).socketPath,
      '/provider.sock',
    );
  });

  test(
    'multiple non-system agents require selection instead of guessing',
    () async {
      await expectLater(
        DartSsh2AuthMaterial.loadAuthMethods(
          [const SshAgentAuth()],
          discoverAgents: () async => [
            DiscoveredSshAgent(
              socketPath: '/a.sock',
              identities: [_identity(1)],
            ),
            DiscoveredSshAgent(
              socketPath: '/b.sock',
              identities: [_identity(2)],
            ),
          ],
        ),
        throwsA(
          isA<UnsupportedSshAuthException>().having(
            (error) => error.code,
            'code',
            'ssh_auth.agent_ambiguous',
          ),
        ),
      );
    },
  );

  test(
    'a selected public key identifies its provider without system priority',
    () async {
      final first = _identity(1);
      final second = _identity(2);
      Future<List<DiscoveredSshAgent>> endpoints() async => [
        DiscoveredSshAgent(
          socketPath: '/system.sock',
          identities: [first],
          isSystem: true,
        ),
        DiscoveredSshAgent(socketPath: '/b.sock', identities: [second]),
      ];
      final filtered = await DartSsh2AuthMaterial.loadAuthMethods([
        SshHardwareKeyAuth(
          agent: IdentityAgentConfig(
            publicKey:
                'ssh-ed25519 ${base64Encode(second.publicKeyBlob)} fixture',
          ),
        ),
      ], discoverAgents: endpoints);
      expect(
        (filtered.identities.single as SshAgentKeyPair).socketPath,
        '/b.sock',
      );
      await expectLater(
        DartSsh2AuthMaterial.loadAuthMethods([
          const SshAgentAuth(),
        ], discoverAgents: endpoints),
        throwsA(
          isA<UnsupportedSshAuthException>().having(
            (error) => error.code,
            'code',
            'ssh_auth.agent_ambiguous',
          ),
        ),
      );
    },
  );

  test(
    'explicit endpoints never fall back to another agent on failure',
    () async {
      await expectLater(
        DartSsh2AuthMaterial.loadAuthMethods(
          [
            const SshAgentAuth(
              agent: IdentityAgentConfig(socketPath: '/chosen.sock'),
            ),
          ],
          discoverAgents: () async => throw StateError('Must not discover'),
          queryIdentities: (path) async {
            expect(path, '/chosen.sock');
            throw const SocketException('Unavailable');
          },
        ),
        throwsA(
          isA<UnsupportedSshAuthException>().having(
            (error) => error.code,
            'code',
            'ssh_auth.agent_unavailable',
          ),
        ),
      );
    },
  );

  test(
    'Windows discovery only probes the local configured named pipe',
    () async {
      final paths = <String>[];
      final found = await SshAgentDiscovery(
        environment: const {},
        operatingSystem: 'windows',
        systemEndpoint: () async => r'\\.\pipe\openssh-ssh-agent',
        query: (path) async {
          paths.add(path);
          return [];
        },
      ).discover();
      expect(found.single.isSystem, isTrue);
      expect(paths, [r'\\.\pipe\openssh-ssh-agent']);
      expect(
        await SshAgentDiscovery(
          environment: const {'SSH_AUTH_SOCK': r'\\remote\pipe\agent'},
          operatingSystem: 'windows',
          query: (path) async =>
              throw StateError('Remote path must not be queried'),
        ).discover(),
        isEmpty,
      );
    },
  );
}

SshAgentIdentity _identity(int seed) => SshAgentIdentity(
  publicKeyBlob:
      (SSHMessageWriter()
            ..writeUtf8('ssh-ed25519')
            ..writeString(Uint8List.fromList(List.filled(32, seed))))
          .takeBytes(),
  comment: 'Fixture $seed',
);

class _AgentFixture {
  _AgentFixture(this.path, this.server);
  final String path;
  final ServerSocket server;
  final requests = <int>[];
  final activeSockets = <Socket>{};
  Future<void> close() async {
    for (final socket in activeSockets.toList()) {
      socket.destroy();
    }
    await server.close();
  }
}

Future<_AgentFixture> _agent(
  String path,
  List<SshAgentIdentity> identities, {
  bool fragmented = false,
  bool stalled = false,
  bool invalid = false,
}) async {
  await File(path).parent.create(recursive: true);
  final server = await ServerSocket.bind(
    InternetAddress(path, type: InternetAddressType.unix),
    0,
  );
  final fixture = _AgentFixture(path, server);
  server.listen((socket) {
    fixture.activeSockets.add(socket);
    final received = <int>[];
    var responded = false;
    socket.listen(
      (chunk) async {
        received.addAll(chunk);
        if (responded || received.length < 5) return;
        responded = true;
        fixture.requests.add(received[4]);
        if (stalled) return;
        final payload = SSHMessageWriter()
          ..writeUint8(invalid ? 99 : 12)
          ..writeUint32(identities.length);
        for (final identity in identities) {
          payload.writeString(identity.publicKeyBlob);
          payload.writeUtf8(identity.comment);
        }
        final frame = (SSHMessageWriter()..writeString(payload.takeBytes()))
            .takeBytes();
        if (fragmented) {
          for (final byte in frame) {
            socket.add([byte]);
            await socket.flush();
          }
        } else {
          socket.add(frame);
        }
      },
      onDone: () {
        fixture.activeSockets.remove(socket);
        socket.destroy();
      },
      onError: (Object _) {
        fixture.activeSockets.remove(socket);
        socket.destroy();
      },
    );
  });
  return fixture;
}
