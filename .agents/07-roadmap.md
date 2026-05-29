# Development Roadmap

## Delivery Strategy

Current implementation note, 2026-05-28: the repository has progressed beyond planning. See [13-progress-status.md](13-progress-status.md) for the latest verified implementation status. The roadmap remains the target plan; the current active implementation focus is terminal maturity, stronger sync conflict/device semantics, release engineering, and integration fixtures.

Build in vertical slices that prove the riskiest parts early:

1. Local encrypted vault and host CRUD.
2. SSH terminal connection.
3. SFTP file manager.
4. Encrypted sync through WebDAV.
5. iCloud provider.
6. Advanced SSH workflows.

Each milestone should produce a usable app, even if hidden behind internal builds.

## Phase 0: Project Foundation

Duration: 1-2 weeks.

Deliverables:

- Flutter project scaffold for macOS, Windows, Linux.
- Package layout from architecture document.
- Linting, formatting, CI baseline.
- App shell with navigation and settings placeholder.
- Drift database setup with migrations.
- Riverpod/bootstrap pattern.
- Logging and redaction utilities.
- Basic design tokens and light/dark shell.

Exit criteria:

- App launches on all three desktop platforms.
- CI runs analysis and unit tests.
- Feature modules compile with placeholder repositories.

## Phase 1: Vault, Host Inventory, And Credential Basics

Duration: 3-4 weeks.

Deliverables:

- Vault creation/unlock/lock.
- OS secure storage abstraction with fake and initial platform implementation.
- Passphrase protector.
- Encrypted vault records.
- Host CRUD.
- Identity CRUD for password and private key metadata.
- Private key import preview.
- OpenSSH known_hosts import parser and encrypted trust record import.
- OpenSSH config import preview/UI for common directives, unsupported-directive warnings, and resolvable ProxyJump linking.
- OpenSSH certificate import UI for encrypted certificate identity storage.
- Device-local vault unlock through OS secure storage without storing the passphrase.
- Locked-state UI.

Exit criteria:

- Local database contains no plaintext host/credential records.
- User can create host and identity after vault unlock.
- User can lock app and host list hides sensitive data.
- Unit tests cover vault envelope and host/identity repositories.

## Phase 2: SSH Terminal MVP

Duration: 4-5 weeks.

Deliverables:

- `dartssh2` SSH connection service.
- Password auth.
- Private key auth with passphrase.
- Host key verification and known host storage.
- `xterm` terminal integration.
- PTY resize.
- Built-in local terminal tabs backed by desktop PTY.
- Terminal settings: font size, line height, scrollback, built-in themes, encrypted global persistence, and encrypted per-host overrides.
- Shared workspace tab model for terminal and SFTP tabs.
- Copy/paste, buffer search, and multiline paste warning.
- Connection state/error UI.

Exit criteria:

- User can connect to OpenSSH server from macOS, Windows, Linux.
- User can start a local shell tab on macOS, Windows, and Linux without going through SSH.
- Terminal can run interactive programs such as vim/top.
- Host key unknown/changed flows are tested.
- Terminal remains responsive under synthetic high output.

## Phase 3: SFTP MVP

Duration: 4 weeks.

Deliverables:

- SFTP connection service.
- List/table SFTP browser.
- Directory navigation and breadcrumbs.
- File and folder upload/download.
- Transfer queue with progress, cancel, retry.
- Rename/move/delete/new folder.
- List filtering.
- Permission display and chmod.
- Conflict resolution.
- Open SFTP from host and from active terminal session as a workspace tab.

Exit criteria:

- User can manage remote files through the list/table SFTP experience.
- Large file transfer streams without loading full file into memory.
- Failed transfer can retry.
- File operations surface typed errors.

## Phase 4: WebDAV Encrypted Sync

Duration: 4-6 weeks.

Deliverables:

- Sync provider interface.
- Local file sync provider for tests.
- WebDAV provider.
- Settings > Sync WebDAV setup UI.
- SecretStore-backed WebDAV password storage.
- Encrypted manifest and records.
- Encrypted sync device metadata and writer-device manifest metadata.
- Automatic encrypted snapshot push.
- Incremental sync.
- Conflict detection.
- Safe pull/import of missing encrypted records.
- Blocking conflict resolver UI for same-record encrypted record conflicts.
- Field-level resolver UI for hosts/identities/snippets/settings.
- Automatic sync after encrypted record changes and periodic background refresh.
- Device list and device revocation/cleanup.
- Blocking repair actions for missing, corrupted, mismatched, or wrong-vault remote manifests.
- Sync account setup and secure credential storage.

Exit criteria:

- Two desktop devices/profiles can sync host inventory through WebDAV.
- Provider data contains only encrypted payloads.
- Conflicts are detected and resolvable.
- Offline edits sync after reconnection.

## Phase 5: Desktop UX Completion

Duration: 3-5 weeks.

Deliverables:

