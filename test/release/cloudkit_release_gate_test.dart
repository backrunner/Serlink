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

  test(
    'release channels share one production CloudKit container and schema',
    () {
      const containerId = 'iCloud.com.alkinum.serlink';
      const recordType = 'SerlinkSyncObject';
      const eventChannel = 'serlink/cloudkit/events';
      const subscriptionId = 'serlink-sync-objects';

      for (final entitlement in const [
        'ios/Runner/Release.entitlements',
        'macos/Runner/Release.entitlements',
        'macos/Runner/Direct.entitlements',
      ]) {
        final services = _plistValue(
          entitlement,
          'com.apple.developer.icloud-services',
        );
        final containers = _plistValue(
          entitlement,
          'com.apple.developer.icloud-container-identifiers',
        );
        final environment = _plistValue(
          entitlement,
          'com.apple.developer.icloud-container-environment',
        );
        final apsEnvironment = _plistValue(
          entitlement,
          entitlement.startsWith('ios/')
              ? 'aps-environment'
              : 'com.apple.developer.aps-environment',
        );

        expect(services, contains('CloudKit'), reason: entitlement);
        expect(containers, contains(containerId), reason: entitlement);
        expect(
          environment.isEmpty || environment.contains('Production'),
          isTrue,
          reason: '$entitlement must not point at CloudKit Development',
        );
        expect(apsEnvironment, contains('production'), reason: entitlement);
      }

      final iosProject = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(iosProject, contains('com.apple.Push'));

      for (final bridge in const [
        'ios/Runner/CloudKitSyncChannel.swift',
        'macos/Runner/CloudKitSyncChannel.swift',
      ]) {
        final source = File(bridge).readAsStringSync();
        expect(
          source,
          contains('containerIdentifier = "$containerId"'),
          reason: bridge,
        );
        expect(source, contains('recordType = "$recordType"'), reason: bridge);
        expect(
          source,
          contains('eventsChannelName = "$eventChannel"'),
          reason: bridge,
        );
        expect(
          source,
          contains('subscriptionID = "$subscriptionId"'),
          reason: bridge,
        );
        expect(source, contains('writeObjectIfUnchanged'), reason: bridge);
      }
    },
  );

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
    expect(script, contains('ALLOW_PROVISIONING_UPDATES'));
    expect(script, contains('SERLINK_MACOS_CODE_SIGN_IDENTITY'));
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
      final commandDoc = File(
        'docs/development_release_commands.md',
      ).readAsStringSync();
      final iosReleaseDoc = File('docs/ios_release.md').readAsStringSync();
      final macosReleaseDoc = File('docs/macos_release.md').readAsStringSync();

      expect(doc, contains('iCloud.com.alkinum.serlink'));
      expect(doc, contains('SerlinkSyncObject'));
      expect(doc, contains('`path`: String'));
      expect(doc, contains('`data`: Asset'));
      expect(doc, contains('SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1'));
      expect(doc, contains('docs/ios_release.md'));
      expect(doc, contains('docs/macos_release.md'));
      expect(commandDoc, contains('upload_ios_testflight.sh'));
      expect(commandDoc, contains('upload_macos_testflight.sh'));
      expect(commandDoc, contains('--bump-build-number'));
      expect(commandDoc, contains('-allowProvisioningUpdates'));
      expect(commandDoc, contains('sips -g hasAlpha'));
      expect(commandDoc, contains('docs/ios_release.md'));
      expect(commandDoc, contains('docs/macos_release.md'));
      expect(iosReleaseDoc, contains('ios/Runner.xcworkspace'));
      expect(iosReleaseDoc, contains('cd ios && pod install && cd ..'));
      expect(iosReleaseDoc, contains('upload_ios_testflight.sh'));
      expect(iosReleaseDoc, contains('--distribution ios_app_store'));
      expect(iosReleaseDoc, contains('Product > Archive'));
      expect(iosReleaseDoc, contains('Distribute App > App Store Connect'));
      expect(macosReleaseDoc, contains('macos/Runner.xcworkspace'));
      expect(macosReleaseDoc, contains('cd macos && pod install && cd ..'));
      expect(macosReleaseDoc, contains('upload_macos_testflight.sh'));
      expect(macosReleaseDoc, contains('build_macos_direct.sh'));
      expect(macosReleaseDoc, contains('SERLINK_DISTRIBUTION=direct'));
      expect(macosReleaseDoc, contains('Developer ID Application'));
    },
  );

  test('macOS TestFlight upload uses App Store Connect export options', () {
    final script = File('tool/upload_macos_testflight.sh').readAsStringSync();
    final appInfo = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final infoPlist = File('macos/Runner/Info.plist').readAsStringSync();
    final project = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final signingCheck = File(
      'tool/check_macos_testflight_signing.sh',
    ).readAsStringSync();
    final exportOptions = File(
      'macos/Runner/ExportOptionsAppStore.plist',
    ).readAsStringSync();
    final docs = File('docs/macos_testflight_signing.md').readAsStringSync();

    expect(script, contains('tool/check_macos_testflight_signing.sh'));
    expect(script, contains('-allowProvisioningUpdates'));
    expect(script, contains('SERLINK_SKIP_LOCAL_SIGNING_CHECK'));
    expect(script, contains('tool/bump_build_number.sh'));
    expect(script, contains('--platform macos'));
    expect(script, contains('--bump-build-number'));
    expect(script, contains('--build-number'));
    expect(script, contains('tool/build_macos_app_store.sh'));
    expect(script, contains('xcodebuild -exportArchive'));
    expect(script, contains('ExportOptionsAppStore.plist'));
    expect(appInfo, contains('SERLINK_MACOS_BUILD_NUMBER'));
    expect(infoPlist, contains(r'$(SERLINK_MACOS_BUILD_NUMBER)'));
    expect(
      project,
      contains(r'CURRENT_PROJECT_VERSION = "$(SERLINK_MACOS_BUILD_NUMBER)"'),
    );
    expect(exportOptions, contains('<string>app-store-connect</string>'));
    expect(exportOptions, contains('<string>upload</string>'));
    expect(exportOptions, contains('<string>Production</string>'));
    expect(exportOptions, contains('<string>Mac App Distribution</string>'));
    expect(signingCheck, contains('Xcode-managed automatic signing'));
    expect(docs, contains('Mac App Distribution'));
    expect(docs, contains('--bump-build-number'));
    expect(docs, contains('-allowProvisioningUpdates'));
    expect(docs, contains('Xcode-managed automatic signing'));
    expect(docs, contains('iCloud.com.alkinum.serlink'));
  });

  test('iOS TestFlight upload uses App Store Connect export options', () {
    final script = File('tool/upload_ios_testflight.sh').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubspecLock = File('pubspec.lock').readAsStringSync();
    final appInfo = File(
      'ios/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();
    final podfileLock = File('ios/Podfile.lock').readAsStringSync();
    final privacyManifest = File(
      'ios/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
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
    expect(script, contains('--platform ios'));
    expect(script, contains('--bump-build-number'));
    expect(script, contains('--build-number'));
    expect(script, contains('flutter build ios'));
    expect(script, contains('--dart-define=SERLINK_DISTRIBUTION=app_store'));
    expect(script, contains('generic/platform=iOS'));
    expect(script, contains('xcodebuild archive'));
    expect(script, contains('xcodebuild -exportArchive'));
    expect(script, contains('ExportOptionsAppStore.plist'));
    expect(podfile, contains('SERLINK_IOS_EXCLUDED_PLUGIN_PODS'));
    expect(podfile, contains("'flutter_pty'"));
    expect(podfileLock, isNot(contains('flutter_pty')));
    expect(pubspec.toLowerCase(), isNot(contains('sentry')));
    expect(pubspecLock.toLowerCase(), isNot(contains('sentry')));
    expect(podfileLock.toLowerCase(), isNot(contains('sentry')));
    expect(privacyManifest, contains('NSPrivacyTracking'));
    expect(privacyManifest, contains('<false/>'));
    expect(
      privacyManifest,
      contains('NSPrivacyAccessedAPICategoryFileTimestamp'),
    );
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(signingCheck, contains('Apple Distribution'));
    expect(signingCheck, contains('get-task-allow'));
    expect(signingCheck, contains('iCloud.com.alkinum.serlink'));
    expect(signingCheck, contains('Xcode-managed automatic signing'));
    expect(appInfo, contains('SERLINK_IOS_BUILD_NUMBER'));
    expect(infoPlist, contains(r'$(SERLINK_IOS_BUILD_NUMBER)'));
    expect(
      project,
      contains(r'CURRENT_PROJECT_VERSION = "$(SERLINK_IOS_BUILD_NUMBER)"'),
    );
    expect(buildNumberScript, contains('--platform ios|macos'));
    expect(buildNumberScript, contains('SERLINK_IOS_BUILD_NUMBER'));
    expect(buildNumberScript, contains('SERLINK_MACOS_BUILD_NUMBER'));
    expect(exportOptions, contains('<string>app-store-connect</string>'));
    expect(exportOptions, contains('<string>upload</string>'));
    expect(exportOptions, contains('<string>Production</string>'));
    expect(exportOptions, contains('<string>Apple Distribution</string>'));
    expect(docs, contains('Apple Distribution'));
    expect(docs, contains('Xcode-managed automatic signing'));
    expect(docs, contains('-allowProvisioningUpdates'));
    expect(docs, contains('Product > Archive'));
    expect(docs, contains('Distribute App > App Store Connect > Upload'));
    expect(docs, contains('iCloud.com.alkinum.serlink'));
  });

  test('build number script previews the next iOS build number', () {
    final result = Process.runSync('bash', [
      'tool/bump_build_number.sh',
      '--platform',
      'ios',
      '--dry-run',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), matches(RegExp(r'^\d+$')));
  });

  test('build number script keeps platform build numbers separate', () {
    final tempRoot = Directory.systemTemp.createTempSync(
      'serlink-build-number-',
    );
    final iosFixture = File(
      p.join(tempRoot.path, 'ios/Runner/Configs/AppInfo.xcconfig'),
    );
    final macosFixture = File(
      p.join(tempRoot.path, 'macos/Runner/Configs/AppInfo.xcconfig'),
    );
    final script = File(p.join(tempRoot.path, 'tool/bump_build_number.sh'));

    try {
      Directory(p.join(tempRoot.path, 'tool')).createSync();
      iosFixture.parent.createSync(recursive: true);
      macosFixture.parent.createSync(recursive: true);
      iosFixture.writeAsStringSync('SERLINK_IOS_BUILD_NUMBER = 8\n');
      macosFixture.writeAsStringSync('SERLINK_MACOS_BUILD_NUMBER = 12\n');
      script.writeAsStringSync(
        File('tool/bump_build_number.sh').readAsStringSync(),
      );

      final iosResult = Process.runSync('bash', [
        script.path,
        '--platform',
        'ios',
        '--set',
        '42',
      ]);
      final macosResult = Process.runSync('bash', [
        script.path,
        '--platform',
        'macos',
      ]);

      expect(iosResult.exitCode, 0, reason: iosResult.stderr.toString());
      expect(macosResult.exitCode, 0, reason: macosResult.stderr.toString());
      expect(
        iosFixture.readAsStringSync(),
        contains('SERLINK_IOS_BUILD_NUMBER = 42'),
      );
      expect(
        macosFixture.readAsStringSync(),
        contains('SERLINK_MACOS_BUILD_NUMBER = 13'),
      );
    } finally {
      tempRoot.deleteSync(recursive: true);
    }
  });
}

String _plistValue(String plistPath, String key) {
  final result = Process.runSync('/usr/libexec/PlistBuddy', [
    '-c',
    'Print :$key',
    plistPath,
  ]);
  if (result.exitCode != 0) {
    return '';
  }
  return result.stdout.toString();
}
