# Gap Analysis

This review captures important items not yet covered deeply enough in the Serlink planning docs. The core product direction is sound, but these gaps should be resolved before implementation or before beta.

## Summary

Serlink has solid coverage for the main first-release product surface: host management, encrypted vault, SSH terminal, SFTP list/table UI, workspace tabs, WebDAV encrypted sync, security modals, and crash resilience. iCloud providers are post-v1 scope.

Current code verification on 2026-05-29:

- `flutter analyze` passes.
- `flutter test` passes with 182 tests.
- No skipped tests were found in `test/`.
- The remaining first-release gaps are primarily release engineering, integration fixtures, platform QA, OpenSSH import verification against real OpenSSH behavior, and user-facing documentation.

The remaining gaps are mostly in four categories:

- Platform integration details.
- SSH/terminal compatibility edge cases.
- Sync/vault lifecycle edge cases.
- Release, compliance, and operational quality.

## Must Resolve Before Implementation

### 1. Workspace Exit And Session Semantics

Decision:

- Serlink does not restore workspace tabs after full app exit.
- Live SSH/SFTP sessions and tab metadata are discarded on full app exit.
- Users start a new workspace after launching the app again.

Requirement:

- Do not persist terminal/SFTP workspace tabs for automatic restore.
- Persist only durable product data such as hosts, credentials, settings, sync state, and transfer history where applicable.

### 2. App Lock Behavior With Active Connections

Decision:

- Vault lock does not affect already-established SSH/SFTP connections.
- Vault lock hides vault-backed inventory and prevents new credential resolution until unlock.

Requirement:

- Existing terminal and SFTP tabs continue running after vault lock.
- Opening new connections or reconnecting disconnected tabs requires vault unlock if credentials must be resolved.

### 3. Single Instance And Database Locking

Risk:

- Two app instances can corrupt local sync state, transfer queue state, or migration assumptions.

Requirement:

- Enforce a single primary app instance per local profile or implement explicit database locking and inter-process coordination.

Current implementation note:

- The real desktop database path now acquires an exclusive `serlink.lock` file before opening SQLite.
- This blocks a second process from using the same local profile. Full single-instance handoff/focus behavior is still a release polish item.

### 4. SSH Config And Known Hosts Edge Cases

Current docs cover basic import, but real OpenSSH files include more complexity.

Need to handle or explicitly warn about:

- `Include`
- `Match`
- `Host *` inheritance
- wildcard hosts
- negated patterns
- `CertificateFile`
- `IdentityAgent`
- `UserKnownHostsFile`
- `GlobalKnownHostsFile`
- `CanonicalizeHostname`
- `ProxyCommand`
- hashed `known_hosts`
- `@cert-authority`
- `@revoked`
- multiple hostnames per known-host entry

Current implementation note:

- OpenSSH config import now expands readable `Include` files with cycle and depth protection.
- `Host *` and other wildcard pattern blocks are used for inheritance when they match concrete aliases, but wildcard/negated patterns are not imported as concrete hosts.
- Unsupported `Match` blocks are isolated so their directives do not mutate surrounding host imports.
- Paired `IdentityFile` and `CertificateFile` entries can import encrypted OpenSSH certificate identities.
- `ProxyCommand`, `IdentityAgent`, `UserKnownHostsFile`, and `GlobalKnownHostsFile` now produce explicit warnings instead of falling through as generic unsupported directives.
- `known_hosts` import supports comma-separated multi-target lines and produces explicit warnings for hashed host targets, wildcard patterns, `@cert-authority`, and `@revoked`.
- Remaining importer gaps are full OpenSSH precedence validation against `ssh -G`, richer manual-conversion guidance for `ProxyCommand`, and future product semantics for host CAs/revoked keys rather than warning-only handling.

MVP recommendation:

- Parse common directives and import/link readable local `IdentityFile` private keys when a concrete config file path is available.
- Preview unsupported directives.
- Never silently drop security-relevant known_hosts markers.

### 5. Terminal Shortcut Pass-Through Model

Risk:

- App shortcuts can conflict with terminal apps such as vim, tmux, nano, htop, and shell readline.

Requirement:

- Define shortcut priority rules:
  - System/menu shortcuts.
  - Workspace shortcuts.
  - Terminal pass-through.
- Provide a terminal focus mode where most key combinations pass directly to the remote session.

### 6. Unicode, CJK, And IME Behavior

Risk:

- SSH terminal apps used by Chinese/Japanese/Korean users can fail visually if width, composition, or font fallback is wrong.

Requirement:

- Test East Asian wide characters, combining marks, emoji width, CJK IME composition, and font fallback.
- Document terminal width behavior and xterm limitations if any.

