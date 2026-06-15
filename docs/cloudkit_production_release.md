# CloudKit production release

Serlink stores encrypted sync objects in the user's private CloudKit database.
The production release gate keeps the CloudKit schema, entitlements, iOS
TestFlight upload path, and macOS distribution split aligned before uploading a
TestFlight, App Store, or DMG build.

For the short command reference, see
`docs/development_release_commands.md`.

For platform release runbooks, see `docs/ios_release.md` and
`docs/macos_release.md`.

## CloudKit schema contract

The current CloudKit schema uses the default private database in:

- Container: `iCloud.com.alkinum.serlink`
- Record type: `SerlinkSyncObject`
- Fields:
  - `path`: String
  - `data`: Asset

The `path` field stores the logical object path used by the Flutter sync layer.
The `data` field stores opaque encrypted bytes. Do not add plaintext metadata to
CloudKit records unless the privacy model is reviewed first.

## Development to Production promotion

Use the Development CloudKit environment until this contract is stable and the
TestFlight smoke plan has passed. Before uploading a release distribution:

1. Open CloudKit Console for `iCloud.com.alkinum.serlink`.
2. Select the Development environment.
3. Confirm `SerlinkSyncObject` has `path` and `data` with the types above.
4. Deploy the schema changes to Production.
5. Switch CloudKit Console to Production and confirm the record type exists.
6. Run the release readiness gate with production confirmation:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/check_cloudkit_release_ready.sh --distribution app_store --require-schema-production
```

The confirmation variable is intentionally explicit because deploying the schema
to Production is an Apple Developer portal action, not a local repository change.

## Build gates

For a full preflight without the production confirmation gate:

```sh
./tool/check_cloudkit_release_ready.sh
```

For iOS TestFlight:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/upload_ios_testflight.sh
```

For macOS App Store, macOS TestFlight, and DMG releases:

```sh
SERLINK_CLOUDKIT_SCHEMA_PRODUCTION_CONFIRMED=1 \
  ./tool/build_macos_app_store.sh
```

The App Store build script runs the release gate before it configures and
archives the macOS app. It verifies:

- iOS and macOS release entitlements are not pinned to CloudKit Development.
- iOS TestFlight upload uses App Store Connect export options and CloudKit
  Production.
- macOS App Store entitlements include the App Sandbox and required file/network
  permissions.
- macOS Direct entitlements keep CloudKit but do not enable the App Sandbox.
- macOS build scripts pass the expected `SERLINK_DISTRIBUTION` defines and
  entitlement files.
- iOS and macOS CloudKit bridges still use the schema contract above.

## TestFlight smoke plan

After uploading a TestFlight build, test with a real iCloud account and at least
two Apple devices:

1. Create a vault on the first device and enable iCloud sync.
2. Add a host, identity, snippet, and transfer-related record.
3. Install the build on a second device and bootstrap from iCloud.
4. Edit the same host on both devices and verify conflict behavior.
5. Delete a record and verify tombstone propagation.
6. Disable network, make a local edit, restore network, and verify retry.
7. Inspect CloudKit Console Production records and confirm payloads remain
   encrypted objects only.

If the schema contract changes after this pass, repeat Development testing and
promote the updated schema before producing another release archive.
