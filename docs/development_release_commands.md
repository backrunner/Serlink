# Development release commands

This page is the short command reference for local verification, build-number
management, and App Store Connect/TestFlight uploads. Platform-specific signing
details live in `docs/ios_testflight_signing.md` and
`docs/macos_testflight_signing.md`.

Use `docs/ios_release.md` and `docs/macos_release.md` for the full release
runbooks.

## Routine verification

Run static analysis:

```sh
flutter analyze
```

Run all Flutter tests:

```sh
flutter test -r expanded
```

Run only the release gate tests:

```sh
flutter test test/release/cloudkit_release_gate_test.dart -r expanded
```

Run the CloudKit/release preflight without the production confirmation gate:

```sh
./tool/check_cloudkit_release_ready.sh
```

Run the iOS-only App Store Connect release surface check:

```sh
./tool/check_cloudkit_release_ready.sh --distribution ios_app_store
```

Run the macOS App Store release surface check:

```sh
./tool/check_cloudkit_release_ready.sh --distribution app_store
```

## iOS dev device install

For the fastest physical-device debug loop, run a Debug build directly on the
iPhone. This stays attached to Flutter, so hot reload and hot restart are
available:

```sh
./tool/ios_dev_install.sh
```

Force USB/attached discovery:

```sh
./tool/ios_dev_install.sh --attached
```

Install the build without keeping a Flutter debug session attached:

```sh
./tool/ios_dev_install.sh --install-only
```

Wireless deploy works after the iPhone has been paired for network debugging in
Xcode:

```sh
./tool/ios_dev_install.sh --wireless
```

If more than one physical iOS device is visible, pass the Flutter device id or
name:

```sh
./tool/ios_dev_install.sh --device 00008110-0000000000000000
```

First-time setup is still Apple/Xcode controlled: connect the iPhone by USB,
unlock it, trust the Mac, enable Developer Mode if iOS asks, then open
Xcode > Window > Devices and Simulators and enable "Connect via network" for
wireless runs. If the wireless device disappears, fall back to `--attached`
first and re-check the Xcode device pairing.

## Build numbers

Preview the next iOS build number without changing files:

```sh
./tool/bump_build_number.sh --platform ios --dry-run
```

Increment the iOS build number before a manual Xcode archive:

```sh
./tool/bump_build_number.sh --platform ios
```

Preview or increment the macOS build number:

```sh
./tool/bump_build_number.sh --platform macos --dry-run
./tool/bump_build_number.sh --platform macos
```

Set a specific platform build number:

```sh
./tool/bump_build_number.sh --platform ios --set 42
./tool/bump_build_number.sh --platform macos --set 42
```

The script updates the platform-specific Xcode settings in
`ios/Runner/Configs/AppInfo.xcconfig` or
`macos/Runner/Configs/AppInfo.xcconfig`. iOS reads
`SERLINK_IOS_BUILD_NUMBER`; macOS reads `SERLINK_MACOS_BUILD_NUMBER`.
`pubspec.yaml` still provides the shared app version name.

## iOS TestFlight

Check local iOS signing assets when using locally installed distribution
certificates and profiles:

```sh
./tool/check_ios_testflight_signing.sh
```

Upload a new iOS TestFlight build using Xcode-managed automatic signing:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --bump-build-number -allowProvisioningUpdates
```

Upload iOS using an already-bumped build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh -allowProvisioningUpdates
```

Upload iOS with a specific build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --build-number 42 -allowProvisioningUpdates
```

For CI, pass App Store Connect API key authentication through to `xcodebuild`:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh \
  --bump-build-number \
  -allowProvisioningUpdates \
  -authenticationKeyPath /path/to/AuthKey.p8 \
  -authenticationKeyID KEY_ID \
  -authenticationKeyIssuerID ISSUER_ID
```

## macOS TestFlight

Check local macOS signing assets when using locally installed distribution
certificates and profiles:

```sh
./tool/check_macos_testflight_signing.sh
```

Upload a new macOS TestFlight build using Xcode-managed automatic signing:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --bump-build-number -allowProvisioningUpdates
```

Upload macOS using an already-bumped build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh -allowProvisioningUpdates
```

Upload macOS with a specific build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --build-number 42 -allowProvisioningUpdates
```

For CI, pass App Store Connect API key authentication through to `xcodebuild`:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh \
  --bump-build-number \
  -allowProvisioningUpdates \
  -authenticationKeyPath /path/to/AuthKey.p8 \
  -authenticationKeyID KEY_ID \
  -authenticationKeyIssuerID ISSUER_ID
```

## macOS Direct DMG build

Build the direct distribution app with Developer ID signing settings:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/build_macos_direct.sh
```

This produces the direct channel app build. Package the resulting app into a
DMG and notarize it before distributing outside the Mac App Store.

## App icon checks

Apple rejects App Store/TestFlight uploads when the large app icon contains an
alpha channel. Check the 1024px icons before upload:

```sh
sips -g hasAlpha \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
```

Both outputs should be `hasAlpha: no`.

## Notes

Do not commit `.p8` API keys, certificate exports, provisioning profiles, or
Apple account credentials.

`SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1` is an explicit local
confirmation that the CloudKit Development schema for
`iCloud.com.alkinum.serlink` has already been deployed to Production in
CloudKit Console.