### 7. Network Keepalive And Reconnect Semantics

Important distinction:

- A disconnected SSH shell usually cannot be resumed unless the user runs tmux/screen/mosh on the server.
- Serlink reconnects in the current tab by opening a new SSH/SFTP connection, but it cannot recover the remote process state.

Requirement:

- UI copy must not imply magical shell resume.
- Reconnect must be presented as a new connection in the same tab.
- Add keepalive settings:
  - SSH keepalive interval.
  - connection timeout.
  - reconnect attempts.
  - reconnect backoff.

Current implementation note:

- Host connection settings now persist connect timeout, keepalive interval, reconnect attempts, and reconnect backoff.
- Those settings flow into SSH/SFTP connection profiles.
- Automatic reconnect uses the configured policy and reopens a new connection in the same tab.
- Tab close now cleans up all attached sessions, including split terminal panes and SFTP sessions.
- Vault lock does not affect already-established SSH/SFTP connections; reconnect always opens a new connection in the current tab.

### 8. Transfer Queue Concurrency And Backpressure

Requirement:

- Limit concurrent SFTP transfers per host and globally.
- Avoid unbounded memory buffering.
- Pause lower-priority tasks when a connection is unstable.
- Keep transfer failures isolated to the task.

Current implementation note:

- The transfer queue limits global concurrency and isolates task-level failures.
- Queue pause/resume/cancel now propagates into dartssh2 upload/download streams instead of only updating UI state.
- Directory transfers check pause/cancel between files and directories. Active file downloads use a controlled read/write loop to avoid unbounded progress buffering.
- Per-host concurrency policy and integration tests with unstable real SFTP servers remain release hardening work.

### 9. WebDAV TLS And Server Compatibility

Need decisions:

- Whether to allow self-signed TLS certificates.
- Whether to allow plain HTTP WebDAV for local/private networks.
- How to present TLS certificate failures.

Recommendation:

- HTTPS required by default.
- Plain HTTP only behind advanced warning.
- Self-signed certificate trust requires modal confirmation and pinning.

### 10. Local File Permissions

Requirement:

- Set restrictive permissions on local database, logs, exports, and temp files where the platform permits.
- Securely delete temp files best-effort after key import/export and transfers.
- Avoid writing private keys or decrypted vault content to temp paths.

Current implementation note:

- The Serlink application support directory is tightened to `0700` and the SQLite database file to `0600` on non-Windows platforms.
- Diagnostic bundle export writes a redacted JSON file and then tightens file permissions where possible.
- Private key imports read selected files directly and do not intentionally write decrypted key material to temp paths.
- Remaining work is an OS-specific pass for Windows ACLs and any plugin-created temp files.

## Must Resolve Before Beta

### 11. Device Management For Sync

Need UI and protocol support for:

- Lost device guidance.
- Key rotation or vault rekey story.

Current implementation note:

- Settings > Sync can remove non-local devices by writing encrypted tombstones.
- Settings > Sync can reset the current local sync device registration. The old local device record is tombstoned, the local SecretStore device id is replaced, and automatic sync is queued so other devices observe the removal.
- This covers device identity rotation and lost-device cleanup at the sync-device layer. Full vault cryptographic rekey remains separate release hardening.

### 12. Remote Vault Repair

Need recovery flows for:

- Corrupted manifest.
- Partial WebDAV upload.
- Conflicting manifests.
- Provider quota exceeded.
- Remote path contains a different vault.
- Local device clock skew.

Current implementation note:

- Encrypted tombstones now propagate deletes and prevent stale remote record objects from restoring locally deleted records.
- Push now removes stale remote record objects not present in the encrypted manifest.
- Host, snippet, and sync settings conflicts support field-level review and merge in Settings; identity and credential conflicts stay whole-record only.
- Sync device removals produce encrypted tombstones, propagate to the provider, remove stale remote device records, and prevent a locally revoked device from silently re-registering.
- Remote manifests from another vault are rejected before decrypt.
- Corrupted or mismatched remote manifests are classified as repairable failures.
- Settings > Sync can rebuild the remote encrypted sync set from local encrypted records after blocking confirmation.
- WebDAV writes create parent directories before encrypted object upload and provider failures are mapped into stable redacted errors for authentication, permission, missing/incomplete paths, locks, quota, TLS certificate failure, timeout, network failure, and server errors.
- Settings > Sync shows local clock and certificate validity timestamps in a blocking modal for not-yet-valid WebDAV certificates.
- Local and WebDAV sync providers reject unsafe object refs such as absolute paths, parent traversal, empty segments, and backslash paths before touching storage.
- Remaining repair gaps are deeper real-provider compatibility validation and provider-specific quota/partial-upload guidance.

