# Testing And Release Plan

## Testing Philosophy

Serlink handles terminals, credentials, remote servers, and sync. Testing must cover:

- Correctness of domain logic.
- Security of vault and redaction behavior.
- Real SSH/SFTP interoperability.
- UI behavior under long-running sessions.
- Cross-platform differences.
- Failure and recovery paths.

## Test Pyramid

### Unit Tests

Targets:

- Domain validation.
- Vault encryption/decryption.
- Key protector logic.
- Sync merge engine.
- Host key verification state machine.
- Import parsers.
- Error mapping.
- Redaction helpers.

Expected volume: high.

### Widget Tests

Targets:

- Host list and detail forms.
- Vault unlock/locked screens.
- Terminal session chrome.
- SFTP browser state.
- Transfer queue.
- Sync conflict resolver.
- Settings forms.

Expected volume: medium.

### Integration Tests

Targets:

- SSH connection to test OpenSSH server.
- SFTP operations.
- WebDAV sync using local test server.
- Vault backup/restore.
- Private key import.
- Host key changed flow.

Expected volume: focused but mandatory.

### Manual Cross-Platform QA

Targets:

- Keyboard shortcuts.
- IME behavior.
- Clipboard.
- Drag/drop.
- Font rendering.
- Window resizing.
- Secret store behavior.
- Packaging/install/update.

## Test Infrastructure

### Local Services

Use Docker or local scripts for:

- OpenSSH server with password auth.
- OpenSSH server with key auth.
- OpenSSH server with changed host key scenario.
- SFTP-enabled server with test directory tree.
- WebDAV server.
- lrzsz-enabled Linux server for zmodem.

Even if Docker is unavailable on a contributor machine, CI should provide these services.

### Test Fixtures

Maintain fixtures:

- OpenSSH config files with common directives.
- Encrypted vault test vectors.
- Private key samples generated only for tests.
- Known host entries.
- Directory trees for SFTP operations.
- WebDAV manifest/record conflict examples.

Never include real credentials.

## Security Tests

Required:

- Local database scan proves no plaintext test hostname/password/key appears.
- Sync provider object scan proves no plaintext test hostname/password/key appears.
- Tampered ciphertext fails decryption.
- Tampered associated data fails decryption.
- Wrong passphrase fails without partial data.
- Host key changed blocks connection.
- Logs redact sensitive values.
- Crash diagnostics redact sensitive values.
- Clipboard cleanup works where platform allows.

## Terminal Tests

Automated:

- PTY resize events.
- UTF-8 output.
- Large output stream.
- Alternate screen enter/exit.
- Bracketed paste.
- Terminal theme mapping.
- Session lifecycle cancellation.

Manual:

- vim/nano/top/htop behavior.
- Mouse support where enabled.
- Copy/paste across platforms.
- Alt/Ctrl/Meta shortcuts.
- Terminal shortcut pass-through while focused.
- CJK wide characters, combining marks, emoji width, and IME composition.
- IME input.
- High DPI display.

## SFTP Tests

Automated:

- List directory.
- Upload file.
- Download file.
- Upload/download large file.
- Rename.
- Delete.
- Create directory.
- chmod.
- Permission denied.
- Conflict overwrite/skip/rename.
- Cancel transfer.
- Retry failed transfer.

Manual:

- Drag/drop upload.
- Download destination picker.
- Symlink behavior.
- Large directory browsing.
- Network interruption during transfer.

## Sync Tests

Automated:

- First sync upload.
- Second device download.
- Local edit then sync.
- Remote edit then sync.
- Same record conflict.
- Delete tombstone propagation.
- Offline edits.
- Provider unreachable.
- Manifest write conflict.
- WebDAV ETag mismatch.

Manual:

- Real WebDAV providers.
- Slow network.
- Interrupted sync.
- Wrong WebDAV credentials.
- Vault mismatch at same remote path.

## Performance Targets

Terminal:

- Sustained output should not freeze UI.
- Resize should feel immediate.
- Scrollback memory bounded by configured limit.

SFTP:

- Large file transfers stream in bounded memory.
- Directory with 10,000 entries remains navigable through virtualization.

Sync:

- Sync 1,000 host records without visible UI stall.
- Crypto and merge work should avoid blocking the UI isolate.

Startup:

- Locked startup should be fast because it does not decrypt everything.
- Unlock should show progress if indexes need rebuild.

## CI Requirements

Jobs:

