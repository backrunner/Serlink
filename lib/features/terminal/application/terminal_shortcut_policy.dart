import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool shouldHandleTerminalShortcutLocally(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return false;
  }
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  final isApple = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => true,
    _ => false,
  };
  final primaryModifier = isApple
      ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
            pressed.contains(LogicalKeyboardKey.metaRight)
      : pressed.contains(LogicalKeyboardKey.controlLeft) ||
            pressed.contains(LogicalKeyboardKey.controlRight);
  if (!primaryModifier) {
    return false;
  }
  final key = event.logicalKey;
  return key == LogicalKeyboardKey.keyC ||
      key == LogicalKeyboardKey.keyV ||
      key == LogicalKeyboardKey.keyA ||
      key == LogicalKeyboardKey.keyF;
}
