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
    final terminal = Terminal();
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
    terminal.write('first chosen word\r\n第二行 done');
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
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, 'first');
  }, skip: !Platform.isIOS);
}
