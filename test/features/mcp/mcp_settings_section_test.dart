import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/mcp/application/agent_config_installer.dart';
import 'package:serlink/features/mcp/application/agent_session_bridge.dart';
import 'package:serlink/features/mcp/application/mcp_server_controller.dart';
import 'package:serlink/features/mcp/data/command_risk_policy.dart';
import 'package:serlink/features/mcp/domain/agent_session.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/workspace/presentation/workspace_screen.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  testWidgets('MCP manager dialog renders status, toggle, and config', (
    tester,
  ) async {
    _useLargeSurface(tester);
    _stubMcpStdioHelperFileExists(installed: true);
    final server = _FakeMcpServerController();
    await _pumpSerlinkApp(tester, serverController: server);
    await _openMcpManager(tester);

    expect(find.text('Agent server'), findsWidgets);
    expect(find.text('Stopped.'), findsWidgets);
    expect(
      find.byKey(const ValueKey('settings-mcp-server-switch')),
      findsOneWidget,
    );
    expect(find.text('Client config'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('stdio'), findsOneWidget);
    expect(
      find.text('Start the agent server to use the HTTP config.'),
      findsOneWidget,
    );
    expect(find.text('Start the server to generate a token.'), findsOneWidget);

    // The stdio tab shows the helper config with an enabled copy action.
    await tester.tap(find.text('stdio'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('"command"'), findsOneWidget);
    expect(_stdioCopyButton(tester).onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-server-switch')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(server.startCallCount, 1);
    expect(find.text('Running at http://127.0.0.1:7432/mcp'), findsWidgets);
    // The token is shown in plain text with an explicit access-token label.
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text('test-token'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-mcp-token-copy-button')),
      findsOneWidget,
    );
  });

  testWidgets('grant list renders and revoke calls through', (tester) async {
    _useLargeSurface(tester);
    final container = await _pumpSerlinkApp(
      tester,
      serverController: _FakeMcpServerController(),
    );

    final authorization = container.read(mcpAuthorizationServiceProvider);
    final grant = await authorization.ensureGrant(
      clientName: 'claude',
      hostId: HostId('host-1'),
      hostDisplayName: 'Test Host',
    );
    await tester.pump();

    await _openMcpManager(tester);

    await _pumpUntilFound(tester, find.text('claude'));
    expect(find.text('Active grants'), findsOneWidget);
    expect(find.textContaining('host-1'), findsWidgets);
    expect(find.textContaining('until app quits'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('settings-mcp-grant-revoke-${grant!.grantId}')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(authorization.grants, isEmpty);
    expect(find.text('No agents currently have access.'), findsOneWidget);
  });

  testWidgets('session list renders and close calls through', (tester) async {
    _useLargeSurface(tester);
    final handle = AgentSessionHandle(
      sessionId: SessionId('session-1'),
      hostId: HostId('host-1'),
      grantId: 'grant-1',
      clientName: 'codex',
      state: AgentSessionState.connected,
      openedAt: DateTime(2026, 8, 29, 10, 30),
    );
    final container = await _pumpSerlinkApp(
      tester,
      serverController: _FakeMcpServerController(),
      bridgeFactory: (ref) => _RecordingAgentSessionBridge(
        ref: ref,
        authorization: ref.watch(mcpAuthorizationServiceProvider),
        riskPolicy: CommandRiskPolicy(),
        securityModalService: _FakeSecurityModalService(),
      ),
      agentSessionsStream: Stream.value([handle]),
    );
    final bridge =
        container.read(agentSessionBridgeProvider)
            as _RecordingAgentSessionBridge;
    await _openMcpManager(tester);

    await _pumpUntilFound(tester, find.text('codex'));
    expect(find.text('Active agent sessions'), findsOneWidget);
    expect(find.textContaining('connected'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-session-close-session-1')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(bridge.closedSessions, [SessionId('session-1')]);
  });

  testWidgets(
    'stdio config tab renders disabled when the helper binary is missing',
    (tester) async {
      _useLargeSurface(tester);
      _stubMcpStdioHelperFileExists(installed: false);
      await _pumpSerlinkApp(
        tester,
        serverController: _FakeMcpServerController(),
      );
      await _openMcpManager(tester);

      await tester.tap(find.text('stdio'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'The stdio helper ships with Serlink release builds and is not '
          'available in this installation.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('"command"'), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-mcp-copy-stdio-config-button')),
        findsNothing,
      );
    },
  );

  testWidgets('install into agents writes the config from the dialog', (
    tester,
  ) async {
    _useLargeSurface(tester);
    _stubMcpStdioHelperFileExists(installed: true);
    final configHome = Directory.systemTemp.createTempSync(
      'serlink-mcp-install-test',
    );
    Directory('${configHome.path}/.claude').createSync();

    await _pumpSerlinkApp(
      tester,
      serverController: _FakeMcpServerController(),
      agentConfigHome: configHome,
    );
    await _openMcpManager(tester);

    expect(find.text('Install into agents'), findsOneWidget);
    // The agent list starts collapsed; expand it via the section header.
    expect(find.text('Claude Code'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-mcp-install-toggle')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.textContaining('/.claude.json'), findsOneWidget);

    final installButton = find.byKey(
      const ValueKey('settings-mcp-install-claude-code'),
    );
    await tester.ensureVisible(installButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(installButton);

    // The install future interleaves fake-zone continuations (flushed by
    // pump) with real file IO (drained by runAsync); alternate both.
    Map<String, Object?>? written;
    final writtenFile = File('${configHome.path}/.claude.json');
    for (var attempt = 0; attempt < 30 && written == null; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      if (writtenFile.existsSync()) {
        final content = writtenFile.readAsStringSync();
        if (content.trim().isNotEmpty) {
          written = jsonDecode(content) as Map<String, Object?>;
        }
      }
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(written, isNotNull);
    final servers = written!['mcpServers']! as Map<String, Object?>;
    expect((servers['serlink']! as Map)['type'], 'stdio');
    expect(find.text('Installed'), findsOneWidget);
  });

  testWidgets('MCP settings section is hidden without the capability', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await _pumpSerlinkApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'windows',
        targetPlatform: TargetPlatform.windows,
      ),
    );
    await _openSettings(tester);

    expect(find.text('MCP / Agent access'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-mcp-server-switch')),
      findsNothing,
    );
  });
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 3600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Overrides [mcpStdioHelperFileExists] for the duration of a test.
void _stubMcpStdioHelperFileExists({required bool installed}) {
  final original = mcpStdioHelperFileExists;
  mcpStdioHelperFileExists = (_) => installed;
  addTearDown(() => mcpStdioHelperFileExists = original);
}

SerlinkIconButton _stdioCopyButton(WidgetTester tester) {
  return tester.widget<SerlinkIconButton>(
    find.byKey(const ValueKey('settings-mcp-copy-stdio-config-button')),
  );
}

Future<void> _openMcpManager(WidgetTester tester) async {
  await _openSettings(tester);
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('settings-mcp-manage-button')),
  );
  await tester.tap(find.byKey(const ValueKey('settings-mcp-manage-button')));
  await _pumpUntilFound(tester, find.text('Client config'));
}

Future<ProviderContainer> _pumpSerlinkApp(
  WidgetTester tester, {
  PlatformCapabilities capabilities = const PlatformCapabilities(
    operatingSystem: 'macos',
    targetPlatform: TargetPlatform.macOS,
  ),
  _FakeMcpServerController? serverController,
  AgentSessionBridge Function(Ref ref)? bridgeFactory,
  Stream<List<AgentSessionHandle>>? agentSessionsStream,
  Directory? agentConfigHome,
}) async {
  final database = SerlinkDatabase(NativeDatabase.memory());
  final transferQueue = TransferQueueController();
  // Deterministic, empty home so agent detection never scans the real one.
  final configHome =
      agentConfigHome ??
      Directory.systemTemp.createTempSync('serlink-mcp-test-home');
  addTearDown(database.close);
  addTearDown(transferQueue.dispose);
  addTearDown(() => configHome.deleteSync(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serlinkDatabaseProvider.overrideWithValue(database),
        platformCapabilitiesProvider.overrideWithValue(capabilities),
        agentConfigInstallerProvider.overrideWithValue(
          AgentConfigInstaller(homeDirectory: configHome.path),
        ),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        cloudKitAvailabilityCheckProvider.overrideWithValue(
          () => Future.value(true),
        ),
        cloudKitSyncProviderFactoryProvider.overrideWithValue(
          () => _EmptySyncProvider(),
        ),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        appPackageInfoProvider.overrideWith((ref) async {
          return PackageInfo(
            appName: 'Serlink',
            packageName: 'com.alkinum.serlink',
            version: '1.2.3',
            buildNumber: '45',
          );
        }),
        securityModalServiceProvider.overrideWithValue(
          _FakeSecurityModalService(),
        ),
        if (serverController != null)
          mcpServerControllerProvider.overrideWith(() => serverController),
        if (bridgeFactory != null)
          agentSessionBridgeProvider.overrideWith(bridgeFactory),
        if (agentSessionsStream != null)
          agentSessionsProvider.overrideWith((ref) => agentSessionsStream),
      ],
      child: const SerlinkApp(),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(SerlinkApp)));
}

Future<void> _openSettings(WidgetTester tester) async {
  await _pumpUntilFound(tester, find.text('Settings'));
  await tester.tap(find.text('Settings'));
  await _pumpUntilFound(tester, find.text('Security'));
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

class _FakeMcpServerController extends McpServerController {
  var startCallCount = 0;
  var stopCallCount = 0;

  @override
  McpServerState build() => const McpServerState();

  @override
  Future<void> start() async {
    startCallCount += 1;
    state = const McpServerState(
      running: true,
      port: 7432,
      token: 'test-token',
    );
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
    state = const McpServerState();
  }
}

class _RecordingAgentSessionBridge extends AgentSessionBridge {
  _RecordingAgentSessionBridge({
    required super.ref,
    required super.authorization,
    required super.riskPolicy,
    required super.securityModalService,
  });

  final List<SessionId> closedSessions = [];

  @override
  Future<void> closeSession(SessionId sessionId) async {
    closedSessions.add(sessionId);
  }
}

class _FakeSecurityModalService implements SecurityModalService {
  AgentAccessDecision accessDecision = AgentAccessDecision.allow;

  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    return Future.value(accessDecision);
  }

  @override
  Future<AgentCommandDecision> confirmAgentCommand(AgentCommandPrompt prompt) {
    return Future.value(AgentCommandDecision.deny);
  }

  @override
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt) {
    throw UnimplementedError();
  }

  @override
  Future<CertificateTrustDecision> confirmWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ExportDecision> confirmExport(ExportPreview preview) {
    throw UnimplementedError();
  }

  @override
  Future<DestructiveDecision> confirmDestructiveAction(String title) {
    throw UnimplementedError();
  }

  @override
  Future<bool> confirmMultilinePaste(String preview) {
    throw UnimplementedError();
  }
}

class _EmptySyncProvider implements SyncProvider {
  @override
  Future<ProviderCapabilities> capabilities() async {
    return const ProviderCapabilities(
      kind: SyncProviderKind.cloudKit,
      supportsConditionalWrites: true,
      requiresTls: true,
    );
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {}

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    return const [];
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    return null;
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    throw const SyncProviderException(
      'sync.provider.object_missing',
      'Remote object is missing.',
    );
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) async {}

  @override
  Future<void> writeManifestIfUnchanged(
    RemoteManifest manifest,
    RemoteManifest? expectedCurrent,
  ) async {}

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {}
}
