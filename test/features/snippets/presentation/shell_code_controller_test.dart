import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_theme.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/snippets/presentation/shell_code_controller.dart';

void main() {
  test('indent and outdent preserve multiline reversed selection', () {
    final controller = ShellCodeController(
      text: 'echo one\necho two\necho three',
    );
    addTearDown(controller.dispose);
    controller.selection = const TextSelection(baseOffset: 18, extentOffset: 0);
    controller.indent();
    expect(controller.text, '  echo one\n  echo two\necho three');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 22, extentOffset: 2),
    );
    controller.indent(outdent: true);
    expect(controller.text, 'echo one\necho two\necho three');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 18, extentOffset: 0),
    );
  });

  test('tab uses two-space stops and does not replace a selected block', () {
    final controller = ShellCodeController(text: 'x');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 0);
    controller.indent();
    expect(controller.text, '  x');
    controller.selection = const TextSelection.collapsed(offset: 3);
    controller.indent();
    expect(controller.text, '  x ');
    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
    controller.indent();
    expect(controller.text, '    x ');
  });

  test('outdent removes spaces or a tab and clamps a caret in indentation', () {
    final controller = ShellCodeController(text: '  echo\n\techo');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.indent(outdent: true);
    expect(controller.text, 'echo\n\techo');
    expect(controller.selection.extentOffset, 0);
    controller.selection = const TextSelection.collapsed(offset: 6);
    controller.indent(outdent: true);
    expect(controller.text, 'echo\necho');
    expect(controller.selection.extentOffset, 5);
  });

  test(
    'newline retains indentation but paste and IME composition stay intact',
    () {
      const formatter = ShellIndentFormatter();
      const old = TextEditingValue(
        text: '  echo ok',
        selection: TextSelection.collapsed(offset: 9),
      );
      const newline = TextEditingValue(
        text: '  echo ok\n',
        selection: TextSelection.collapsed(offset: 10),
      );
      final indented = formatter.formatEditUpdate(old, newline);
      expect(indented.text, '  echo ok\n  ');
      expect(indented.selection.extentOffset, 12);
      const pasted = TextEditingValue(
        text: '  echo ok\nprintf ok\n',
        selection: TextSelection.collapsed(offset: 20),
      );
      expect(formatter.formatEditUpdate(old, pasted), pasted);
      final composing = newline.copyWith(
        composing: const TextRange(start: 2, end: 5),
      );
      expect(formatter.formatEditUpdate(old, composing), composing);
    },
  );

  testWidgets(
    'highlight preserves escaped quotes, comments, variables and IME spans',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: SerlinkTheme.dark(),
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final controller = ShellCodeController(
        text:
            r'echo "a\"#b" $HOME | cat # comment'
            '\n'
            r"printf '#literal' foo#bar",
      );
      addTearDown(controller.dispose);
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );
      expect(span.toPlainText(), controller.text);
      Color? colorOf(String value) => span.children!
          .cast<TextSpan>()
          .firstWhere((span) => span.text == value)
          .style
          ?.color;
      expect(colorOf(r'"a\"#b"'), SerlinkTokens.dark.statusSuccess);
      expect(colorOf(r'$HOME'), SerlinkTokens.dark.statusInfo);
      expect(colorOf('# comment'), SerlinkTokens.dark.textMuted);
      expect(colorOf("'#literal'"), SerlinkTokens.dark.statusSuccess);
      expect(
        span.children!
            .cast<TextSpan>()
            .where((span) => span.style?.color == SerlinkTokens.dark.textMuted)
            .map((span) => span.text),
        ['# comment'],
      );
      controller.value = const TextEditingValue(
        text: 'echo 你好',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 5, end: 7),
      );
      final composing = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );
      expect(composing.toPlainText(), 'echo 你好');
      expect(
        composing.children!
            .cast<TextSpan>()
            .where((span) => span.style?.decoration == TextDecoration.underline)
            .map((span) => span.text)
            .join(),
        '你好',
      );
      final previous = controller.value;
      controller.indent();
      expect(controller.value, previous);
    },
  );
}
