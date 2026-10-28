# macOS App Store capability audit — 2026-10-29

Audited source: `5d3bcf3`, including MCP connection borrowing/SFTP downloads
(`51e5196`), generic SSH agents/hardware credentials, notifications, command
protection, demo access, distribution gates and release materials. The findings
below describe that baseline; local remediation is recorded separately. This is
not an Apple approval. App Store Connect status,
the currently selected binary and live reviewer infrastructure were not checked.

## Initial assessment

Do not submit a new binary from this source until the MCP download destination
is corrected and the data-sharing/review-material gaps below are resolved.
The new SSH-agent and hardware-key features are gated out of the App Store
edition. MCP itself is not identified as categorically prohibited by Apple's
published rules; its actual sandbox behavior, consent and disclosure matter.

## Local remediation

| Finding | Implemented behavior |
| --- | --- |
| Download permissions | `mcpDownloadDirectory` selects app-container Application Support for App Store builds, keeps direct-edition Downloads, and uses the existing native-panel Export action in Transfers. No broad Downloads entitlement was added. |
| Discovery and connection consent | Discovery requires a revocable grant scoped to the caller and privacy level before records are read or returned. Startup commands are excluded. Existing connections require a separate grant for their session ID, covering history and file access. Access notifications open the full disclosure; short commands still support one-execution notification approval. |
| Provider sharing and declaration | Explicit, versioned command-sharing consent gates TypeSafe calls. Legacy enabled configurations cannot transmit until consent is renewed. The macOS manifest and local store proposal disclose Other User Content, User ID and Product Interaction linked to the provider account. No universal ZDR assumption remains. |
| Review and policy materials | English, Chinese and Japanese consent/policy/guide copy and the review notes describe actual data flows, container downloads, connection borrowing and key transmission. The review notes contain 3,981 characters, below Apple's 4,000-character limit. |

The local source/material findings are repaired. Before submitting a new build,
publish the updated policy, save matching App Store Connect privacy answers,
provide a limited TypeSafe review key privately, and validate the final
distribution export. Those external operations were not performed by this code
remediation. Do not describe the local build as Apple approval or current
submission state.

### Remediation validation

- Static analysis: no issues. Store materials, manifest plist and App Store
  entitlement/release-surface checks pass. The static CloudKit gate does not
  establish current Production schema deployment or two-device sync.
- Default-distribution full suite: 997 passed, 16 skipped; two files failed to
  launch because of Flutter's `Invalid WebSocket upgrade request`. Both were
  rerun individually at concurrency 1: all 12 tests passed. An earlier run with
  a global App Store define also encountered expected failures in existing
  local-shell tests, which assume the direct distribution; no app behavior was
  changed to accommodate that mismatched test configuration.
- App Store-defined MCP/security/demo/platform run: 244 passed. The final bridge
  rerun passed all 56 tests, including two additional cases for vault locking
  and unlock-generation changes during discovery consent. Tests also cover
  denial, revocation during reads, privacy-scope expansion, existing-session
  grant isolation, legacy model settings and consent withdrawal.
- Website: type checks and strict translation checks pass; 39 pages, 186 search
  records, no diagnostics. Static build succeeds and all 44 browser tests pass.
- A signed native sandbox probe still gets EPERM for the old Downloads path,
  while the new container path successfully writes and reads identical bytes.
  Source and results are in
  `build/release-proof/macos-review-audit-2026-10-29/`. This probe verifies the OS
  permission boundary; it is not an end-to-end Serlink SSH/SFTP transfer.
- Local App Store-channel release-mode builds compile successfully with
  development signing. Final distribution signing, upload, live provider
  assessment, notification clicks and Apple review remain separate gates.
  The final universal build is at
  `/tmp/serlink-macos-review-20261029/Build/Products/Release/serlink.app`;
  strict signature verification passes. It has App Sandbox, no Downloads
  entitlement, no standalone MCP helper, installer disabled, and the three
  declared privacy-collection categories. Development `get-task-allow` is
  present; this is not a distribution export.
- A final default-path rebuild ran out of disk space while writing the x86_64
  snapshot. The project volume had 59 MiB free. Only ignored Flutter snapshot
  and test caches were removed; archives, products and release evidence were
  retained. Rebuilding with clean Xcode derived data on `/tmp` succeeded for
  arm64 and x86_64. No global Flutter configuration was changed.
- `final-build-audit.json` and the final validation logs are retained beside
  the sandbox probe in `build/release-proof/macos-review-audit-2026-10-29/`.

## Findings at baseline

### 1. High: MCP SFTP download conflicts with App Sandbox file permissions

- `lib/features/mcp/application/agent_session_bridge.dart:106` resolves the
  default destination with `getDownloadsDirectory()`. `downloadSftp`, at line
  520, creates a directory and file there without an Open/Save panel.
