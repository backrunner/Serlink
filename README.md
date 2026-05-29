# Serlink

Serlink is a Flutter-based desktop SSH terminal and SFTP workstation for macOS, Windows, and Linux.

Current code status: the project already has a substantial desktop core, including an encrypted vault, host and identity management, mixed Terminal/SFTP/local-terminal tabs, transfer queueing, and automatic encrypted WebDAV sync. It is not yet release-complete: packaging, real integration fixtures, and cross-platform QA are still in progress.

## Current Scope

Primary target in this repository:

- macOS
- Windows
- Linux

Desktop-first architecture is being kept compatible with future mobile expansion, but iOS/Android clients are not part of the current implementation round.

## Implemented

### Security and Storage

- Encrypted vault with lock/unlock flows
- Recovery key support
- Device-local unlock protector via OS secure storage
- Encrypted Drift/SQLite record storage
- Encrypted backup export/import
- Encrypted known-host storage
- Best-effort local profile locking and restrictive file permissions on non-Windows platforms

### Hosts and Credentials

- Host CRUD
- Password identities
- Private key identities
- OpenSSH certificate identities
- Known-host verification and fingerprint confirmation modal
- OpenSSH config preview/import with:
  - `Include` expansion
  - `Host *` inheritance
  - wildcard inheritance for concrete aliases
  - `Match` isolation
  - `IdentityFile` import/linking
  - paired `CertificateFile` import
  - `ProxyJump` resolution/linking
- OpenSSH `known_hosts` import with explicit warnings for hashed entries, patterns, `@cert-authority`, and `@revoked`

### Terminal

- SSH terminal tabs backed by `xterm`
- Local terminal tabs backed by `flutter_pty`
- Mixed Terminal / SFTP / Local Terminal tab container
- Reconnect-in-place semantics
- Automatic reconnect policy from host settings
- Multiline paste confirmation
- Terminal buffer search
- Theme / font / line-height settings
- Per-host terminal display profiles
- Split terminal panes inside a tab
- Local/remote/SOCKS dynamic port forwarding UI and lifecycle
- Startup commands after shell attach

### SFTP and Transfers

- SFTP list/table view
- Directory navigation and filtering
- `mkdir`, rename, move, delete, `chmod`
- Bounded text preview/edit for remote files
- File and folder upload/download
- Transfer queue with:
  - global concurrency limit
  - progress, speed, ETA
  - pause / resume / cancel / retry
  - encrypted transfer history
- Conflict handling for upload/download targets:
  - replace / merge
  - rename
  - skip

### Sync

- Automatic encrypted WebDAV sync
- Encrypted WebDAV settings
- WebDAV password storage via secure storage, not plaintext DB records
- Conflict detection and blocking resolution flow
- Delete tombstone propagation
- Device metadata and device cleanup
- Remote repair handling for missing/corrupt/wrong-vault manifests
- TLS certificate diagnostics and endpoint pinning
- Sync object-path validation to reject traversal/unsafe refs

### Diagnostics

- Sentry integration with redaction hooks
- Redacted diagnostic bundle export
- Debug-oriented logging without a debug panel

## Not Yet Release-Complete

These areas are still open before a production desktop release:

- macOS signing/notarization, Windows installer/MSIX, Linux packaging
- CI, dependency audit, SBOM, third-party notices
- Real integration fixtures for SSH/SFTP/WebDAV/ProxyJump/OpenSSH certificates/forwarding
- Cross-platform secure-storage and IME verification on real machines
- Final accessibility and polish pass
- OpenSSH import validation against real `ssh -G` behavior

## Intentionally Deferred From First Desktop Release

- CloudKit sync
- iCloud Drive sync
- SSH Agent auth
- FIDO2 / hardware security key SSH auth
- Zmodem / `rz` / `sz`
- PuTTY PPK import
- Explorer-style SFTP file manager mode
- Full vault cryptographic rekey flow

See [.agents/14-release-scope-decisions.md](.agents/14-release-scope-decisions.md) for the maintained scope decisions.

## Development

### Requirements

- Flutter SDK compatible with `sdk: ^3.12.0`
- Desktop Flutter toolchains for the target OS
- Xcode command line tools on macOS
- Visual Studio C++ desktop workload on Windows
- GTK/clang toolchain normally required by Flutter desktop on Linux

### Install Dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

### Static Analysis

```bash
flutter analyze
```

### Tests

```bash
flutter test
```

As of 2026-05-29:

- `flutter analyze` passes
- `flutter test` passes with 182 tests

## Repository Layout

```text
lib/
  app/          app shell, dependency wiring, router, theme
  core/         shared failures, ids, runtime, security, logging
  database/     Drift database
  features/     product modules: vault, hosts, ssh, terminal, sftp, sync, etc.
  platform/     OS integration wrappers such as secure storage

test/           unit, widget, and smoke tests
.agents/        planning, architecture, gap analysis, and roadmap docs
```

## Security Notes

- Sensitive host, identity, and settings data are designed to be stored encrypted at rest.
- WebDAV sync transfers encrypted manifests and encrypted records, not plaintext host data.
- Vault lock does not forcibly tear down already-established SSH/SFTP sessions.
- Full app exit does not restore workspace tabs or live sessions on next launch.

## Known Issues

- `flutter_pty` currently emits a macOS Swift Package Manager support warning during Flutter commands. It is non-blocking today, but it must be addressed before upgrading to a Flutter version that makes it fatal.
- Current verification is mostly unit/widget/smoke level. Integration coverage against real SSH/SFTP/WebDAV stacks is still missing.

## Project Docs

Detailed planning and implementation docs live under `.agents/`:

- [.agents/01-product-requirements.md](.agents/01-product-requirements.md)
- [.agents/02-technical-feasibility.md](.agents/02-technical-feasibility.md)
- [.agents/06-code-level-design.md](.agents/06-code-level-design.md)
- [.agents/07-roadmap.md](.agents/07-roadmap.md)
- [.agents/12-gap-analysis.md](.agents/12-gap-analysis.md)
- [.agents/13-progress-status.md](.agents/13-progress-status.md)
- [.agents/14-release-scope-decisions.md](.agents/14-release-scope-decisions.md)
