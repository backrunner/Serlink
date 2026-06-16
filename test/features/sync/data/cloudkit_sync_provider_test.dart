import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/data/cloudkit_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'writeManifestIfUnchanged forwards expected bytes to native bridge',
    () async {
      const channel = MethodChannel('serlink/cloudkit_test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final provider = CloudKitSyncProvider(channel: channel);
      final current = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        encryptedPayload: [1, 2, 3],
      );
      final next = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        encryptedPayload: [4, 5, 6],
      );
      final calls = <MethodCall>[];
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });

      await provider.writeManifestIfUnchanged(next, current);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'writeObjectIfUnchanged');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['path'], 'manifest.json');
      expect(arguments['data'], isA<Uint8List>());
      expect(arguments['expectedData'], isA<Uint8List>());
      expect(arguments['data'], next.toBytes());
      expect(arguments['expectedData'], current.toBytes());
    },
  );

  test(
    'writeManifestIfUnchanged sends null expected bytes for empty remote',
    () async {
      const channel = MethodChannel('serlink/cloudkit_test_empty');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final provider = CloudKitSyncProvider(channel: channel);
      final next = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        encryptedPayload: [4, 5, 6],
      );
      Map<Object?, Object?>? capturedArguments;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        capturedArguments = call.arguments as Map<Object?, Object?>;
        return null;
      });

      await provider.writeManifestIfUnchanged(next, null);

      expect(capturedArguments?['expectedData'], isNull);
    },
  );

  test('CloudKitSyncChange parses remote change events defensively', () {
    final change = CloudKitSyncChange.tryParse({
      'type': 'remoteChange',
      'source': 'push',
      'receivedAt': '2026-06-17T09:00:00Z',
    });

    expect(change, isNotNull);
    expect(change!.source, 'push');
    expect(change.receivedAt, DateTime.utc(2026, 6, 17, 9));
    expect(CloudKitSyncChange.tryParse({'type': 'other'}), isNull);
    expect(CloudKitSyncChange.tryParse('not-a-map'), isNull);
  });
}
