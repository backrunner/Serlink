# macOS release

This runbook covers both macOS release channels:

- Mac App Store and TestFlight
- Direct DMG distribution

Related docs:

- [Prepared submission materials](release/macos/README.md)
- [2026-09-30 dependency and application review](release/review-2026-09-30.md)

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
identity by default. It enables `SERLINK_DMG_INSTALLER_ENABLED=YES` and produces
`build/Serlink-<version>+<build>.dmg`. Override the output with `SERLINK_DMG_PATH`.
Install `uv` first (`brew install uv`); packaging uses pinned `dmgbuild==1.6.7`
to write Finder metadata without Finder automation permissions.

The DMG uses `macos/dmg/background.png` and `background@2x.png`, a 720 × 480
Finder window, and a single centered app icon. Regenerate both images with
`swift tool/render_macos_dmg_background.swift`; layout settings live in
`macos/dmg/settings.py`.

Double-clicking the app installs and opens it before the Flutter engine, vault,
or MCP server starts. Installation is enabled only for direct builds launched
from read-only volumes, including Gatekeeper App Translocation. It copies to
`/Applications` or, when that is not writable and no system copy exists, to
`~/Applications`. Existing matching apps require replacement confirmation;
running apps must be quit first. The installer stages and verifies the complete
signed bundle before replacing the old app, rolls back failed replacements,
and preserves quarantine attributes. User data is outside the app bundle and
is not modified. App Store builds leave the installer disabled.

### Notarization

The build script does not submit to Apple. Notarize and staple the app first,
then repackage it so the app inside the DMG carries its ticket. For example,
using an existing `notarytool` keychain profile named `serlink-notary`:

```sh
APP=build/macos/Build/Products/Release/serlink.app
DMG=build/Serlink-1.0.0+14.dmg # Use the version/build produced above.
ditto -c -k --keepParent "$APP" build/Serlink-notary.zip
xcrun notarytool submit build/Serlink-notary.zip --keychain-profile serlink-notary --wait
xcrun stapler staple "$APP"
./tool/package_macos_dmg.sh "$APP" "$DMG"
codesign --sign 'Developer ID Application' --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile serlink-notary --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
```

For local testing, `SERLINK_INSTALL_DEV_APP=0 ./tool/build_macos_dev_dmg.sh`
builds the same layout without replacing the development app on the build Mac.
Development DMGs retain development provisioning and are not public releases.

Run `./tool/test_macos_installer.sh` with Xcode selected to test first installs,
upgrades, copy/signature failures, rollback, running apps, and unsafe targets.
Before release, smoke-test a downloaded, quarantined, notarized DMG on a clean
Mac: verify the background at standard/Retina resolution, double-click install,
launch from Applications, replacement cancellation, running-app retry, and a
standard account's `~/Applications` fallback. Eject the DMG and confirm the
installed app still launches. Gatekeeper prompts are controlled by macOS.

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
