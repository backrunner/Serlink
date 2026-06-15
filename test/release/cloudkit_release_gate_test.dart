import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('CloudKit bridge keeps the production schema contract stable', () {
    for (final file in [
      File('ios/Runner/CloudKitSyncChannel.swift'),
      File('macos/Runner/CloudKitSyncChannel.swift'),
    ]) {
      final source = file.readAsStringSync();

      expect(
        source,
        contains('containerIdentifier = "iCloud.com.alkinum.serlink"'),
      );
      expect(source, contains('recordType = "SerlinkSyncObject"'));
      expect(source, contains('pathField = "path"'));
      expect(source, contains('dataField = "data"'));
    }
  });

  test('macOS App Store build runs CloudKit production release gate', () {
    final script = File('tool/build_macos_app_store.sh').readAsStringSync();
    final releaseGate = File(
      'tool/check_cloudkit_release_ready.sh',
    ).readAsStringSync();

    expect(script, contains('tool/check_cloudkit_release_ready.sh'));
    expect(script, contains('--distribution app_store'));
    expect(script, contains('--require-schema-production'));
    expect(script, contains('--dart-define=SERLINK_DISTRIBUTION=app_store'));
    expect(
      script,
      contains('SERLINK_MACOS_ENTITLEMENTS=Runner/Release.entitlements'),
    );
    expect(script, contains('xcodebuild archive'));
    expect(releaseGate, contains('ios_app_store|app_store|direct|all'));
  });

  test('macOS Direct build keeps direct distribution surface', () {
    final script = File('tool/build_macos_direct.sh').readAsStringSync();

    expect(script, contains('tool/check_cloudkit_release_ready.sh'));
    expect(script, contains('--distribution direct'));
    expect(script, contains('--require-schema-production'));
    expect(script, contains('--dart-define=SERLINK_DISTRIBUTION=direct'));
    expect(
      script,
      contains('SERLINK_MACOS_ENTITLEMENTS=Runner/Direct.entitlements'),
    );
    expect(script, contains('Developer ID Application'));
  });

  test(
    'CloudKit production release documentation names the schema contract',
    () {
      final doc = File(
        'docs/cloudkit_production_release.md',
      ).readAsStringSync();

      expect(doc, contains('iCloud.com.alkinum.serlink'));
      expect(doc, contains('SerlinkSyncObject'));
      expect(doc, contains('`path`: String'));
      expect(doc, contains('`data`: Asset'));
      expect(doc, contains('SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1'));
    },
  );

  test('macOS TestFlight upload uses App Store Connect export options', () {
    final script = File('tool/upload_macos_testflight.sh').readAsStringSync();
    final exportOptions = File(
      'macos/Runner/ExportOptionsAppStore.plist',
    ).readAsStringSync();
    final docs = File('docs/macos_testflight_signing.md').readAsStringSync();

    expect(script, contains('tool/check_macos_testflight_signing.sh'));
    expect(script, contains('-allowProvisioningUpdates'));
    expect(script, contains('SERLINK_SKIP_LOCAL_SIGNING_CHECK'));
    expect(script, contains('tool/build_macos_app_store.sh'));
    expect(script, contains('xcodebuild -exportArchive'));
    expect(script, contains('ExportOptionsAppStore.plist'));
    expect(exportOptions, contains('<string>app-store-connect</string>'));
    expect(exportOptions, contains('<string>upload</string>'));
    expect(exportOptions, contains('<string>Production</string>'));
    expect(exportOptions, contains('<string>Mac App Distribution</string>'));
    expect(docs, contains('Mac App Distribution'));
    expect(docs, contains('iCloud.com.alkinum.serlink'));
  });

  test('iOS TestFlight upload uses App Store Connect export options', () {
    final script = File('tool/upload_ios_testflight.sh').readAsStringSync();
    final buildNumberScript = File(
      'tool/bump_build_number.sh',
    ).readAsStringSync();
    final signingCheck = File(
      'tool/check_ios_testflight_signing.sh',
    ).readAsStringSync();
    final exportOptions = File(
      'ios/Runner/ExportOptionsAppStore.plist',
    ).readAsStringSync();
    final docs = File('docs/ios_testflight_signing.md').readAsStringSync();

    expect(script, contains('tool/check_ios_testflight_signing.sh'));
    expect(script, contains('--distribution ios_app_store'));
    expect(script, contains('-allowProvisioningUpdates'));
    expect(script, contains('SERLINK_SKIP_LOCAL_SIGNING_CHECK'));
    expect(script, contains('tool/bump_build_number.sh'));
    expect(script, contains('--bump-build-number'));
    expect(script, contains('--build-number'));
    expect(script, contains('flutter build ios'));
    expect(script, contains('--dart-define=SERLINK_DISTRIBUTION=app_store'));
    expect(script, contains('generic/platform=iOS'));
    expect(script, contains('xcodebuild archive'));
    expect(script, contains('xcodebuild -exportArchive'));
    expect(script, contains('ExportOptionsAppStore.plist'));
    expect(signingCheck, contains('Apple Distribution'));
    expect(signingCheck, contains('get-task-allow'));
    expect(signingCheck, contains('iCloud.com.alkinum.serlink'));
    expect(buildNumberScript, contains('version: " next_version'));
    expect(buildNumberScript, contains('flutter pub get'));
    expect(exportOptions, contains('<string>app-store-connect</string>'));
    expect(exportOptions, contains('<string>upload</string>'));
    expect(exportOptions, contains('<string>Production</string>'));
    expect(exportOptions, contains('<string>Apple Distribution</string>'));
    expect(docs, contains('Apple Distribution'));
    expect(docs, contains('Product > Archive'));
    expect(docs, contains('Distribute App > App Store Connect > Upload'));
    expect(docs, contains('iCloud.com.alkinum.serlink'));
  });

  test('build number script previews the next pubspec build number', () {
    final result = Process.runSync('bash', [
      'tool/bump_build_number.sh',
      '--dry-run',
      '--no-pub-get',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      result.stdout.toString().trim(),
      matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')),
    );
  });

  test('build number script can set a specific pubspec build number', () {
    final tempRoot = Directory.systemTemp.createTempSync(
      'serlink-build-number-',
    );
    final fixture = File(p.join(tempRoot.path, 'pubspec.yaml'));
    final script = File(p.join(tempRoot.path, 'tool/bump_build_number.sh'));

    try {
      Directory(p.join(tempRoot.path, 'tool')).createSync();
      fixture.writeAsStringSync('''
name: fixture
version: 2.3.4+8
''');
      script.writeAsStringSync(
        File('tool/bump_build_number.sh').readAsStringSync(),
      );

      final result = Process.runSync('bash', [
        script.path,
        '--set',
        '42',
        '--no-pub-get',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(fixture.readAsStringSync(), contains('version: 2.3.4+42'));
    } finally {
      tempRoot.deleteSync(recursive: true);
    }
  });
}
