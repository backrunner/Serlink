import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
  test('filled button labels meet normal text contrast in both themes', () {
    for (final theme in [
      SerlinkTheme.foruiLight(),
      SerlinkTheme.foruiDark(),
      SerlinkTheme.foruiLightTouch(),
      SerlinkTheme.foruiDarkTouch(),
    ]) {
      for (final (fill, label) in [
        (theme.colors.primary, theme.colors.primaryForeground),
        (theme.colors.destructive, theme.colors.destructiveForeground),
      ]) {
        final background = fill.computeLuminance();
        final foreground = label.computeLuminance();
        final contrast =
            (math.max(background, foreground) + 0.05) /
            (math.min(background, foreground) + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets('custom rows support Tab, visible focus, Enter and Space', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      _TestApp(
        child: SerlinkPressable(
          onTap: () => activations++,
          child: const Text('Open host'),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final overlay = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(SerlinkPressable),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((overlay.decoration! as BoxDecoration).border, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(activations, 2);
  });

  testWidgets('disabled custom rows are skipped during keyboard traversal', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      _TestApp(
        child: Column(
          children: [
            const SerlinkPressable(child: Text('Unavailable')),
            SerlinkPressable(
              onTap: () => activations++,
              child: const Text('Available'),
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activations, 1);
  });

  testWidgets('choice chips expose selection and accept keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    bool? selected;
    await tester.pumpWidget(
      _TestApp(
        child: SerlinkChoiceChip(
          label: 'Production',
          selected: true,
          onSelected: (value) => selected = value,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SerlinkChoiceChip)),
      matchesSemantics(
        label: 'Production',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, false);
    semantics.dispose();
  });

  testWidgets(
    'empty state action stays reachable in a short enlarged viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 240);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var activated = false;
      await tester.pumpWidget(
        _TestApp(
          child: SerlinkEmptyState(
            icon: Icons.dns_outlined,
            title: 'No hosts yet',
            body: 'Add a host to start a terminal or browse remote files.',
            action: SerlinkFilledButton(
              onPressed: () => activated = true,
              child: const Text('Add host'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Add host'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add host'));
      await tester.pumpAndSettle();
      expect(activated, isTrue);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: SerlinkTheme.light(platform: TargetPlatform.windows),
    builder: (context, child) => FTheme(
      data: SerlinkTheme.foruiLight(platform: TargetPlatform.windows),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}
