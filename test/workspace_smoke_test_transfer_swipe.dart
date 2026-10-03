part of 'workspace_smoke_test.dart';

void _mobileTransferSwipeTests() {
  for (final choice in ['keep file', 'delete file', 'missing file']) {
    testWidgets('iOS transfers swipe to delete one task: $choice', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory.systemTemp.createTempSync(
        'serlink-swipe-test-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final selectedFile = File('${directory.path}/selected.pdf');
      final otherFile = File('${directory.path}/other.pdf')
        ..writeAsStringSync('keep this');
      if (choice != 'missing file') selectedFile.writeAsStringSync('download');
      final gateway = _MobileOpenDocumentGateway(selectedFile.path);
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
      final otherId = queue.enqueueDownload(
        connection: connection,
        remotePath: '/other.pdf',
        localPath: otherFile.path,
      );
      final selectedId = queue.enqueueDownload(
        connection: connection,
        remotePath: '/selected.pdf',
        localPath: selectedFile.path,
      );
      await tester.tap(find.text('Transfers').last);
      await tester.pumpAndSettle();
      final row = find.text('selected.pdf');
      final deleteButton = find.byKey(
        ValueKey('mobile-transfer-${selectedId.value}-delete-button'),
      );
      final otherDelete = find.byKey(
        ValueKey('mobile-transfer-${otherId.value}-delete-button'),
      );
      expect(deleteButton, findsNothing);

      // Vertical scrolling does not reveal or trigger a row action.
      await tester.drag(row, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(deleteButton, findsNothing);
      expect(gateway.openedPaths, isEmpty);

      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(deleteButton.hitTestable(), findsOneWidget);
      expect(otherDelete, findsNothing);
      expect(tester.getSize(deleteButton), const Size(44, 44));
      expect(gateway.openedPaths, isEmpty);
      await tester.dragFrom(tester.getCenter(row), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(deleteButton, findsNothing);
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      // Tapping the shifted content closes the actions without opening a file.
      await tester.tapAt(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(deleteButton, findsNothing);
      expect(gateway.openedPaths, isEmpty);
      if (choice != 'missing file') {
        await tester.tap(row);
        await _pumpMobileFileIoUntil(
          tester,
          () => gateway.openedPaths.isNotEmpty,
        );
        expect(gateway.openedPaths, [selectedFile.path]);
      }

      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      if (choice != 'missing file') {
        await _pumpMobileFileIoUntil(
          tester,
          () => find.text('Delete transfer?').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(queue.state.tasks, hasLength(2));
        expect(selectedFile.existsSync(), isTrue);
        expect(deleteButton, findsNothing);
        await tester.drag(row, const Offset(-100, 0));
        await tester.pumpAndSettle();
        await tester.tap(deleteButton);
        await _pumpMobileFileIoUntil(
          tester,
          () => find.text('Delete transfer?').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            choice == 'keep file' ? 'Remove transfer' : 'Delete file too',
          ),
        );
      }
      await _pumpMobileFileIoUntil(
        tester,
        () =>
            queue.state.byId(selectedId) == null &&
            (choice != 'delete file' || !selectedFile.existsSync()),
      );
      await tester.pumpAndSettle();
      expect(queue.state.tasks.single.id, otherId);
      expect(find.text('selected.pdf'), findsNothing);
      expect(find.text('other.pdf'), findsOneWidget);
      expect(otherFile.readAsStringSync(), 'keep this');
      expect(selectedFile.existsSync(), choice == 'keep file');
      expect(otherDelete, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
