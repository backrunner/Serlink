# Implementation Backlog

This backlog turns the planning documents into module-sized implementation work. Each item should be small enough for an implementation agent or engineer to own with clear dependencies and a definition of done.

## Epic A: Project Foundation

### A1 Flutter Desktop Scaffold

Dependencies: none.

Deliverables:

- Create Flutter app with macOS, Windows, Linux targets.
- Add package structure from [03-architecture.md](03-architecture.md).
- Add lint rules, formatting, and test folders.
- Add app bootstrap and placeholder shell.

Definition of done:

- `flutter analyze` passes.
- `flutter test` passes.
- App launches on macOS locally and is ready for Windows/Linux CI smoke tests.

### A2 Dependency Baseline

Dependencies: A1.

Deliverables:

- Add `xterm`, `dartssh2`, Drift, SQLite, Riverpod, routing, file picker, secure storage, cryptography packages.
- Create dependency decision notes in code comments or docs when a package has platform risk.
- Add wrapper interfaces before feature code consumes libraries directly.

Definition of done:

- Dependencies compile on desktop.
- No feature UI imports `dartssh2` directly.

### A3 App Shell And Routing

Dependencies: A1.

Deliverables:

- Desktop shell with sidebar, top toolbar, and main content outlet.
- Routes for hosts, sessions, files, transfers, snippets, settings.
- Locked vault route placeholder.
- Global status area placeholder.

Definition of done:

- Navigation works with keyboard and pointer.
- Layout adapts from 900 px to wide desktop widths.

## Epic B: Vault And Storage

### B1 Vault Envelope Format

Dependencies: A2.

Deliverables:

- Implement `VaultRecordEnvelope`.
- Implement AEAD encryption/decryption.
- Include associated data validation.
- Add test vectors.

Definition of done:

- Tampered ciphertext and tampered AAD fail tests.
- No plaintext test hostnames appear in serialized records.

### B2 Key Protectors

Dependencies: B1.

Deliverables:

- OS secure storage protector.
- Passphrase protector.
- Recovery key model, even if UI ships later.
- Vault create/unlock/lock service.

Definition of done:

- User can create vault and unlock with passphrase.
- Fake secret store tests cover missing/unavailable secure storage.

### B3 Drift Database

Dependencies: A2, B1.

Deliverables:

- Drift database schema.
- `vault_records`, indexes, settings, sync checkpoint, transfer task tables.
- Migration test baseline.

Definition of done:

- Database can store/retrieve encrypted records.
- Schema migration test exists.

### B4 Redaction And Logging

Dependencies: A1.

Deliverables:

- Redaction utilities.
- Typed log events.
- Sensitive value wrappers.

Definition of done:

- Unit tests prove sample secrets are redacted.
- Logging guidelines are enforced in core services.

## Epic C: Host And Identity Management

### C1 Host Repository And UI

Dependencies: B1, B3.

Deliverables:

- Host domain validation.
- Host repository.
- Host list, create/edit/detail UI.
- Group/tag fields.

Definition of done:

- Host CRUD works after vault unlock.
- Locked state hides host data.

### C2 Identity Repository And UI

Dependencies: B2, B3.

Deliverables:

- Identity domain model.
- Password identity.
- Private key identity metadata.
- Portable vs device-local display.

Definition of done:

- Identity can be created, linked to host, and deleted.
- UI clearly labels storage mode.

### C3 Private Key Import

Dependencies: C2.

Deliverables:

- File and clipboard import.
- Format detection.
- Passphrase prompt.
- Fingerprint display.
- Storage choice UI.

Definition of done:

- Test keys import successfully.
- Unsupported key format returns actionable error.

### C4 Data Export

Dependencies: B2, C1, C2.

Deliverables:

- Encrypted vault backup export.
- Selected host metadata export.
- Public key material export where applicable.
- Diagnostic bundle export with redaction.
- Export preview and security confirmation modal.

Definition of done:

- Sensitive export cannot proceed without modal confirmation.
- Encrypted backup restore path is documented and tested.
- Diagnostic bundle contains no plaintext secrets, hostnames, usernames, commands, or paths by default.

### C5 OpenSSH Config Import

Dependencies: C1, C2.

Deliverables:

- Parser/adapter for common directives.
- Import preview modal.
- Settings import entry.
- Encrypted host metadata writes after confirmation.
- Warning list for unsupported directives.
- Resolvable ProxyJump alias linking to imported or existing host IDs.
- Identity file linking/import prompts.
- Host pattern and invalid directive warnings.

Definition of done:

- Fixture configs import expected hosts.
- Unsupported directives are visible in preview.
- Resolvable ProxyJump aliases are written as encrypted host jump links.
- Imported host metadata is encrypted in vault records.

### C6 OpenSSH Known Hosts Import

Dependencies: C1, D2.

Deliverables:

- Parser for plain OpenSSH `known_hosts` hostname and `[host]:port` entries.
- Warnings for hashed hosts, wildcard patterns, markers, and invalid key blobs.
- Hostname/port matching against existing Serlink hosts.
- Encrypted known-host record writes with dartssh2-compatible MD5 fingerprints.

