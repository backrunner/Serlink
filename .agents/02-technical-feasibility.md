# Technical Feasibility

## Research Snapshot

The dependency landscape is feasible for a Flutter desktop-first SSH client:

- Flutter officially supports desktop targets including macOS, Windows, and Linux.
- The Dart package `xterm` provides terminal emulation and Flutter widgets, and its current package line depends on `zmodem`.
- The Dart package `dartssh2` provides pure-Dart SSH and SFTP primitives and is actively maintained.
- Drift provides a mature SQLite persistence layer for Flutter desktop.
- Secure storage is feasible through `flutter_secure_storage`, `biometric_storage`, or platform-specific plugins, but platform behavior must be tested carefully.
- WebDAV has usable Dart client packages, but robust sync requires an application-level encrypted record protocol.
- iCloud support is feasible on macOS but likely requires native Swift plugin work for CloudKit or iCloud Drive semantics.

Research references:

- Flutter desktop: https://docs.flutter.dev/platform-integration/desktop
- xterm package: https://pub.dev/packages/xterm
- dartssh2 package: https://pub.dev/packages/dartssh2
- drift package: https://pub.dev/packages/drift
- flutter_secure_storage package: https://pub.dev/packages/flutter_secure_storage
- cryptography package: https://pub.dev/packages/cryptography

## Dependency Version Snapshot

Checked against pub.dev on 2026-05-27 Asia/Shanghai.

| Package | Latest observed version | Published | Role |
| --- | --- | --- | --- |
| `xterm` | 4.0.0 | 2024-02-27 | terminal emulator and Flutter terminal view |
| `dartssh2` | 2.17.1 | 2026-04-12 | SSH/SFTP transport |
| `drift` | 2.33.0 | 2026-05-03 | typed SQLite persistence |
| `flutter_secure_storage` | 10.3.0 | 2026-05-22 | cross-platform secure storage baseline |
| `cryptography` | 2.9.0 | 2025-11-21 | cryptographic primitives |
| `webdav_client` | 1.2.2 | 2024-05-12 | WebDAV provider candidate |
| `file_selector` | 1.1.0 | 2025-11-21 | desktop file picker |
| `riverpod` | 3.2.1 | 2026-02-03 | application state |
| `go_router` | 17.2.3 | 2026-05-01 | routing |

Version decisions should be pinned in `pubspec.yaml` during implementation and revisited before beta. The packages above are candidates, not a lockfile.

## Platform Strategy

### macOS

- Primary desktop target and strongest secure storage story.
- Use Keychain for device-local secret wrapping.
- Evaluate Keychain sync as opt-in; clearly label whether a secret is iCloud Keychain portable or local-only.
- iCloud sync can be implemented through a native plugin with CloudKit private database or iCloud Drive file coordination.
- Needs hardened runtime, signing, notarization, and keychain access group decisions.

### Windows

- Use Windows Credential Manager or DPAPI-backed storage through secure storage plugin.
- Test terminal keyboard behavior for AltGr, IME, Ctrl/Alt combinations, and paste behavior.
- Packaging target: MSIX first; installer can follow.
- SFTP drag/drop integration needs Windows-specific verification.

### Linux

- Use libsecret/Secret Service when available; provide fallback with explicit warning if no secret service is configured.
- Test X11 and Wayland clipboard, font rendering, IME, and drag/drop.
- Packaging target: AppImage or Flatpak after tarball/dev package.
- Sync and vault passphrase flows must not depend on a functioning desktop keyring.

## Dependency Evaluation

### Terminal: `xterm`

Reasons to choose:

- Flutter-native terminal widget.
- xterm-compatible terminal model.
- Supports terminal themes and controller-like integration.
- Already aligned with the user's suggested xterm.dart direction.
- Current package metadata includes zmodem-related dependency, making rz/sz integration more realistic than starting from scratch.

Risks:

- Need stress testing for high-throughput output.
- Need IME, keyboard shortcuts, scrollback, and selection QA across all desktop OSes.
- Need careful byte stream interception for zmodem without breaking terminal rendering.

Mitigations:

- Build a terminal adapter abstraction, not direct UI-to-SSH coupling.
- Add synthetic throughput tests using recorded terminal output.
- Keep terminal settings persisted separately from session state.

### SSH/SFTP: `dartssh2`

Reasons to choose:

- Pure Dart implementation reduces native build complexity.
- Supports SSH client sessions and SFTP.
- Suitable for Flutter desktop and future mobile.
- Enables shared connection/authentication logic across platforms.

Risks:

- SSH agent support may require platform-specific sockets/pipes and extra integration.
- Some advanced auth flows may need additional implementation.
- Long-running SFTP transfer resilience must be built above the library.

Mitigations:

- Create `SshClientFacade` and `SftpClientFacade` interfaces.
- Keep auth methods pluggable.
- Add integration tests against containerized OpenSSH servers.

### Persistence: Drift + SQLite

Reasons to choose:

- Strong typing and migrations.
- Works on desktop and mobile.
- Good testability.
- Can store encrypted record envelopes and local indexes.

Risks:

- Full-text search over encrypted fields requires local decrypted index design.
- Sync conflicts require stable schema evolution.

Mitigations:

- Store canonical encrypted record payloads separately from derived local indexes.
- Treat decrypted display indexes as rebuildable cache.
- Version every encrypted payload schema.

### Cryptography

Recommended primitives:

- Argon2id for passphrase key derivation where package support is acceptable.
- HKDF for subkey derivation.
- XChaCha20-Poly1305 or AES-GCM for authenticated encryption.
- Ed25519 or HMAC-based record integrity if needed beyond AEAD.

Pragmatic package options:

