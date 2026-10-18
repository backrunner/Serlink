part of 'workspace_smoke_test.dart';

void _hostGroupTests() {
  testWidgets('host context menu highlights its row and moves to any group', (
    tester,
  ) async {
    final hosts = _MemoryHostRepository();
    for (final (id, name, group) in [
      ('menu-a', 'Menu Bastion', 'Production'),
      ('menu-b', 'Other Bastion', 'Staging'),
    ]) {
      await hosts.save(
        _hostConfig(
          id: id,
          displayName: name,
          hostname: '$id.internal',
          groupId: group,
          createdAt: DateTime.utc(2026),
        ),
      );
    }
    await _pumpLockedVaultApp(
      tester,
      hostRepository: hosts,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'macos',
        targetPlatform: TargetPlatform.macOS,
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SerlinkApp)),
    );
    await container.read(hostGroupRepositoryProvider).save('Empty Group');
    container.invalidate(hostGroupNamesProvider);
    await tester.pumpAndSettle();

    Finder row(String id) => find.byKey(ValueKey('host-row-$id'));
    bool active(String id) => tester
        .widget<ListRow>(
          find.descendant(of: row(id), matching: find.byType(ListRow)),
        )
        .selected;
    Finder option(String label) => find.text(label).last;
    Future<void> openBastionMenu() async {
      await tester.tap(
        find.descendant(of: row('menu-a'), matching: find.text('Menu Bastion')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
    }

    final press = await tester.startGesture(
      tester.getCenter(find.text('Menu Bastion')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await press.up();
    await tester.pumpAndSettle();
    expect(find.text('Edit host'), findsOneWidget);
    expect(find.text('New group…'), findsNothing);
    expect(active('menu-a'), isTrue);
    expect(active('menu-b'), isFalse);

    await tester.tapAt(
      tester.getRect(row('menu-b')).centerLeft + const Offset(24, 0),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(active('menu-a'), isFalse);
    expect(active('menu-b'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(active('menu-b'), isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('workspace-search-field')),
      'Menu Bastion',
    );
    await tester.pumpAndSettle();
    expect(find.text('Other Bastion'), findsNothing);
    await openBastionMenu();
    await tester.tap(find.text('Add to group…'));
    await tester.pumpAndSettle();
    expect(option('Empty Group'), findsOneWidget);
    expect(option('Staging'), findsOneWidget);
    expect(option('Ungrouped'), findsOneWidget);
    final current = tester
        .widget<SerlinkContextMenu>(
          find.descendant(
            of: row('menu-a'),
            matching: find.byType(SerlinkContextMenu),
          ),
        )
        .actions
        .expand((action) => action.children)
        .singleWhere((action) => action.label == 'Production');
    expect(current.onPressed, isNull);
    expect(current.checked, isTrue);
    await tester.tap(option('Empty Group'));
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () =>
          hosts.hosts.firstWhere((host) => host.id.value == 'menu-a').groupId ==
          'Empty Group',
    );
    await tester.pumpAndSettle();
    expect(active('menu-a'), isFalse);
    expect(
      hosts.hosts.firstWhere((host) => host.id.value == 'menu-b').groupId,
      'Staging',
    );

    await openBastionMenu();
    await tester.tap(find.text('Add to group…'));
    await tester.pumpAndSettle();
    await tester.tap(option('Ungrouped'));
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () =>
          hosts.hosts.firstWhere((host) => host.id.value == 'menu-a').groupId ==
          null,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'host group drag scrolls at both edges and reaches offscreen groups',
    (tester) async {
      final hosts = _MemoryHostRepository();
      for (var index = 0; index < 36; index += 1) {
        await hosts.save(
          _hostConfig(
            id: 'scroll-host-$index',
            displayName: 'Scroll Host $index',
            hostname: 'host-$index.internal',
            groupId: index == 0 ? 'A Source' : 'B Servers',
            createdAt: DateTime.utc(2026).subtract(Duration(minutes: index)),
          ),
        );
      }
      await _pumpLockedVaultApp(
        tester,
        hostRepository: hosts,
        capabilities: const PlatformCapabilities(
          operatingSystem: 'macos',
          targetPlatform: TargetPlatform.macOS,
        ),
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      final list = find.byType(AnimatedList);
      final viewport = tester.getRect(list);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Scroll Host 0')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 4));
      for (var frame = 0; frame < 45; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, greaterThan(100));

      await gesture.moveTo(viewport.center);
      await tester.pump(const Duration(milliseconds: 16));
      final pausedOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 300));
      expect(position.pixels, pausedOffset);

      await gesture.moveTo(Offset(viewport.center.dx, viewport.top + 4));
      for (var frame = 0; frame < 20; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, lessThan(pausedOffset));

      // Moving outside the list must stop edge scrolling too.
      await gesture.moveTo(Offset(viewport.left - 10, viewport.bottom - 4));
      await tester.pump(const Duration(milliseconds: 16));
      final outsideOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 300));
      expect(position.pixels, outsideOffset);

      await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 4));
      for (var frame = 0; frame < 500; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
        if (position.pixels == position.maxScrollExtent) break;
      }
      expect(position.pixels, position.maxScrollExtent);
      // The source row has been recycled; the drag must still update and drop.
      expect(
        find.byKey(const ValueKey('host-row-scroll-host-0')),
        findsNothing,
      );
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('host-group-'))),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.up();
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () =>
            hosts.hosts
                .firstWhere((host) => host.id.value == 'scroll-host-0')
                .groupId ==
            null,
      );
      await tester.pumpAndSettle();
      final releasedOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 400));
      expect(position.pixels, releasedOffset);

      final canceledDrag = await tester.startGesture(
        tester.getCenter(find.text('Scroll Host 0')),
        kind: PointerDeviceKind.mouse,
      );
      await canceledDrag.moveBy(const Offset(0, -20));
      await canceledDrag.moveTo(Offset(viewport.center.dx, viewport.top + 4));
      for (var frame = 0; frame < 45; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(position.pixels, lessThan(releasedOffset));
      await canceledDrag.cancel();
      await tester.pumpAndSettle();
      final canceledOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 400));
      expect(position.pixels, canceledOffset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'host group drag refreshes stationary drop targets after wheel scrolling',
    (tester) async {
      final hosts = _MemoryHostRepository();
      for (var index = 0; index < 30; index += 1) {
        await hosts.save(
          _hostConfig(
            id: 'wheel-host-$index',
            displayName: 'Wheel Host $index',
            hostname: 'host-$index.internal',
            groupId: index < 15 ? 'A Source' : 'B Target',
            createdAt: DateTime.utc(2026).subtract(Duration(minutes: index)),
          ),
        );
      }
      await _pumpLockedVaultApp(
        tester,
        hostRepository: hosts,
        capabilities: const PlatformCapabilities(
          operatingSystem: 'macos',
          targetPlatform: TargetPlatform.macOS,
        ),
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      final list = find.byType(AnimatedList);
      final viewport = tester.getRect(list);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      // Measure the destination, then restore the source to begin a real drag.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('host-group-B Target')),
        250,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      final targetY =
          tester
              .getCenter(find.byKey(const ValueKey('host-group-B Target')))
              .dy +
          scrollable.position.pixels;
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      final pointer = Offset(viewport.center.dx, viewport.top + 110);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Wheel Host 0')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveTo(pointer);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: pointer,
          scrollDelta: Offset(0, targetY - pointer.dy),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('host-row-wheel-host-0')), findsNothing);
      final target = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('host-group-drop-B Target')),
      );
      expect(
        (target.decoration! as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      // No mouse movement after the scroll: release over the new group.
      await gesture.up();
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () =>
            hosts.hosts
                .firstWhere((host) => host.id.value == 'wheel-host-0')
                .groupId ==
            'B Target',
      );
      expect(tester.takeException(), isNull);
    },
  );

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
