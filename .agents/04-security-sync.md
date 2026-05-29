# Security And Sync Design

## Security Objectives

- Protect credentials even if the local database file is copied.
- Protect all sync data from iCloud/WebDAV providers.
- Provide recoverable multi-device sync without trusting platform-specific keychain sync.
- Support OS-native secure storage as an enhancement.
- Make host key verification explicit and safe.
- Minimize accidental leaks in logs, crash reports, clipboard, screenshots, and telemetry.

## Threat Model

### Assets

- SSH private keys.
- Private key passphrases.
- Server passwords.
- Hostnames, usernames, ports, notes, tags, and groups.
- Known host keys and trust decisions.
- WebDAV/iCloud sync credentials and tokens.
- Terminal scrollback and command history.
- SFTP remote paths and file names.

### Attackers

- Someone who obtains the local SQLite database.
- A compromised or curious sync provider.
- Malware with user-level filesystem access.
- Network attacker performing MITM during SSH connection.
- A local shoulder-surfer or clipboard snooper.
- A future bug that logs sensitive fields.

### Security Boundaries

- OS secure storage protects local vault key wrappers.
- Vault encryption protects database and sync contents.
- SSH host key verification protects transport authenticity.
- User passphrase/recovery key protects portable onboarding.
- App redaction boundaries protect logs and diagnostics.

## Vault Model

Serlink should use envelope encryption:

1. Generate a random vault root key on first setup.
2. Derive subkeys for record encryption, manifest encryption, and metadata authentication.
3. Wrap the vault root key with one or more key protectors:
   - OS secure storage protector.
   - User passphrase protector.
   - Optional recovery key protector.
   - Optional macOS Keychain sync protector.
4. Encrypt each syncable record independently with AEAD.
5. Store and sync only encrypted envelopes.

## Key Hierarchy

```text
Vault Root Key (VRK)
  ├─ Record Encryption Key: HKDF(VRK, "serlink.record.v1")
  ├─ Manifest Encryption Key: HKDF(VRK, "serlink.manifest.v1")
  ├─ Search Index Key: HKDF(VRK, "serlink.index.v1")
  └─ Backup Export Key: HKDF(VRK, "serlink.backup.v1")
```

Key protectors:

```text
OS Protector:
  random device key stored in OS secure storage
  wraps VRK locally

Passphrase Protector:
  Argon2id(passphrase, salt, calibrated params) => wrapping key
  wraps VRK for portable unlock

Recovery Key Protector:
  high-entropy generated recovery phrase/key
  wraps VRK

macOS Keychain Sync Protector:
  Keychain item configured for sync if supported and user opts in
  wraps VRK or stores a wrapping key
```

## Cryptographic Requirements

- Use authenticated encryption, preferably XChaCha20-Poly1305 or AES-256-GCM.
- Use unique nonces per encrypted payload.
- Include record metadata as AEAD associated data:
  - vault id
  - record id
  - record type
  - schema version
  - revision
  - tombstone flag
- Use Argon2id or a defensible memory-hard KDF for passphrase wrapping.
- Calibrate KDF parameters per platform and store parameters in protector metadata.
- Do not implement primitives manually.
- Add deterministic test vectors for the vault envelope format.

## Record Classification

| Data | Local Storage | Sync | Notes |
| --- | --- | --- | --- |
| Host hostname/user/port | encrypted record | encrypted | sensitive infrastructure metadata |
| Host display alias | encrypted by default | encrypted | can optionally expose local-only index after unlock |
| Private key | encrypted record or device-local secure store | encrypted only if portable | device-local keys must be clearly labeled |
| Password | encrypted record or device-local secure store | encrypted only if portable | no plaintext |
| Passphrase | encrypted record or device-local secure store | encrypted only if portable | no plaintext |
| Known host key | encrypted record | encrypted | needed for multi-device trust continuity |
| Terminal scrollback | memory only by default | no | optional encrypted local history later |
| Transfer paths | encrypted local queue | no by default | sync not required |
| Sync provider password/token | OS secure storage | no | WebDAV password should stay device-local unless user explicitly saves portable |

## Secret Store Abstraction

Interface:

```dart
abstract interface class SecretStore {
  Future<SecretStoreCapabilities> capabilities();
  Future<void> write(SecretRef ref, SecretBytes value, SecretWriteOptions options);
  Future<SecretBytes?> read(SecretRef ref);
  Future<void> delete(SecretRef ref);
  Future<bool> contains(SecretRef ref);
}
```

Capabilities:

- `deviceLocal`
- `syncable`
- `biometricGate`
- `requiresUserPresence`
- `available`
- `canStoreLargeSecrets`
- `notes`

Platform notes:

- macOS: Keychain, optional syncable access class where supported.
- Windows: Credential Manager/DPAPI; syncability is not assumed.
- Linux: Secret Service/libsecret; if unavailable, require passphrase unlock and warn about reduced convenience.

## macOS Keychain Options

Support three modes:

1. Portable encrypted vault: default and cross-platform.
2. Device-local Keychain unlock: stores local wrapping key in Keychain.
3. iCloud Keychain unlock: optional; only if native implementation can guarantee the requested sync behavior.

The UI must show whether an identity is:

- Portable encrypted.
- Device-local.
- Synced via platform keychain.
- Missing on this device.

## Host Key Verification

Requirements:

- Verify host keys by default.
- Store trusted host keys per host/hostname/port tuple and algorithm.
- Display fingerprint in SHA256 format.
- Support first-connect trust prompt.
- Changed host key requires a blocking warning with:
  - old fingerprint
  - new fingerprint
  - algorithm
  - host/port
  - explanation that this may indicate MITM or server replacement
