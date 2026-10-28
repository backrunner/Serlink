# macOS review entitlements and review access

Build 17 replaces build 16's broad Downloads permission with native
user-selected file access, adds an isolated offline demo and supplies a
separate live review environment. Its distribution export has the ten keys
below and no broad Downloads or debug entitlement. Build 17 is uploaded,
selected and Waiting for Review; see [the validation report](review-2026-10-19.md).
This document contains no live hostname, login name or password.

## Entitlement inventory

| Entitlement | Reason and user-visible location | Verification |
| --- | --- | --- |
| `com.apple.security.app-sandbox` | Mac App Store sandbox; app-private database and vault | Inspect distribution signature; exercise the app under App Sandbox |
| `com.apple.security.files.user-selected.read-write` | SFTP/ZMODEM file and folder transfers, vault/metadata imports and exports, diagnostics exports | Native Open/Save/folder panels; transfer a disposable file outside the app container and compare bytes |
| `com.apple.security.network.client` | SSH/SFTP, optional WebDAV/CloudKit sync and user-configured command-protection API | Live SSH/SFTP; Settings > Sync; optional protection requires the user's own API key |
| `com.apple.security.network.server` | Local SSH forwards, dynamic SOCKS proxy, authenticated loopback MCP HTTP | Forward to remote `127.0.0.1:8080`; initialize MCP with/without token, stop server and check listener closure |
| `com.apple.developer.icloud-container-identifiers` | `iCloud.com.alkinum.serlink`, private encrypted vault snapshots | Settings > Sync > iCloud using an Apple ID; signed container list |
| `com.apple.developer.icloud-services` | `CloudKit` record/asset storage | Inspect container schema; normal CloudKit sync |
| `com.apple.developer.icloud-container-environment` | `Production`, added by distribution export | Inspect the exported distribution-signed app; a development preview is insufficient |
| `com.apple.developer.aps-environment` | `production` for distribution; silent CloudKit record-change pushes | Content-available `CKQuerySubscription`; two signed devices for end-to-end delivery |
| `com.apple.application-identifier` | Signing-generated application identity | Match profile and `com.alkinum.serlink` |
| `com.apple.developer.team-identifier` | Signing-generated developer identity | Match distribution profile and certificate |

`com.apple.security.files.downloads.read-write` is unnecessary: desktop
`DocumentGateway.pickFileDownloadPath` uses `getSaveLocation`; directory
downloads use `getDirectoryPath`. Exports and ZMODEM also use native panels.
MCP-initiated downloads now stage in an `mcp-downloads` directory under the
app-container Application Support directory; the user exports a completed file
from Transfers through a native Save panel. Direct builds retain Downloads
staging. A server token or MCP host grant never grants macOS filesystem access.
The mobile `Documents/Downloads` staging directory is inside the mobile app
container and does not justify macOS Downloads-folder access. Apple distinguishes
[user-selected access from programmatic Downloads access](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html).

Development signing may inject `com.apple.security.get-task-allow`; distribution
must not retain it. Debug JIT and the direct helper's unsigned executable-memory
entitlement are not Mac App Store release requirements. The standalone helper
is not shipped in this channel.

## Offline review mode

Hold the lock badge on Create/Unlock Vault, or Settings' version label. This
documented, universal preview has no reviewer detection or remote activation.
The banner identifies simulation throughout.

`DemoWorkspace` creates a parentless Riverpod container, its own in-memory
database, synthetic encrypted credentials, preferences and temporary recovery
paths. It cannot inherit the normal vault, Keychain, database, sync settings or
SSH connections. SSH and SFTP share `DemoFileSystem`; `DemoShell` never invokes
a process or opens a socket. Simulated remote storage has a 16 MiB budget.
User-selected local transfers preserve real file bytes. Reset/exit dispose
connections and temporary data. Sync and MCP can be tested after exiting demo.

The [review-completeness guidance](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review)
requires functional review access. The simulator complements the live SSH
account; a video, screenshot fixture or reviewer-owned server is not the plan.

## Private live review environment

`tool/provision_review_environment.py` runs on a dedicated Ubuntu machine over
an authorized admin session. Hostname and account name are runtime arguments.
It generates a random password and writes access details only to a root-owned
`0600` JSON file. Never copy that file into this repository, GitHub issues,
public screenshots or public release notes.

The review account has no supplementary groups or sudo. OpenSSH chroots shell
and SFTP into a root-owned minimal filesystem with a small toolset and synthetic
account files. The writable workspace is a 256 MiB tmpfs with
`nosuid,nodev,noexec` and an inode limit; a systemd service seeds examples after
reboot. No administrator home, shadow file, host `/proc` or host sockets are
mounted. A user slice limits memory, CPU, processes and socket binds.
UID-specific nftables rules cover IPv4/IPv6; new outgoing connections can reach
only the loopback example service. OpenSSH permits local/dynamic forwarding
only to `127.0.0.1:8080`; remote, agent, X11, stream-local and tunnel forwarding
are disabled. The HTTP service has its own unprivileged identity and read-only
content mount.

Give Apple the real host, port, account, password, SFTP folder and SSH key
fingerprint only in private App Store Connect review information. Rotate or
retire the account after review; keep administrator access separate.

## MCP host metadata

Normal mode returns non-secret host configuration: address, username, port,
tags, routing, forwarding and connection settings. Credential material, secret
records and credential references are excluded. The device-local Strict host
privacy switch defaults off. When enabled, discovery returns only opaque host
IDs and display names. The setting is checked on each call; unreadable settings
block metadata access. Vault locking, grants and command protection remain.

Both host and active-connection discovery require a revocable in-memory grant
for the calling client and the requested privacy scope before returning data.
Startup commands are excluded in both modes. Borrowing an existing connection
requires a separate connection-specific grant describing existing terminal
history and file access. Data-sharing access grants require the full in-app
disclosure; notifications offer Deny/View details. Short command approvals can
still allow one execution from an authenticated notification action.

This switch controls metadata. Remote terminal output may contain addresses;
it is not a general terminal data-loss-prevention mechanism.
