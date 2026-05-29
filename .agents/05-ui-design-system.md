# UI Design System

## Design Intent

Serlink should feel professional, calm, and fast. The design should support repeated operational work: scanning many hosts, connecting quickly, moving files safely, and keeping terminal sessions readable for hours.

Avoid decorative dashboard tropes. The app should be compact, precise, and keyboard-friendly, with enough polish to feel trustworthy.

## Cross-Platform Principles

- Same information architecture on macOS, Windows, and Linux.
- Platform-specific menu and shortcut conventions where users expect them.
- Dense but readable layouts.
- Primary work surfaces should not be boxed into decorative cards.
- Terminal and file manager get maximum screen real estate.
- Status and risk states must be visually clear without being loud.
- Every icon-only action needs tooltip text.
- Text must fit in compact controls at common localized lengths.
- Avoid duplicate metadata and redundant indicators. Show compact status only when it changes what the user can or should do.

## Information Architecture

Primary areas:

- Hosts.
- Sessions.
- Files.
- Transfers.
- Snippets.
- Settings.

Sync is not a primary navigation item. It lives under Settings while global sync status remains visible in the toolbar.

Recommended desktop shell:

```text
┌──────────────────────────────────────────────────────────────┐
│ Global toolbar: workspace, search, new session, sync, status │
├──────────────┬───────────────────────────────────────────────┤
│ Sidebar      │ Main work surface                             │
│ Hosts        │ Host list / Workspace tabs                    │
│ Sessions     │                                               │
│ Files        │                                               │
│ Transfers    │                                               │
│ Snippets     │                                               │
│ Settings     │                                               │
└──────────────┴───────────────────────────────────────────────┘
```

Breakpoints:

- Wide desktop: sidebar + split detail.
- Medium desktop: collapsible sidebar + main.
- Narrow/mobile future: bottom/navigation rail + stacked views.

## Visual Tokens

### Spacing

- Base unit: 4 px.
- Compact control height: 28 px.
- Standard control height: 32 px.
- Toolbar height: 44 px.
- Sidebar width: 220-280 px.
- Minimum terminal pane size: 320 x 220 px.

### Radius

- General controls: 6 px.
- Repeated list items: 6 px.
- Dialogs/popovers: 8 px.
- Avoid oversized rounded cards.

### Typography

- UI font: platform default system font.
- Terminal font: default to a bundled/user system monospace, with configurable fallback.
- Terminal line-height configurable from 1.0 to 1.4.
- Do not scale UI font size by viewport width.

### Color

Use semantic tokens, not direct colors in feature code:

- `surface.base`
- `surface.raised`
- `surface.sunken`
- `border.subtle`
- `text.primary`
- `text.secondary`
- `text.muted`
- `accent.primary`
- `status.success`
- `status.warning`
- `status.danger`
- `status.info`
- `terminal.background`
- `terminal.foreground`
- `terminal.cursor`
- `terminal.selection`
- `terminal.ansi.*`

Provide light and dark themes. Dark theme must not be a single blue/slate palette; terminal themes can vary independently.

## Core Screens

### Hosts

Layout:

- Left filter tree: all hosts, groups, tags, recently used, favorites.
- Main list/table: name, host, username, auth indicator, tags, last connected, status.
- Detail inspector: connection settings, identity, port forwards, snippets, notes.

Required interactions:

- Command palette connect.
- Double click/Enter opens terminal.
- Secondary action opens SFTP.
- Inline status for missing credentials or untrusted host key.
- Bulk edit tags/groups.
- Import preview from SSH config.

### Workspace Tabs

The main work surface uses one shared tab container. Terminal tabs and SFTP tabs can be mixed in the same tab strip.

Tab types:

- Terminal tab.
- SFTP tab.

Connection entry points:

- From a host, user can choose open terminal, open SFTP, or open both.
- From an active terminal tab, user can open SFTP for the same host.
- From an active SFTP tab, user can open terminal for the same host/path where supported.

Tab behavior:

- Multiple hosts can be connected at the same time.
- Each tab has its own lifecycle and failure state.
- Unexpected disconnect keeps the tab open and shows reconnect/close actions.
- Reconnect happens in-place in the current tab and starts a new connection.
- Full app exit does not restore previous workspace tabs.
- Tab labels show only the useful identity: host alias plus optional path/session suffix.
- Use one compact state mark at most: connecting, failed, disconnected, or transfer active.

### Terminal Tab

Layout:

- Session tab strip.
- Split panes.
- Minimal session toolbar: reconnect, duplicate, split, SFTP, search, settings.
- Terminal consumes remaining space.

Required interactions:

- New tab.
- Split horizontal/vertical.
- Close pane/tab.
- Rename session.
- Search terminal buffer.
- Copy selection.
- Paste with bracketed paste support.
- Optional paste confirmation for multiline paste.
- Quick switcher by session name.

Terminal settings:

- Font family.
- Font size.
- Line height.
- Cursor style.
- Cursor blink.
- Scrollback lines.
- Bell style.
- Theme.
- Copy on select.
- Right-click behavior.

### SFTP Tab

Recommended desktop layout:

- Single-pane by default with path breadcrumb and file table.
- Transfer drawer or bottom panel.
- Windows Explorer-like mode, richer file manager interactions, and dual-pane mode are roadmap items after the initial list/table SFTP experience. Bounded text preview/edit can live inside the list/table mode as a compact modal.