- Provide explicit actions:
  - cancel
  - trust new key once
  - replace stored key
- Log only redacted host identifier.

## SSH Credential Import

Private key import flow:

1. User chooses file or pastes key.
2. App detects format.
3. App validates parseability.
4. If passphrase-protected, prompt for passphrase.
5. App offers storage choices:
   - portable encrypted vault
   - device-local secure storage
   - do not store passphrase
6. App records public key fingerprint and metadata.
7. App never keeps the source file path as sensitive metadata unless user chooses to link external key.

Supported formats for first release:

- OpenSSH private key.
- PEM RSA/ECDSA/Ed25519 if `dartssh2` supports parse path or adapter can convert.

Rejected or deferred:

- PuTTY PPK, out of first desktop release scope unless conversion/import support is explicitly added.
- Hardware security keys/FIDO2, out of first desktop release scope.
- SSH Agent authentication, out of first desktop release scope until async signer architecture is available.

## Sync Protocol

### Provider Abstraction

```dart
abstract interface class SyncProvider {
  Future<ProviderCapabilities> capabilities();
  Future<RemoteManifest?> readManifest();
  Future<void> writeManifest(RemoteManifest manifest, WriteCondition condition);
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix});
  Future<Uint8List> readObject(RemoteObjectRef ref);
  Future<void> writeObject(RemoteObjectRef ref, Uint8List bytes, WriteCondition condition);
  Future<void> deleteObject(RemoteObjectRef ref, WriteCondition condition);
}
```

### Manifest

The manifest should be encrypted and contain:

- Vault id.
- Protocol version.
- Device entries.
- Latest known record revisions.
- Tombstone summary.
- Provider checkpoint metadata.
- Last compaction time.

### Conflict Handling

Conflict classes:

- Local and remote changed different records: auto-merge.
- Local and remote changed same record: produce conflict record.
- Local deleted, remote changed: ask user.
- Remote deleted, local changed: ask user.
- Protector mismatch: require vault unlock/recovery.

Record conflict UX:

- Show record type and safe display label after local decrypt.
- Show modified device/time.
- Offer keep local, keep remote, duplicate, or manual merge where supported.

### Tombstones

- Tombstones are encrypted records with type/id/revision metadata.
- Retain tombstones for a configured period, default 90 days.
- Compact only when all known devices have checkpointed after tombstone creation or user forces cleanup.

### WebDAV Strategy

Use:

- `PROPFIND` for listing.
- `GET`/`PUT` for objects.
- `MKCOL` for directories.
- `MOVE` for temp-to-final if supported.
- ETag/If-Match/If-None-Match where reliable.

Upload pattern:

1. Write object to temp path.
2. Verify size/hash if possible.
3. Move to final path.
4. Update manifest last with write condition.

If server lacks reliable move/etag, fall back to generation objects and conflict-safe manifest upload.

TLS policy:

- HTTPS is required by default for WebDAV.
- Plain HTTP is allowed only through an advanced setting with a modal warning.
- Self-signed or untrusted TLS certificates require explicit modal confirmation and certificate pinning before use.
- TLS certificate failures must be surfaced as security errors, not generic network failures.

### iCloud Strategy

Recommended implementation sequence:

1. Define provider API and sync protocol using WebDAV.
2. Implement local file provider for tests.
3. Add macOS iCloud provider as beta.
4. Choose CloudKit private database if structured record semantics and conflict metadata matter more.
5. Choose iCloud Drive if file-based encrypted vault portability matters more.

iCloud provider must not require plaintext data. It only moves encrypted envelopes and manifest bytes.

## Unlock And Lock Lifecycle

Unlock sources:

- OS secure storage auto-unlock.
- User passphrase.
- Recovery key.

Lock triggers:

- App quit.
- Manual lock.
- Sleep/lock screen detection where available.
- Timeout after inactivity if configured.

When locked:

- Hide hosts and identities.
- Close or preserve existing sessions based on user setting.
- Clear decrypted indexes and plaintext caches.
- Stop sync operations that require decrypting conflict labels.

## Logging And Diagnostics Redaction

Default logs may include:

- session id
- host record id
- provider type
- error code
- timing
- byte counts

Default logs must not include:

- hostname
- username
- password
- private key
- passphrase
- command text
- remote/local file path
- file names
- terminal output

Local file protection:

- Local database, logs, exports, and temp files should use restrictive file permissions where the platform permits.
- Private keys and decrypted vault content should not be written to temp files.
- Temporary files created during import, export, or transfer workflows must be cleaned up best-effort.

## Security Test Requirements

- Unit tests for encryption/decryption and failed authentication tags.
- Test vectors for vault envelope.
- Tests that encrypted payload changes when nonce changes.
- Tests that associated data tampering fails decryption.
- Tests that logs redact sensitive fields.
- Sync tests proving provider sees no plaintext hostnames.
- Host key verification tests for first trust, match, changed key, and cancel.
- Secret store capability tests using fakes and platform integration smoke tests.

## Security Review Gates

Before public beta:

- Internal threat model review.
- Dependency audit.
- Vault protocol review by a cryptography/security engineer.
- Redaction review of logs and crash reports.
- Manual tests for key import and host key warnings.

Before v1.0:

- External security review if budget allows.
- Reproducible backup restore test across all desktop platforms.
- Sync conflict tests between at least two physical machines or VMs.
