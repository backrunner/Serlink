import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_buffer_search_controller.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('repeated searches release anchors and publish one update', () {
    final terminal = Terminal(maxLines: 1024);
    terminal.write(List.filled(1000, 'needle\r\n').join());
    final controller = TerminalController();
    final search = TerminalBufferSearchController(
      terminal: terminal,
      controller: controller,
    );
    final unrelated = controller.highlight(
      p1: terminal.buffer.createAnchor(0, 0),
      p2: terminal.buffer.createAnchor(1, 0),
      color: const Color(0xff000000),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    for (var i = 0; i < 8; i++) {
      expect(search.search('needle').matchCount, 1000);
    }
    expect(notifications, 8);
    search.clear();
    expect(notifications, 9);
    expect(controller.highlights, [unrelated]);
    expect(_anchorCount(terminal), 2);
    unrelated.dispose();
    unrelated.dispose();
    expect(_anchorCount(terminal), 0);
    search.search('needle');
    controller.dispose();
    expect(_anchorCount(terminal), 0);
  });

  test('search highlights matches and selects the current match', () {
    final terminal = Terminal(maxLines: 100);
    final controller = TerminalController();
    final search = TerminalBufferSearchController(
      terminal: terminal,
      controller: controller,
    );

    terminal.write('alpha beta\r\nbeta gamma');

    final result = search.search('beta');

    expect(result.matchCount, 2);
    expect(result.displayIndex, 1);
    expect(controller.highlights, hasLength(2));
    expect(controller.selection, isNotNull);
  });

  test('next and previous wrap around match list', () {
    final terminal = Terminal(maxLines: 100);
    final controller = TerminalController();
    final search = TerminalBufferSearchController(
      terminal: terminal,
      controller: controller,
    );

    terminal.write('one one');
    search.search('one');

    expect(search.next().displayIndex, 2);
    expect(search.next().displayIndex, 1);
    expect(search.previous().displayIndex, 2);
  });

  test('clear removes highlights and selection', () {
    final terminal = Terminal(maxLines: 100);
    final controller = TerminalController();
    final search = TerminalBufferSearchController(
      terminal: terminal,
      controller: controller,
    );

    terminal.write('needle');
    search.search('needle');
    search.clear();

    expect(controller.highlights, isEmpty);
    expect(controller.selection, isNull);
  });
}

int _anchorCount(Terminal terminal) => List.generate(
  terminal.buffer.height,
  (y) => terminal.buffer.lines[y].anchors.length,
).fold(0, (sum, count) => sum + count);