File table columns:

- Name.
- Size.
- Modified.
- Permissions.
- Owner/group where available.
- Type.

Actions:

- Upload.
- Download.
- New folder.
- Rename.
- Delete.
- Move.
- Copy path.
- Show hidden.
- Change permissions.
- Refresh.
- Open terminal here.

Conflict UI:

- Overwrite.
- Skip.
- Rename.
- Apply to all.

### Transfers

Show:

- Active, queued, completed, failed.
- Direction.
- Source/target labels.
- Progress.
- Speed.
- ETA.
- Retry/cancel.

Sensitive path display:

- Respect privacy mode by hiding full paths or showing basename only.

### Snippets

Features:

- Store reusable commands.
- Tags/groups.
- Variables such as `${host}`, `${user}`, `${date}`.
- Confirm before inserting/executing.
- Insert into active terminal rather than execute by default.

### Settings

Sections:

- General.
- Appearance.
- Terminal.
- Security.
- Sync.
- SSH.
- SFTP/Transfers.
- Data Import/Export.
- Shortcuts.
- Advanced/Diagnostics.

Security settings must explain:

- Vault lock timeout.
- Portable credentials.
- Device-local credentials.
- macOS Keychain options.
- Clipboard cleanup.
- Privacy/redaction mode.

Sync settings include:

- WebDAV account setup.
- iCloud setup when available.
- Automatic sync status.
- Background sync controls when policy tuning is available.
- Sync health and last sync time.
- Conflict resolver entry point.

Data Import/Export includes:

- Import OpenSSH config.
- Import SSH key.
- Import known hosts.
- Import encrypted vault backup.
- Export encrypted vault backup.
- Export selected host metadata.
- Export diagnostic bundle.

Export actions must show a modal explaining exactly what data leaves the app and whether the payload is encrypted.

### Security Modals

Use modal dialogs for blocking, security-sensitive decisions:

- First-time host key trust.
- Changed host key.
- Fingerprint confirmation.
- Private key export.
- Vault backup export.
- Vault reset.
- Deleting credentials or hosts.
- Multiline paste into terminal when enabled.

Fingerprint modal requirements:

- Show hostname, port, algorithm, and SHA256 fingerprint.
- Show trust action buttons: cancel, trust once, trust and save.
- Changed-key modal additionally shows previous fingerprint and new fingerprint.
- Default focused action must be the safe action, usually cancel.
- Do not allow the underlying connection flow to proceed while the modal is unresolved.

## Command Palette

Command palette is critical for efficiency.

Examples:

- Connect to Host.
- Open SFTP.
- New Host.
- Import SSH Config.
- Export Encrypted Backup.
- Sync Now.
- Lock Vault.
- Open Settings.
- Split Terminal.
- Search Current Terminal.
- Show Transfers.

Palette results should be keyboard navigable and show concise metadata.

## Keyboard Shortcuts

Use platform conventions:

- macOS: Cmd primary.
- Windows/Linux: Ctrl primary.

Baseline:

- New terminal tab.
- Close tab/pane.
- Split pane.
- Command palette.
- Search.
- Copy/paste.
- Increase/decrease terminal font.
- Open SFTP.

Shortcuts must be editable later; initial MVP can use fixed defaults with a documented map.

## Terminal Themes

Theme model:

```text
TerminalTheme
  id
  name
  brightness
  foreground
  background
  cursor
  selection
  black/red/green/yellow/blue/magenta/cyan/white
  brightBlack/.../brightWhite
```

Built-in themes:

- Serlink Dark: neutral dark with balanced ANSI colors.
- Serlink Light: readable light terminal.
- High Contrast Dark.

Host-specific override:

- Use default app theme.
- Use selected terminal theme.
- Use imported theme.

## Accessibility

Requirements:

- Keyboard access for all primary workflows.
- Screen reader labels for navigation/actions.
- Sufficient contrast in UI and terminal themes.
- Focus rings visible.
- No color-only status communication.
- Respect OS text scaling where feasible while preserving terminal grid correctness.
- Provide reduced motion option.

## Empty, Loading, And Error States

Empty hosts:

- Offer create host and import SSH config.

Locked vault:

- Show unlock view; do not leak host names.

No SFTP permissions:

- Show permission error and retry/change path actions.

Sync conflict:

- Use a focused conflict resolver inside Settings > Sync, not a raw JSON diff.

Terminal failure:

- Show concise failure state with reconnect and diagnostics actions.

SFTP failure:

- Keep the tab open, preserve last path when possible, and show reconnect/refresh actions without closing other tabs.

## Design QA Checklist

- Terminal remains primary surface and is not visually crowded.
- File manager handles long filenames and paths without overlapping.
- SFTP MVP remains list/table-first and does not introduce Explorer-style chrome early.
- Host list remains readable with many tags.
- Text fits in controls at 320 px minimum pane width.
- Light/dark themes both pass contrast checks.
- Keyboard-only workflows work for connect, SFTP browse, transfer retry, and vault unlock.
- No sensitive data appears when vault is locked.
- Security modals show safe default actions and do not leak secrets.
- Sync setup appears under Settings, while toolbar only shows sync status/action.
- Workspace tabs can mix terminal and SFTP tabs without duplicate host/status information.
