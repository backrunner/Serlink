# macOS distribution channels

Serlink uses one codebase with build-time distribution switches.

## App Store and TestFlight

Use this channel for App Store Connect uploads:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/build_macos_app_store.sh
```

The script archives with:

- `SERLINK_DISTRIBUTION=app_store`
- `Runner/Release.entitlements`
- Mac App Store sandbox entitlements
- `Mac App Distribution` signing identity

The script first runs `tool/check_cloudkit_release_ready.sh --distribution
app_store --require-schema-production`, so the CloudKit schema must already be
deployed to Production in CloudKit Console.

The App Store/TestFlight channel disables capabilities that are not compatible
with a sandboxed Mac App Store build:

- local terminal tabs backed by the user's shell
- SSH agent authentication
- direct local file opening through platform launch commands

Remote SSH terminal, SFTP, WebDAV sync, CloudKit sync, and user-selected file
import/export remain enabled.

## Direct DMG distribution

Use this channel for a Developer ID signed and notarized direct download:

```sh
./tool/build_macos_direct.sh
```

The script builds with:

- `SERLINK_DISTRIBUTION=direct`
- `Runner/Direct.entitlements`
- `Developer ID Application` signing identity

This channel keeps desktop-local features enabled, including local terminal
tabs and SSH agent authentication. It can still use CloudKit as long as the
app is signed with the required CloudKit entitlements and a Developer ID
provisioning profile. Package the resulting app into a DMG and notarize it
before distribution.