- Format check.
- Static analysis.
- Unit tests.
- Widget tests.
- Integration tests with services on at least Linux.
- Build macOS, Windows, Linux where runner availability allows.
- Dependency vulnerability scan.
- Third-party license/notice generation check.
- Dependency inventory or SBOM generation before beta.

Branch protection:

- No merge with failing analysis/tests.
- Security-sensitive modules require review.

## Packaging

### macOS

- Build universal or architecture-specific app bundles.
- Sign and notarize.
- Hardened runtime.
- Configure keychain and iCloud entitlements.
- Validate first launch, update, and uninstall cleanup.

### Windows

- MSIX package initially.
- Code signing.
- Credential Manager access verification.
- Windows OpenSSH agent investigation.

### Linux

- AppImage or Flatpak.
- Secret Service integration.
- Desktop file and icons.
- Wayland/X11 clipboard and drag/drop checks.

## Release Channels

- Internal nightly.
- Private alpha.
- Public beta.
- Stable.

Channel differences:

- Nightly can enable experimental zmodem/iCloud flags.
- Debug builds can enable verbose redacted logs and local test endpoints.
- Profile builds can enable performance counters while preserving release-grade redaction.
- Beta must default experimental flags off unless stable enough.
- Stable must avoid debug logs and unsafe diagnostics.

## Crash Resilience And Runtime Modes

Release requirements:

- Guard app bootstrap, Flutter framework errors, platform dispatcher errors, zones, and stream subscriptions.
- Contain failures to the relevant session, transfer, sync run, or settings operation.
- Show typed recovery UI instead of terminating the app where recovery is possible.
- Persist enough redacted diagnostics for user-approved support export.
- Never include terminal output, command text, credentials, hostnames, usernames, or file paths in crash diagnostics by default.

Debug requirements:

- Provide verbose redacted logs.
- Allow local test endpoints.
- Show developer-oriented error details in logs with redaction.
- Keep an obvious visual marker when unsafe diagnostics are enabled.

Tests:

- Simulate SSH stream exception and verify only the session fails.
- Simulate SFTP transfer exception and verify app remains usable.
- Simulate sync provider exception and verify Settings > Sync shows recoverable error.
- Simulate vault decrypt failure and verify no plaintext leaks.
- Verify release mode disables debug logs and unsafe diagnostics.
- Simulate unexpected terminal disconnect and verify the tab remains open with reconnect action.
- Simulate unexpected SFTP disconnect and verify the tab preserves last path and other tabs remain usable.
- Verify reconnect opens a new connection in the same tab.
- Verify vault lock does not close or interrupt already-established terminal/SFTP sessions.
- Verify full app exit does not restore previous workspace tabs on next launch.

## Observability

Default diagnostics:

- Local logs only unless user opts in.
- Redacted event codes.
- Session/transfer/sync correlation IDs.
- No terminal output.
- No hostnames/usernames/paths.

Optional crash reporting:

- Explicit user consent.
- Redaction before upload.
- Security review before enabling.

## Release Checklists

### Desktop MVP Checklist

- macOS, Windows, Linux smoke tests passed.
- Vault locked/unlocked behavior passed.
- SSH password/key auth passed.
- Host key warning passed.
- Fingerprint confirmation modal passed.
- Terminal interactive apps passed.
- SFTP file operations passed.
- Mixed terminal/SFTP workspace tabs passed.
- WebDAV encrypted sync passed.
- Database contains no plaintext test secrets.
- Logs contain no plaintext test secrets.
- Backup/restore passed.
- Release crash-resilience smoke tests passed.

### Beta Checklist

- Packaging signed where required.
- Auto-update decision implemented or documented.
- Known limitations documented.
- Security review complete.
- Third-party notices generated.
- Dependency audit/SBOM complete.
- Encryption distribution/compliance review tracked.
- Privacy policy/diagnostics copy ready if telemetry exists.
- Crash-free smoke run completed.

### v1.0 Checklist

- Migration from beta data tested.
- External security review considered/completed.
- iCloud support status finalized.
- zmodem support status finalized.
- Accessibility review complete.
- Performance targets met.

## Documentation Requirements

User docs:

- Create first host.
- Import SSH key.
- Import OpenSSH config.
- Export encrypted vault backup.
- Export diagnostic bundle safely.
- Understand portable vs device-local credentials.
- Set up WebDAV sync.
- Set up iCloud sync when available.
- Resolve host key warning.
- Use SFTP transfers.
- Backup and restore vault.

Developer docs:

- Architecture.
- Vault protocol.
- Sync protocol.
- Platform secure storage.
- Running integration services.
- Release process.
