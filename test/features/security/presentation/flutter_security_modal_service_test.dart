import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/security/presentation/flutter_security_modal_service.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:serlink/l10n/l10n.dart';

void main() {
  testWidgets('host key confirmation blocks until user chooses a decision', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_LocalizedTestApp(navigatorKey: navigatorKey));

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

  testWidgets('host key changed dialog defaults to cancel', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_LocalizedTestApp(navigatorKey: navigatorKey));

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
    await tester.pumpWidget(_LocalizedTestApp(navigatorKey: navigatorKey));

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
    await tester.pumpWidget(_LocalizedTestApp(navigatorKey: navigatorKey));

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
    await tester.pumpWidget(_LocalizedTestApp(navigatorKey: navigatorKey));

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
}

class _LocalizedTestApp extends StatelessWidget {
  const _LocalizedTestApp({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}
