# Release Scope Decisions

Last updated: 2026-05-29.

This file records capabilities intentionally moved out of the first desktop release. These are not permanent product rejections; they are excluded from the current release target because implementation cost, platform variance, or upstream limitations would reduce release quality.

## In Scope For First Desktop Release

- macOS, Windows, and Linux desktop app.
- Encrypted local Vault and encrypted record storage.
- Host, identity, known-host, import/export, and encrypted backup flows.
- SSH terminal with password, private key, keyboard-interactive, OpenSSH certificate auth, host-key verification, ProxyJump, startup commands, and local/remote/SOCKS dynamic port forwarding.
- Real local terminal tabs through desktop PTY, subject to resolving the `flutter_pty` macOS Swift Package Manager warning before release if Flutter makes it fatal.
- SFTP list/table file manager with upload/download for files and folders, queueing, conflict handling, common file operations, preview/edit for bounded text files, and transfer history.
- WebDAV encrypted automatic sync, same-record conflict handling, tombstone delete propagation, and blocking remote repair actions for missing/corrupted/wrong-vault manifests.
- Settings-contained sync UI, local OS secure-storage vault unlock protection, security modals, Sentry crash/error/performance telemetry with redaction, and diagnostic export.
- Release engineering for direct desktop distribution.

## Out Of Scope For First Desktop Release

### iCloud Sync Providers

Decision: defer CloudKit and iCloud Drive providers.

Reason:

- macOS-only native plugin, entitlements, account state, quota behavior, and file coordination are all substantial.
- WebDAV already proves the encrypted sync protocol without tying the first release to Apple-specific infrastructure.

Follow-up condition:

- Revisit after WebDAV sync has integration fixtures, repair flows, and stable encrypted manifest semantics.

### SSH Agent Authentication

Decision: defer local SSH agent auth for macOS/Linux `SSH_AUTH_SOCK`, Windows OpenSSH agent, and Pageant.

Reason:

- `dartssh2` public-key auth currently expects synchronous `SSHKeyPair.sign()`.
- Real local agents require asynchronous Unix socket or named-pipe signing.
- A robust implementation needs either an async signer adapter in `dartssh2`, a maintained fork, or a separate connection backend strategy.

Follow-up condition:

- Revisit after choosing an upstream/fork strategy for async public-key signing.

### Hardware Security Key / FIDO2 SSH Auth

Decision: defer.

Reason:

- Requires platform-native FIDO/U2F handling and SSH signature integration.
- This depends on the same async signing path as agent auth and has additional UX/security prompts.

Follow-up condition:

- Revisit after async signer architecture is available.

### Zmodem / rz / sz

Decision: defer terminal-integrated zmodem for the first release.

Reason:

- zmodem intercepts terminal byte streams and can corrupt interactive output if detection is imperfect.
- SFTP file/folder transfer queue already covers the primary file-transfer need for v1.

Follow-up condition:

- Revisit behind an experimental flag with `lrzsz` fixtures.

### PuTTY PPK Import

Decision: defer.

Reason:

- Requires PPK parsing/conversion and validation beyond current private-key import support.

Follow-up condition:

- Revisit after OpenSSH private key import, IdentityFile linking, and certificate auth are fully exercised in integration tests.

### Explorer-Style SFTP Mode

Decision: defer as a post-v1 UI enhancement.

Reason:

- Current list/table SFTP already supports file/folder transfer and common operations.
- Explorer-style dual-pane/drag-drop mode is mainly UX expansion, not a release blocker for core file management.

Follow-up condition:

- Revisit after list/table SFTP has integration fixtures and cross-platform file picker/drag-drop QA.

## Still Required For First Desktop Release

- Shortcut pass-through and CJK/IME verification.
- Provider-specific sync quota guidance and partial-upload repair guidance.
- OS-specific validation for secure storage capability/fallback UX.
- Remaining OpenSSH import hardening is now focused on validation against real `ssh -G`, richer `ProxyCommand` manual-conversion guidance, and future product semantics for host CAs/revoked keys. `Include`, `Host *` inheritance, `Match` isolation, paired `CertificateFile` import, and known-host security marker warnings have code coverage.
- Integration fixtures for SSH, SFTP, WebDAV, ProxyJump, OpenSSH certificates, startup commands, and port forwarding.
- Release packaging, signing/notarization, installers, SBOM, license notices, dependency audit, app-version/package metadata in support bundles, and cross-platform CI.
