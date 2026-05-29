# Original Requirements Delta Review

Last updated: 2026-05-30.

This document compares the original `.agents` planning documents against the current implementation status in `13-progress-status.md` and the explicit deferrals in `14-release-scope-decisions.md`.

The goal is to separate three cases:

- Implemented or mostly implemented.
- Explicitly deferred from the first desktop release.
- Still omitted or under-specified and therefore likely to be missed unless added to the release backlog.

## Summary

The main Serlink desktop spine is present: encrypted vault, host CRUD, SSH terminal, local terminal, SFTP list/table, transfer queue, WebDAV encrypted sync, snippets, security modals, redacted diagnostics, and a compact desktop shell.

The remaining gaps are not mostly architectural. They are product-completion and release-readiness items. Since this review was opened, the codebase has closed workspace search wiring for Hosts and Snippets, selected host metadata export, terminal font/scrollback settings, and SFTP hidden/metadata list polish. The biggest remaining omissions are host inventory depth, remaining export formats, release/integration validation, and platform QA.

## Explicitly Deferred, Not Omissions

These were present in the original requirements but now have explicit scope decisions:

- CloudKit sync.
- iCloud Drive sync.
- SSH Agent authentication.
- FIDO2 / hardware security key SSH authentication.
- Zmodem / `rz` / `sz`.
- PuTTY PPK import.
- Explorer-style SFTP mode.
- Full vault cryptographic rekey.

They remain valid product directions but are not release blockers for the first desktop release unless the scope decision changes.

## True Or Under-Tracked Omissions

### 1. Host Inventory Completion

Original requirement:

- Hosts can be stored, searched, grouped, tagged, duplicated, archived, pinned, filtered, and organized with environment and notes.
- Host groups/tags bulk editing.
- Full-text local search over decrypted display fields.
- Soft delete with trash/recovery for at least host and identity records.

Current state:

- Host CRUD and tags exist.
- `groupId` exists in the host model, but group management and group UI are not implemented.
- The top search field now filters hosts and snippets. Sessions intentionally uses a tab strip without a search box, with a plus button that returns to Hosts for new connections.
- Duplicate, archive, pin/favorite, environment, notes, trash/recovery, and bulk editing are not implemented.
- Deletes create sync tombstones, but that is not the same as user-visible trash/recovery.

Action:

- Either implement the remaining inventory features as first-release desktop features or explicitly reduce v1 scope.
- Minimum recommended release gate now starts at duplicate host, notes/environment, and a clear decision on archive/pin/trash because wired search/filter is implemented.

### 2. Export Surface Is Narrower Than Planned

Original requirement:

- Import and export SSH configs, keys, encrypted vault backups, selected host metadata, public key material, app data where safe, and diagnostic bundles.
- Sensitive export flows require preview and modal confirmation.

Current state:

- Encrypted vault backup export/import exists.
- Redacted diagnostic bundle export exists.
- OpenSSH config, known_hosts, private key, and OpenSSH certificate import exist.
- Selected non-secret host metadata export is implemented with a blocking selection/confirmation modal.
- OpenSSH config export is implemented as a portable, credential-free `Host` block export for selected hosts and their required jump hosts.
- Public identity metadata export is implemented; public key file export and private key export policy/UI are not implemented.

Action:

- Add an export backlog item with exact allowed outputs:
  - encrypted vault backup: implemented;
  - selected non-secret host metadata: implemented;
  - OpenSSH config export: implemented;
  - public identity metadata export: implemented;
  - public key file export: missing;
  - private key export: requires explicit security decision and modal.

### 3. Credential Portability And OS-Native Credential UX

Original requirement:

- Users can choose portable encrypted credentials or OS-native credentials.
- Users can inspect which credentials are portable and which are device-local.
- Private key import can come from file or clipboard.

Current state:

- Vault credentials and encrypted identity secrets exist.
- Device-local vault unlock protector exists.
- WebDAV password is stored through secure storage.
- Local SSH Agent auth is explicitly deferred.
- Credential manager exists, but the portable/device-local distinction is not fully surfaced as a product concept.
- Private key import from file exists; clipboard import is not implemented.

Action:

- Add credential metadata/status UI for portable vs device-local secrets.
- Add clipboard private-key import or explicitly defer it.

### 4. Terminal Settings Are Not Complete

Original requirement:

- Font family, font size, cursor style, color theme, scrollback, copy mode, bell, and selection behavior are customizable.
- Common terminal shortcuts, bracketed paste, mouse reporting, alternate screen, and clipboard copy/paste are supported or verified.

