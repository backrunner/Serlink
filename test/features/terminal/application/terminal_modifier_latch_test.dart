import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_modifier_latch.dart';

void main() {
  group('applyTerminalModifierLatchToText', () {
    test('passes text through when no modifier is active', () {
      expect(
        applyTerminalModifierLatchToText('a', const TerminalModifierLatch()),
        'a',
      );
    });

    test('turns ctrl plus letters into control characters', () {
      expect(
        applyTerminalModifierLatchToText(
          'c',
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x03',
      );
      expect(
        applyTerminalModifierLatchToText(
          'M',
          const TerminalModifierLatch(ctrl: true),
        ),
        '\r',
      );
    });

    test('supports common ctrl punctuation and digit aliases', () {
      expect(
        applyTerminalModifierLatchToText(
          '[',
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x1b',
      );
      expect(
        applyTerminalModifierLatchToText(
          '3',
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x1b',
      );
      expect(
        applyTerminalModifierLatchToText(
          '8',
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x7f',
      );
    });

    test('prefixes alt input with escape', () {
      expect(
        applyTerminalModifierLatchToText(
          'x',
          const TerminalModifierLatch(alt: true),
        ),
        '\x1bx',
      );
    });

    test('applies shift to ascii letters, digits, and symbols', () {
      expect(
        applyTerminalModifierLatchToText(
          'a',
          const TerminalModifierLatch(shift: true),
        ),
        'A',
      );
      expect(
        applyTerminalModifierLatchToText(
          '1',
          const TerminalModifierLatch(shift: true),
        ),
        '!',
      );
      expect(
        applyTerminalModifierLatchToText(
          '/',
          const TerminalModifierLatch(shift: true),
        ),
        '?',
      );
    });

    test('leaves non-ascii and composed input unchanged', () {
      expect(
        applyTerminalModifierLatchToText(
          '你',
          const TerminalModifierLatch(ctrl: true),
        ),
        '你',
      );
      expect(
        applyTerminalModifierLatchToText(
          'ab',
          const TerminalModifierLatch(alt: true),
        ),
        'ab',
      );
    });
  });

  group('terminalControlInputSequence', () {
    test('emits basic navigation sequences', () {
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.arrowUp,
          const TerminalModifierLatch(),
        ),
        '\x1b[A',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.pageDown,
          const TerminalModifierLatch(),
        ),
        '\x1b[6~',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.insert,
          const TerminalModifierLatch(),
        ),
        '\x1b[2~',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.delete,
          const TerminalModifierLatch(),
        ),
        '\x1b[3~',
      );
    });

    test('adds xterm modifier codes for navigation keys', () {
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.arrowRight,
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x1b[1;5C',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.pageUp,
          const TerminalModifierLatch(ctrl: true, alt: true, shift: true),
        ),
        '\x1b[5;8~',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.insert,
          const TerminalModifierLatch(ctrl: true),
        ),
        '\x1b[2;5~',
      );
    });

    test('emits function key sequences', () {
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.f1,
          const TerminalModifierLatch(),
        ),
        '\x1bOP',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.f4,
          const TerminalModifierLatch(alt: true),
        ),
        '\x1bO3S',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.f5,
          const TerminalModifierLatch(),
        ),
        '\x1b[15~',
      );
      expect(
        terminalControlInputSequence(
          TerminalControlInputKey.f12,
          const TerminalModifierLatch(shift: true, alt: true),
        ),
        '\x1b[24;4~',
      );
    });
  });
}
