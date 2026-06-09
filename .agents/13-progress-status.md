# Implementation Progress Status

Last updated: 2026-06-09.

This file tracks the current codebase against the desktop complete-product plan. It is intentionally stricter than a public MVP checklist: items marked partial are not release-complete.

## Current Verification

- `flutter analyze`: passed on 2026-05-30 after the current gap review.
- `flutter test`: passed on 2026-05-30 with 195 tests.
- Current verified scope is unit/widget-level plus smoke tests. Full desktop build and integration tests are still required.
- `flutter_pty` currently emits a macOS Swift Package Manager support warning during Flutter commands. It is non-blocking today, but must be tracked before release because future Flutter versions may make it an error.
- Scope note: see [14-release-scope-decisions.md](14-release-scope-decisions.md) for capabilities intentionally moved out of the first desktop release.

## Phase Status

| Phase | Status | Notes |
| --- | --- | --- |
| Phase 0: Project Foundation | Mostly complete | Flutter desktop project, module layout, Riverpod, Drift, xterm, dartssh2, Sentry redaction hooks, app shell, tests, strict analyzer, profile database lock, and best-effort local file permission tightening are in place. CI/package automation is still not complete. |
| Phase 1: Vault, Host Inventory, Credentials | Partial, strong core | Vault create/unlock/lock, recovery key modal, encrypted records, host CRUD, password/private-key identities, private-key file import, encrypted backup import/export, local OS secure-storage unlock protector, OpenSSH config preview/import UI with resolvable ProxyJump linking, `Include` expansion, `Host *` inheritance, `Match` block isolation, IdentityFile private-key import/linking, paired CertificateFile certificate identity import, explicit ProxyCommand/IdentityAgent/known-host-file warnings, OpenSSH known_hosts import UI/service with explicit hashed-host, cert-authority, and revoked-key warnings, OpenSSH certificate import UI/service, Settings credential manager, Settings known-host manager, host connection settings with persisted keepalive/timeout/reconnect policy, and locked UI exist. PPK import is out of first-release scope. |
| Phase 2: SSH Terminal | Partial | dartssh2 shell service, password/private-key auth, xterm adapter, real local terminal tabs backed by desktop PTY, batched terminal output writes, workspace tabs, reconnect-in-place semantics, automatic reconnect policy, split-tab session cleanup, known-host encrypted storage, fingerprint modal, multiline paste confirmation, buffer search, encrypted global terminal theme/font/line-height/scrollback settings, encrypted per-host terminal profiles, terminal split panes with independent pane sessions, a basic terminal shortcut pass-through policy, and automated CJK/emoji/combining-character input compatibility coverage exist. Cross-platform shortcut audit and real OS IME interaction verification are still pending. |
| Phase 3: SFTP MVP | Partial | SFTP service and list/table runtime view exist. Directory navigation, filtering, hidden-file toggle, owner/group/modified-time display, mkdir, rename, move, delete, chmod, permission display, text preview/remote edit for bounded-size files, file/folder upload and download queueing, Transfers queue UI, overwrite/merge/skip/rename confirmation, speed, ETA, typed SFTP failures, concise failure UI, encrypted transfer history persistence, and real pause/resume/cancel propagation into dartssh2 SFTP transfer streams exist. Integration fixtures still need work. Explorer-style mode is out of first-release scope. |
| Phase 4: WebDAV Encrypted Sync | Partial, strong core | Sync provider interfaces, local test provider, WebDAV security guard, Settings setup UI, encrypted WebDAV configuration, SecretStore-backed WebDAV password storage, automatic WebDAV sync scheduling, pull/import of missing remote records, same-record conflict detection, host/snippet/sync-settings field-level conflict merge, encrypted tombstone delete propagation, stale remote record cleanup, automatic retry/backoff after failures, blocking Settings conflict resolver, encrypted sync device metadata, Settings device cleanup, remote wrong-vault/corrupt-manifest detection, blocking repair actions, delete tombstones for device revocation, local-device revoked write blocking, WebDAV parent-directory creation, stable WebDAV provider error classification, TLS certificate diagnostic/pinning handling, and sync object path traversal protection exist. Identity/credential conflicts remain whole-record only by design. |
| Phase 5: Desktop UX Completion | Partial | Professional compact shell exists with Hosts/Sessions/Transfers/Snippets/Settings. Settings is structured. The top workspace search now filters hosts and snippets with area-specific placeholders, while Sessions uses a tab strip with a new-connection plus button. Encrypted command snippets now support CRUD, tags, confirm-before-run, sync-safe delete tombstones, and insert/run into the active connected terminal tab. Command palette, shortcut map, accessibility pass, and final UI polish remain. |
| Phase 6: Advanced SSH | Partial | Keyboard-interactive auth material exists. Local, remote, and SOCKS dynamic forwarding have service support, Terminal toolbar modal UI, stop control, and session cleanup. ProxyJump host links are resolved into ordered jump snapshots and dartssh2 connects through bastions with nested `forwardLocal` channels. OpenSSH certificate auth material is bound to private-key signing for dartssh2 public-key auth. Host startup commands resolve into connection profiles and execute after terminal attach. Bastion/certificate/forwarding integration fixtures are not complete. SSH Agent, FIDO2, and zmodem are out of first-release scope. |
| Phase 7: iCloud Sync | Partial, not release-complete | CloudKit provider wiring, native iOS/macOS method channels, entitlement files, and debugging docs exist. Release still needs signed-device validation, CloudKit production schema deployment, provider hardening, and integration coverage. iCloud Drive remains deferred. |
| Phase 8: Beta Hardening | Early partial | Sentry redaction, runtime mode basics, and redacted diagnostic bundle export with build metadata exist. Packaging, signing/notarization, installers, dependency audit, SBOM, notices, and integration test servers are missing. |

