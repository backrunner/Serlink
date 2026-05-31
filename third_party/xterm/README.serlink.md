This is a local copy of `xterm` 4.0.0 with Serlink-specific rendering patches.

Current patch:

- Paint terminal line backgrounds before foreground glyphs. This prevents
  adjacent colored cells from shaving Nerd Font and Powerline glyph overhangs.
