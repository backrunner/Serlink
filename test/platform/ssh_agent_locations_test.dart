import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/ssh_agent_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('serlink/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'macOS public metadata provides home, app names and container paths',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'sshAgentLocations');
        expect(call.arguments, isNull);
        return {
          'home': '/Users/example',
          'roots': [
            {
              'path':
                  '/Users/example/Library/Group Containers/GENERIC.provider/t',
              'name': 'Example Manager',
            },
            {'path': 123},
          ],
        };
      });
      final result = await loadMacSshAgentLocations();
      expect(result.home, '/Users/example');
      expect(result.roots, hasLength(1));
      expect(result.roots.single.name, 'Example Manager');
      expect(result.roots.single.path, endsWith('/GENERIC.provider/t'));
    },
  );

  for (final error in [
    MissingPluginException(),
    PlatformException(code: 'unavailable'),
  ]) {
    test(
      'missing native metadata keeps filesystem discovery available (${error.runtimeType})',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async => throw error);
        final result = await loadMacSshAgentLocations();
        expect(result.home, isNull);
        expect(result.roots, isEmpty);
      },
    );
  }
}
