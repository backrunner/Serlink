import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_buffer_search_controller.dart';
import 'package:xterm/xterm.dart';

void main() {
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
