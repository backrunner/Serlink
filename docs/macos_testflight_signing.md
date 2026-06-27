# macOS TestFlight signing

macOS TestFlight uses the Mac App Store signing path. It is separate from the
Developer ID signing used for DMG distribution.

For the short command reference, see
`docs/development_release_commands.md`.

For the full macOS release runbook, see `docs/macos_release.md`.

## Apple Developer account

Prepare these items in Apple Developer and App Store Connect:

1. App ID: `com.alkinum.serlink`
2. Capabilities:
   - App Sandbox
   - iCloud with CloudKit
   - CloudKit container `iCloud.com.alkinum.serlink`
3. Certificate:
   - `Mac App Distribution` or `Apple Distribution`
4. Provisioning profile:
   - macOS App Store distribution profile for `com.alkinum.serlink`
   - Includes the CloudKit container above
   - Uses the Production CloudKit environment
5. App Store Connect app record:
   - macOS app for bundle id `com.alkinum.serlink`
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
./tool/check_macos_testflight_signing.sh
```

The check verifies:

- CloudKit release settings are on the production release path.
- A Mac App Store distribution signing identity is installed.
- A provisioning profile for `com.alkinum.serlink` exists locally.
- The profile contains CloudKit entitlements for `iCloud.com.alkinum.serlink`.

On this machine, the current known missing pieces are:

- `Mac App Distribution` or `Apple Distribution` signing identity
- local macOS App Store provisioning profile

## Upload

After the CloudKit schema has been deployed to Production:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --bump-build-number -allowProvisioningUpdates
```

The upload script:

1. Runs the signing readiness check.
2. Optionally increments the macOS build number when
   `--bump-build-number` is provided.
3. Archives with `SERLINK_DISTRIBUTION=app_store`.
4. Uses `macos/Runner/ExportOptionsAppStore.plist`.
5. Exports with `method=app-store-connect` and `destination=upload`.

To set a specific build number instead of incrementing:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh --build-number 42
```

For manual Xcode Organizer archives, increment the macOS build number
before archiving:

```sh
./tool/bump_build_number.sh --platform macos
```

For CI or a clean machine, use Xcode's automatic provisioning options by passing
the normal `xcodebuild` provisioning/authentication flags through the scripts:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_macos_testflight.sh \
  --bump-build-number \
  -allowProvisioningUpdates \
  -authenticationKeyPath /path/to/AuthKey.p8 \
  -authenticationKeyID KEY_ID \
  -authenticationKeyIssuerID ISSUER_ID
```

Do not commit the `.p8` key, certificate exports, provisioning profiles, or any
Apple account credentials.
