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

  testWidgets('does not duplicate committed composing text', (tester) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    binding.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "'",
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    binding.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "'",
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    binding.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "'d",
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await binding.idle();

    expect(output.join(), "'d");
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('passes Flutter view id to text input configuration', (
    tester,
  ) async {
    final terminal = Terminal();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerminalView(terminal, autofocus: true)),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    final setClientCall = binding.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    final args = setClientCall.arguments! as List<Object?>;
    final config = args[1]! as Map<String, Object?>;

    expect(config['viewId'], isNotNull);
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

  testWidgets('detects repeated software keyboard backspace when enabled', (
    tester,
  ) async {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true, deleteDetection: true),
        ),
      ),
    );

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 200));

    for (var i = 0; i < 3; i += 1) {
      binding.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await binding.idle();
    }

    expect(output.join(), '\x7f\x7f\x7f');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('keeps software keyboard delete detection opt-in', (
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

    binding.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
    await binding.idle();

    expect(output.join(), isNot(contains('\x7f')));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('deferred keyboard activation waits for a completed tap', (
    tester,
  ) async {
    final terminal = Terminal();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, deferKeyboardActivation: true),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TerminalView)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.testTextInput.isVisible, isFalse);

    await gesture.up();
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('long press selects text without opening the keyboard', (
    tester,
  ) async {
    final terminal = Terminal(maxLines: 200)
      ..write(
        [for (var i = 0; i < 80; i += 1) 'copy terminal line $i\r\n'].join(),
      );
    final controller = TerminalController();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: TerminalView(
              terminal,
              controller: controller,
              scrollController: scrollController,
              deferKeyboardActivation: true,
            ),
          ),
        ),
      ),
    );
    tester.testTextInput.log.clear();

    final terminalFinder = find.byType(TerminalView);
    final terminalRect = tester.getRect(terminalFinder);
    expect(scrollController.position.maxScrollExtent, greaterThan(0));
    scrollController.jumpTo(scrollController.position.maxScrollExtent / 2);
    await tester.pump();
    final scrollOffsetBeforeLongPress = scrollController.offset;

    await tester.longPressAt(terminalRect.centerLeft + const Offset(24, 0));
    await tester.pump();

    expect(controller.selection, isNotNull);
    expect(scrollController.offset, closeTo(scrollOffsetBeforeLongPress, 0.01));
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.show')),
    );
  });

  testWidgets('short and long swipes do not open the keyboard', (tester) async {
    final terminal = Terminal(maxLines: 200)
      ..write([for (var i = 0; i < 80; i += 1) 'line $i\r\n'].join());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: TerminalView(terminal, deferKeyboardActivation: true),
          ),
        ),
      ),
    );

    final terminalFinder = find.byType(TerminalView);
    await tester.timedDrag(
      terminalFinder,
      const Offset(0, -32),
      const Duration(milliseconds: 80),
    );
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);

    await tester.timedDrag(
      terminalFinder,
      const Offset(0, 140),
      const Duration(milliseconds: 700),
    );
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      tester.testTextInput.log.map((call) => call.method),
      isNot(contains('TextInput.show')),
    );
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

  test('reports cursor position using one-based CPR coordinates', () {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    terminal.write('\x1b[2;3H\x1b[6n');

    expect(output, ['\x1b[2;3R']);
  });

  test('handles forward and backward cursor tab CSI sequences', () {
    final terminal = Terminal();
    terminal.resize(40, 8);

    terminal.write('\x1b[2I');
    expect(terminal.buffer.cursorX, 16);

    terminal.write('\x1b[12G\x1b[Z');
    expect(terminal.buffer.cursorX, 8);
  });

  test('keeps scroll-region buffer lines attached after scroll moves', () {
    final terminal = Terminal(maxLines: 100);
    terminal.resize(20, 8);
    terminal.setMargins(1, 6);

    terminal.scrollUp(1);
    _expectAllBufferLinesAttached(terminal);

    terminal.scrollDown(1);
    _expectAllBufferLinesAttached(terminal);
  });

  test('uses Apple option-arrow sequences on iOS hardware keyboards', () {
    final output = <String>[];
    final terminal = Terminal(
      onOutput: output.add,
      platform: TerminalTargetPlatform.ios,
    );

    terminal.keyInput(TerminalKey.arrowRight, alt: true);
    terminal.keyInput(TerminalKey.arrowLeft, alt: true);

    expect(output, ['\x1bf', '\x1bb']);
  });

  test('does not synthesize escape-prefixed option characters on iOS', () {
    final output = <String>[];
    final terminal = Terminal(
      onOutput: output.add,
      platform: TerminalTargetPlatform.ios,
    );

    final handled = terminal.charInput('a'.codeUnitAt(0), alt: true);

    expect(handled, isFalse);
    expect(output, isEmpty);
  });
}

void _expectAllBufferLinesAttached(Terminal terminal) {
  final lines = terminal.buffer.lines as dynamic;
  for (var i = 0; i < terminal.buffer.height; i += 1) {
    expect(lines[i].attached, isTrue, reason: 'line $i should stay attached');
  }
}
