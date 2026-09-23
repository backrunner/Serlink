part of 'workspace_smoke_test.dart';

void _hostGroupTests() {
  testWidgets(
    'host groups can be created from empty space and persist across locks',
    (tester) async {
      await _pumpLockedVaultApp(tester);
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      await _openGroupCreation(tester);
      await tester.tap(find.byKey(const ValueKey('host-group-create-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid group name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('host-group-name-field')),
        '  Production  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('host-group-Production')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('host-group-name-field')), findsNothing);
      expect(find.text('Production'), findsOneWidget);
      expect(find.text('No Hosts'), findsNothing);

      await _openGroupCreation(tester);
      await tester.enterText(
        find.byKey(const ValueKey('host-group-name-field')),
        'production',
      );
      await tester.tap(find.byKey(const ValueKey('host-group-create-button')));
      await _pumpUntilFound(
        tester,
        find.text('A group with this name already exists.'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SerlinkApp)),
      );
      expect(await container.read(hostGroupRepositoryProvider).list(), [
        'Production',
      ]);
      await container.read(vaultSessionControllerProvider.notifier).lock();
      await tester.pumpAndSettle();
      expect(find.text('Production'), findsNothing);
      expect(find.byKey(const ValueKey('hosts-background-menu')), findsNothing);
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await _pumpUntilFound(tester, find.text('Production'));
      await tester.pumpAndSettle();

      await _tapAddHost(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('host-group-select')));
      await tester.pumpAndSettle();
      expect(find.text('Production').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'host groups accept mouse drops into collapsed groups and back to ungrouped',
    (tester) async {
      final hosts = _MemoryHostRepository();
      final host = _hostConfig(
        id: 'drag-host',
        displayName: 'Drag Bastion',
        hostname: 'bastion.internal',
        createdAt: DateTime.utc(2026),
      );
      await hosts.save(host);
      await _pumpLockedVaultApp(tester, hostRepository: hosts);
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      await _openHostContextMenu(tester, 'Drag Bastion');
      expect(find.text('Edit host'), findsOneWidget);
      expect(find.text('New group…'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _openGroupCreation(tester);
      await tester.enterText(
        find.byKey(const ValueKey('host-group-name-field')),
        'Production',
      );
      await tester.tap(find.byKey(const ValueKey('host-group-create-button')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('host-group-Production')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Production'));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Drag Bastion')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('host-group-Production'))),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final target = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('host-group-drop-Production')),
      );
      expect(
        (target.decoration! as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => hosts.hosts.single.groupId == 'Production',
      );
      await tester.pumpAndSettle();
      expect(find.text('Drag Bastion'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Drag Bastion')).dy,
        lessThan(tester.getTopLeft(find.text('Ungrouped')).dy),
      );
      expect(hosts.hosts.single.hostname, host.hostname);

      final returnDrag = await tester.startGesture(
        tester.getCenter(find.text('Drag Bastion')),
        kind: PointerDeviceKind.mouse,
      );
      await returnDrag.moveBy(const Offset(0, 20));
      await tester.pump();
      await returnDrag.moveTo(
        tester.getCenter(find.byKey(const ValueKey('host-group-'))),
      );
      await tester.pump();
      await returnDrag.up();
      await tester.pumpAndSettle();
      await _pumpUntil(tester, () => hosts.hosts.single.groupId == null);
      await tester.pumpAndSettle();
      expect(find.text('Production'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Drag Bastion')).dy,
        greaterThan(tester.getTopLeft(find.text('Ungrouped')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openGroupCreation(WidgetTester tester) async {
  final background = tester.getRect(
    find.byKey(const ValueKey('hosts-background-menu')),
  );
  await tester.tapAt(
    background.bottomRight - const Offset(30, 30),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('New group…'));
  await tester.pumpAndSettle();
  expect(find.text('New Group'), findsOneWidget);
}
