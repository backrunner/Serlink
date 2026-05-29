import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_paste_guard.dart';

void main() {
  group('TerminalPasteGuard', () {
    test('does not require confirmation for normal enter key output', () {
      expect(TerminalPasteGuard.needsConfirmation('ls -la\r'), isFalse);
    });

    test('requires confirmation for bracketed multiline paste', () {
      expect(
        TerminalPasteGuard.needsConfirmation('\x1b[200~ls\npwd\x1b[201~'),
        isTrue,
      );
    });

    test(
      'does not treat a single pasted line with trailing newline as multiline',
      () {
        expect(
          TerminalPasteGuard.needsConfirmation('\x1b[200~ls -la\n\x1b[201~'),
          isFalse,
        );
      },
    );

    test('strips bracketed paste delimiters from preview', () {
      expect(
        TerminalPasteGuard.preview('\x1b[200~ls\r\npwd\x1b[201~'),
        'ls\npwd',
      );
    });
  });
}
