# Risk Assessment And Reality Check

This document answers whether Serlink can fully implement the original product request and which parts need special handling, staged delivery, or scope adjustment.

## Executive Summary

The original Serlink vision is technically feasible, but not perfectly implementable in a single clean pass across macOS, Windows, Linux, and future mobile without tradeoffs.

The realistic target is:

- Desktop v1 can be excellent and production-grade for SSH terminal, host management, encrypted local vault, SFTP, WebDAV sync, and terminal customization.
- Some advanced capabilities should be staged behind feature flags: iCloud sync, SSH agent, zmodem/rz/sz, jump hosts, port forwarding, and OpenSSH certificate edge cases.
- "Perfectly consistent across all platforms" is not realistic because secure storage, keychain sync, SSH agent access, file drag/drop, IME, terminal keyboard behavior, and iCloud APIs differ by OS.
- "End-to-end encrypted sync" is realistic if Serlink owns an encrypted record protocol and treats iCloud/WebDAV as untrusted object stores.

## First-Release Scope Adjustment

As of 2026-05-28, the first desktop release scope intentionally excludes iCloud providers, SSH Agent authentication, hardware security key/FIDO2 SSH auth, zmodem/rz/sz, PuTTY PPK import, and Explorer-style SFTP mode. These are post-v1 candidates unless a dedicated implementation path is chosen.

This changes the release question from "can Serlink perfectly match every advanced SSH client feature in v1" to "can Serlink ship a secure, professional desktop SSH/SFTP/WebDAV client with clear post-v1 expansion points." The latter is realistic.

## Can We Perfectly Implement The Original Requirement?

No, not in the literal sense of "perfectly" and "all advanced SSH behaviors fully compatible everywhere."

Yes, we can implement the product intent: a professional cross-platform SSH terminal app with strong security, SFTP, encrypted sync, and a unified UI.

The difference matters:

- Product intent is achievable.
- Exact parity with mature tools across every SSH server, every terminal program, every OS credential system, and every sync backend is not achievable without years of iteration.

## Highest-Risk Areas

### 1. iCloud Sync

Difficulty: high.

Why:

- Flutter does not provide first-class cross-platform iCloud sync.
- A macOS implementation likely needs native Swift/Objective-C plugin work.
- CloudKit and iCloud Drive have different data models, entitlements, conflict behavior, and account-state APIs.
- Windows/Linux cannot use iCloud natively in the same way.

Recommendation:

- Ship WebDAV sync first.
- Defer iCloud from the first desktop release; implement iCloud as macOS-only beta after the encrypted sync protocol stabilizes.
- Keep iCloud behind `SyncProvider` so it does not affect vault or UI architecture.

### 2. macOS Keychain Sync

Difficulty: medium-high.

Why:

- Device-local Keychain is straightforward.
- iCloud Keychain sync behavior depends on entitlements, item attributes, user account state, and Apple platform rules.
- Cross-platform users cannot rely on Keychain sync.

Recommendation:

- Make portable encrypted vault the primary sync model.
- Treat Keychain as an unlock convenience, not the canonical sync mechanism.
- Clearly label credentials as portable, device-local, or Keychain-synced.

### 3. Secure Storage Parity Across OSes

Difficulty: medium-high.

Why:

- macOS Keychain is robust.
- Windows Credential Manager/DPAPI behavior must be verified.
- Linux Secret Service may be unavailable on minimal desktops, servers, or some window manager setups.

Recommendation:

- Implement a `SecretStore` capability system.
- Always support passphrase unlock fallback.
- Warn users when OS secure storage is unavailable rather than silently downgrading.

### 4. Terminal Quality

Difficulty: high.

Why:

- A terminal app is judged by edge cases: vim, tmux, mouse tracking, IME, alternate screen, bracketed paste, color handling, font rendering, resize behavior, high output volume.
- Flutter rendering and desktop keyboard handling need platform-specific QA.
- `xterm` gives a strong start but does not remove the need for extensive terminal compatibility testing.

