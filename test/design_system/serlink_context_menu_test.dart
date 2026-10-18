import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
  testWidgets('nested right-click uses the row menu after a held press', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ContextMenuTestApp(
        child: SerlinkContextMenu(
          actions: [SerlinkMenuAction(label: 'New group', onPressed: () {})],
          child: const SizedBox(
            width: 600,
            height: 500,
            child: Align(
              alignment: Alignment.topLeft,
              child: _ContextMenuTarget(
                targetKey: ValueKey('nested-row'),
                label: 'Host',
                menuLabel: 'Edit host',
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('nested-row'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Edit host'), findsOneWidget);
    expect(find.text('New group'), findsNothing);

    await tester.tapAt(const Offset(550, 450), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Edit host'), findsNothing);
    expect(find.text('New group'), findsOneWidget);
  });

  testWidgets('context target stays active until Escape or outside dismissal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _ContextMenuTestApp(
        child: SerlinkContextMenu(
          actions: [SerlinkMenuAction(label: 'Edit', onPressed: () {})],
          builder: (context, active) => SizedBox(
            key: const ValueKey('active-target'),
            width: 160,
            height: 80,
            child: Text(active ? 'Active host' : 'Idle host'),
          ),
        ),
      ),
    );
    await _secondaryTap(tester, find.byKey(const ValueKey('active-target')));
    expect(find.text('Active host'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Idle host'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await _secondaryTap(tester, find.byKey(const ValueKey('active-target')));
    await tester.tapAt(const Offset(600, 450));
    await tester.pumpAndSettle();
    expect(find.text('Idle host'), findsOneWidget);
  });

  testWidgets('submenu opens on hover, flips at the edge and accepts a group', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _ContextMenuTestApp(
        child: Align(
          alignment: Alignment.bottomRight,
          child: SerlinkContextMenu(
            actions: [
              SerlinkMenuAction(
                label: 'Add to group',
                children: [
                  const SerlinkMenuAction(label: 'Current', checked: true),
                  for (var index = 0; index < 24; index += 1)
                    SerlinkMenuAction(
                      label: 'Group $index',
                      onPressed: () => selected = 'Group $index',
                    ),
                ],
              ),
            ],
            child: const SizedBox(
              key: ValueKey('submenu-target'),
              width: 120,
              height: 60,
            ),
          ),
        ),
      ),
    );
    await _secondaryTap(tester, find.byKey(const ValueKey('submenu-target')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.text('Add to group')));
    await tester.pumpAndSettle();
    expect(find.text('Current'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getRect(find.text('Group 0')).left,
      lessThan(tester.getRect(find.text('Add to group')).left),
    );
    expect(tester.getRect(find.text('Group 0')).left, greaterThanOrEqualTo(0));
    await tester.tap(find.text('Current'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Add to group'), findsOneWidget);
    await tester.ensureVisible(find.text('Group 23'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group 23'));
    await tester.pumpAndSettle();
    expect(selected, 'Group 23');
    expect(find.text('Add to group'), findsNothing);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary clicking another item replaces an open menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _ContextMenuTestApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ContextMenuTarget(
              targetKey: ValueKey('target-a'),
              label: 'Target A',
              menuLabel: 'Menu A',
            ),
            SizedBox(height: 140),
            _ContextMenuTarget(
              targetKey: ValueKey('target-b'),
              label: 'Target B',
              menuLabel: 'Menu B',
            ),
          ],
        ),
      ),
    );

    await _secondaryTap(tester, find.byKey(const ValueKey('target-a')));
    expect(find.text('Menu A'), findsOneWidget);
    expect(find.text('Menu B'), findsNothing);

    await _secondaryTap(tester, find.byKey(const ValueKey('target-b')));
    expect(find.text('Menu A'), findsNothing);
    expect(find.text('Menu B'), findsOneWidget);
  });
}

Future<void> _secondaryTap(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await tester.pump();
}

class _ContextMenuTestApp extends StatelessWidget {
  const _ContextMenuTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: SerlinkTheme.dark(),
      builder: (context, child) => FTheme(
        data: SerlinkTheme.foruiDark(),
        platform: FPlatformVariant.macOS,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }
}

class _ContextMenuTarget extends StatelessWidget {
  const _ContextMenuTarget({
    required this.targetKey,
    required this.label,
    required this.menuLabel,
  });

  final Key targetKey;
  final String label;
  final String menuLabel;

  @override
  Widget build(BuildContext context) {
    return SerlinkContextMenu(
      actions: [
        SerlinkMenuAction(
          label: menuLabel,
          icon: Icons.edit_outlined,
          onPressed: () {},
        ),
      ],
      child: SizedBox(
        key: targetKey,
        width: 160,
        height: 80,
        child: Center(child: Text(label)),
      ),
    );
  }
}
