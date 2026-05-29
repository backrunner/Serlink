# Serlink Agent Documentation

Serlink is a Flutter-based cross-platform SSH terminal and SFTP application. The initial product target is macOS, Windows, and Linux, while keeping architecture, UI, storage, and sync choices compatible with future mobile clients.

This directory is the source of truth for early product, engineering, and delivery planning. Documents are written so separate implementation agents can pick up bounded modules without needing hidden context.

## Documents

- [01-product-requirements.md](01-product-requirements.md): product vision, personas, scope, Terminus-inspired feature map, and acceptance criteria.
- [02-technical-feasibility.md](02-technical-feasibility.md): Flutter desktop feasibility, dependency choices, SSH/SFTP/zmodem research, and platform risks.
- [03-architecture.md](03-architecture.md): layered architecture, module boundaries, package layout, data flow, and runtime model.
- [04-security-sync.md](04-security-sync.md): threat model, credential storage, end-to-end encryption, iCloud/WebDAV sync, and platform keychain integration.
- [05-ui-design-system.md](05-ui-design-system.md): cross-platform design principles, layout system, terminal theming, file manager UX, and accessibility rules.
- [06-code-level-design.md](06-code-level-design.md): concrete domain models, service interfaces, state management, error taxonomy, and code-level implementation requirements.
- [07-roadmap.md](07-roadmap.md): phased delivery plan from foundation to desktop MVP and advanced SSH capabilities.
- [08-testing-release.md](08-testing-release.md): testing strategy, security validation, CI, packaging, release, observability, and quality gates.
- [09-implementation-backlog.md](09-implementation-backlog.md): module-by-module backlog, dependencies, deliverables, and definition of done for implementation agents.
- [10-risk-assessment.md](10-risk-assessment.md): reality check for hard requirements, platform gaps, and recommended staged scope.
- [11-codex-skills.md](11-codex-skills.md): Flutter, Dart, and design skills installed or available for Serlink implementation work.
- [12-gap-analysis.md](12-gap-analysis.md): missing considerations and edge cases to resolve before implementation or beta.
- [13-progress-status.md](13-progress-status.md): current implementation status, completed slices, and highest-priority unfinished work.
- [14-release-scope-decisions.md](14-release-scope-decisions.md): first desktop release scope exclusions and remaining release blockers.

## Current Product Positioning

Serlink should feel like a professional terminal workstation rather than a decorative SSH client. The core experience is:

1. Store and organize hosts, identities, credentials, groups, tags, snippets, and connection profiles.
2. Open reliable SSH terminal sessions with a capable xterm-style emulator, keyboard shortcuts, tabs/splits, themes, and transport diagnostics.
3. Manage remote files through SFTP with transfer queues, previews, conflict handling, and permission operations.
4. Keep all sensitive host data end-to-end encrypted before any sync provider receives it.
5. Offer platform-native credential options such as macOS Keychain while preserving portable encrypted vault sync.

## Initial Technical Direction

- Framework: Flutter stable with desktop first support for macOS, Windows, and Linux.
- Terminal: `xterm` package, wrapping `xterm.dart`, with `TerminalView` integration and custom theme profiles.
- SSH/SFTP: `dartssh2` for SSH sessions, shell channels, exec channels, port forwarding, and SFTP.
- Persistence: Drift + SQLite for local metadata and encrypted blobs.
- Secret storage: envelope encryption with app-managed vault keys protected by OS secure storage, with optional macOS Keychain syncing.
- Sync: provider abstraction for iCloud and WebDAV, syncing encrypted records only.
- State management: Riverpod with repository/service boundaries; UI remains transport-agnostic.

## Non-Negotiables

- Passwords, private keys, passphrases, host definitions, sync provider credentials, and connection metadata that can identify infrastructure must never be stored or synced in plaintext.
- Terminal sessions must remain responsive under high output volume.
- SFTP transfers must be resumable or safely retryable where protocol and server support allow.
- Desktop MVP must be useful without cloud sync.
- Future mobile support must not require rewriting core domain, vault, sync, or SSH abstractions.
