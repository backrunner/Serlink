import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/document_gateway.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformChannel = MethodChannel('serlink/platform');
  late FileSelectorPlatform originalPlatform;
  late _FakeFileSelectorPlatform fakePlatform;
  late Directory tempDirectory;

  setUp(() async {
    originalPlatform = FileSelectorPlatform.instance;
    fakePlatform = _FakeFileSelectorPlatform();
    FileSelectorPlatform.instance = fakePlatform;
    tempDirectory = await Directory.systemTemp.createTemp(
      'serlink_document_gateway_test_',
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
    FileSelectorPlatform.instance = originalPlatform;
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'presents iOS file actions using a path without copying file bytes',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformChannel, (call) async {
            received = call;
            return true;
          });
      const gateway = DocumentGateway(
        capabilities: PlatformCapabilities(
          operatingSystem: 'ios',
          targetPlatform: TargetPlatform.iOS,
        ),
      );
      expect(
        await gateway.openLocalFile('/Documents/Downloads/report.pdf'),
        isTrue,
      );
      expect(received?.method, 'openLocalFile');
      expect(received?.arguments, {'path': '/Documents/Downloads/report.pdf'});
      expect(fakePlatform.suggestedName, isNull);
    },
  );

  test('propagates native presentation failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (_) async {
          throw PlatformException(code: 'file_unavailable');
        });
    const gateway = DocumentGateway(
      capabilities: PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await expectLater(
      gateway.openLocalFile('/missing.pdf'),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'exports local files through saveTo on iOS document locations',
    () async {
      final source = File('${tempDirectory.path}/source.txt');
      final destination = File('${tempDirectory.path}/exported.txt');
      await source.writeAsString('hello from ios');
      fakePlatform.saveLocation = FileSaveLocation(destination.path);

      final gateway = DocumentGateway(
        capabilities: const PlatformCapabilities(
          operatingSystem: 'ios',
          targetPlatform: TargetPlatform.iOS,
        ),
      );

      final exported = await gateway.exportLocalFile(
        source.path,
        suggestedName: 'out.txt',
      );

      expect(exported, isTrue);
      expect(fakePlatform.suggestedName, 'out.txt');
      expect(await destination.readAsString(), 'hello from ios');
    },
  );

  test('keeps stable path export behavior on macOS', () async {
    final source = File('${tempDirectory.path}/source.txt');
    final destination = File('${tempDirectory.path}/exported.txt');
    await source.writeAsString('hello from mac');
    fakePlatform.saveLocation = FileSaveLocation(destination.path);

    final gateway = DocumentGateway(
      capabilities: const PlatformCapabilities(
        operatingSystem: 'macos',
        targetPlatform: TargetPlatform.macOS,
      ),
    );

    final exported = await gateway.exportLocalFile(source.path);

    expect(exported, isTrue);
    expect(fakePlatform.suggestedName, 'source.txt');
    expect(await destination.readAsString(), 'hello from mac');
  });
}

class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  FileSaveLocation? saveLocation;
  String? suggestedName;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    suggestedName = options.suggestedName;
    return saveLocation;
  }
}
