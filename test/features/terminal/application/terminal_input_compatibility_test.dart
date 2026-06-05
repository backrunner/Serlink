import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accepts CJK text input through TerminalView', (tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    binding.testTextInput.enterText('你好世界');
    await binding.idle();

    expect(output.join(), '你好世界');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('accepts emoji text input through TerminalView', (tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    binding.testTextInput.enterText('deploy 🚀');
    await binding.idle();

    expect(output.join(), 'deploy 🚀');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('accepts combining character text input through TerminalView', (
    tester,
  ) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    binding.testTextInput.enterText('e\u0301');
    await binding.idle();

    expect(output.join(), 'e\u0301');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('allows software keyboard insert interception', (tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            autofocus: true,
            onInsertText: (text) => text == 'a' ? 'A' : text,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    binding.testTextInput.enterText('a');
    await binding.idle();

    expect(output.join(), 'A');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('does not apply safe area padding inside TerminalView', (
    tester,
  ) async {
    final terminal = Terminal();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: SizedBox(
              width: 390,
              height: 300,
              child: TerminalView(terminal, padding: EdgeInsets.zero),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final terminalViewState =
        tester.state(find.byType(TerminalView)) as dynamic;
    final firstCellOffset =
        terminalViewState.renderTerminal.getOffset(const CellOffset(0, 0))
            as Offset;

    expect(firstCellOffset.dy, 0);
  });

  test('encodes arrow keys with terminal cursor key mode', () {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    terminal.keyInput(TerminalKey.arrowUp);
    terminal.setCursorKeysMode(true);
    terminal.keyInput(TerminalKey.arrowUp);

    expect(output, ['\x1b[A', '\x1bOA']);
  });
}
