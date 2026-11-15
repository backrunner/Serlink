# Serlink 1.0.0 (13): iPhone and iPad review guide

Bundle ID: `com.alkinum.serlink`. Minimum iOS/iPadOS: 15.0.
This guide describes the iOS App Store edition. Review-server connection
details belong only in the private App Store Connect attachment, never in this
repository or in the application binary.

## Public audience and business model: Guideline 3.2

1. **Single-company restriction:** none. No employer, school, partner,
   contractor, organization membership, invitation, approval or managed-device
   enrollment is required.
2. **Limited companies:** none. Individuals and organizations can independently
   purchase and use Serlink. There is no sales contract, organization allowlist
   or Serlink onboarding service. Examples include a hobbyist's home Linux
   machine, a student's rented VPS, a freelancer's server and an administrator's
   authorized infrastructure. Servers use standard SSH/SFTP protocols.
3. **Public features:** the entire iOS feature set below is available to ordinary
   App Store purchasers. The category is a general-purpose remote-terminal and
   file-transfer utility, like Termius, Blink Shell or Prompt. A technical target
   audience does not require affiliation with a particular organization.
4. **Accounts:** there is no Serlink account or registration service. The first
   Create Vault screen creates local encrypted storage protected by a passphrase
   and recovery key chosen/generated on the device. It does not create an online
   or enterprise account. SSH credentials authenticate to the user's chosen
   server; iCloud and WebDAV accounts are optional and independent.
5. **Payment:** the configured US base price is a one-time US$1.99 App Store
   purchase, with localized storefront prices. No in-app purchase, subscription,
   paid membership, feature unlock or external Serlink checkout is required.
   Users obtain access to their own remote servers independently.

The review sandbox is an optional testing resource for Apple, not an access
requirement for customers and not an organization to which users must belong.

## Immediate, populated offline exploration

On Create/Unlock Vault, press and hold the large colored lock/shield icon for
approximately one second. In an unlocked workspace, the alternative entry is
pressing and holding the version label at the bottom of Settings. This same
entry is available to all users; it is not activated by reviewer detection.

The banner labels this workspace **Demo mode: simulated terminal and remote
files**. It uses an isolated temporary workspace, fictional hosts, sample
credentials and an in-memory remote filesystem. It does not read the user's
vault, connect to real SSH servers or perform CloudKit/WebDAV sync.

1. Hosts contains Review Sandbox, Staging Workspace and Documentation Server.
2. Open Review Sandbox and explore the terminal. Try `help`, `pwd`, `ls -la`,
   `cat README.txt`, `mkdir scratch` and `echo hello > scratch/hello.txt`.
3. Terminal and SFTP share this simulated filesystem. Browse directories,
   preview/edit text, rename, create folders and inspect permissions.
4. Snippets contains sample commands; Transfers contains a sample record.
   Credentials also contains fictional examples.
5. Review guide explains the controls. Reset demo restores the sample data;
   Exit demo discards the temporary workspace and returns to the original app.

This exploration path is a supplement to real functionality. Real SSH,
forwarding, biometric authentication and cloud synchronization must be tested
using the corresponding actual services/device capabilities.

## Real SSH and SFTP walkthrough

The private attachment supplies a dedicated restricted review-server address,
port, username/password, expected host-key fingerprints and starting directory.
Use those only for App Review. No purchase of a server or Serlink account is
needed to exercise this supplied environment.

1. Exit demo. Create a vault with any strong passphrase and retain its recovery
   key. This protects this device's workspace; it is not the SSH password.
2. In Settings > Credentials, add a password identity with the private review
   username/password. Add a Host using the supplied address/port, select that
   identity and set the SFTP starting folder to `/workspace`.
3. Connect. Compare the displayed host-key fingerprint with the private
   attachment before trusting the key. Try `pwd`, `whoami`, `ls -la` and
   `cat documents/notes.txt`.
4. Use terminal input, the mobile accessory keys/modifiers, output search,
   session tabs and reconnect. Create a harmless snippet such as `pwd` and
   review/send it to the session. The shell is on the remote server.
5. Open SFTP. Preview `documents/notes.txt`; edit a disposable copy, create a
   directory, rename a disposable file and inspect/change its permissions.
   Upload an innocuous document using the system document picker.
6. Download README.txt. Open/Export uses the system share sheet; on iPad it is
   anchored to the application view. Save to Files or open a compatible app.
   External edits are not automatically sent back to the SSH server.
7. Transfers shows progress, supported retry/pause/resume/cancel actions and
   completed history. Removing a history record and deleting its local file are
   separate choices. Keep Serlink in the foreground during transfers.
8. Close sessions and transfers explicitly when finished. Locking a vault
   prevents new credential retrieval but does not disconnect existing sessions.

The restricted server permits disposable file operations in `/workspace`.
Administration, unrelated server files and arbitrary network destinations are
intentionally unavailable to its review account. This server-side confinement
does not limit what a customer can do on their own authorized server.

## Complete iOS feature inventory