Definition of done:

- Matching known_hosts entries skip future trust prompts for existing hosts.
- Hashed and marker entries are not silently imported.
- Imported fingerprints are stored only inside encrypted vault records.

### C7 OpenSSH Certificate Import

Dependencies: C2.

Deliverables:

- OpenSSH certificate public-key line validation.
- Private key format validation.
- Preview warnings for missing comments and passphrase whitespace.
- Encrypted certificate/private-key/passphrase secret material writes.
- `openSshCertificate` identity record creation.
- Settings > Data import entry and blocking preview modal.

Definition of done:

- Certificate import stores no plaintext key, certificate, passphrase, or principal in serialized vault records.
- Invalid certificate and private-key formats fail before writing records.
- UI stores imported certificate identities through the encrypted identity repository.

## Epic D: SSH Terminal

### D1 SSH Service

Dependencies: B2, C1, C2.

Deliverables:

- `SshSessionService` using `dartssh2`.
- Password auth.
- Private key auth.
- Connection profile resolution.
- Typed SSH errors.

Definition of done:

- Integration test connects to OpenSSH test server.
- Auth failure is handled without leaking secret values.

### D2 Host Key Verification

Dependencies: D1.

Deliverables:

- Known host storage.
- First trust prompt.
- Changed host key warning.
- Fingerprint display.
- Blocking fingerprint confirmation modal.

Definition of done:

- Tests cover unknown, matching, changed, and rejected keys.
- UI test verifies safe default action in fingerprint modal.

### D3 Xterm Integration

Dependencies: D1.

Deliverables:

- `TerminalAdapter` wrapping `xterm`.
- Terminal widget.
- SSH channel stream attachment.
- Batched stdout/stderr writes for high-output sessions.
- PTY resize.
- Basic copy/paste.
- Multiline paste confirmation.

Definition of done:

- Interactive shell works.
- Resize updates remote PTY.
- Terminal survives high-output smoke test.

### D4 Terminal Workspace

Dependencies: D3.

Deliverables:

- Shared workspace tab container.
- Terminal tab type.
- Local terminal tab type backed by desktop PTY.
- SFTP tab type integration point.
- Same-host SFTP from terminal tabs and same-host terminal from SFTP tabs.
- Session lifecycle state UI.
- Global and per-host terminal profile settings.
- Encrypted persistence for global and per-host terminal display settings.
- Built-in themes.
- Search buffer.
- Reconnect/close actions for failed or disconnected tabs.

Definition of done:

- Multiple sessions can run independently.
- Local terminal opens the user's default desktop shell and reconnect starts a new shell in the same tab.
- Terminal and SFTP tabs can be mixed in one tab strip.
- Users can open related terminal/SFTP tabs without returning to the host list.
- Unexpected disconnect leaves a recoverable tab state.
- Font/theme settings persist globally and can be overridden per host.

## Epic E: SFTP And Transfers

### E1 SFTP Service

Dependencies: D1.

Deliverables:

- `SftpConnection` using `dartssh2`.
- List, mkdir, rename, delete, chmod.
- Move via SFTP rename.
- Typed SFTP errors.

Definition of done:

- Integration tests pass against SFTP test server.

### E2 File Manager UI

Dependencies: E1, A3.

Deliverables:

- File table.
- List filtering.
- Breadcrumb path navigation.
- Hidden file toggle.
- Sort and refresh.
- Bounded text preview and remote edit modal for files.
- Open terminal here action.
- Shared workspace tab integration.

Definition of done:

- User can browse directories and inspect metadata.
- User can preview and edit bounded-size text files without leaving the list/table view.
- SFTP opens as a tab in the shared workspace container.
- Large directory UI remains responsive.
- Explorer-style file manager mode is not part of MVP and remains roadmap work.

### E3 Transfer Queue

Dependencies: E1, B3.

Deliverables:

- File and folder upload/download streaming.
- Progress, speed, ETA.
- Cancel/retry.
- Conflict overwrite/skip/rename.
- Durable task metadata.

Definition of done:

- Large upload/download works in bounded memory.
- Failed task can retry.

## Epic F: Sync

### F1 Sync Protocol And Local Provider

Dependencies: B1, B3.

Deliverables:

- Encrypted manifest model.
- Sync provider interface.
- Local filesystem provider for tests.
- Merge engine.

Definition of done:

- Two local vault directories can sync encrypted records.
- Conflict tests pass.

### F2 WebDAV Provider

Dependencies: F1, B2.

Deliverables:

- WebDAV account setup.
- Provider credential storage.
- PROPFIND/GET/PUT/MKCOL/MOVE support.
- Retry/backoff.

Definition of done:

- WebDAV integration test syncs two profiles.
- Remote objects contain no plaintext fixtures.

### F3 Settings Sync UI

Dependencies: F2.

Deliverables:

