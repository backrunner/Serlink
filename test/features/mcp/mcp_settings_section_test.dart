import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:serlink/features/mcp/domain/command_decision.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/mcp/application/agent_config_installer.dart';
import 'package:serlink/features/mcp/application/agent_skill_installer.dart';
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
import 'package:serlink/l10n/l10n.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  testWidgets(
    'command timeout saves and reloads without replacing the bridge',
    (tester) async {
      _useLargeSurface(tester);
      final container = await _pumpSerlinkApp(
        tester,
        serverController: _FakeMcpServerController(),
      );
      await _openMcpManager(tester);
      final bridge = container.read(agentSessionBridgeProvider);
      final picker = find.byKey(
        const ValueKey('settings-mcp-approval-timeout'),
      );
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      expect(tester.widget<SerlinkSelect<int>>(picker).value, 60);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      final l10n = tester.element(picker).l10n;
      await tester.tap(
        find.text(l10n.settingsMcpApprovalTimeoutMinutes(10)).last,
      );
      await tester.pumpAndSettle();
      expect(
        (await container.read(mcpCommandApprovalProvider).read())
            .timeoutSeconds,
        600,
      );
      expect(
        identical(container.read(agentSessionBridgeProvider), bridge),
        isTrue,
      );
      final close = find.widgetWithText(SerlinkTextButton, l10n.closeAction);
      await tester.tap(close);
      await tester.pumpAndSettle();
      final manage = find.byKey(const ValueKey('settings-mcp-manage-button'));
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      expect(tester.widget<SerlinkSelect<int>>(picker).value, 600);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bypass setting persists without replacing active bridge', (
    tester,
  ) async {
    _useLargeSurface(tester);
    final container = await _pumpSerlinkApp(
      tester,
      serverController: _FakeMcpServerController(),
    );
    await _openMcpManager(tester);
    final policy = container.read(mcpCommandApprovalProvider);
    final bridge = container.read(agentSessionBridgeProvider);
    expect((await policy.read()).bypass, isFalse);
    final toggle = find.byKey(const ValueKey('settings-mcp-command-bypass'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect((await policy.read()).bypass, isTrue);
    expect(
      identical(container.read(agentSessionBridgeProvider), bridge),
      isTrue,
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect((await policy.read()).bypass, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(1000, 760), scale: 1.0, dark: false),
    (size: const Size(1000, 760), scale: 1.0, dark: true),
    (size: const Size(600, 480), scale: 1.5, dark: true),
    (size: const Size(800, 600), scale: 1.5, dark: false),
  ]) {
    testWidgets('MCP manager layout $scenario', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
      tester.platformDispatcher.platformBrightnessTestValue = scenario.dark
          ? Brightness.dark
          : Brightness.light;
      tester.platformDispatcher.localesTestValue = [const Locale('zh')];
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      _stubMcpStdioHelperFileExists(installed: true);
      await _pumpSerlinkApp(
        tester,
        serverController: _FakeMcpServerController(
          initialState: const McpServerState(
            running: true,
            port: 7432,
            token: '00000000-0000-4000-8000-000000000000',
          ),
        ),
      );
      await _openMcpManager(tester);
      await tester.pumpAndSettle();

      final dialog = find.byType(SerlinkDialog);
      final l10n = tester.element(dialog).l10n;
      final serverTitle = find.descendant(
        of: dialog,
        matching: find.text(l10n.settingsMcpServerTitle),
      );
      final tokenTitle = find.text(l10n.settingsMcpTokenTitle);
      expect(
        tester.getTopLeft(serverTitle).dx,
        tester.getTopLeft(tokenTitle).dx,
      );
      final close = find.descendant(
        of: dialog,
        matching: find.widgetWithText(SerlinkTextButton, l10n.closeAction),
      );
      final closeBounds = tester.getRect(close);
      expect(closeBounds.bottom, lessThanOrEqualTo(scenario.size.height));
      expect(close.hitTestable(), findsOneWidget);

      final tokenScroll = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('settings-mcp-token-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(tokenScroll.axis, Axis.horizontal);
      if (scenario.size.width == 600) {
        expect(tokenScroll.maxScrollExtent, greaterThan(0));
      }

      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('settings-mcp-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.settingsMcpSessionsEmpty).hitTestable(),
        findsOneWidget,
      );
      expect(tester.getRect(close), closeBounds);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('notification permission can be enabled and settings opened', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    _useLargeSurface(tester);
    const channel = MethodChannel('serlink/mcp-approvals');
    var status = 'notDetermined';
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'requestPermission') status = 'authorized';
      return status;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _pumpSerlinkApp(tester, serverController: _FakeMcpServerController());
    await _openMcpManager(tester);
    await tester.pumpAndSettle();
    expect(calls, ['status']);
    final button = find.byKey(
      const ValueKey('mcp-approval-notification-settings'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('Enabled · approve from system notifications'),
      findsOneWidget,
    );
    expect(
      calls.where((method) => method == 'requestPermission'),
      hasLength(1),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, contains('openSettings'));
    expect(
      calls.where((method) => method == 'requestPermission'),
      hasLength(1),
    );
  });

  testWidgets('model protection settings save keys without exposing them', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    _useLargeSurface(tester);
    final container = await _pumpSerlinkApp(
      tester,
      serverController: _FakeMcpServerController(),
    );
    await _openMcpManager(tester);
    final bridge = container.read(agentSessionBridgeProvider);
    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-guard-configure')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Model command protection'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-mcp-guard-enable')));
    await tester.tap(find.byKey(const ValueKey('settings-mcp-guard-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Agree to command sharing before enabling model protection.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-guard-sharing-consent')),
    );
    await tester.tap(find.byKey(const ValueKey('settings-mcp-guard-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Check the model, connection settings and required API key.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-mcp-guard-api-key')),
      'fixture-api-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-mcp-guard-model')),
      'jev-latest',
    );
    await tester.tap(find.byKey(const ValueKey('settings-mcp-guard-save')));
    await tester.pumpAndSettle();
    final guard = container.read(commandDecisionGuardProvider);
    expect((await guard.readSettings()).enabled, isTrue);
    expect(find.text('Local rules + jev-latest'), findsOneWidget);
    expect(
      identical(container.read(agentSessionBridgeProvider), bridge),
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-guard-configure')),
    );
    await tester.pumpAndSettle();
    final keyField = tester.widget<SerlinkTextField>(
      find.byKey(const ValueKey('settings-mcp-guard-api-key')),
    );
    expect(keyField.obscureText, isTrue);
    expect(keyField.controller!.text, isEmpty);
    expect(find.text('fixture-api-key'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-guard-remove-key')),
    );
    await tester.pumpAndSettle();
    final removed = await guard.readSettings();
    expect(removed.enabled, isFalse);
    expect(removed.hasApiKey, isFalse);
    expect(
      identical(container.read(agentSessionBridgeProvider), bridge),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy stays behind a small entry and opens provider details', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await _pumpSerlinkApp(tester, serverController: _FakeMcpServerController());
    await _openMcpManager(tester);
    await tester.tap(
      find.byKey(const ValueKey('settings-mcp-guard-configure')),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(SerlinkDialog).last).l10n;
    expect(find.text(l10n.settingsMcpGuardDescription), findsNothing);
    expect(find.text(l10n.settingsMcpGuardInputHint), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-mcp-guard-privacy')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsMcpGuardDescription), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-mcp-guard-provider-terms')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.closeAction).last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-mcp-guard-save')),
      findsOneWidget,
    );
    expect(find.text(l10n.settingsMcpGuardDescription), findsNothing);
  });

  for (final scenario in [
    (
      size: const Size(1000, 850),
      scale: 1.0,
      dark: true,
      locale: 'zh',
      provider: CommandDecisionProvider.typesafe,
    ),
    (
      size: const Size(1000, 850),
      scale: 1.0,
      dark: false,
      locale: 'zh',
      provider: CommandDecisionProvider.gemini,
    ),
    (
      size: const Size(960, 600),
      scale: 1.5,
      dark: true,
      locale: 'en',
      provider: CommandDecisionProvider.cloudflare,
    ),
    (
      size: const Size(960, 700),
      scale: 1.3,
      dark: false,
      locale: 'ja',
      provider: CommandDecisionProvider.local,
    ),
  ]) {
    testWidgets(
      'command protection stays bounded at both scroll edges $scenario',
      (tester) async {
        _useLargeSurface(tester);
        tester.platformDispatcher.localesTestValue = [Locale(scenario.locale)];
        tester.platformDispatcher.platformBrightnessTestValue = scenario.dark
            ? Brightness.dark
            : Brightness.light;
        tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await _pumpSerlinkApp(
          tester,
          serverController: _FakeMcpServerController(),
        );
        await _openMcpManager(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-mcp-guard-configure')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-mcp-guard-configure')),
        );
        await tester.pumpAndSettle();
        final select = find.byKey(
          const ValueKey('settings-mcp-guard-provider'),
        );
        if (scenario.provider != CommandDecisionProvider.typesafe) {
          await tester.tap(select);
          await tester.pumpAndSettle();
          final label = tester
              .widget<SerlinkSelect<CommandDecisionProvider>>(select)
              .items
              .firstWhere((item) => item.value == scenario.provider)
              .label;
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<SerlinkTextField>(
                find.byKey(const ValueKey('settings-mcp-guard-model')),
              )
              .controller!
              .text,
          scenario.provider.defaultModel,
        );
        if (scenario.provider == CommandDecisionProvider.cloudflare) {
          await tester.enterText(
            find.byKey(const ValueKey('settings-mcp-guard-account')),
            'a' * 32,
          );
        }
        if (scenario.provider.requiresApiKey) {
          await tester.enterText(
            find.byKey(const ValueKey('settings-mcp-guard-api-key')),
            'fixture-new-provider-key',
          );
        }
        await tester.tap(
          find.byKey(const ValueKey('settings-mcp-guard-enable')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('settings-mcp-guard-sharing-consent')),
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-mcp-guard-sharing-consent')),
        );
        await tester.pumpAndSettle();
        tester.view.physicalSize = scenario.size;
        await tester.pumpAndSettle();
        final dialog = find.byType(SerlinkDialog).last;
        final l10n = tester.element(dialog).l10n;
        final title = find.text(l10n.settingsMcpGuardDialogTitle);
        final save = find.byKey(const ValueKey('settings-mcp-guard-save'));
        final titleBounds = tester.getRect(title);
        final saveBounds = tester.getRect(save);
        expect(save.hitTestable(), findsOneWidget);
        expect(saveBounds.bottom, lessThanOrEqualTo(scenario.size.height));
        final viewport = find.byKey(
          const ValueKey('settings-mcp-guard-scroll'),
        );
        final scrollable = find
            .descendant(of: viewport, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        for (final bottom in [true, false]) {
          position.jumpTo(bottom ? position.maxScrollExtent : 0);
          await tester.pumpAndSettle();
          final extent = position.maxScrollExtent;
          for (var i = 0; i < 4; i++) {
            tester.binding.handlePointerEvent(
              PointerScrollEvent(
                position: tester.getCenter(viewport),
                scrollDelta: Offset(0, bottom ? 100 : -100),
              ),
            );
            await tester.pumpAndSettle();
            await tester.drag(viewport, Offset(0, bottom ? -80 : 80));
            await tester.pump(const Duration(milliseconds: 16));
            expect(position.pixels, bottom ? extent : 0);
            expect(position.maxScrollExtent, extent);
            expect(tester.getRect(title), titleBounds);
            expect(tester.getRect(save), saveBounds);
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(save);
        await tester.pumpAndSettle();
        final settings = await container
            .read(commandDecisionGuardProvider)
            .readSettings();
        expect(settings.enabled, isTrue);
        expect(settings.connection.provider, scenario.provider);
        expect(settings.hasApiKey, scenario.provider.requiresApiKey);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changing provider clears typed credentials and sharing consent',
    (tester) async {
      _useLargeSurface(tester);
      await _pumpSerlinkApp(
        tester,
        serverController: _FakeMcpServerController(),
      );
      await _openMcpManager(tester);
      await tester.tap(
        find.byKey(const ValueKey('settings-mcp-guard-configure')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('settings-mcp-guard-api-key')),
        'private-old-provider-key',
      );
      await tester.tap(
        find.byKey(const ValueKey('settings-mcp-guard-sharing-consent')),
      );
      await tester.tap(
        find.byKey(const ValueKey('settings-mcp-guard-provider')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google · Gemini Decision').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SerlinkTextField>(
              find.byKey(const ValueKey('settings-mcp-guard-api-key')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<SerlinkCheckboxListTile>(
              find.byKey(const ValueKey('settings-mcp-guard-sharing-consent')),
            )
            .value,
        isFalse,
      );
    },
  );

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

    await tester.tap(find.byKey(const ValueKey('settings-mcp-server-switch')));
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
    expect(find.text('Allowed agents'), findsOneWidget);
    expect(find.textContaining('All hosts and connections'), findsWidgets);
    expect(find.textContaining('Remembered on this device'), findsOneWidget);

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
        commandApproval: ref.watch(mcpCommandApprovalProvider),
        securityModalService: _FakeSecurityModalService(),
      ),
      agentSessionsStream: Stream.value([handle]),
    );
    final bridge = container.read(
      agentSessionBridgeProvider,
    ) as _RecordingAgentSessionBridge;
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
    await _drainAgentWrites(
      tester,
      () => find.text('Installed').evaluate().length == 2,
    );
    expect(find.text('Installed'), findsNWidgets(2));
    expect(
      File('${configHome.path}/.claude/skills/serlink-mcp/SKILL.md')
          .readAsStringSync(),
      contains('serlink_sftp_upload'),
    );
  });

  for (final initial in ['missing', 'outdated', 'customized']) {
    testWidgets(
      'global skill $initial can be installed or updated without a stdio helper',
      (tester) async {
        _useLargeSurface(tester);
        _stubMcpStdioHelperFileExists(installed: false);
        final home = Directory.systemTemp.createTempSync('serlink-skill-ui-');
        Directory('${home.path}/.claude').createSync();
        final skill = File('${home.path}/.claude/skills/serlink-mcp/SKILL.md');
        if (initial != 'missing') {
          await tester.runAsync(() async {
            final configs = AgentConfigInstaller(homeDirectory: home.path);
            final target = configs.knownTargets.first;
            await AgentSkillInstaller(
              configInstaller: configs,
              loadContent: () async => 'old bundled content',
            ).install(target);
            if (initial == 'customized') {
              await skill.writeAsString('custom instructions');
            }
          });
        }
        final container = await _pumpSerlinkApp(
          tester,
          serverController: _FakeMcpServerController(),
          agentConfigHome: home,
        );
        await _openMcpManager(tester);
        expect(
          container.read(mcpServerControllerProvider).agentSkills,
          hasLength(1),
          reason:
              'loading=${container.read(mcpServerControllerProvider).agentSkillsLoading}',
        );
        await tester.tap(
          find.byKey(const ValueKey('settings-mcp-install-toggle')),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(
          const ValueKey('settings-mcp-skill-claude-code'),
        );
        expect(button, findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings-mcp-install-claude-code')),
          findsNothing,
        );
        expect(
          find.text(
            initial == 'missing'
                ? 'Install'
                : initial == 'outdated'
                ? 'Update'
                : 'Replace skill',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await _drainAgentWrites(
          tester,
          () => find.text('Installed').evaluate().isNotEmpty,
        );
        expect(skill.readAsStringSync(), contains('serlink_sftp_upload'));
        expect(File('${home.path}/.claude.json').existsSync(), isFalse);
        if (initial == 'customized') {
          final backup = skill.parent.listSync().whereType<File>().singleWhere(
            (f) => f.path.contains('.serlink-backup-'),
          );
          expect(backup.readAsStringSync(), 'custom instructions');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

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
  await tester.ensureVisible(
    find.byKey(const ValueKey('settings-mcp-manage-button')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-mcp-manage-button')));
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('settings-mcp-scroll')),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SerlinkApp)),
  );
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (!container.read(mcpServerControllerProvider).agentSkillsLoading) break;
  }
  await tester.pumpAndSettle();
}

Future<void> _drainAgentWrites(
  WidgetTester tester,
  bool Function() done,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (done()) return;
  }
  fail('Timed out waiting for global skill writes');
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
        agentSkillInstallerProvider.overrideWith(
          (ref) => AgentSkillInstaller(
            configInstaller: ref.watch(agentConfigInstallerProvider),
            loadContent: () => rootBundle.loadString(
              'assets/agent_skills/serlink-mcp/SKILL.md',
              cache: false,
            ),
          ),
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
  await _pumpUntilFound(tester, find.byType(WorkspaceScreen));
  final l10n = tester.element(find.byType(WorkspaceScreen)).l10n;
  await _pumpUntilFound(tester, find.text(l10n.settingsTitle));
  await tester.tap(find.text(l10n.settingsTitle));
  await _pumpUntilFound(tester, find.text(l10n.settingsSecuritySection));
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
  _FakeMcpServerController({this.initialState = const McpServerState()});

  final McpServerState initialState;
  var startCallCount = 0;
  var stopCallCount = 0;

  @override
  McpServerState build() => initialState;

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
    required super.commandApproval,
    required super.securityModalService,
  });

  final List<SessionId> closedSessions = [];

  @override
  Future<void> closeSession(
    SessionId sessionId, {
    String? clientName,
    bool keepConnection = false,
  }) async {
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
  Future<AgentAccessDecision> confirmAgentUpload(
    AgentUploadPrompt prompt,
  ) async => AgentAccessDecision.deny;

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