- `macos/Runner/Release.entitlements:15` enables App Sandbox and user-selected
  file access, with no programmatic Downloads entitlement. The release gate
  explicitly rejects `com.apple.security.files.downloads.read-write`.
- `docs/release/macos/entitlements.md` and `review-notes.txt` explain Downloads
  permission removal on the basis that transfers use native file panels. That
  reasoning no longer covers the new MCP path.
- A minimal ad-hoc-signed sandbox app using the same Foundation directory API
  and the same two file-related sandbox entitlements reproduced the failure:

  ```text
  downloads=/Users/<user>/Library/Containers/<probe-id>/Data/Downloads
  create=denied domain=NSCocoaErrorDomain code=513
  underlying=NSPOSIXErrorDomain:1
  ```

  The probe never selected a file or directory. It did not run inside Serlink;
  it verifies the OS permission mismatch independently of Flutter. A clean
  App Store-channel Serlink run is still needed after repair.
- Recommended repair: use app-container storage for MCP downloads and offer
  explicit native-panel export, or ask the user to select the destination.
  If destination access must survive restart, add the appropriate scoped
  bookmark lifecycle. Keep direct-edition Downloads behavior separate. Update
  the MCP tool description and review notes to match the chosen behavior.
- Relevant rules: 2.1 and 2.4.5(i). This is a functional submission blocker,
  rather than merely an entitlement-description issue.

### 2. High: MCP data discovery precedes specific sharing consent

- `AgentSessionBridge.describeHosts` checks vault state and the strict-privacy
  setting, but does not call `McpAuthorizationService.ensureGrant`.
- `lib/features/mcp/application/mcp_host_visibility.dart:14` defaults strict
  privacy to false. The normal response includes hostname, username, tags,
  paths, forwarding configuration and `startupCommands` (line 51).
- A client with the user-copied bearer token can obtain that metadata before
  the first host-control approval. Token setup is user initiated, but its UI
  does not establish specific consent for all these fields or downstream AI
  sharing. The optional privacy switch describes addresses/settings; it does
  not make arbitrary startup-command text safe or secret-free.
- Connection borrowing uses the existing per-host grant. The current prompt
  says the client wants to **open** a session and can run commands until quit
  or revocation (`lib/l10n/app_en.arb:562`). It does not explain access to an
  existing user session, its existing terminal buffer, directory listings, or
  downloads. A previously granted client can attach without a new prompt.
- Recommended repair: establish explicit discovery/data-sharing consent before
  returning metadata, and disclose which data an external agent can read and
  send onward. Exclude startup commands from ordinary discovery or authorize
  them separately. Make borrowed-session consent cover existing screen history
  and the requested session; use a distinct approval if the existing grant did
  not cover that access. Preserve user control of strict privacy rather than
  relying on its default as a substitute for consent.
- Relevant rules: 1.6 and 5.1.2(i). This is a consent/disclosure risk assessment;
  no claim is made that copying a token can never constitute authorization.

### 3. High: the privacy-label basis needs reassessment for TypeSafe

- Model protection is off by default and requires the user's API key and an
  explicit enable/save action. The dialog already names TypeSafe and says
  commands are transmitted; these are useful safeguards.
- `lib/features/mcp/data/typesafe_command_decision_model.dart:43` sends the
  command text to TypeSafe, with the API key in the authorization header. No
  host-record or terminal-screen object is attached, but command text can
  itself contain passwords, tokens, addresses and personal data.
- `metadata.json` still proposes `DATA_NOT_COLLECTED`. The privacy manifest's
  empty collection array does not independently establish that this label is
  correct. Apple's definition depends on off-device retention and third-party
  practices, rather than who provides the API key or whether the feature is
  optional.
- TypeSafe's current help says retention depends on the data, agreements and
  any agreed ZDR arrangement. Its enterprise page presents ZDR as an available
  account arrangement. Neither establishes universal zero retention for keys
  supplied by arbitrary users. No account-specific retention terms were
  verified in this audit.
- Recommended repair: document the applicable API retention/processing basis
  and reassess App Store Connect answers and manifests as appropriate. If
  retained data is collected, declare the actual data categories and purposes.
  Do not infer non-collection from BYOK or from the absence of developer-run
  storage. Consent should also warn about secrets embedded in command text.
- Relevant rules: 5.1.1/5.1.2 and Apple's app-privacy definitions. This is an
  unresolved declaration gate, not a finding that every API call must count as
  collected data.

### 4. Medium: review materials and several privacy statements are stale

- `docs/release/macos/network-server-review-reply.txt:15` says Serlink does not
  contact an AI provider by itself. Qualify that statement with the optional,
  user-enabled TypeSafe path; do not reuse it unchanged for a new submission.
