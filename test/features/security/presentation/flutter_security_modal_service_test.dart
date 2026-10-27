import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/security/presentation/flutter_security_modal_service.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/l10n/l10n.dart';
import 'package:serlink/features/mcp/application/mcp_approval_notifications.dart';
import 'package:serlink/features/mcp/application/mcp_request_context.dart';

const double _expectedHostKeyDialogDesktopWidth = 520;

void main() {
  const prompt = AgentAccessPrompt(
    clientName: 'agent',
    hostDisplayName: 'host',
    hostId: 'host-1',
  );

  testWidgets('notification approval resolves the same dialog once', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final notifications = _Notifications();
    await tester.pumpWidget(_TestApp(navigatorKey: key));
    final service = FlutterSecurityModalService(
      key: key,
      notifications: notifications,
    );
    final result = service.confirmAgentAccess(prompt);
    await tester.pumpAndSettle();
    expect(find.text('Agent access request'), findsOneWidget);
    notifications.actions.single.complete('allow');
    await tester.pumpAndSettle();
    expect(await result, AgentAccessDecision.allow);
    expect(find.text('Agent access request'), findsNothing);
    expect(notifications.dismissed, [notifications.requests.single['id']]);
  });

  testWidgets('timeout removes approval and ignores a late notification', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final notifications = _Notifications();
    await tester.pumpWidget(_TestApp(navigatorKey: key));
    final service = FlutterSecurityModalService(
      key: key,
      notifications: notifications,
      approvalTimeout: const Duration(seconds: 2),
    );
    final result = service.confirmAgentAccess(prompt);
    final expectation = expectLater(
      result,
      throwsA(
        isA<McpApprovalException>().having(
          (e) => e.code,
          'code',
          'approval_timeout',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await expectation;
    expect(find.text('Agent access request'), findsNothing);
    expect(notifications.dismissed, hasLength(1));
    notifications.actions.single.complete('allow');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling a queued request does not unblock a later approval', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final notifications = _Notifications();
    await tester.pumpWidget(_TestApp(navigatorKey: key));
    final service = FlutterSecurityModalService(
      key: key,
      notifications: notifications,
    );
    final first = service.confirmAgentAccess(prompt);
    final scope = McpRequestContext();
    final second = scope.run(() => service.confirmAgentAccess(prompt));
    final expectation = expectLater(
      second,
      throwsA(isA<McpApprovalException>()),
    );
    final third = service.confirmAgentAccess(prompt);
    await tester.pumpAndSettle();
    scope.cancel();
    await tester.pumpAndSettle();
    await expectation;
    expect(notifications.requests, hasLength(1));
    notifications.actions.first.complete('deny');
    await tester.pumpAndSettle();
    expect(await first, AgentAccessDecision.deny);
    expect(notifications.requests, hasLength(2));
    notifications.actions.last.complete('allow');
    await tester.pumpAndSettle();
    expect(await third, AgentAccessDecision.allow);
  });

  testWidgets('request cancellation withdraws a visible approval', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final notifications = _Notifications();
    await tester.pumpWidget(_TestApp(navigatorKey: key));
    final service = FlutterSecurityModalService(
      key: key,
      notifications: notifications,
    );
    final scope = McpRequestContext();
    final result = scope.run(() => service.confirmAgentAccess(prompt));
    final expectation = expectLater(
      result,
      throwsA(
        isA<McpApprovalException>().having(
          (e) => e.code,
          'code',
          'request_cancelled',
        ),
      ),
    );
    await tester.pumpAndSettle();
    scope.cancel();
    await tester.pumpAndSettle();
    await expectation;
    notifications.actions.single.complete('allow');
    await tester.pumpAndSettle();
    expect(find.text('Agent access request'), findsNothing);
    expect(notifications.dismissed, hasLength(1));
  });

  testWidgets('long commands cannot be approved from a notification', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final notifications = _Notifications();
    await tester.pumpWidget(_TestApp(navigatorKey: key));
    final service = FlutterSecurityModalService(
      key: key,
      notifications: notifications,
    );
    final result = service.confirmAgentCommand(
      AgentCommandPrompt(
        clientName: 'agent',
        hostDisplayName: 'host',
        command: 'sudo ${'x' * 100}',
        ruleDescription: 'sudo',
      ),
    );
    await tester.pumpAndSettle();
    expect(notifications.requests.single['directApproval'], isFalse);
    notifications.actions.single.complete('allow');
    await tester.pumpAndSettle();
    expect(find.text('Agent command confirmation'), findsOneWidget);
    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();
    expect(await result, AgentCommandDecision.deny);
  });

  testWidgets('certificate details scroll on a narrow enlarged viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 600);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));
    final decision = FlutterSecurityModalService(key: navigatorKey)
        .confirmWebDavCertificate(
          WebDavTlsCertificateDetails(
            endpoint: Uri.parse('https://dav.example.test/a/long/sync/path'),
            fingerprint: 'SHA256:${'abcdef0123456789' * 4}',
            expectedFingerprint: 'SHA256:${'0123456789abcdef' * 4}',
            algorithm: 'SHA256',
            subject: 'CN=dav.example.test, O=Example Organization',
            issuer: 'CN=Example Certificate Authority',
            validFrom: DateTime.utc(2026),
            validUntil: DateTime.utc(2027),
            reason: 'untrusted',
          ),
        );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final issuer = find.text('Issuer: CN=Example Certificate Authority');
    await tester.ensureVisible(issuer);
    await tester.pumpAndSettle();
    expect(issuer.hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await expectLater(decision, completion(CertificateTrustDecision.cancel));
  });

  testWidgets('host key confirmation blocks until user chooses a decision', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmHostKey(
      HostKeyPrompt(
        hostId: HostId('host-1'),
        hostname: 'bastion.internal',
        port: 22,
        algorithm: 'ssh-ed25519',
        fingerprint: 'MD5:aa:bb:cc',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm Fingerprint'), findsOneWidget);
    expect(find.text('bastion.internal:22'), findsOneWidget);
    expect(find.text('MD5:aa:bb:cc'), findsOneWidget);

    await tester.tap(find.text('Trust Once'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(HostKeyDecision.trustOnce));
  });

  testWidgets('host key dialog uses compact desktop width', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    unawaited(
      service.confirmHostKey(
        HostKeyPrompt(
          hostId: HostId('host-1'),
          hostname: 'bastion.internal',
          port: 22,
          algorithm: 'ssh-ed25519',
          fingerprint: 'MD5:aa:bb:cc',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialog = tester.widget<FDialog>(find.byType(FDialog));
    expect(dialog.constraints.maxWidth, _expectedHostKeyDialogDesktopWidth);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('host key changed dialog defaults to cancel', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmHostKey(
      HostKeyPrompt(
        hostId: HostId('host-1'),
        hostname: 'bastion.internal',
        port: 22,
        algorithm: 'ssh-ed25519',
        fingerprint: 'MD5:new',
        previousFingerprint: 'MD5:old',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host Key Changed'), findsOneWidget);
    expect(find.text('Previous: MD5:old'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(HostKeyDecision.cancel));
  });

  testWidgets('multiline paste dialog returns true only after Paste', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmMultilinePaste('ls\npwd');
    await tester.pumpAndSettle();

    expect(find.text('Paste multiple lines?'), findsOneWidget);
    expect(
      find.text('2 lines will be sent to the active terminal.'),
      findsOneWidget,
    );
    expect(find.text('ls\npwd'), findsOneWidget);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(isTrue));
  });

  testWidgets('webdav certificate dialog saves trust only after confirmation', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmWebDavCertificate(
      WebDavTlsCertificateDetails(
        endpoint: Uri.parse('https://dav.example.test'),
        fingerprint: 'SHA256:abc',
        algorithm: 'SHA256',
        subject: 'CN=dav.example.test',
        issuer: 'CN=Local CA',
        validFrom: DateTime.utc(2026),
        validUntil: DateTime.utc(2027),
        reason: 'untrusted',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trust WebDAV Certificate?'), findsOneWidget);
    expect(find.text('SHA256:abc'), findsOneWidget);
    expect(find.text('Subject: CN=dav.example.test'), findsOneWidget);

    await tester.tap(find.text('Trust and Save'));
    await tester.pumpAndSettle();

    await expectLater(
      decisionFuture,
      completion(CertificateTrustDecision.trustAndSave),
    );
  });

  testWidgets('export dialog returns confirm when Export is chosen', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmExport(
      const ExportPreview(
        title: 'Export encrypted backup?',
        encrypted: true,
        sensitiveFields: ['vault header', 'encrypted records'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export encrypted backup?'), findsOneWidget);
    expect(find.text('Encrypted export'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(ExportDecision.confirm));
  });

  testWidgets('agent access dialog allows access only after Allow', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmAgentAccess(
      const AgentAccessPrompt(
        clientName: 'claude-code',
        hostDisplayName: 'Bastion',
        hostId: 'host-1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent access request'), findsOneWidget);
    expect(
      find.text('claude-code wants to open a session on Bastion.'),
      findsOneWidget,
    );
    expect(find.text('Host ID: host-1'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(AgentAccessDecision.allow));
  });

  testWidgets('agent access dialog denies access when Deny is chosen', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmAgentAccess(
      const AgentAccessPrompt(
        clientName: 'claude-code',
        hostDisplayName: 'Bastion',
        hostId: 'host-1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();

    await expectLater(decisionFuture, completion(AgentAccessDecision.deny));
  });

  testWidgets('agent command dialog shows flagged command and allows once', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmAgentCommand(
      const AgentCommandPrompt(
        clientName: 'claude-code',
        hostDisplayName: 'Bastion',
        command: 'rm -rf /var/tmp/build',
        ruleDescription: 'recursive force delete',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent command confirmation'), findsOneWidget);
    expect(
      find.text('claude-code wants to run a command on Bastion.'),
      findsOneWidget,
    );
    expect(find.text('Flagged: recursive force delete'), findsOneWidget);
    expect(find.text('rm -rf /var/tmp/build'), findsOneWidget);

    await tester.tap(find.text('Allow Once'));
    await tester.pumpAndSettle();

    await expectLater(
      decisionFuture,
      completion(AgentCommandDecision.allowOnce),
    );
  });

  testWidgets('agent command dialog allows for session', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_TestApp(navigatorKey: navigatorKey));

    final service = FlutterSecurityModalService(key: navigatorKey);
    final decisionFuture = service.confirmAgentCommand(
      const AgentCommandPrompt(
        clientName: 'claude-code',
        hostDisplayName: 'Bastion',
        command: 'rm -rf /var/tmp/build',
        ruleDescription: 'recursive force delete',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow for Session'));
    await tester.pumpAndSettle();

    await expectLater(
      decisionFuture,
      completion(AgentCommandDecision.allowSession),
    );
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: SerlinkTheme.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => FTheme(
        data: SerlinkTheme.foruiDark(),
        platform: FPlatformVariant.macOS,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}

class _Notifications extends McpApprovalNotifications {
  final requests = <Map<String, Object>>[];
  final actions = <Completer<String?>>[];
  final dismissed = <String>[];
  @override
  Future<String?> show(Map<String, Object> request) {
    requests.add(request);
    final action = Completer<String?>();
    actions.add(action);
    return action.future;
  }

  @override
  Future<void> dismiss(String id) async {
    dismissed.add(id);
  }
}