## Completed Or Implemented In Code

- Encrypted vault envelope with AAD validation and tamper tests.
- Drift persistence for vault header and encrypted records.
- Vault creation/unlock/lock and recovery key handling.
- Device-local vault unlock uses OS secure storage for a random device key, never stores the vault passphrase, and can be enabled/disabled from Settings.
- Host repository and host UI create/edit/delete.
- Password identity and private-key identity creation through host flow.
- Encrypted identity secret records.
- Encrypted known-host records and fingerprint verification flow.
- Blocking fingerprint modal for unknown/changed host keys.
- Settings > Data exposes OpenSSH config, `known_hosts`, and OpenSSH certificate import actions while the vault is unlocked.
- Settings > Data can export selected non-secret host metadata as JSON after a blocking selection/confirmation modal; credentials, private keys, passphrases, and identity secret IDs are excluded.
- OpenSSH config import previews common `Host`, `HostName`, `User`, `Port`, `IdentityFile`, `CertificateFile`, and `ProxyJump` directives, expands readable `Include` files with cycle/depth protection, applies `Host *` and wildcard pattern inheritance to concrete aliases, isolates unsupported `Match` blocks so their directives cannot mutate surrounding host imports, links resolvable ProxyJump aliases to imported or existing host IDs, imports readable local `IdentityFile` private keys as encrypted identities when the config source path is available, imports paired `IdentityFile`/`CertificateFile` entries as encrypted OpenSSH certificate identities, explicitly warns for unsafe `ProxyCommand`, deferred `IdentityAgent`, `UserKnownHostsFile`/`GlobalKnownHostsFile`, unsupported directives/patterns/unresolved jumps/missing keys, and imports host metadata as encrypted records after confirmation.
- Connection profiles now expand host `jumpHostIds` into ordered ProxyJump chains, reject cyclic chains, and keep each jump host's own encrypted auth material isolated in memory for connection time only.
- OpenSSH `known_hosts` import maps hostname/port entries, including comma-separated multi-target lines, to existing Serlink hosts and stores imported fingerprints as encrypted known-host records after confirmation. Hashed host targets, wildcard patterns, `@cert-authority`, and `@revoked` lines are skipped with explicit warnings instead of being silently dropped.
- OpenSSH certificate import UI/service validates certificate public-key lines, stores certificate/private-key/passphrase material as encrypted identity secrets, and creates `openSshCertificate` identity records after a blocking preview modal.
- Settings includes compact credential and known-host managers with blocking delete confirmation and encrypted tombstone generation for deleted credential/known-host records.
- OpenSSH certificate identities now resolve into connection auth material and dartssh2 sends the certificate public-key blob while signing with the paired private key.
- Host connection settings now persist connect timeout, keepalive interval, reconnect attempts, and reconnect backoff, and those values flow into SSH connection profiles.
- Encrypted vault backup import/export service and Settings entry points.
- OpenSSH config export now writes portable `Host` blocks for selected hosts and required jump hosts, with sanitized aliases, `HostName`, `User`, `Port`, and connection-timeout directives while excluding credentials and private key material.
- Identity metadata export now writes public identity details and fingerprints without secret references.
- Terminal/SFTP/local terminal mixed workspace tab container, including opening same-host SFTP from a terminal tab and same-host terminal from an SFTP tab.
- Local terminal tabs now start the desktop user's default shell through `flutter_pty`, attach to the same xterm adapter as SSH terminals, disconnect cleanly on process exit, and reconnect in place by starting a new local shell.
- Closing a workspace tab now cleans up all underlying pane/session connections, including split terminal panes and SFTP sessions.
- Terminal tabs can manage local, remote, and SOCKS dynamic forwards through one compact blocking modal, and forwards are cleaned up when the SSH/SFTP session closes.
- SSH and SFTP sessions can connect through configured ProxyJump bastions using dartssh2 `forwardLocal` channels; host-key verification runs for each hop.
- SSH terminal profiles carry startup commands; terminal tabs execute non-empty commands after the shell is attached.
- Terminal multiline paste detection and blocking confirmation modal.
- Terminal adapter batches burst stdout/stderr writes and flushes pending terminal output before session close.
- Terminal buffer search with highlighted matches and current-match navigation.
- Terminal display settings for font size, line height, and built-in themes persist as encrypted vault records.
- Terminal display settings now expose font family and scrollback in the UI. New terminal runtimes use the configured scrollback line count; existing open terminal buffers keep their current xterm allocation.
- Per-host terminal display profiles persist as encrypted vault records and are attached to terminal tabs as in-memory snapshots so existing terminals keep their styling after vault lock.
- Reconnect in the current tab as a new connection.
- Vault lock blocks new credential resolution but does not explicitly tear down existing runtimes.
- SFTP runtime list view using the active SFTP connection.
- SFTP list filtering and file operations for mkdir, rename, move, delete, and chmod through the active runtime connection.
- SFTP list rows now show modified time and owner/group metadata when the server provides it, and the SFTP toolbar includes an explicit hidden-file toggle.
- SFTP file rows open a compact text preview/edit modal; previews are capped at 64 KiB and truncated previews are read-only to avoid overwriting large files with partial content.
- SFTP file and folder upload/download queueing through `TransferQueueController`.
- Transfers page with queue state, progress, speed, ETA, pause/resume/cancel/retry actions.
- Overwrite/merge/skip/rename confirmation for remote upload targets and local download targets.
- Recursive folder upload/download support in the dartssh2 SFTP adapter.
- Transfer queue domain/controller with unit and smoke coverage.
- Transfer pause/resume/cancel now propagates to the active dartssh2 upload/download stream instead of only changing queue state, and completed transfer progress is no longer treated as user cancellation.
- Typed SFTP failure mapping for dartssh2 and local file-system errors.
- SFTP list/operation/transfer failures now surface concise user-facing messages instead of raw exception strings.
- Transfer task metadata/history persists as encrypted vault records.
- App restart does not restore transfer sessions; previously active transfer history is marked `transfer.interrupted`.
- Transfer persistence is best-effort so vault lock does not interrupt already-established SFTP connections.
- Settings > Sync supports WebDAV account configuration.
- WebDAV endpoint, username, base path, enabled state, and insecure-HTTP opt-in are stored as encrypted vault settings.
- WebDAV password material is stored through `SecretStore` instead of vault records or SQLite plaintext.
- HTTP WebDAV requires a blocking modal confirmation in the setup flow.
- WebDAV sync is automatic: the app starts an auto-sync controller after launch, schedules sync when the vault is unlocked and WebDAV is enabled, syncs after syncable encrypted record changes, and periodically refreshes in the background.
- Automatic WebDAV sync pulls missing remote encrypted records, detects same-record revision conflicts, then pushes the merged encrypted vault header, encrypted records, and encrypted manifest.
- Automatic WebDAV sync propagates encrypted delete tombstones, prevents locally deleted records from being restored by stale remote objects, removes stale remote record objects during push, and retries failed syncs with bounded backoff.
- Settings > Sync surfaces detected encrypted record conflicts and resolves them through blocking keep-local or use-remote actions.
- Settings > Sync supports field-level conflict review and merge for host, snippet, and sync settings records; identity/credential conflicts intentionally stay whole-record resolution.
- Sync rejects remote manifests from another vault, treats corrupted or mismatched remote manifests as repairable failures, and Settings > Sync can rebuild the remote encrypted sync set after blocking confirmation.
- Sync registers a device-local sync device ID through `SecretStore`, stores device metadata as encrypted vault records, writes encrypted writer-device metadata into the sync manifest, exposes a Settings modal for removing non-local device records, supports resetting the current local sync device registration with an encrypted tombstone for the old identity, propagates encrypted device tombstones, and prevents a locally revoked device from silently re-registering during automatic sync.
- WebDAV sync creates remote parent directories before encrypted object writes and maps provider failures into stable redacted errors for authentication, permission, missing/incomplete remote paths, provider locks, quota, TLS certificate failures, timeouts, network failures, and server errors. Certificate diagnostics now carry fingerprint/validity data into the repair flow and certificate trust is persisted as an endpoint pin.
- Local and WebDAV sync providers reject unsafe object references such as absolute paths, parent-directory traversal, empty segments, and backslash-separated paths before reading/writing/deleting encrypted sync objects.
- CloudKit sync wiring exists for iOS and macOS through the `serlink/cloudkit` method channel, private database encrypted-object storage, checked-in entitlement plists, and local entitlement diagnostics. It still requires signed-device validation and production CloudKit schema work before release.
- The real desktop database path is protected by a profile lock and best-effort `0700` directory / `0600` database-file permissions on non-Windows platforms.
- Diagnostic bundle export writes app build metadata, redacted runtime metadata, and redacted log tail only, explicitly excluding terminal output, commands, hostnames, usernames, paths, credentials, and private keys.
- Diagnostic bundle export also includes the recent Sentry event id when one exists, but still excludes all sensitive session content.
- Snippets are stored as encrypted vault records, support CRUD in the Snippets surface, and can be inserted into or executed in the active connected terminal tab with modal confirmation when required.
- The top workspace search field filters host records and snippets with page-specific placeholders; Sessions keeps focus on the tab strip and exposes a trailing plus button that returns to Hosts for new connections.
- Terminal tabs now support split-pane presentation with horizontal/vertical layout switching, active-pane selection, and independent pane-level terminal sessions and lifecycle inside one tab container.
- Terminal views now keep a narrow local shortcut allowlist for copy/paste/select-all/search while leaving other key combinations to the terminal input path by default.
- Terminal widget tests now cover CJK text, emoji, and combining-character input through `TerminalView`, guarding the desktop input path on top of xterm's built-in wide-character and composing support.
- Redaction utility and Sentry `beforeSend` sanitization.

