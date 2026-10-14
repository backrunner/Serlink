# macOS incoming-network entitlement review follow-up

Serlink 1.0.0 (16) was resubmitted on 2026-10-12 at 22:48 GMT+8 after saving
the incoming-network entitlement explanation and sending an App Review reply.
App Store Connect shows **Waiting for Review**, not approval.

## Submission

- App: `6780579821`; bundle ID: `com.alkinum.serlink`.
- Submission: `6c24459c-a8fe-4027-a93d-db24a217052b`.
- Existing build: `3b6a91a9-e66b-4447-b786-d4907692505c`, version `1.0.0 (16)`.
- Original issue: guideline 2.4.5, automated detection of
  `com.apple.security.network.server` without matching functionality.
- Retained the entitlement because SSH local forwarding, dynamic SOCKS
  forwarding and the embedded MCP HTTP server create incoming TCP listeners.
- Saved the 3964-character `review-notes.txt` in App Review Information and
  a separate `network.server` justification in App Sandbox Information.
- Sent `network-server-review-reply.txt`, confirmed the message appeared in
  the submission history, updated the review item and resubmitted the same build.
- No app behavior, entitlements, data schema, build number or binary changed.

## Verification

- macOS publishable store-material checks passed, including three locales,
  screenshot dimensions and icon alpha checks. `git diff --check` passed.
- Existing MCP transport, controller and settings tests: 18 passed.
- Ran the existing App Store archive at
  `build/macos/archives/serlink-app-store.xcarchive/Products/Applications/serlink.app`.
  Settings displayed version `1.0.0 (16)` and the MCP manager was accessible
  while the vault remained locked; no vault credentials were needed.
- The live loopback HTTP endpoint rejected an unauthenticated request with 403.
  An authenticated initialization using the documented `2025-03-26` protocol
  returned HTTP 200 and identified `serlink` version `1.0.0`; the verification
  session was deleted successfully.
- Turning Agent server off showed Stopped. A subsequent TCP connection returned
  `ECONNREFUSED`, and `lsof` found no listener on the tested port.
- Quit the verification app after stopping it. Temporary token configuration
  was deleted; no token or user vault information was sent to Apple.
- SSH local/dynamic forwarding was reviewed in source and documented for the
  reviewer; actual SSH forwarding was not rerun against a remote server.

Evidence screenshots are local, temporary artifacts under
`/tmp/serlink-review-evidence/`: `macos-resubmission-and-reply.jpg`,
`macos-waiting-for-review.jpg`, and `mcp-stopped.png`.
