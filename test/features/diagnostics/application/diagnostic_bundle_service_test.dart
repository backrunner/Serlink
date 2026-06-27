import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:serlink/core/logging/offline_diagnostic_logger.dart';
import 'package:serlink/core/runtime/runtime_mode.dart';
import 'package:serlink/features/diagnostics/application/diagnostic_bundle_service.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test(
    'exports build metadata and redacts sensitive diagnostic content',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'good passphrase');

      final bundle = await DiagnosticBundleService(
        vault: vault,
        runtime: const RuntimeCapabilities(
          mode: SerlinkRuntimeMode.release,
          verboseRedactedLogging: false,
          crashReporting: true,
          unsafeDiagnosticsAllowed: false,
        ),
        packageInfoLoader: () async => PackageInfo(
          appName: 'Serlink',
          packageName: 'space.serlink.app',
          version: '1.0.0',
          buildNumber: '42',
        ),
        sentryLastEventId: () =>
            SentryId.fromId('1234567890abcdef1234567890abcdef'),
      ).buildRedactedBundle();

      final entries = _readStoredZipEntries(bundle.bytes);
      expect(
        entries.keys,
        containsAll(['manifest.json', 'logs/runtime-debug.log']),
      );

      final manifest =
          jsonDecode(utf8.decode(entries['manifest.json']!))
              as Map<String, Object?>;
      final app = manifest['app'] as Map<String, Object?>;

      expect(app['version'], '1.0.0');
      expect(app['buildNumber'], '42');
      expect(manifest['runtimeMode'], 'release');
      expect(manifest['lastSentryEventId'], '1234567890abcdef1234567890abcdef');
      expect(manifest['files'].toString(), contains('logs/runtime-debug.log'));
      expect(manifest['excludedData'], contains('terminal output'));
      expect(manifest['excludedData'], contains('private keys'));

      final logText = utf8.decode(entries['logs/runtime-debug.log']!);
      expect(logText, contains('Serlink Runtime Debug Log'));
      expect(logText, contains('No runtime debug log was found.'));

      final serialized = String.fromCharCodes(bundle.bytes);
      expect(serialized, isNot(contains('good passphrase')));
    },
  );

  test('omits empty Sentry event id', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );

    final bundle = await DiagnosticBundleService(
      vault: vault,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Serlink',
        packageName: 'space.serlink.app',
        version: '1.0.0',
        buildNumber: '42',
      ),
      sentryLastEventId: () => const SentryId.empty(),
    ).buildRedactedBundle();
    final entries = _readStoredZipEntries(bundle.bytes);
    final manifest =
        jsonDecode(utf8.decode(entries['manifest.json']!))
            as Map<String, Object?>;

    expect(manifest.containsKey('lastSentryEventId'), isFalse);
  });

  test('exports redacted offline logs inside diagnostic zip', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );

    final bundle = await DiagnosticBundleService(
      vault: vault,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Serlink',
        packageName: 'space.serlink.app',
        version: '1.0.0',
        buildNumber: '42',
      ),
      logTailReader: () async => const [
        'debug password=hunter2 command=ssh user=root host=example.test',
      ],
    ).buildRedactedBundle();

    final entries = _readStoredZipEntries(bundle.bytes);
    final logText = utf8.decode(entries['logs/runtime-debug.log']!);

    expect(logText, contains('Serlink Runtime Debug Log'));
    expect(logText, contains('[redacted]'));
    expect(logText, isNot(contains('hunter2')));
    expect(logText, isNot(contains('example.test')));
  });

  test('exports rotated offline log files inside diagnostic zip', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );

    final bundle = await DiagnosticBundleService(
      vault: vault,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Serlink',
        packageName: 'space.serlink.app',
        version: '1.0.0',
        buildNumber: '42',
      ),
      logFileReader: () async => [
        DiagnosticLogFile(
          name: '../serlink-2026-06-26.log',
          bytes: utf8.encode('host=example.test password=hunter2\n'),
          lineCount: 1,
        ),
        DiagnosticLogFile(
          name: 'serlink-2026-06-27.1.log',
          bytes: utf8.encode('event=sync.push.success recordsUploaded=1\n'),
          lineCount: 1,
        ),
      ],
    ).buildRedactedBundle();

    final entries = _readStoredZipEntries(bundle.bytes);

    expect(entries.keys, contains('logs/serlink-2026-06-26.log'));
    expect(entries.keys, contains('logs/serlink-2026-06-27.1.log'));
    expect(
      utf8.decode(entries['logs/serlink-2026-06-27.1.log']!),
      contains('sync.push'),
    );
    final rotated = utf8.decode(entries['logs/serlink-2026-06-26.log']!);
    expect(rotated, contains('[redacted]'));
    expect(rotated, isNot(contains('hunter2')));
    expect(rotated, isNot(contains('example.test')));
  });

  test('exports redacted runtime debug logs separately', () async {
    final vault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );

    final logExport = await DiagnosticBundleService(
      vault: vault,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Serlink',
        packageName: 'space.serlink.app',
        version: '1.0.0',
        buildNumber: '42',
      ),
      logTailReader: () async => const [
        'debug password=hunter2 command=ssh user=root host=example.test',
      ],
    ).buildRedactedRuntimeDebugLog();

    final serialized = utf8.decode(logExport.bytes);
    expect(serialized, contains('Serlink Runtime Debug Log'));
    expect(serialized, contains('[redacted]'));
    expect(serialized, isNot(contains('hunter2')));
    expect(serialized, isNot(contains('example.test')));
  });
}

Map<String, List<int>> _readStoredZipEntries(List<int> bytes) {
  final entries = <String, List<int>>{};
  var offset = 0;
  while (offset + 4 <= bytes.length) {
    final signature = _uint32(bytes, offset);
    if (signature != 0x04034b50) {
      break;
    }

    final compressionMethod = _uint16(bytes, offset + 8);
    expect(compressionMethod, 0);
    final compressedSize = _uint32(bytes, offset + 18);
    final nameLength = _uint16(bytes, offset + 26);
    final extraLength = _uint16(bytes, offset + 28);
    final nameStart = offset + 30;
    final dataStart = nameStart + nameLength + extraLength;
    final dataEnd = dataStart + compressedSize;
    final name = utf8.decode(bytes.sublist(nameStart, nameStart + nameLength));
    entries[name] = bytes.sublist(dataStart, dataEnd);
    offset = dataEnd;
  }
  return entries;
}

int _uint16(List<int> bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _uint32(List<int> bytes, int offset) {
  return _uint16(bytes, offset) | (_uint16(bytes, offset + 2) << 16);
}
