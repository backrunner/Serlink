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

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` scheme.
3. Select `Any iOS Device` or `Any iOS Device (arm64)` as the run destination.
4. Confirm Signing & Capabilities uses team `PB8H83VL3Z`, bundle ID
   `com.alkinum.serlink`, iCloud, CloudKit, and container
   `iCloud.com.alkinum.serlink`.
5. Choose Product > Archive.
6. In Organizer, select the new archive.
7. Choose Distribute App > App Store Connect > Upload.
8. Use automatic signing, confirm CloudKit Production, upload symbols, and
   finish the upload.
9. Open App Store Connect > Serlink > TestFlight after processing completes.

Apple creates the first beta version after the first build upload. The build
still needs to finish App Store Connect processing before it can be assigned to
internal or external testers.

## Scripted upload

After the CloudKit schema has been deployed to Production:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh
```

The upload script:

1. Runs the signing readiness check.
2. Configures the Flutter iOS release build with
   `SERLINK_DISTRIBUTION=app_store`.
3. Archives `ios/Runner.xcworkspace` for `generic/platform=iOS`.
4. Uses `ios/Runner/ExportOptionsAppStore.plist`.
5. Exports with `method=app-store-connect`, `destination=upload`, and
   CloudKit Production.

For CI or a clean machine, use Xcode's automatic provisioning options by
passing the normal `xcodebuild` authentication flags through the script:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh \
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
