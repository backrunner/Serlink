part of 'workspace_smoke_test.dart';

void _desktopTransferMenuTests() {
  for (final appStore in [false, true]) {
    testWidgets(
      'desktop transfer context menu opens and deletes items (App Store: $appStore)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1440, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final directory = Directory.systemTemp.createTempSync(
          'serlink-menu-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/report.txt')
          ..writeAsStringSync('report');
        final gateway = _DesktopTransferDocuments(
          PlatformCapabilities(
            operatingSystem: appStore ? 'macos' : 'windows',
            targetPlatform: appStore
                ? TargetPlatform.macOS
                : TargetPlatform.windows,
            distribution: appStore
                ? SerlinkDistribution.appStore
                : SerlinkDistribution.direct,
          ),
        );
        await _pumpLockedVaultApp(
          tester,
          capabilities: gateway.capabilities,
          documentGateway: gateway,
        );
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(WorkspaceScreen)),
        );
        final queue = container.read(transferQueueControllerProvider);
        final connection = _MutableFakeSftpConnection();
        final folderId = queue.enqueueDownload(
          connection: connection,
          remotePath: '/folder',
          localPath: directory.path,
          itemKind: TransferItemKind.directory,
        );
        final fileId = queue.enqueueDownload(
          connection: connection,
          remotePath: '/report.txt',
          localPath: file.path,
        );
        await tester.tap(find.text('Transfers').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('report.txt'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete transfer'), findsOneWidget);
        expect(find.text(appStore ? 'Export' : 'Open'), findsOneWidget);
        expect(gateway.opened, isEmpty);
        await tester.tap(find.text(appStore ? 'Export' : 'Open'));
        await _pumpMobileFileIoUntil(
          tester,
          () => (appStore ? gateway.exported : gateway.opened).isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(appStore ? gateway.exported : gateway.opened, [file.path]);
        // Canceling an export dialog is a normal result, not an open failure.
        expect(find.text('Completed item could not be opened.'), findsNothing);
        await tester.tap(find.text('folder'), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        expect(find.text('Delete transfer'), findsOneWidget);
        expect(find.text('Open'), appStore ? findsNothing : findsOneWidget);
        expect(find.text('Export'), findsNothing);
        await tester.tap(
          find.text('report.txt'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete transfer'));
        await _pumpMobileFileIoUntil(
          tester,
          () => find.text('Delete transfer?').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove transfer'));
        await _pumpMobileFileIoUntil(
          tester,
          () => queue.state.byId(fileId) == null,
        );
        await tester.pumpAndSettle();
        expect(queue.state.tasks.single.id, folderId);
        expect(file.readAsStringSync(), 'report');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'desktop transfer context menu controls running, paused, queued and failed tasks',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpLockedVaultApp(tester);
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceScreen)),
      );
      final queue = container.read(transferQueueControllerProvider);
      final connection = _MenuTransferConnection();
      final ids = [
        for (final name in ['active.log', 'other.log', 'queued.log'])
          queue.enqueueDownload(
            connection: connection,
            remotePath: '/$name',
            localPath: '/unused/$name',
          ),
      ];
      await tester.tap(find.text('Transfers').last);
      await tester.pumpAndSettle();
      Future<void> choose(String fileName, String action) async {
        await tester.tap(find.text(fileName), buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        expect(find.text('Delete transfer'), findsOneWidget);
        await tester.tap(find.text(action).last);
        await tester.pumpAndSettle();
      }

      await choose('queued.log', 'Cancel');
      expect(queue.state.byId(ids[2])!.state, TransferState.canceled);
      await choose('active.log', 'Pause');
      expect(queue.state.byId(ids[0])!.state, TransferState.paused);
      await choose('active.log', 'Resume');
      expect(queue.state.byId(ids[0])!.state, TransferState.running);
      connection.streams[ids[0]]!.addError(
        SftpFailureException(SftpFailure.connectionClosed()),
      );
      await tester.pumpAndSettle();
      expect(queue.state.byId(ids[0])!.state, TransferState.failed);
      await choose('active.log', 'Retry');
      expect(queue.state.byId(ids[0])!.state, TransferState.running);
      await choose('active.log', 'Cancel');
      expect(queue.state.byId(ids[0])!.state, TransferState.canceled);
      expect(queue.state.byId(ids[1])!.state, TransferState.running);
      expect(tester.takeException(), isNull);
    },
  );
}

class _DesktopTransferDocuments extends DocumentGateway {
  _DesktopTransferDocuments(PlatformCapabilities capabilities)
    : super(capabilities: capabilities);
  final opened = <String>[];
  final exported = <String>[];

  @override
  Future<bool> openLocalFile(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> exportLocalFile(String path, {String? suggestedName}) async {
    exported.add(path);
    return false;
  }
}

class _MenuTransferConnection extends _MutableFakeSftpConnection {
  final streams = <TransferTaskId, StreamController<TransferProgress>>{};

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    final stream = StreamController<TransferProgress>();
    streams[taskId] = stream;
    stream.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 1,
        totalBytes: 10,
      ),
    );
    // Keep cancellation in the widget test zone instead of using the SDK
    // shared completed future, which can belong to the real async zone.
    stream.onCancel = () async {};
    return stream.stream;
  }
}