### 13. Data Migration And Downgrade Policy

Need decisions:

- Can users downgrade app versions after schema migration?
- How are vault record versions migrated?
- What happens if one device uses a newer record schema and another older device syncs?

Recommendation:

- Support forward migrations only.
- Block older clients from writing unsupported newer vault protocol versions.

### 14. Third-Party Licenses And Notices

Requirement:

- Track licenses for Flutter packages, native dependencies, icons, fonts, and any bundled terminal themes.
- Produce a third-party notices file for release builds.

### 15. Cryptography Export / Compliance Review

Requirement:

- Review distribution requirements for apps containing encryption, especially if publishing through app stores or distributing internationally.
- Keep this as legal/compliance review, not an engineering guess.

### 16. Dependency Pinning And Supply Chain

Requirement:

- Pin dependencies through lockfile.
- Add dependency audit.
- Generate SBOM or dependency inventory before beta.
- Define policy for abandoned or risky packages.

### 17. Support Bundle Design

Need:

- Export redacted diagnostic bundle.
- Include app version, OS, package versions, feature flags, redacted error codes, and recent event IDs.
- Exclude terminal output, hostnames, usernames, commands, paths, credentials, and private keys by default.

Current implementation note:

- Settings > Data includes redacted diagnostic bundle export.
- Current bundle contains app build metadata, runtime/platform/vault-state metadata, recent Sentry event ID when available, and a redacted local log tail when present.
- Remaining work is expanding package inventory and release packaging metadata once the release toolchain is wired.

### 18. Packaging And Auto-Update

Need decisions:

- Auto-update mechanism per platform.
- Rollback strategy.
- Update signing.
- Migration backup before update.

### 19. User-Facing Documentation

Current gap:

- `README.md` is still the default Flutter starter text.
- Release builds need clear setup, security model, sync behavior, supported authentication modes, known limitations, and troubleshooting guidance.

Requirement:

- Replace the starter README with Serlink-specific development and product documentation.
- Add release support metadata once packaging targets are wired.

### 20. Test Matrix

Define explicit supported versions:

- macOS versions and Apple Silicon/Intel.
- Windows 10/11.
- Linux distros and desktop environments.
- OpenSSH server versions.
- WebDAV providers.

### 21. Localization Strategy

Even if first release is Chinese/English only:

- Add localization structure early.
- Avoid hardcoded user-facing strings.
- Confirm terminal UI and app UI font fallback for Chinese.

## Product Decisions Still Needed

### Built-In Local Terminal

Decision:

- Serlink supports local shell tabs on desktop.

Current implementation:

- Local terminal tabs use `flutter_pty`, pick the user's default shell from platform environment, attach through the shared xterm adapter, and reconnect by starting a new local shell in the same tab.

Remaining risk:

- `flutter_pty` currently warns that its macOS plugin does not support Swift Package Manager. This is acceptable for current local development, but it must be resolved by dependency upgrade, fork, or alternative PTY bridge before release if Flutter makes the warning fatal.

### Connection Profiles

Question:

- Should one host support multiple named connection profiles, such as "prod readonly", "prod root", "SFTP only", "bastion path A"?

Recommendation:

- Add data model room for profiles, but keep MVP UI simple.

### Command Snippet Execution Safety

Question:

- Should snippets insert only, execute immediately, or support both?

Recommendation:

- Insert only by default.
- Execute requires explicit confirmation.

### Terminal Scrollback Persistence

Question:

- Should scrollback be saved?

Recommendation:

- Memory-only by default.
- Encrypted local session history can be post-MVP.

### Privacy Mode

Question:

- Should there be a quick privacy mode that hides hostnames, usernames, and paths in UI?

Recommendation:

- Add as post-MVP or beta hardening feature if users often screen-share.

## Post-MVP Candidates

- Hardware security key / FIDO2 SSH auth.
- PuTTY PPK import.
- SSH Agent authentication.
- iCloud CloudKit/iCloud Drive sync providers.
- Zmodem/rz/sz.
- Mosh.
- Explorer-style SFTP mode.
- Team vaults.
- Cloud provider host discovery.
- Per-host icon/color customization.
- Full command history vault.

## Immediate Document Updates Recommended

- Keep workspace exit and app lock behavior decisions in product requirements.
- Add SSH config and known_hosts edge cases to importer requirements.
- Add terminal shortcut pass-through and CJK/IME tests to UI/testing docs.
- Add WebDAV TLS policy to security/sync docs.
- Add release compliance, third-party notices, dependency audit, and SBOM to release docs.
