import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

      final decoded =
          jsonDecode(utf8.decode(bundle.bytes)) as Map<String, Object?>;
      final manifest = decoded['manifest'] as Map<String, Object?>;
      final app = manifest['app'] as Map<String, Object?>;

      expect(app['version'], '1.0.0');
      expect(app['buildNumber'], '42');
      expect(manifest['runtimeMode'], 'release');
      expect(manifest['lastSentryEventId'], '1234567890abcdef1234567890abcdef');
      expect(manifest['excludedData'], contains('terminal output'));
      expect(manifest['excludedData'], contains('private keys'));

      final serialized = utf8.decode(bundle.bytes);
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
    final decoded =
        jsonDecode(utf8.decode(bundle.bytes)) as Map<String, Object?>;
    final manifest = decoded['manifest'] as Map<String, Object?>;

    expect(manifest.containsKey('lastSentryEventId'), isFalse);
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
