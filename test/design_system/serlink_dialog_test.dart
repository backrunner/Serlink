import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('dialog title, body and actions share edges at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: SerlinkTheme.dark(platform: TargetPlatform.windows),
          builder: (context, child) =>
              FTheme(data: SerlinkTheme.foruiDark(), child: child!),
          home: const Scaffold(
            body: Center(
              child: SerlinkDialog(
                maxWidth: 688,
                titlePadding: EdgeInsets.fromLTRB(20, 22, 20, 0),
                contentPadding: EdgeInsets.fromLTRB(3, 18, 11, 0),
                actionsPadding: EdgeInsets.fromLTRB(9, 18, 5, 24),
                title: SizedBox(key: ValueKey('title'), height: 24),
                content: SizedBox(key: ValueKey('body'), height: 300),
                actions: [
                  SizedBox(key: ValueKey('action'), width: 80, height: 40),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(find.byKey(const ValueKey('title')));
      final body = tester.getRect(find.byKey(const ValueKey('body')));
      final action = tester.getRect(find.byKey(const ValueKey('action')));
      expect(body.left, title.left);
      expect(body.right, title.right);
      expect(action.right, body.right);
      expect(tester.takeException(), isNull);
    });
  }
}
