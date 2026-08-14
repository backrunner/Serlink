import 'dart:io';

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

  test(
    'replyTerminate invokes the desktop window channel when supported',
    () async {
      const channel = MethodChannel('serlink/window');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });

      await AppWindow.replyTerminate(true);

      if (AppWindow.isSupported) {
        expect(calls, hasLength(1));
        expect(calls.single.method, 'replyTerminate');
        expect(calls.single.arguments, isTrue);
      } else {
        expect(calls, isEmpty);
      }
    },
  );

  test(
    'terminate request handler answers through replyTerminate',
    () async {
      if (!Platform.isMacOS) {
        return;
      }
      const channel = MethodChannel('serlink/window');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        AppWindow.setTerminateRequestHandler(null);
      });

      AppWindow.setTerminateRequestHandler(() async => false);

      await messenger.handlePlatformMessage(
        'serlink/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('requestTerminate'),
        ),
        (_) {},
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'replyTerminate');
      expect(calls.single.arguments, isFalse);
    },
  );
}
