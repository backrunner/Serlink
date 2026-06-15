# iOS release

This runbook covers the iOS App Store Connect and TestFlight release path for
Serlink.

Related docs:

- `docs/development_release_commands.md` for the short command reference
- `docs/ios_testflight_signing.md` for certificates, profiles, and managed
  signing
- `docs/cloudkit_production_release.md` for the CloudKit schema gate

## Release target

- Bundle ID: `com.alkinum.serlink`
- CloudKit container: `iCloud.com.alkinum.serlink`
- CloudKit schema record: `SerlinkSyncObject`
- Distribution define: `SERLINK_DISTRIBUTION=app_store`
- Export options: `ios/Runner/ExportOptionsAppStore.plist`
- Xcode workspace: `ios/Runner.xcworkspace`

## Before archiving

Start from an up-to-date checkout and refresh Flutter and CocoaPods
dependencies:

```sh
flutter pub get
cd ios && pod install && cd ..
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
./tool/check_cloudkit_release_ready.sh --distribution ios_app_store
```

Confirm the CloudKit Development schema has already been deployed to
Production, then run the production gate:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/check_cloudkit_release_ready.sh \
  --distribution ios_app_store \
  --require-schema-production
```

Check that the App Store icon does not contain an alpha channel:

```sh
sips -g hasAlpha \
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

The output should include `hasAlpha: no`.

## Build number

Preview the next shared Flutter build number:

```sh
./tool/bump_build_number.sh --dry-run --no-pub-get
```

Increment the build number before a manual archive:

```sh
./tool/bump_build_number.sh
```

Set a specific build number:

```sh
./tool/bump_build_number.sh --set 42
```

The script updates the `version: x.y.z+n` line in `pubspec.yaml` and runs
`flutter pub get` unless `--no-pub-get` is provided. iOS and macOS both read
this shared build number through Flutter's generated Xcode settings.

## Scripted TestFlight upload

Use this path when you want one command to check the release gate, bump the
build number, archive, export, and upload to App Store Connect:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --bump-build-number -allowProvisioningUpdates
```

Use an already-bumped build number:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh -allowProvisioningUpdates
```

Set a specific build number during upload:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --build-number 42 -allowProvisioningUpdates
```

`-allowProvisioningUpdates` lets Xcode-managed automatic signing download or
create the needed App Store Connect signing assets. If you use manually
installed certificates and profiles, run `./tool/check_ios_testflight_signing.sh`
first.

## Xcode Organizer upload

Use this path when you prefer to archive from Xcode:

1. Run `./tool/bump_build_number.sh`.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Select the `Runner` scheme.
4. Select `Any iOS Device` or `Any iOS Device (arm64)`.
5. Confirm Signing & Capabilities uses team `PB8H83VL3Z`, bundle ID
   `com.alkinum.serlink`, iCloud, CloudKit, and
   `iCloud.com.alkinum.serlink`.
6. Choose Product > Archive.
7. In Organizer, select the new archive.
8. Choose Distribute App > App Store Connect > Upload.
9. Use automatic signing unless you intentionally prepared manual signing
   assets.
10. Confirm the export uses CloudKit Production and upload the archive.

## App Store Connect after upload

Wait for App Store Connect processing to finish before assigning the build.
Then:

1. Complete the export compliance and encryption questionnaire according to the
   current crypto review for this build.
2. For internal TestFlight, add the processed build to an internal testing
   group.
3. For external TestFlight or public beta, add the build to an external group
   and submit it for Beta App Review if App Store Connect requires it.
4. For App Store review, create or open the iOS app version, attach the build,
   complete screenshots, description, privacy, pricing, availability, and
   review metadata, then submit the version for review.

The build will not appear in external or public beta groups until processing is
complete and the build has been assigned to that testing group.

## Smoke test

After the build is available in TestFlight:

1. Install it on a physical iPhone signed in to an iCloud account.
2. Create or unlock a vault.
3. Add a host and identity.
4. Enable CloudKit sync and confirm encrypted records appear in the Production
   CloudKit environment.
5. Install the same build on a second Apple device with the same iCloud account
   and confirm the same data can be read.
6. Edit and delete a record, then verify sync and tombstone behavior.