## Highest Priority Missing Work

1. Release engineering: cross-platform CI, macOS signing/notarization, Windows installer/MSIX, Linux package target, dependency audit, SBOM, and third-party notices.
2. Integration fixtures: real or containerized SSH, SFTP, WebDAV, ProxyJump, OpenSSH certificate, startup-command, and port-forwarding coverage.
3. Host inventory depth: group management, duplicate, archive/pin, notes/environment fields, bulk edits, and a user-visible trash/recovery decision.
4. Remaining export breadth: public key file export and explicit private-key export policy.
5. OpenSSH import hardening still remaining: more exact OpenSSH first-value semantics validation against `ssh -G`, richer `ProxyCommand` manual-conversion guidance, and future product semantics for host certificate authorities and revoked keys rather than warning-only handling.
6. Platform validation: macOS/Windows/Linux secure-storage behavior, file permissions/ACLs, temp-file cleanup, clipboard, shortcut pass-through, and real OS IME behavior.
7. Product polish still in release gate: command palette or final shortcut map decision, accessibility pass, concise empty/error states, README/user-facing docs, and support/package metadata.
8. Sync production hardening: provider-specific quota and partial-upload guidance, migration/downgrade policy, and real WebDAV provider compatibility matrix.
9. `flutter_pty` release risk: resolve or consciously pin/fork/replace before future Flutter versions make the macOS Swift Package Manager warning fatal.
10. Explicitly deferred post-v1: iCloud Drive, SSH Agent, FIDO2/hardware keys, zmodem/rz/sz, PuTTY PPK import, Explorer-style SFTP mode, and full vault cryptographic rekey.

## Current Implementation Focus

The next implementation slices should close remaining desktop product gaps in this order:

1. Add release engineering automation for CI, packaging inputs, dependency inventory, third-party notices, and SBOM.
2. Add integration fixtures for OpenSSH/SFTP/WebDAV, including ProxyJump, certificates, startup commands, and port forwarding.
3. Decide and implement/reduce remaining host inventory depth: groups, notes, duplicate, archive/pin, and trash/recovery.
4. Continue hardening OpenSSH import/export edges against `ssh -G` and define product semantics for host CAs/revoked keys.
5. Run platform QA for secure storage, ACLs, temp files, clipboard, shortcuts, IME, and local terminal behavior.
