This is a local copy of `xterm` 4.0.0 with Serlink-specific rendering and
terminal compatibility patches.

Current patches:

- Pass each cell's code point to `TerminalStyle.toTextStyle` so Serlink can use
  the bundled Nerd Font for icons while measuring and painting ordinary text
  in the user's selected font. This also handles non-Nerd fonts with conflicting
  private-use glyphs, where ordinary missing-glyph fallback would not activate.

- Release highlight anchors on disposal and support batched selection/highlight
  changes, including linear-time removal of a group of search highlights.

- Paint terminal line backgrounds before foreground glyphs. This prevents
  adjacent colored cells from shaving Nerd Font and Powerline glyph overhangs.
- Pass the Flutter view id to text input configuration so terminal text input
  works on Flutter 3.44+ Windows.
- Keep IME/composing text diffs stable when platforms report cumulative editing
  values after a committed composing character.
- Keep scroll-region buffer lines attached when scroll-up/scroll-down moves
  rows inside `IndexAwareCircularBuffer`.
- Reply to CPR cursor position queries with 1-indexed VT coordinates and support
  CHT/CBT cursor tab CSI sequences used by ncurses applications.
- Consume unsupported DCS/APC/PM/SOS strings through their terminator, including
  across SSH chunks, so capability probes never become visible TUI text.
- Preserve omitted CSI parameters, apply cursor-position defaults, and restore
  saved cursor attributes when returning from the 1049 alternate screen.
- Reserve bare Ctrl+A/C/F/V for remote applications on Windows/Linux; local
  copy, paste, select-all and search use Ctrl+Shift chords. Apple keeps Cmd chords.
- Ignore keyboard visibility metric callbacks after `TerminalView` disposal.
- Detect ZMODEM handshakes across SSH chunks and ignore pending file selection
  and transfer callbacks after the terminal closes.
- Allow touch-first clients to defer keyboard activation until a tap completes,
  so long presses, text selection, and scroll gestures do not summon the IME.
