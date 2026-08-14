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

  /// Replies to a native `requestTerminate` call (macOS). Safe to invoke on
  /// other platforms: platforms without a native `replyTerminate` handler
  /// raise [MissingPluginException], which is swallowed.
  static Future<void> replyTerminate(bool confirmed) async {
    await _invoke<void>('replyTerminate', confirmed);
  }

  static Future<bool> Function()? _terminateRequestHandler;

  /// Registers a handler invoked when the native side asks whether the app
  /// may terminate (macOS Cmd+Q, Dock quit, logout). The handler returns
  /// true to allow termination. Only wired up on macOS; a no-op elsewhere.
  static void setTerminateRequestHandler(Future<bool> Function()? handler) {
    if (!Platform.isMacOS) {
      return;
    }
    _terminateRequestHandler = handler;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'requestTerminate') {
      return;
    }
    final handler = _terminateRequestHandler;
    if (handler == null) {
      return;
    }
    var confirmed = true;
    try {
      confirmed = await handler();
    } catch (_) {
      // Never wedge quitting (or an OS logout) on a handler failure.
      confirmed = true;
    }
    await replyTerminate(confirmed);
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
