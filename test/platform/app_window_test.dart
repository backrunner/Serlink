import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/app_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('activate invokes the desktop window channel when supported', () async {
    const channel = MethodChannel('serlink/window');
    final methods = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    await AppWindow.activate();

    expect(methods, AppWindow.isSupported ? ['activate'] : isEmpty);
  });
}