Recommendation:

- Benchmark terminal throughput early.
- Keep terminal adapter isolated.
- Test real interactive apps, not only echo commands.
- Ship with conservative scrollback limits and batched writes.

### 5. Zmodem / rz / sz

Difficulty: medium-high.

Why:

- zmodem rides inside the terminal byte stream.
- Detection/interception must be exact or terminal output can be corrupted.
- Server-side implementations vary.

Recommendation:

- Do not make zmodem part of the first MVP acceptance criteria.
- Implement behind `enableZmodem`.
- Test specifically against `lrzsz`.
- Integrate with the transfer queue only after basic detection works.

### 6. SSH Agent

Difficulty: medium.

Why:

- macOS/Linux usually use `SSH_AUTH_SOCK`.
- Windows can involve Windows OpenSSH agent or Pageant-like behavior.
- Flutter/Dart may need native or socket-specific integration.

Recommendation:

- Ship password and imported key auth first.
- Defer agent auth from the first desktop release. Current `dartssh2` public-key auth signs synchronously through `SSHKeyPair.sign()`, while local agents require asynchronous socket/named-pipe signing. Revisit after choosing an async signer adapter, a fork, or an upstream change.

### 7. OpenSSH Certificates

Difficulty: medium to high.

Why:

- "SSH certificate" can mean imported private keys, public keys, or actual OpenSSH user certificates (`*-cert.pub`).
- Many libraries support private keys before they support OpenSSH certificate authentication.
- Certificate auth needs pairing private key + cert + server support.

Recommendation:

- In requirements, distinguish "SSH private key import" from "OpenSSH certificate authentication."
- Ship private key import first.
- Add OpenSSH cert support only after confirming `dartssh2` support or implementing a compatible adapter.

### 8. SFTP File Manager Completeness

Difficulty: medium.

Why:

- Basic list/upload/download is straightforward.
- Robust transfers need queueing, cancellation, conflict handling, retries, permissions, symlinks, huge directories, partial failure behavior, and path encoding correctness.

Recommendation:

- Build transfer queue as a real subsystem, not a thin UI wrapper.
- Do list/table SFTP MVP first, then add Explorer-style file manager mode, previews, dual-pane workflows, and polish.

### 9. WebDAV Provider Differences

Difficulty: medium.

Why:

- WebDAV servers differ in ETag behavior, locking, MOVE support, path encoding, quotas, and error responses.

Recommendation:

- Use temp object + final move where possible.
- Use manifest revisions and conflict-safe writes.
- Maintain compatibility tests for several providers before v1.

### 10. Future Mobile Support

Difficulty: medium.

Why:

- Flutter helps, but mobile has different background execution, file picker, keyboard, secure storage, and session lifecycle constraints.
- A desktop split-pane UI cannot simply shrink into a phone app.

Recommendation:

- Keep core domain/vault/sync/SSH abstractions portable.
- Do not promise mobile release until desktop core stabilizes.

## Suggested Scope Adjustment

Desktop MVP should guarantee:

- Host and identity management.
- Encrypted local vault.
- SSH terminal with password/private-key auth.
- Host key verification.
- xterm-based terminal themes and settings.
- SFTP browser and transfer queue.
- WebDAV encrypted sync.
- Import OpenSSH config and private keys.
- Professional cross-platform desktop UI.

Desktop v1.1/v1.2 should add:

- iCloud sync.
- SSH agent.
- Jump hosts.
- Port forwarding.
- zmodem/rz/sz.
- OpenSSH certificate authentication if not already supported cleanly.

## Implementation Posture

Serlink should be built as a serious desktop client, not as a demo app. The safest delivery posture is:

- Make the core local SSH/SFTP app excellent first.
- Make encryption and sync protocol correct before adding providers.
- Add platform-native features as capability-based enhancements.
- Avoid claiming support for an advanced SSH feature until it has integration tests against real OpenSSH servers.
