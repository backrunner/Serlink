import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/workspace/application/workspace_runtime_registry.dart';

void main() {
  test('terminal reflows wrapped history when the viewport widens', () {
    final registry = WorkspaceRuntimeRegistry();
    final terminal = registry.createTerminal(sessionId: SessionId('s1'));

    terminal.resize(10, 24, 0, 0);
    terminal.write('1234567890ABCDEF\r\n');

    // Sanity: at 10 columns the 16-character line soft-wraps onto two rows.
    // isWrapped marks continuation rows, not the row a logical line starts on.
    expect(terminal.lines[0].getText(), '1234567890');
    expect(terminal.lines[0].isWrapped, isFalse);
    expect(terminal.lines[1].getText(), 'ABCDEF');
    expect(terminal.lines[1].isWrapped, isTrue);

    // Dragging the window wider must unwrap the history instead of leaving
    // the wrap (and the blank right side) behind.
    terminal.resize(16, 24, 0, 0);
    expect(terminal.lines[0].getText(), '1234567890ABCDEF');
    expect(terminal.lines[0].isWrapped, isFalse);
    expect(terminal.lines[1].getText(), isNot('ABCDEF'));
  });

  test('terminal re-wraps history when the viewport narrows', () {
    final registry = WorkspaceRuntimeRegistry();
    final terminal = registry.createTerminal(sessionId: SessionId('s1'));

    terminal.resize(16, 24, 0, 0);
    terminal.write('1234567890ABCDEF\r\n');
    expect(terminal.lines[0].getText(), '1234567890ABCDEF');

    terminal.resize(10, 24, 0, 0);
    expect(terminal.lines[0].getText(), '1234567890');
    expect(terminal.lines[0].isWrapped, isFalse);
    expect(terminal.lines[1].getText(), 'ABCDEF');
    expect(terminal.lines[1].isWrapped, isTrue);
  });

  test('hard line breaks are preserved by reflow', () {
    final registry = WorkspaceRuntimeRegistry();
    final terminal = registry.createTerminal(sessionId: SessionId('s1'));

    terminal.resize(10, 24, 0, 0);
    terminal.write('abc\r\ndef\r\n');

    terminal.resize(16, 24, 0, 0);
    expect(terminal.lines[0].getText(), 'abc');
    expect(terminal.lines[0].isWrapped, isFalse);
    expect(terminal.lines[1].getText(), 'def');
    expect(terminal.lines[1].isWrapped, isFalse);
  });
}