- Settings > Sync section.
- WebDAV configuration form.
- HTTPS-by-default validation and blocking HTTP opt-in confirmation.
- SecretStore-backed provider password storage.
- Automatic sync after encrypted record changes and periodic background refresh.
- Encrypted snapshot push of vault header, record envelopes, and manifest.
- Device-local sync device ID and encrypted device metadata records.
- Settings modal for listing sync devices and removing non-local device records.
- Pull missing encrypted records.
- Same-record revision conflict detection.
- Minimal sync status text/actions inside Settings.
- Blocking same-record conflict resolver with keep-local/use-remote actions.
- Field-level conflict resolver for decryptable host/identity/snippet/settings records.
- Provider error states.

Definition of done:

- User can configure WebDAV and resolve same-record conflict inside Settings.
- WebDAV password is absent from encrypted settings records and local SQLite plaintext.
- Synced device metadata is encrypted before leaving the machine.

### F4 iCloud Provider

Dependencies: F1.

Deliverables:

- Native macOS provider prototype.
- Account availability detection.
- Encrypted object read/write.
- Entitlement documentation.

Definition of done:

- macOS beta can sync encrypted records through selected iCloud backend.

## Epic G: Advanced SSH

### G1 Port Forwarding

Dependencies: D1, D4.

Deliverables:

- Local forwarding. Implemented for one local forward per active Terminal tab.
- Remote forwarding. Implemented in the service backend; UI and fixtures still pending.
- Dynamic/SOCKS forwarding. Implemented in the service backend; UI and fixtures still pending.
- Status and stop controls. Implemented for the local forwarding path.
- Status and stop controls for remote/dynamic forwarding.
- Forwarding integration fixtures.

Definition of done:

- Forwarding works against test server and cleans up ports on close.

### G2 Jump Hosts

Dependencies: D1.

Deliverables:

- ProxyJump model. Implemented through encrypted host `jumpHostIds`.
- Connection profile chain resolution. Implemented with ordered chain expansion and cycle detection.
- Bastion connection implementation. Implemented with nested dartssh2 `forwardLocal` channels.
- Bastion integration fixture and end-to-end test.

Definition of done:

- Host connects through a test bastion.

### G3 SSH Agent

Dependencies: D1, platform research.

Deliverables:

- Capability detection.
- macOS/Linux `SSH_AUTH_SOCK` support.
- Windows agent support investigation/implementation.
- Dedicated async signer strategy or dartssh2 fork/upstream change. Current blocker: dartssh2 public-key auth calls `SSHKeyPair.sign()` synchronously, while local SSH agents require async Unix socket or named-pipe signing.

Definition of done:

- Agent auth works on at least macOS and Linux before enabling flag by default.

### G4 Zmodem / rz / sz

Dependencies: D3, E3.

Deliverables:

- Terminal stream detector.
- Transfer prompt.
- Upload/download integration with queue.
- lrzsz compatibility tests.

Definition of done:

- Representative rz/sz upload and download work against Linux test server.
- Unrecognized sequences pass through safely.

## Epic H: Design, Accessibility, And Polish

### H1 Design Tokens And Components

Dependencies: A3.

Deliverables:

- Color, spacing, type, radius tokens.
- Buttons, icon buttons, side nav, toolbar, dialogs, tables.
- Security modal components for fingerprint, export, destructive action, and multiline paste confirmations.
- Shared workspace tab components for terminal/SFTP mixed tabs.
- Light/dark themes.

Definition of done:

- Feature screens use shared components and tokens.

### H2 Command Palette

Dependencies: A3, C1, D4, E2.

Deliverables:

- Palette UI.
- Commands for connect, SFTP, settings, import, export backup, and split terminal. Sync remains automatic; command palette may expose repair or conflict-resolution entries only when auto-sync is blocked.
- Keyboard navigation.

Definition of done:

- User can connect to a host without using mouse.

### H3 Accessibility Pass

Dependencies: major feature UI.

Deliverables:

- Focus traversal.
- Tooltips.
- Semantic labels.
- Contrast checks.
- Reduced motion support.

Definition of done:

- Primary workflows are keyboard-accessible.

## Epic I: Release Engineering

### I1 Integration Test Environment

Dependencies: A1.

Deliverables:

- OpenSSH test server.
- SFTP fixture server.
- WebDAV fixture server.
- lrzsz test server.

Definition of done:

- CI can run integration tests on Linux.

### I2 Desktop Packaging

Dependencies: core MVP.

Deliverables:

- macOS signed/notarized build path.
- Windows MSIX build path.
- Linux AppImage or Flatpak build path.

Definition of done:

- Internal builds install and launch on all desktop platforms.

### I3 Beta Readiness

Dependencies: MVP feature set.

Deliverables:

- Release checklist.
- Security review checklist.
- Known limitations.
- User docs.
- Release crash-resilience checklist.
- Debug/profile/release runtime mode verification.

Definition of done:

- Private beta can be shipped with clear rollback/backup guidance.
- Release build contains recoverable SSH/SFTP/sync failures without process crash in smoke tests.
