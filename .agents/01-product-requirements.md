# Product Requirements

## Vision

Serlink is a professional cross-platform SSH terminal and SFTP workstation for engineers, operators, and technical teams. It should combine the speed and reliability of a local terminal with the organization, sync, and credential management expected from modern clients such as Terminus/Termius.

The first release focuses on macOS, Windows, and Linux. Every core decision must keep future iOS and Android clients viable: domain models are portable, sync uses encrypted records, and UI patterns are responsive enough to adapt to touch.

## Goals

- Provide a complete SSH terminal experience on desktop platforms.
- Store, search, group, tag, import, export, and sync host configurations.
- Support SSH authentication through password, private key, passphrase, agent, and OS-provided credentials where possible.
- Support importing SSH private keys, public keys, known hosts, and OpenSSH config entries.
- Provide an integrated SFTP file manager with transfers, permissions, and remote file operations.
- Protect host data and credentials with end-to-end encryption before iCloud or WebDAV sync.
- Provide a unified, professional, efficient, simple UI across desktop platforms.
- Keep enough abstraction for future mobile support without reducing desktop quality.
- Provide both import and export for SSH configs, keys, encrypted vault backups, and app data where safe.
- Use modal confirmation flows for security-sensitive events such as host fingerprint verification, changed host keys, credential export, vault reset, and destructive actions.

## Non-Goals For Desktop MVP

- Full tmux replacement.
- Browser-based web terminal.
- Team collaboration, RBAC, or shared enterprise vaults.
- Built-in server monitoring dashboards.
- Full Mosh support.
- Native mobile releases in the first milestone.
- Every rz/sz edge case in MVP; zmodem support can ship progressively behind capability detection.

## Personas

### Individual Developer

Needs quick access to personal servers, cloud VMs, and dev boxes. Wants saved hosts, synced keys, terminal themes, SFTP upload/download, and reliable reconnects.

### DevOps / SRE

Works with many hosts, jump servers, port forwards, snippets, and incident workflows. Wants fast search, keyboard-first operations, secure credential storage, and clear connection status.

### Cross-Platform Team Member

Uses more than one OS. Needs the same encrypted host inventory on macOS, Windows, and Linux, with platform-specific credential integrations when available.

## Terminus / Termius-Inspired Feature Map

Termius-style capabilities to evaluate and selectively implement:

- Hosts and groups.
- SSH terminal sessions.
- SFTP file browser.
- Identities / key management.
- Snippets and command shortcuts.
- Port forwarding.
- Known hosts and host key verification.
- Sync across devices.
- End-to-end encrypted vault data.
- Import from OpenSSH config.
- Local terminal themes and terminal preferences.
- Multi-tab workflows.
- Jump hosts / proxy commands.

Serlink should not clone visual details. It should implement the same class of professional SSH workflows while using its own concise desktop-first interaction model.

Reference pages checked on 2026-05-27 Asia/Shanghai:

- Termius product page: https://termius.com/
- Termius vault documentation: https://termius.com/documentation/set-up-vaults
- Termius SSH key documentation: https://termius.com/documentation/ssh-keys
- Termius mobile sync documentation: https://termius.com/documentation/sync-to-mobile

## Core User Stories

### Host Management

- As a user, I can create a host with name, hostname, port, username, auth method, tags, group, environment, and notes.
- As a user, I can duplicate, archive, delete, pin, search, and filter hosts.
- As a user, I can import hosts from `~/.ssh/config`.
- As a user, I can attach one or more identities to a host.
- As a user, I can define jump host settings and proxy chains.
- As a user, I can choose whether a host uses portable encrypted credentials or OS-native credentials.

### Credential Management

- As a user, I can import SSH private keys from file or clipboard.
- As a user, I can export selected non-secret public metadata or encrypted backups after explicit security confirmation.
- As a user, I can store key passphrases securely.
- As a user, I can create identity records that can be reused by multiple hosts.
- As a user, I can use password authentication where allowed.
- As a user, I can use local SSH agent authentication when available.
- As a macOS user, I can choose Keychain-backed storage, including a future option for Keychain sync where platform rules allow it.
- As a user, I can inspect which credentials are portable and which are device-local.

