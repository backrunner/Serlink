# macOS release

This runbook covers both macOS release channels:

- Mac App Store and TestFlight
- Direct DMG distribution

Related docs:

- `docs/development_release_commands.md` for the short command reference
- `docs/macos_testflight_signing.md` for App Store Connect signing
- `docs/macos_distribution.md` for the App Store versus direct channel split
- `docs/cloudkit_production_release.md` for the CloudKit schema gate

## Release targets

### Mac App Store and TestFlight

- Bundle ID: `com.alkinum.serlink`
- CloudKit container: `iCloud.com.alkinum.serlink`
- CloudKit schema record: `SerlinkSyncObject`
- Distribution define: `SERLINK_DISTRIBUTION=app_store`
- Entitlements: `macos/Runner/Release.entitlements`
- App Sandbox: enabled
- Export options: `macos/Runner/ExportOptionsAppStore.plist`
- Xcode workspace: `macos/Runner.xcworkspace`

### Direct DMG

- Bundle ID: `com.alkinum.serlink`
- CloudKit container: `iCloud.com.alkinum.serlink`
- Distribution define: `SERLINK_DISTRIBUTION=direct`
- Entitlements: `macos/Runner/Direct.entitlements`
- App Sandbox: disabled
- Signing identity: `Developer ID Application`

The App Store channel disables local desktop capabilities that are incompatible
with sandboxed Mac App Store distribution. The direct channel keeps those
desktop-local capabilities enabled and must be Developer ID signed and
notarized before distribution.

## Before archiving

Start from an up-to-date checkout and refresh Flutter and CocoaPods
dependencies:

```sh
flutter pub get
cd macos && pod install && cd ..
```

Run `pod install` again if Xcode reports:

```text
The sandbox is not in sync with the Podfile.lock.
```

Run local verification:

```sh
flutter analyze
flutter test -r expanded
flutter test test/release/cloudkit_release_gate_test.dart -r expanded
./tool/check_cloudkit_release_ready.sh --distribution app_store
./tool/check_cloudkit_release_ready.sh --distribution direct
```

Confirm the CloudKit Development schema has already been deployed to
Production, then run the production gates for the release channel you are
building:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/check_cloudkit_release_ready.sh \
  --distribution app_store \
  --require-schema-production
```

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/check_cloudkit_release_ready.sh \
  --distribution direct \
  --require-schema-production
```

Check that the App Store icon does not contain an alpha channel:

```sh
sips -g hasAlpha \
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
```

The output should include `hasAlpha: no`.

## Build number

Preview the next macOS build number:

```sh
./tool/bump_build_number.sh --platform macos --dry-run
```

Increment the macOS build number before a manual archive:

```sh
./tool/bump_build_number.sh --platform macos
```

Set a specific build number:

```sh
./tool/bump_build_number.sh --platform macos --set 42
```

The script updates `SERLINK_MACOS_BUILD_NUMBER` in
`macos/Runner/Configs/AppInfo.xcconfig`. macOS uses that value for
`CFBundleVersion`; iOS has its own independent build number.

## Scripted TestFlight upload

Use this path when you want one command to check the release gate, bump the
build number, archive, export, and upload to App Store Connect:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --bump-build-number -allowProvisioningUpdates
```

Use an already-bumped build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh -allowProvisioningUpdates
```

Set a specific build number during upload:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --build-number 42 -allowProvisioningUpdates
```

`-allowProvisioningUpdates` lets Xcode-managed automatic signing download or
create the needed App Store Connect signing assets. If you use manually
installed certificates and profiles, run
`./tool/check_macos_testflight_signing.sh` first.

## Xcode Organizer upload

Use this path when you prefer to archive from Xcode:

1. Run `./tool/bump_build_number.sh --platform macos`.
2. Open `macos/Runner.xcworkspace` in Xcode.
3. Select the `Runner` scheme.
4. Select `Any Mac` or `My Mac`.
5. Confirm Signing & Capabilities uses team `PB8H83VL3Z`, bundle ID
   `com.alkinum.serlink`, App Sandbox, iCloud, CloudKit, and
   `iCloud.com.alkinum.serlink`.
6. Choose Product > Archive.
7. In Organizer, select the new archive.
8. Choose Distribute App > App Store Connect > Upload.
9. Use automatic signing unless you intentionally prepared manual signing
   assets.
10. Confirm the export uses CloudKit Production and upload the archive.

## Direct DMG build

Build the direct channel app:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/build_macos_direct.sh
```

The direct script uses `SERLINK_DISTRIBUTION=direct`,
`Runner/Direct.entitlements`, and the `Developer ID Application` signing
identity by default. Package the resulting `.app` into a DMG and notarize it
before distributing it outside the Mac App Store.

Direct DMG builds can use the same CloudKit data as the App Store build when
they are signed for the same CloudKit container, use the Production CloudKit
environment, and the user signs in with the same iCloud account.

## App Store Connect after upload

Wait for App Store Connect processing to finish before assigning the build.
Then:

1. Complete the export compliance and encryption questionnaire according to the
   current crypto review for this build.
2. Fill the macOS App Store metadata, including screenshots, description,
   privacy, pricing, availability, support URL, marketing URL if used, and app
   review notes.
3. Confirm the App Store icon and screenshots are present in the macOS app
   record. The build icon does not replace all App Store Connect metadata.
4. For internal TestFlight, add the processed build to an internal testing
   group.
5. For external TestFlight or public beta, add the build to an external group
   and submit it for Beta App Review if App Store Connect requires it.
6. For App Store review, create or open the macOS app version, attach the
   build, complete metadata, and submit the version for review.

The build will not appear in external or public beta groups until processing is
complete and the build has been assigned to that testing group.

## Smoke test

After the build is available in TestFlight or as a notarized DMG:

1. Install it on a physical Mac signed in to an iCloud account.
2. Create or unlock a vault.
3. Add a host and identity.
4. Enable CloudKit sync and confirm encrypted records appear in the Production
   CloudKit environment.
5. Install the matching iOS or macOS build on a second Apple device with the
   same iCloud account and confirm the same data can be read.
6. Edit and delete a record, then verify sync and tombstone behavior.
7. For the App Store channel, confirm sandboxed limitations are hidden or
   disabled in the UI.
8. For the direct channel, confirm local terminal and other direct-only desktop
   capabilities remain available.
