# iOS TestFlight signing

iOS TestFlight uses the App Store Connect distribution path. It is separate
from local development signing and from macOS Developer ID distribution.

## Apple Developer account

Prepare these items in Apple Developer and App Store Connect:

1. App ID: `com.alkinum.serlink`
2. Capabilities:
   - iCloud with CloudKit
   - CloudKit container `iCloud.com.alkinum.serlink`
3. Certificate:
   - `Apple Distribution`
4. Provisioning profile:
   - App Store Connect distribution profile for iOS
   - Uses the explicit App ID for `com.alkinum.serlink`
   - Includes the CloudKit container above
   - Uses the Production CloudKit environment
5. App Store Connect app record:
   - iOS app for bundle ID `com.alkinum.serlink`
   - TestFlight enabled

Install the certificate private key in the login keychain and install the
provisioning profile into:

```sh
~/Library/MobileDevice/Provisioning Profiles/
```

Xcode can also download managed certificates and profiles when the Apple
Developer account is signed in under Xcode > Settings > Accounts.

If you use Xcode-managed automatic signing, the local provisioning profile may
not exist until Xcode archives or exports the app. In that case, use the upload
script with `-allowProvisioningUpdates` instead of relying on the local profile
readiness check.

## Local readiness check

Run:

```sh
./tool/check_ios_testflight_signing.sh
```

The check verifies:

- CloudKit release settings are on the production release path.
- An `Apple Distribution` signing identity is installed.
- An iOS provisioning profile for `com.alkinum.serlink` exists locally.
- The profile is an App Store Connect distribution profile, not a development
  or ad hoc profile.
- The profile contains CloudKit entitlements for `iCloud.com.alkinum.serlink`.

On this machine, the current known missing pieces are:

- `Apple Distribution` signing identity
- local iOS App Store Connect provisioning profile

## Xcode Organizer upload

After the CloudKit schema has been deployed to Production:

1. Increment the build number:

   ```sh
   ./tool/bump_build_number.sh
   ```

2. Open `ios/Runner.xcworkspace` in Xcode.
3. Select the `Runner` scheme.
4. Select `Any iOS Device` or `Any iOS Device (arm64)` as the run destination.
5. Confirm Signing & Capabilities uses team `PB8H83VL3Z`, bundle ID
   `com.alkinum.serlink`, iCloud, CloudKit, and container
   `iCloud.com.alkinum.serlink`.
6. Choose Product > Archive.
7. In Organizer, select the new archive.
8. Choose Distribute App > App Store Connect > Upload.
9. Use automatic signing, confirm CloudKit Production, upload symbols, and
   finish the upload.
10. Open App Store Connect > Serlink > TestFlight after processing completes.

Apple creates the first beta version after the first build upload. The build
still needs to finish App Store Connect processing before it can be assigned to
internal or external testers.

`tool/bump_build_number.sh` updates the `version: x.y.z+n` line in
`pubspec.yaml` and runs `flutter pub get`, which refreshes Flutter's generated
build settings before Xcode archives the app.

## Scripted upload

After the CloudKit schema has been deployed to Production:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --bump-build-number -allowProvisioningUpdates
```

The upload script:

1. Runs the signing readiness check.
2. Optionally increments the Flutter build number when
   `--bump-build-number` is provided.
3. Configures the Flutter iOS release build with
   `SERLINK_DISTRIBUTION=app_store`.
4. Archives `ios/Runner.xcworkspace` for `generic/platform=iOS`.
5. Uses `ios/Runner/ExportOptionsAppStore.plist`.
6. Exports with `method=app-store-connect`, `destination=upload`, and
   CloudKit Production.

To set a specific build number instead of incrementing:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh --build-number 42
```

For CI or a clean machine, use Xcode's automatic provisioning options by
passing the normal `xcodebuild` provisioning/authentication flags through the
script:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh \
  --bump-build-number \
  -allowProvisioningUpdates \
  -authenticationKeyPath /path/to/AuthKey.p8 \
  -authenticationKeyID KEY_ID \
  -authenticationKeyIssuerID ISSUER_ID
```

Do not commit the `.p8` key, certificate exports, provisioning profiles, or any
Apple account credentials.

## CloudKit data compatibility

iOS, macOS App Store, and direct macOS builds can read the same user data when
they are signed for the same iCloud container, use the same CloudKit Production
environment, and the user is signed in to the same iCloud account. For Serlink,
that means `iCloud.com.alkinum.serlink` and the `SerlinkSyncObject` schema.