### Terminal

- As a user, I can open an SSH terminal from any host record.
- As a user, I can open multiple terminal and SFTP tabs in one shared workspace tab container.
- As a user, I can choose whether a connection opens as terminal, SFTP, or both when starting from a host.
- As a user, I can maintain simultaneous connections to multiple different hosts.
- As a user, I can customize font family, font size, cursor style, color theme, scrollback, copy mode, bell, and selection behavior.
- As a user, I can use common terminal shortcuts, bracketed paste, mouse reporting, alternate screen, and clipboard copy/paste.
- As a user, I can reconnect after network interruptions when feasible.
- As a user, I can see clear connection states: connecting, authenticating, verifying host key, connected, reconnecting, failed, disconnected.
- As a user, I understand that reconnecting in the current tab creates a new SSH/SFTP connection; SSH shell process state is not restored unless the remote side uses tmux/screen or another session manager.

### SFTP

- As a user, I can open SFTP for a host using the same connection profile as a workspace tab.
- As a user, I can browse remote directories, sort, search, create folders, rename, delete, upload, download, and move files.
- As a user, I can view file metadata, permissions, owner/group where available, and hidden files.
- As a user, I can manage a transfer queue with progress, retry, cancel, overwrite, skip, rename, and conflict resolution.
- As a user, I can drag files from the OS file manager into Serlink for upload and drag downloads out where platform support allows.
- As a user, I can open terminal and SFTP tabs for the same host or different hosts in the same tab container.

### Advanced SSH

- As a user, I can define local, remote, and dynamic port forwards.
- As a user, I can use jump hosts.
- As a user, I can upload or download files through zmodem/rz/sz when the remote environment supports it.
- As a user, I can define reusable command snippets.
- As a user, I can optionally run startup commands after login.
- As a user, I can manage known hosts and handle changed host keys safely.
- As a user, I can review and confirm server fingerprints in a focused modal before trusting a host key.

### Sync

- As a user, I can enable iCloud sync.
- As a user, I can enable WebDAV sync by entering endpoint, username, password/app-password, and path.
- As a user, I can sync encrypted host records, identities, snippets, settings, and metadata.
- As a user, I can resolve conflicts without exposing plaintext to the sync provider.
- As a user, I can disable sync and continue using local data.
- As a user, I can reset local data from remote encrypted vault after authenticating with vault credentials.

## Functional Requirements

### Host Inventory

- Store hosts, groups, tags, identities, snippets, port forwards, known host keys, and sync metadata.
- Support soft delete with trash/recovery for at least host and identity records.
- Provide full-text local search over decrypted display fields.
- Maintain immutable record IDs so sync can merge across devices.
- Support import from OpenSSH config with a preview step.
- Support export of selected host metadata and encrypted vault backups with a confirmation modal and clear sensitivity labels.

### SSH Connection

- Support SSH protocol v2 through `dartssh2`.
- Support password authentication.
- Support public key authentication with imported private keys.
- Support passphrase-protected private keys.
- Support SSH agent integration as a platform-specific enhancement.
- Support keyboard-interactive authentication as a post-MVP requirement.
- Persist known host keys and verify on each connection.
- Provide clear host-key changed warnings requiring explicit user action.
- Host key fingerprints and changed-key warnings must be shown in modal dialogs that block the connection until the user chooses cancel, trust once, or replace stored key.

### Terminal Emulation

- Use xterm-compatible terminal emulation via `xterm`.
- Support PTY sizing and resize propagation.
- Support UTF-8 input/output.
- Support scrollback configuration.
- Support copy/paste and selection.
- Support terminal themes at the application and host-profile level.
- Support zmodem detection hooks so rz/sz flows can intercept terminal byte streams.

### SFTP

- Use SFTP through the existing SSH transport where possible.
- Support one-off SFTP sessions and terminal-associated SFTP sessions.
- Cache remote directory listings briefly for navigation performance but invalidate after mutations.
- Transfer files through a queue with durable task state for long-running transfers.
- Preserve modified times when supported.
- Provide permissions editor using octal and symbolic presentation.

