import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_shortcut_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    HardwareKeyboard.instance.clearState();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.android,
  ]) {
    test('$platform keeps bare Ctrl keys remote', () {
      debugDefaultTargetPlatformOverride = platform;
      HardwareKeyboard.instance.clearState();
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          timeStamp: Duration.zero,
          logicalKey: LogicalKeyboardKey.controlLeft,
          physicalKey: PhysicalKeyboardKey.controlLeft,
        ),
      );
      for (final key in [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyF,
      ]) {
        expect(
          shouldHandleTerminalShortcutLocally(
            KeyDownEvent(
              timeStamp: Duration.zero,
              logicalKey: key,
              physicalKey: PhysicalKeyboardKey.keyA,
            ),
          ),
          isFalse,
        );
      }
    });
  }

  test('treats common edit shortcuts as local terminal shortcuts', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
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

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        logicalKey: LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
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