- Command palette.
- Terminal split panes.
- Workspace tab polish for mixed terminal/SFTP tabs.
- Host groups/tags bulk editing.
- Snippets insertion.
- Transfer history.
- Keyboard shortcut map.
- Search hosts and sessions.
- Settings screens completed.
- Accessibility pass.
- Visual polish across macOS/Windows/Linux.

Exit criteria:

- Common workflows are keyboard-friendly.
- UI handles narrow and wide desktop windows.
- Light/dark themes are production quality.
- Accessibility labels and focus traversal pass review.

## Phase 6: Advanced SSH

Duration: 5-8 weeks, can run partially parallel after Phase 2.

Current status, 2026-05-28: first-release code now includes local/remote/SOCKS forwarding UI, ProxyJump chaining, keyboard-interactive auth material, and startup commands. SSH agent, FIDO2/hardware keys, zmodem/rz/sz, and PuTTY PPK import are out of first-release scope. Remaining first-release work is integration fixtures and terminal compatibility verification.

Deliverables:

- Local/remote/dynamic port forwarding.
- Jump hosts / ProxyJump.
- Keyboard-interactive auth.
- Startup commands.
- Known hosts manager.
- Integration fixtures for bastion, certificate, startup command, and forwarding flows.
- Post-v1: SSH agent integration.
- Post-v1: Zmodem/rz/sz detection and transfer flow.

Exit criteria:

- Port forwards can be started/stopped and show status.
- Jump host connection works with at least one bastion. Code-level connection chaining is implemented; integration fixture coverage is still required.
- Startup commands execute only after terminal attach and do not imply remote process recovery.
- Deferred post-v1 SSH agent and rz/sz work has explicit scope records.

## Phase 7: iCloud Sync

Current decision, 2026-05-28: CloudKit and iCloud Drive are out of scope for the first desktop release. WebDAV is the first-release encrypted sync provider. Keep Phase 7 as post-v1 work behind the existing `SyncProvider` abstraction.

Duration: 4-8 weeks depending on chosen strategy.

Deliverables:

- Native macOS iCloud provider.
- Entitlement/config documentation.
- iCloud account status detection.
- Encrypted record upload/download.
- Conflict behavior parity with WebDAV.
- Optional Keychain sync capability investigation.

Exit criteria:

- macOS users can sync encrypted vault data through iCloud.
- Provider receives no plaintext.
- Failure states for iCloud disabled, quota, network, account unavailable are clear.

## Phase 8: Beta Hardening

Duration: 4-6 weeks.

Deliverables:

- Packaging for macOS, Windows, Linux.
- Auto-update strategy decision.
- Security review.
- Performance profiling.
- Crash diagnostics with redaction.
- Redacted diagnostic bundle export.
- Documentation and onboarding.
- Backup/restore workflow.
- Migration tests.

Exit criteria:

- Signed/notarized macOS build.
- Windows package build.
- Linux package build.
- Beta release checklist complete.
- No critical security findings open.

## Parallel Workstreams

### Core Platform

- Database.
- Vault.
- Secure storage.
- Sync provider.

### Terminal/SSH

- SSH connection.
- Terminal UI.
- Host key verification.
- Advanced SSH.

### File Management

- SFTP browsing.
- Transfer queue.
- Conflict and permissions.

### UX/Design

- Design system.
- Shell/navigation.
- Settings.
- Command palette.

### QA/Release

- Test infrastructure.
- Containerized SSH server.
- Cross-platform CI.
- Packaging.

## Suggested MVP Scope

Desktop MVP should include:

- Vault.
- Host/identity management.
- SSH terminal.
- SFTP file manager.
- Explorer-style SFTP file manager mode and dual-pane workflow after MVP; bounded text preview/edit can remain available in the list/table view.
- WebDAV encrypted sync.
- Terminal themes.
- Basic snippets.
- Host key verification.
- Private key import.

Defer from MVP:

- iCloud to beta or v1.1 if native plugin schedule slips.
- zmodem to experimental flag if compatibility is not ready.
- SSH agent if platform support is incomplete.
- Hardware security key / FIDO2 SSH auth until async signing architecture exists.
- PuTTY PPK import until the OpenSSH import path is fully hardened.
- Explorer-style SFTP mode until list/table SFTP has integration coverage.
- Team collaboration.
- Mobile builds.

## Staffing Estimate

For a high-quality desktop MVP:

- 1 Flutter application engineer.
- 1 Flutter UI/design systems engineer.
- 1 systems/security engineer for vault, SSH, sync.
- 1 QA/release engineer part-time.

Small team schedule: roughly 4-6 months to solid beta, depending on iCloud/zmodem scope.

## Milestone Quality Gates

Every phase must include:

- Unit tests for new domain/service logic.
- Manual QA checklist.
- Security review for secret-handling changes.
- Cross-platform smoke test.
- Documentation update in `.agents` if behavior changes.