### Sync

- Sync encrypted records only.
- Support iCloud and WebDAV behind a provider interface.
- Support incremental sync using record revision, vector clock or hybrid logical timestamp, tombstones, and conflict payloads.
- Support offline-first operation.
- Provide automatic sync after encrypted record changes and periodic background refresh.
- Avoid storing sync provider credentials in plaintext.

## Security Requirements

- All sensitive records must be encrypted at rest.
- Synced data must be encrypted before leaving the device.
- Master encryption key material must be protected by OS secure storage where available.
- A user-defined vault passphrase must be supported for portable recovery and multi-device onboarding.
- Memory exposure of secrets must be minimized; avoid excessive logging and never log credential values.
- Host key verification must be enabled by default.
- Private key import must detect weak permissions and unsupported formats.
- Clipboard use for secrets must be explicit and should support timed cleanup where feasible.
- Crash reports and logs must redact hostnames, usernames, paths, commands, and credential-related fields by default.

## UX Requirements

- Main window must optimize for repeated operational work, not marketing presentation.
- Primary navigation: hosts, sessions, SFTP/transfers, snippets, settings.
- Sync is configured inside Settings, not as a separate primary page.
- Import and export are exposed through command palette, host/identity actions, and Settings > Data.
- Support keyboard-first launch/search/connect flows.
- Use native-looking but cross-platform consistent desktop controls.
- Keep important status visible: active sessions, transfer progress, sync health, connection state.
- Terminal should occupy maximum useful area and avoid visual clutter.
- SFTP MVP should support a dense list/table view. Windows Explorer-like file manager modes, richer previews, and dual-pane workflows are roadmap items after the first SFTP release.
- All destructive actions require confirmation or undo.
- Security-sensitive confirmations should use modal dialogs that block the current flow until the user explicitly confirms, cancels, or chooses a documented trust action.
- The UI must stay minimal: avoid duplicate metadata, avoid redundant status indicators, and show indicators only when they clarify actionability, risk, progress, or failure.
- Vault locking hides vault-backed inventory and prevents new credential resolution, but it does not affect already-established SSH/SFTP connections.
- Full app exit does not restore previous workspace tabs or session metadata on next launch.

## Runtime Mode Requirements

- Debug builds should favor developer visibility through verbose redacted logs and clear error surfaces. Serlink does not need an in-app debug panel.
- Release builds should favor resilience and privacy: guarded async entrypoints, crash isolation, redacted diagnostics, conservative feature flags, safe fallbacks, and no sensitive debug overlays.
- Profile/internal builds should support performance diagnostics without exposing secrets.
- The app must never crash because a sync provider, SSH session, SFTP transfer, secure storage backend, or terminal channel fails; failures should be contained to the relevant session/task and shown through typed UI errors.

## Acceptance Criteria For Desktop MVP

- Runs on macOS, Windows, and Linux from one Flutter codebase.
- User can create host, store credential, verify host key, connect via SSH, and interact with terminal.
- User can import a private key and connect with it.
- User can open SFTP, browse files, upload, download, rename, delete, and change permissions.
- User can configure at least two terminal themes and custom font size.
- User can enable WebDAV sync and sync encrypted records between two desktop devices.
- User can enable iCloud sync on macOS if platform implementation is available, otherwise iCloud is documented as macOS-only beta until implemented.
- User can resolve a changed host key warning.
- User can review and confirm host fingerprints through a modal dialog.
- User can export/import encrypted vault backup.
- Automated tests cover domain model, vault encryption, sync merge, SSH service fakes, and core UI state.

## Open Product Questions

- Should iCloud sync use CloudKit, iCloud Drive document storage, or both? CloudKit is more structured but requires Apple entitlements and native plugin work.
- Should portable vault recovery be passphrase-only, recovery-key-only, or support both?
- Should team/shared vaults be deferred entirely or reserved in data model fields?
- What level of rz/sz compatibility is required for v1.0: automatic zmodem popup, manual transfer mode, or terminal-integrated transfer queue?
- Should built-in local terminal sessions be included or deferred until SSH/SFTP is mature?
