# macOS distribution channels

Serlink uses one codebase with build-time distribution switches.

## App Store and TestFlight

Use this channel for App Store Connect uploads:

```sh
./tool/build_macos_app_store.sh
```

The script archives with:

- `SERLINK_DISTRIBUTION=app_store`
- `Runner/Release.entitlements`
- Mac App Store sandbox entitlements
- `Mac App Distribution` signing identity

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
tabs and SSH agent authentication. Package the resulting app into a DMG and
notarize it before distribution.
