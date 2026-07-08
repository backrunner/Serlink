This is a local copy of `xterm` 4.0.0 with Serlink-specific rendering and
terminal compatibility patches.

Current patches:

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
- Ignore keyboard visibility metric callbacks after `TerminalView` disposal.
