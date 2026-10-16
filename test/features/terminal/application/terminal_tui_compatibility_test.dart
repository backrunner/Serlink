import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  test(
    'keeps unsupported terminal query payloads out of TUI cells across chunks',
    () {
      final terminal = Terminal()..resize(80, 24);
      for (final chunk in [
        'before\x1bP+q544e;',
        '436f\x1b',
        '\\after',
        '\x1b_Gi=1;',
        'a=q\x1b\\',
        'done',
      ]) {
        terminal.write(chunk);
      }
      expect(terminal.buffer.getText().trim(), 'beforeafterdone');
    },
  );

  test(
    'restores the shell cursor and style when leaving a 1049 TUI screen',
    () {
      final terminal = Terminal()..resize(80, 24);
      terminal.write('\x1b[3;8H\x1b[31m');
      final shellColor = terminal.cursor.foreground;
      terminal.write('\x1b[?1049h');
      terminal.write('\x1b[1;1H\x1b[32mTUI\x1b[?1049l');
      terminal.write('shell');
      expect(terminal.isUsingAltBuffer, isFalse);
      expect(terminal.buffer.cursorX, 12);
      expect(terminal.buffer.cursorY, 2);
      expect(terminal.buffer.currentLine.getForeground(7), shellColor);
    },
  );

  test(
    'accepts omitted and zero cursor-position parameters used by TUI redraws',
    () {
      final terminal = Terminal()..resize(80, 24);
      terminal.write('\x1b[8H');
      expect(terminal.buffer.cursorY, 7);
      expect(terminal.buffer.cursorX, 0);
      terminal.write('\x1b[;12H');
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.buffer.cursorX, 11);
      terminal.write('\x1b[0;0H');
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.buffer.cursorX, 0);
    },
  );
}