- The current review notes describe MCP grants, but do not give concrete steps
  for connection borrowing, SFTP tool downloads, notification approvals or
  TypeSafe behavior, including how the reviewer can exercise optional model
  protection without buying their own access. Arrange private review access
  or an agreed review method without publishing keys.
- `settingsMcpGuardDescription` says the API key stays on the device. The key
  is stored locally but necessarily transmitted to TypeSafe for authentication.
  Say it is stored in device-local secure storage, used only to authenticate
  TypeSafe requests, and excluded from vault sync/backups.
- Statements that credentials are never shared must distinguish managed vault
  credentials from secret text a user puts in startup commands or terminal
  output. The standalone-helper/HTTP distinction is already documented.
- Update the English, Chinese and Japanese copy and the private submission
  notes together. Relevant rules: 2.3.1, 2.3.12 and 5.1.

## Capabilities with appropriate source-level separation

| Capability | App Store source behavior | Assessment |
| --- | --- | --- |
| Local shell / PTY | `localTerminal` is false | No new local-shell exposure found |
| Generic SSH agent, agent key picker, hardware-backed credentials | `sshAgentAuth` and `hardwareKeyAuth` are false; resolver rejects agent auth | New direct-edition capability does not become a supported App Store feature |
| Automatic SSH config access/writeback | `sshConfigImport` is false; startup/provider paths are gated | Correct channel boundary found |
| MCP stdio helper and other agents' config installation | `mcpStdioHelper` is false; UI hides the installer; helper embedding is in direct build scripts | Keep HTTP configuration manual in App Store builds |
| Direct DMG installation | Installer defaults to disabled through `SERLINK_DMG_INSTALLER_ENABLED=NO` | Direct installation flow is separately gated |
| Embedded MCP | Random loopback port, per-start bearer token, host controls gated by grants | Supported architecture, with the disclosure and download findings above |
| SSH local/dynamic forwarding | App includes client/server network entitlements; local-forward binds are loopback | `network.server` has a concrete feature justification; retain review steps |
| Approval notifications | System permission requested by user action; authenticated allow actions, expiry/cancellation, in-app fallback | No categorical notification-policy conflict identified; real signed-app interaction still needs QA |
| Offline demo | Clearly marked simulation; separate in-memory workspace; no real MCP/SSH/sync | Useful review supplement; retain live private SSH/SFTP review access |
| Remote SSH/SFTP, ZMODEM, sync and selected-file transfers | Remain enabled | No new blanket prohibition identified; validate permissions and signed runtime behavior |

## Baseline validation

- Reviewed distribution capabilities and build scripts, native installer and
  notification code, entitlements, MCP discovery/authorization/borrowing/
  transfer/model paths, privacy policy and release materials.
- Ran the existing platform, MCP bridge, transport, authorization, controller
  and settings tests with `SERLINK_DISTRIBUTION=app_store`: **87 tests passed**.
  The initial combined run passed 75 tests but failed to load the settings test
  process with `Invalid WebSocket upgrade request`; the isolated settings rerun
  passed all 12 tests.
- Existing download tests inject a temporary directory, so their success does
  not exercise the real Downloads permission boundary. Unit/widget execution
  with a Dart define is not a signed App Sandbox runtime test.
- Independently compiled/signed/executed the Foundation sandbox probe above.
  Its source and entitlements are retained under
  `build/release-proof/macos-review-audit-2026-10-29/`.
- At the initial audit, no application implementation, version, entitlements, App Store Connect data
  or submission was changed. No fresh release archive was produced. Historical
  build-17 review notes are historical evidence, not current submission state.

## Initial recommended acceptance checks

1. Repair MCP download storage and validate it in a fresh signed sandbox run
   without pre-existing picker permissions. Compare downloaded bytes, exercise
   cancellation, and verify the chosen export/access lifecycle.
2. Validate no metadata or existing terminal history is shared before the
   corresponding consent, and that denial/revocation stops further access.
3. Resolve TypeSafe retention and privacy declarations; synchronize consent,
   multilingual privacy copy and review instructions.
4. Verify the final exported binary's distribution flag, entitlements, helper
   absence and installer setting. Exercise notification actions and reviewer
   SSH/SFTP access in that build. Verify optional CloudKit independently.

## Current primary sources

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Sandbox entitlement reference](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)
- [Apple app privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple complete-review access guidance](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review)
- [TypeSafe request retention guidance](https://help.typesafe.ai/articles/5974925716-how-is-submitted-data-used-or-retained)
- [TypeSafe enterprise ZDR availability](https://typesafe.ai/enterprise)
- [TypeSafe privacy policy](https://typesafe.ai/legal/privacy-policy)

Sources checked on 2026-10-29. Rule application above is an engineering review
risk assessment; the final review decision belongs to Apple.
