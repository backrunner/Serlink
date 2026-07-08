import 'dart:io';

import 'package:flutter/services.dart';

class AppWindow {
  const AppWindow._();

  static const MethodChannel _channel = MethodChannel('serlink/window');

  static bool get isSupported {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get usesCustomChrome {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get usesMacStyleChrome {
    return Platform.isMacOS;
  }

  static bool get usesTrailingWindowControls {
    return Platform.isWindows || Platform.isLinux;
  }

  static bool get needsFlutterSurfaceClip {
    return Platform.isLinux;
  }

  static Future<void> activate() async {
    await _invoke<void>('activate');
  }

  static Future<void> minimize() async {
    await _invoke<void>('minimize');
  }

  static Future<bool> toggleMaximize() async {
    return await _invoke<bool>('toggleMaximize') ?? false;
  }

  static Future<bool> isMaximized() async {
    return await _invoke<bool>('isMaximized') ?? false;
  }

  static Future<void> close() async {
    await _invoke<void>('close');
  }

  static Future<void> startDrag() async {
    await _invoke<void>('startDrag');
  }

  static Future<void> setWindowDraggingEnabled(bool enabled) async {
    await _invoke<void>('setWindowDraggingEnabled', enabled);
  }

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }
}

class DesktopWindowMetrics {
  const DesktopWindowMetrics._();

  static const double cornerRadius = 12;
}
