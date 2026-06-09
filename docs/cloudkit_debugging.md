# CloudKit and iCloud debugging

Serlink's CloudKit sync is implemented by the iOS and macOS targets. The
Flutter layer uses the `serlink/cloudkit` method channel, and the native
implementations store encrypted sync objects in the user's private CloudKit
database.

## Repository-safe configuration

These values are safe to keep in the open source repository:

- Bundle identifier: `com.alkinum.serlink`
- CloudKit container identifier: `iCloud.com.alkinum.serlink`
- Entitlement files under `ios/Runner` and `macos/Runner`
- Source code that calls CloudKit

Do not commit Apple signing material or account credentials:

- `.mobileprovision`, `.provisionprofile`
- `.p8`, `.p12`, `.pfx`, `.pem`, `.cer`, `.crt`, `.key`
- App Store Connect API keys
- Apple ID passwords or app-specific passwords

The root `.gitignore` already excludes the common signing and credential file
types.

## Apple Developer setup

Use Xcode so Apple Developer account state, App ID capabilities, provisioning
profiles, and local entitlements stay aligned.

1. Open `ios/Runner.xcworkspace` or `macos/Runner.xcworkspace`.
2. Select the `Runner` target.
3. Open `Signing & Capabilities`.
4. Enable automatic signing and select your Apple Developer team.
5. Confirm the bundle identifier is `com.alkinum.serlink`.
6. Add the `iCloud` capability.
7. Under iCloud services, enable `CloudKit`.
8. Select or create the container `iCloud.com.alkinum.serlink`.
9. Make sure this capability is applied to Debug, Profile, and Release.

For development builds, CloudKit should use the Development environment. Before
shipping or testing release distribution, deploy the schema in CloudKit Console
and test against Production.

## Local debug flow

Run the app from Flutter after Xcode signing is configured:

```sh
flutter run -d macos
flutter run -d <ios-device-or-simulator>
```

Then inspect the signed app:

```sh
./tool/check_cloudkit_entitlements.sh
./tool/check_cloudkit_entitlements.sh build/ios/iphoneos/Runner.app
```

iOS simulator builds can be ad-hoc signed with empty runtime entitlements even
when the target build settings point at the correct entitlement file. For
simulator checks, validate the source entitlement plist instead:

```sh
./tool/check_cloudkit_entitlements.sh ios/Runner/DebugProfile.entitlements
```

The output should include:

- `com.apple.developer.icloud-services` containing `CloudKit`
- `com.apple.developer.icloud-container-identifiers` containing `iCloud.com.alkinum.serlink`
- `com.apple.developer.icloud-container-environment` set to `Development` for debug builds

If the app still reports iCloud as unavailable, check:

- The Mac or iOS device/simulator is signed in to iCloud.
- iCloud Drive and CloudKit services are available for the Apple ID.
- Xcode shows no signing or provisioning warnings for `Runner`.
- CloudKit Console has the `iCloud.com.alkinum.serlink` container.

CloudKit data can be inspected in CloudKit Console:

https://icloud.developer.apple.com/
