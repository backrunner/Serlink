import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_shortcut_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('treats common edit shortcuts as local terminal shortcuts', () {
    final event = KeyDownEvent(
      timeStamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.keyF,
      physicalKey: PhysicalKeyboardKey.keyF,
      character: 'f',
    );

    HardwareKeyboard.instance.clearState();
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        logicalKey: LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      ),
    );

    expect(shouldHandleTerminalShortcutLocally(event), isTrue);
  });

  test('does not keep arbitrary control shortcuts local', () {
    final event = KeyDownEvent(
      timeStamp: Duration.zero,
      logicalKey: LogicalKeyboardKey.keyK,
      physicalKey: PhysicalKeyboardKey.keyK,
      character: 'k',
    );

    HardwareKeyboard.instance.clearState();
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        logicalKey: LogicalKeyboardKey.controlLeft,
        physicalKey: PhysicalKeyboardKey.controlLeft,
      ),
    );

    expect(shouldHandleTerminalShortcutLocally(event), isFalse);
  });
}