Current state:

- Theme, font family in model, font size, and line height exist.
- UI exposes theme, font family, font size, line height, and scrollback.
- New terminal instances use the configured scrollback line count; existing open terminal buffers keep their current xterm allocation.
- Cursor style, bell, copy mode, and selection behavior are not exposed.
- Bracketed multiline paste confirmation exists.
- Shortcut pass-through has a minimal allowlist.
- Real mouse reporting, alternate screen, clipboard behavior, and OS IME behavior still need integration/platform validation.

Action:

- Decide whether cursor/bell/selection settings are v1 release features or post-v1 polish.
- At minimum, update terminal settings documentation and add platform verification tasks for mouse reporting, alternate screen, clipboard, and IME.

### 5. SFTP Desktop Ergonomics Still Lag Original Requirements

Original requirement:

- Browse, sort, search, create folders, rename, delete, upload, download, move files.
- View metadata, permissions, owner/group where available, and hidden files.
- Drag files from OS file manager into Serlink for upload and drag downloads out where supported.
- Cache remote directory listings briefly and invalidate after mutations.
- Preserve modified times when supported.
- Permissions editor should support octal and symbolic presentation.

Current state:

- List/table SFTP, navigation, filtering, mkdir, rename, move, delete, chmod, preview/edit, upload/download, queue, conflict handling, and typed errors exist.
- Owner/group and modified time are surfaced in SFTP list rows when the server provides them.
- Hidden entries are detected by name and can be shown/hidden from the SFTP toolbar.
- Drag/drop upload/download is not implemented.
- Directory listing cache is not implemented.
- Modified time preservation is not implemented.
- Permissions are octal-focused; symbolic presentation/editor is not implemented.

Action:

- Keep Explorer-style mode deferred, but add smaller list/table completion items:
  - drag/drop upload where Flutter desktop support is acceptable;
  - optional modified-time preservation;
  - symbolic permission display.

### 6. Sync Protocol Is Strong But Not Exactly The Original Incremental Model

Original requirement:

- Incremental sync using record revision, vector clock or hybrid logical timestamp, tombstones, and conflict payloads.

Current state:

- WebDAV encrypted sync uses encrypted records, revisions, encrypted manifests, tombstones, conflict detection, conflict resolution, device metadata, and repair flows.
- Current push/pull is closer to encrypted snapshot plus revision comparison than a full vector-clock/HLC incremental protocol.
- iCloud providers are deferred.

Action:

- Document the v1 sync model as "encrypted manifest plus revision/tombstone sync" unless a true HLC/vector-clock design is still required.
- Add migration/downgrade policy before release.

### 7. Keyboard-First UX And Navigation Are Still Incomplete

Original requirement:

- Keyboard-first launch/search/connect flows.
- Command palette.
- Shortcut map.
- Accessibility pass.

Current state:

- Core navigation exists.
- Snippets and terminal shortcuts have partial support.
- Command palette is not implemented.
- Shortcut map is not implemented.
- Accessibility pass is not complete.
- Workspace search is wired for hosts and snippets with page-specific placeholders. Sessions intentionally keeps the tab strip unfiltered.

Action:

- Treat command palette as a separate backlog item.
- If command palette is deferred, document that decision and ensure host search/connect remains keyboard-friendly.

### 8. Release Engineering And Integration Fixtures Remain The Largest Release Gate

Original requirement:

- Cross-platform desktop release, CI, tests, packaging, signing/notarization, dependency audit, SBOM, notices, integration fixtures, and platform QA.

Current state:

- `flutter analyze` and unit/widget/smoke tests pass.
- No full release packaging pipeline yet.
- No signed/notarized macOS build, Windows installer/MSIX, or Linux AppImage/Flatpak pipeline yet.
- No real/containerized integration fixtures for SSH/SFTP/WebDAV/ProxyJump/certificate/forwarding.
- `flutter_pty` macOS Swift Package Manager warning remains a release risk.

Action:

- Keep this as the first release gate after product-surface tightening.

## Recommended Next Backlog Order

1. Decide and implement/defer host groups, notes, duplicate, archive/pin, and trash/recovery.
2. Add remaining export formats: public key file export and private key export policy, or explicitly reduce export scope.
3. Complete terminal settings scope decision for cursor style, bell, and selection behavior.
4. Add remaining SFTP list/table polish: drag/drop decision, optional modified-time preservation, and symbolic permission display.
5. Write the v1 sync protocol note and migration/downgrade policy.
6. Build integration fixtures and release engineering pipeline.
