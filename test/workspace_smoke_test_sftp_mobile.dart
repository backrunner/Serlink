part of 'workspace_smoke_test.dart';

void _sftpMobileTests() {
  for (final scenario in [
    'binary',
    'preview failure',
    'truncated',
    'download failure',
    'unsaved text',
  ]) {
    testWidgets('iOS SFTP external opening handles $scenario', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync(
        'serlink-open-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final gateway = _MobileOpenDocumentGateway('${directory.path}/app.env');
      final gate = Completer<void>();
      final ssh = _FakeSshSessionService();
      ssh.sftp
        ..writeDownloads = true
        ..downloadGate = gate
        ..previewOverride = SftpFilePreview(
          text: scenario == 'truncated' || scenario == 'unsaved text'
              ? 'original text'
              : '',
          bytesRead: 64,
          truncated: scenario == 'truncated',
          isText: scenario == 'truncated' || scenario == 'unsaved text',
        );
      if (scenario == 'preview failure') {
        ssh.sftp.previewError = SftpFailureException(
          SftpFailure.operationFailed(),
        );
      }
      if (scenario == 'download failure') {
        ssh.sftp.downloadError = SftpFailureException(
          SftpFailure.connectionClosed(),
        );
      }
      await _pumpLockedVaultApp(
        tester,
        capabilities: gateway.capabilities,
        documentGateway: gateway,
        sshService: ssh,
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await _tapAddHost(tester);
      await tester.enterText(
        find.byKey(const ValueKey('host-display-name-field')),
        'Mobile files',
      );
      await tester.enterText(
        find.byKey(const ValueKey('host-hostname-field')),
        'files.internal',
      );
      await tester.enterText(
        find.byKey(const ValueKey('host-username-field')),
        'ops',
      );
      await tester.enterText(
        find.byKey(const ValueKey('host-password-field')),
        'server-password',
      );
      await tester.tap(find.byKey(const ValueKey('host-save-button')));
      await tester.pumpAndSettle();
      await tester.tap(_byTooltipLabel('SFTP'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceScreen)),
      );
      final queue = container.read(transferQueueControllerProvider);

      await tester.tap(find.text('app.env'));
      await tester.pumpAndSettle();
      if (scenario == 'truncated' || scenario == 'unsaved text') {
        expect(
          find.byKey(const ValueKey('remote-file-editor')),
          findsOneWidget,
        );
        if (scenario == 'truncated') {
          expect(find.text('Save'), findsNothing);
          await tester.tap(find.text('Open in…'));
        } else {
          final editor = find.byKey(const ValueKey('remote-file-editor'));
          await tester.enterText(editor, 'unsaved edits');
          await tester.tap(find.text('Open in…'));
          await tester.pumpAndSettle();
          expect(find.text('Discard changes?'), findsOneWidget);
          expect(queue.state.tasks, isEmpty);
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
          expect(
            tester.widget<SerlinkTextField>(editor).controller!.text,
            'unsaved edits',
          );
          await tester.tap(find.text('Open in…'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard and open'));
        }
      } else {
        expect(find.byKey(const ValueKey('remote-file-editor')), findsNothing);
        expect(find.text('Preview unavailable'), findsOneWidget);
        // Canceling the offer must not download or present system UI.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(queue.state.tasks, isEmpty);
        expect(gateway.openedPaths, isEmpty);
        await tester.tap(find.text('app.env'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Download and open'));
      }
      await _pumpMobileFileIoUntil(tester, () => queue.state.tasks.isNotEmpty);
      expect(gateway.openedPaths, isEmpty);
      expect(find.text('Download queued.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Download queued.'), findsNothing);

      gate.complete();
      await _pumpMobileFileIoUntil(
        tester,
        () => scenario == 'download failure'
            ? queue.state.tasks.single.state == TransferState.failed
            : gateway.openedPaths.isNotEmpty,
      );
      if (scenario == 'download failure') {
        expect(gateway.openedPaths, isEmpty);
        expect(find.text('Download failed. Try again.'), findsOneWidget);
      } else {
        expect(gateway.openedPaths, [gateway.downloadPath]);
        expect(queue.state.tasks.single.state, TransferState.completed);
        // Reopening remains available after dismissing the native sheet.
        await tester.tap(find.text('Transfers').last);
        await tester.pumpAndSettle();
        expect(find.text('Open in…'), findsOneWidget);
        await tester.tap(find.text('Open in…'));
        await _pumpMobileFileIoUntil(
          tester,
          () => gateway.openedPaths.length == 2,
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpMobileFileIoUntil(
  WidgetTester tester,
  bool Function() done,
) async {
  for (var attempt = 0; attempt < 100 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
  await tester.pump();
}

class _MobileOpenDocumentGateway extends DocumentGateway {
  _MobileOpenDocumentGateway(this.downloadPath)
    : super(
        capabilities: const PlatformCapabilities(
          operatingSystem: 'ios',
          targetPlatform: TargetPlatform.iOS,
        ),
      );

  final String downloadPath;
  final openedPaths = <String>[];

  @override
  Future<String?> pickFileDownloadPath({required String suggestedName}) async =>
      downloadPath;

  @override
  Future<bool> openLocalFile(String path) async {
    openedPaths.add(path);
    return true;
  }
}
