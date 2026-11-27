import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS copies a touch selection to the system clipboard', (
    tester,
  ) async {
    final reports = <String>[];
    final terminal = Terminal(onOutput: reports.add);
    final view = GlobalKey<TerminalViewState>();
    final controller = TerminalController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: TerminalView(
              terminal,
              key: view,
              controller: controller,
              deferKeyboardActivation: true,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ),
    );
    terminal.write('\x1b[?1000h\x1b[?1006hfirst chosen word\r\n第二行 done');
    await tester.pump();

    final render = view.currentState!.renderTerminal;
    Offset cell(int column, int row) => render.localToGlobal(
      render.getOffset(CellOffset(column, row)) +
          render.cellSize.center(Offset.zero),
    );
    final copy = find.text('Copy');
    await tester.longPressAt(cell(7, 0));
    await tester.pumpAndSettle();
    expect(copy, findsOneWidget);
    expect(view.currentState!.hasInputConnection, isFalse);
    expect(terminal.buffer.getText(controller.selection!), 'chosen');

    final endHandle = find.byKey(const ValueKey(TextSelectionHandleType.right));
    await tester.dragFrom(
      tester.getCenter(endHandle),
      cell(6, 1) - cell(12, 0),
    );
    await tester.pumpAndSettle();
    final startHandle = find.byKey(
      const ValueKey(TextSelectionHandleType.left),
    );
    await tester.dragFrom(
      tester.getCenter(startHandle),
      cell(2, 0) - cell(6, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text,
      'rst chosen word\n第二行',
    );
    expect(controller.selection, isNull);
    expect(copy, findsNothing);

    await tester.tapAt(cell(2, 0));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(cell(2, 0));
    await tester.pumpAndSettle();
    expect(copy, findsOneWidget);
    expect(view.currentState!.hasInputConnection, isFalse);
    expect(reports, isEmpty);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, 'first');

    // Both halves of a wide character belong to the same word.
    await tester.longPressAt(cell(3, 1));
    await tester.pumpAndSettle();
    expect(terminal.buffer.getText(controller.selection!), '第二行');
    // Ending the selection inside 二 includes the whole character.
    final grip = tester.getCenter(endHandle);
    final drag = await tester.startGesture(grip);
    await drag.moveBy(const Offset(60, 0));
    await tester.pump();
    await drag.moveTo(grip + cell(3, 1) - cell(6, 1));
    await drag.up();
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, '第二');

    await tester.tapAt(cell(2, 0));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(view.currentState!.hasInputConnection, isTrue);
    expect(reports, ['\x1b[<0;3;1M', '\x1b[<0;3;1m']);
  }, skip: !Platform.isIOS);
}