- `cryptography` for cross-platform Dart primitives.
- Consider `libsodium` bindings only if audited primitives or Argon2id/XChaCha20 availability is insufficient in pure Dart.

Risks:

- Implementing a custom vault protocol incorrectly.
- Weak passphrases leading to brute-force risk.

Mitigations:

- Keep protocol small and documented.
- Use audited primitives from packages, not homegrown crypto.
- Enforce strong KDF parameters and allow calibration.
- Add test vectors.

### Secure Storage

Options:

- `flutter_secure_storage` for broad platform support.
- `biometric_storage` for biometric-gated secrets where appropriate.
- Custom method channels for macOS Keychain, Windows Credential Manager, Linux Secret Service if plugin behavior is insufficient.

Risks:

- Linux availability varies by distribution.
- Windows plugin behavior and roaming must be validated.
- macOS Keychain sync semantics need explicit entitlement/config testing.

Mitigations:

- Build `SecretStore` abstraction with capability reporting.
- Never make OS secure storage the only recovery path.
- Provide portable encrypted vault passphrase flow.

### Sync Providers

#### WebDAV

Feasible through Dart HTTP and WebDAV packages.

Needed application features:

- Provider credential storage.
- Remote capability detection.
- Atomic-ish upload strategy using temp object then move.
- ETag or Last-Modified based compare.
- Retry/backoff.
- Conflict file handling.

Risks:

- WebDAV servers differ significantly.
- Some providers have weak locking or inconsistent ETag behavior.

Mitigations:

- Use append-only or immutable generation files where possible.
- Keep a remote manifest.
- Support manual repair/resync.

#### iCloud

Feasible but needs native work.

Options:

- CloudKit private database: structured records, conflict metadata, good Apple-native sync; requires Apple developer setup and native plugin.
- iCloud Drive container: file-based encrypted vault sync; simpler mental model, more file coordination complexity.

Recommendation:

- Implement provider interface first with WebDAV.
- Add iCloud as macOS beta using iCloud Drive or CloudKit after storage protocol stabilizes.
- Keep iCloud implementation isolated behind `SyncProvider`.

## SSH Feature Feasibility

### Password Auth

High feasibility. Needs secure prompt flow and credential persistence policy.

### Public Key Auth

High feasibility for common OpenSSH key formats. Need importer validation and passphrase handling.

### SSH Agent

Medium feasibility.

- macOS/Linux: `SSH_AUTH_SOCK` Unix socket.
- Windows: named pipe or Pageant-compatible/Windows OpenSSH agent integrations.

Implement after password/key auth works.

### Host Key Verification

High feasibility but must be treated as core, not optional.

Needs:

- Known host storage.
- Fingerprint rendering.
- Changed key workflow.
- Algorithm display.

### Port Forwarding

Medium-high feasibility with `dartssh2`, but UX and lifecycle management are important.

### Jump Hosts

Medium feasibility. Requires opening nested SSH transport or direct-tcpip through bastion.

### Zmodem / rz / sz

Medium feasibility.

The terminal stream can detect zmodem control sequences and hand the flow to a zmodem handler. Because terminal behavior varies and remote tools differ, implement progressively:

1. Detect zmodem initiation sequences and show transfer prompt.
2. Support simple upload/download over terminal stream.
3. Integrate zmodem transfers into the same transfer queue UI.
4. Add compatibility tests against `lrzsz` on Linux test server.

Risks:

- Binary stream handling through terminal and SSH channel must be exact.
- Accidental interception can corrupt terminal output.
- Windows local file picker and permissions need separate QA.

## Performance Feasibility

Terminal risks:

- Massive output can cause Flutter repaint pressure.
- Scrollback memory can grow quickly.
- Session panes can multiply throughput load.

Requirements:

- Cap scrollback with user-configurable limits.
- Batch terminal writes.
- Avoid doing decryption, sync merge, or SFTP hashing on UI isolate.
- Use isolates for CPU-heavy import/export/encryption/sync tasks.

SFTP risks:

- Large transfers need streaming, cancellation, progress, and retries.
- Directory listings with thousands of files need virtualization.

Requirements:

- Use lazy/virtualized file list UI.
- Persist transfer queue metadata.
- Stream file content; never read large files fully into memory.

## Mobile Readiness

Keep shared:

- Domain models.
- Vault protocol.
- Sync providers, where platform APIs permit.
- SSH/SFTP services, unless platform restrictions require adaptation.
- Terminal theme model.

Expect mobile-specific:

- Window/tab/split presentation.
- Keyboard accessory bar.
- Background transfer constraints.
- iCloud/Keychain/secure storage integration.
- File picker/document provider integration.

## Major Technical Risks

| Risk | Impact | Likelihood | Mitigation |
| --- | --- | --- | --- |
| iCloud implementation complexity | High | Medium | Ship WebDAV first; isolate provider API |
| Incorrect crypto protocol | Critical | Medium | Keep small, document, test vectors, external review |
| Terminal performance under heavy output | High | Medium | Benchmark early; batch writes; cap scrollback |
| SSH agent platform differences | Medium | High | Defer behind auth adapter; ship key/password first |
| WebDAV provider inconsistency | Medium | High | Capability tests; temp upload + manifest strategy |
| Linux secure storage availability | Medium | High | Capability UI; passphrase fallback |
| zmodem compatibility | Medium | Medium | Experimental flag; test against lrzsz |

## Recommendation

Proceed with Flutter desktop, `xterm`, `dartssh2`, Drift, encrypted record vault, and provider-based sync. Build local-only SSH and SFTP first, then WebDAV encrypted sync, then iCloud, then advanced workflows such as zmodem, SSH agent, jump hosts, and port forwarding.
