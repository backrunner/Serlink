import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/mcp/application/mcp_download_storage.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  test(
    'App Store resolves container storage without querying Downloads',
    () async {
      const capabilities = PlatformCapabilities(
        operatingSystem: 'macos',
        targetPlatform: TargetPlatform.macOS,
        distribution: SerlinkDistribution.appStore,
      );
      final root = await Directory.systemTemp.createTemp('mcp-container-');
      addTearDown(() => root.delete(recursive: true));
      final destination = await mcpDownloadDirectory(
        capabilities,
        supportDirectory: () async => root,
        downloadsDirectory: () =>
            throw StateError('Downloads must not be queried'),
        documentsDirectory: () =>
            throw StateError('Documents must not be queried'),
      );
      expect(destination.path, '${root.path}/mcp-downloads');
      await destination.create(recursive: true);
      final file = File('${destination.path}/download.bin');
      await file.writeAsBytes([1, 2, 3]);
      expect(await file.readAsBytes(), [1, 2, 3]);
    },
  );

  test('direct edition retains Downloads and its Documents fallback', () async {
    const capabilities = PlatformCapabilities(
      operatingSystem: 'macos',
      targetPlatform: TargetPlatform.macOS,
    );
    for (final hasDownloads in [true, false]) {
      final directory = await mcpDownloadDirectory(
        capabilities,
        supportDirectory: () => throw StateError('not container storage'),
        downloadsDirectory: () async =>
            hasDownloads ? Directory('/downloads') : null,
        documentsDirectory: () async => Directory('/documents'),
      );
      expect(directory.path, hasDownloads ? '/downloads' : '/documents');
    }
  });
}