| Area | Review actions and scope |
| --- | --- |
| Hosts | Add/edit/delete, groups/tags, search, display names, address/port/user settings, credential selection, jump hosts and per-host connection/startup/forwarding settings. |
| Authentication | Password, supported imported private keys, key generation, keyboard-interactive prompts and supported certificate records. Host-key trust/changed-key verification is separate from user authentication. A server may support only some methods. |
| Remote terminal | SSH PTY, tabs, reconnect, output search, touch accessory keys, terminal settings/fonts and bundled Nerd Font glyphs. Remote programs can include ordinary shell commands, editors and terminal interfaces. They execute on the SSH server, not in an iOS local shell. |
| Snippets | Create/edit/delete, organize/search and send chosen commands to a remote session after reviewing them. |
| Forwarding | Standard SSH local, remote and dynamic forwarding according to host settings and the destination server's policy. Foreground session lifetime applies. This is not a system VPN or Network Extension. The review sandbox permits only local forwarding to its sample HTTP endpoint `127.0.0.1:8080`; use a local loopback port such as 18080. |
| SFTP | Directory browsing, file details/permissions, supported text preview/edit, folders, rename, deletion, selected-file uploads and downloads. Local recursive directory transfer is not an iOS feature. |
| Transfers | Progress, supported pause/resume/retry/cancel, local history and separate cleanup/export/open actions. Downloads are ordinary local files outside vault encryption. |
| Vault | Local encrypted hosts, credentials and workspace records; passphrase, recovery-key and supported device-biometric unlock; encrypted backup/restore. Keep recovery material safely. |
| Import/export | Explicit file-picker import/export of supported host/credential metadata, SSH config and known-host data, certificates and encrypted backup files. Plain metadata exports disclose the selected fields and require confirmation. No automatic access to the device's system SSH configuration. |
| Synchronization | Optional encrypted iCloud or user-configured WebDAV snapshots, device state, sync history/conflicts and restoration. SSH/SFTP works without either. Files downloaded through SFTP are not automatically vault-synchronized. |
| Preferences/support | English, Simplified Chinese, Japanese; light/dark system appearance; terminal display/input preferences; optional app-switcher privacy cover; local diagnostics and explicit export; support/about/license links. |

## All entitlements in the exported distribution IPA

These values were read from the actual distribution-signed build 13, rather
than inferred from the development archive. Xcode adds signing metadata during
export; an archive can have development signing before distribution export.

| Entitlement | Value and purpose |
| --- | --- |
| `application-identifier` | `PB8H83VL3Z.com.alkinum.serlink`: signed app identity and associated app-scoped security resources. |
| `com.apple.developer.team-identifier` | `PB8H83VL3Z`: developer team identity, not a customer organization restriction. |
| `get-task-allow` | `false`: distribution build does not permit debugger attachment. |
| `beta-reports-active` | `true`: Apple distribution/TestFlight reporting metadata. |
| `com.apple.developer.icloud-container-identifiers` | `[iCloud.com.alkinum.serlink]`: optional CloudKit encrypted workspace storage. |
| `com.apple.developer.icloud-services` | `[CloudKit]`: access to CloudKit, using the user's private database. |
| `com.apple.developer.icloud-container-environment` | `Production`: the shipping CloudKit environment. |
| `aps-environment` | `production`: APNs transport for CloudKit silent change notifications. |

There are no additional entitlement keys in the exported main application.
There are no iOS app extensions or embedded local-shell executables.

## Permission prompts, Info.plist and background behavior

- `NSFaceIDUsageDescription`: optional biometric vault unlock. The user enables
  this in Settings; Apple LocalAuthentication/Keychain authenticates access to
  device-local key material. Serlink does not receive biometric templates.
- `NSLocalNetworkUsageDescription`: direct connections to SSH/SFTP/WebDAV
  endpoints the user selects on their LAN. This does not enable LAN scanning,
  Bonjour discovery or multicast. Public internet connections do not need this
  LAN permission. Permission can be changed in system Settings.
- `UIBackgroundModes=[remote-notification]`: CloudKit installs a query
  subscription with content-available notifications. Notifications invalidate
  local sync state and trigger bounded refresh where iOS permits. They are not
  advertising or continuous terminal/transfer execution. The app does not
  promise background SSH sessions or background transfer completion.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`: app-document
  access through Files/Finder and chosen document workflows. Imports/exports
  use native system document selection; opening a downloaded file uses the
  native activity/share sheet. There is no broad filesystem permission on iOS.
- No camera, microphone, photos, contacts, location, tracking, VPN, Network
  Extension or multicast entitlement is requested. No user-facing push
  notification service or notification-permission onboarding is required.

## Optional encrypted synchronization and privacy

In Settings > Sync, choose iCloud on an Apple device signed into iCloud, or
configure an authorized WebDAV endpoint. To test cross-device synchronization,
use two Apple devices with the same iCloud account and the same vault recovery
material, then add/edit/delete a disposable host or snippet. Inspect sync and
conflict status. The supplied SSH review account is not an iCloud or WebDAV
account. CloudKit schema deployment checks are separate from device sync tests.

The app encrypts workspace records before upload. CloudKit uses the private
database; WebDAV uses the selected server. SSH/SFTP credentials are used to
authenticate to the chosen remote server. WebDAV credentials authenticate to
the configured endpoint. No Serlink registration, advertising, tracking SDK or
developer-operated terminal relay is part of this iOS build. Diagnostics remain
local unless the user explicitly exports/shares them. Server operators and
storage providers have their own processing policies.

MCP, external-agent access, AI command classification/TypeSafe settings, macOS
notification approval, system SSH agents/hardware keys, local shell/PTY,
desktop splits and ZMODEM are not enabled on iOS. These desktop features must
not be inferred from the cross-platform project or macOS entitlements.

## Encryption and export-compliance facts

The app uses standard library cryptography for SSH/SFTP and its encrypted
vault, beyond OS-only cryptography: XChaCha20-Poly1305, Argon2id and derived-key
operations; SSH algorithms are negotiated with the server. It introduces no
proprietary cryptographic algorithm. HTTPS/TLS protects applicable WebDAV
transport. App Store Connect encryption answers must reflect this inventory;
do not describe the implementation as OS-only or invent an export approval.
The existing distribution excludes France pending the applicable declaration.

## Primary references

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/
- https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription
- https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- https://serlink.alkinum.com/privacy/
- https://serlink.alkinum.com/support/
