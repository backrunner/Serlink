import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
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
      home: FTheme(
        data: SerlinkTheme.foruiDark(),
        platform: FPlatformVariant.macOS,
        child: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
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
