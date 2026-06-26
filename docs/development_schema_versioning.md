# Development schema versioning

Serlink has multiple schema/version markers. Treat them separately.

## Remote sync compatibility

- `supportedRemoteSyncProtocolVersion` covers the remote manifest protocol.
- `supportedVaultSchemaVersion` covers encrypted vault data that can be shared
  through sync.
- Bump either version only for incompatible breaking changes that an older app
  cannot safely read, merge, preserve, or write back.
- Do not bump these versions for compatible changes such as adding optional JSON
  fields, adding records that older apps can ignore, or adding fields that can
  be defaulted when absent.
- When a bump is required, add tests that an older app rejects the newer remote
  data before pulling or pushing, and that the user-facing error asks the user to
  update Serlink or turn sync off.

Older apps must not overwrite a remote vault whose sync protocol or vault schema
is newer than they support.

## Local database migrations

The Drift `SerlinkDatabase.schemaVersion` is for local SQLite migrations. Bump it
when Drift needs to run a local migration between app versions. This is separate
from remote sync compatibility: a local-only table or preference migration does
not imply a remote vault/schema bump.
