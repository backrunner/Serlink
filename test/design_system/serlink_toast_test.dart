import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';

void main() {
  test(
    'Chinese toast endings are normalized without changing other content',
    () {
      expect(
        formatSerlinkToastMessage('已写入 Codex。  \n', languageCode: 'zh'),
        '已写入 Codex',
      );
      expect(
        formatSerlinkToastMessage('已保存。下次生效。', languageCode: 'zh'),
        '已保存。下次生效',
      );
      expect(formatSerlinkToastMessage('同步中…', languageCode: 'zh'), '同步中…');
      expect(
        formatSerlinkToastMessage(
          'https://example.test/v1.2',
          languageCode: 'zh',
        ),
        'https://example.test/v1.2',
      );
      expect(formatSerlinkToastMessage('Saved.', languageCode: 'en'), 'Saved.');
      expect(
        formatSerlinkToastMessage('保存しました。', languageCode: 'ja'),
        '保存しました。',
      );
    },
  );

  testWidgets(
    'short and MCP messages use natural width, without unnecessary wrapping',
    (tester) async {
      final context = await _app(tester, width: 1000);
      await _show(tester, context, '已复制。');
      final shortWidth = tester.getSize(_toast).width;
      expect(shortWidth, lessThan(120));
      await _show(tester, context, '已将 Serlink MCP 配置写入 Codex。');
      final message = find.text('已将 Serlink MCP 配置写入 Codex');
      expect(tester.getSize(_toast).width, greaterThan(shortWidth));
      expect(_lineCount(tester, message), 1);
      expect(find.text('已将 Serlink MCP 配置写入 Codex。'), findsNothing);
      expect(tester.takeException(), isNull);
      await _dismiss(tester);
    },
  );

  testWidgets(
    'long text expands past the old cap, and wraps when the window narrows',
    (tester) async {
      final context = await _app(tester, width: 1000);
      const message = '已将 Serlink MCP 配置写入 Codex Desktop 客户端';
      await _show(tester, context, message);
      expect(tester.getSize(_toast).width, greaterThan(320));
      expect(_lineCount(tester, find.text(message)), 1);
      tester.view.physicalSize = const Size(320, 700);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      final bounds = tester.getRect(_toast);
      expect(bounds.left, greaterThanOrEqualTo(16));
      expect(bounds.right, lessThanOrEqualTo(304));
      expect(_lineCount(tester, find.text(message)), greaterThan(1));
      expect(tester.takeException(), isNull);
      await _dismiss(tester);
    },
  );

  testWidgets(
    'only close intercepts taps, replacement cancels the previous timer',
    (tester) async {
      var taps = 0;
      final context = await _app(tester, width: 1000, onTap: () => taps++);
      await _show(tester, context, '已复制');
      await tester.tapAt(
        tester.getRect(_toast).centerLeft + const Offset(16, 0),
      );
      expect(taps, 1);
      await _show(tester, context, '已保存');
      expect(find.text('已复制'), findsNothing);
      expect(_toast, findsOneWidget);
      await _dismiss(tester);
      expect(taps, 1);
      expect(_toast, findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}

final _toast = find.byKey(const ValueKey('app-toast'));

Future<BuildContext> _app(
  WidgetTester tester, {
  required double width,
  VoidCallback? onTap,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 700);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext target;
  await tester.pumpWidget(
    MaterialApp(
      theme: SerlinkTheme.light(platform: TargetPlatform.macOS),
      builder: (context, child) => FTheme(
        data: SerlinkTheme.foruiLight(platform: TargetPlatform.macOS),
        platform: FPlatformVariant.macOS,
        child: child!,
      ),
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          target = context;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const ColoredBox(color: Colors.white),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return target;
}

Future<void> _show(
  WidgetTester tester,
  BuildContext context,
  String message,
) async {
  showSerlinkToast(context, message, closeLabel: '关闭');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close));
  await tester.pumpAndSettle();
}

int _lineCount(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  final value = tester.widget<Text>(text).data!;
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: value.length),
      )
      .map((box) => box.top)
      .toSet()
      .length;
}
