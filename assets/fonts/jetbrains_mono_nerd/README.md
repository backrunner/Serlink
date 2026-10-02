# Bundled terminal font

JetBrainsMono Nerd Font Mono from Nerd Fonts **v3.4.0**, based on JetBrains Mono **2.304**.

Upstream: https://github.com/ryanoasis/nerd-fonts/tree/v3.4.0/patched-fonts/JetBrainsMono/Ligatures

The four original TTF files are redistributed without modification. The Mono variant keeps terminal icons within a single character cell. Flutter registers this family on every platform through `pubspec.yaml`; no system installation or runtime download is needed.

`lib/features/terminal/domain/nerd_font_glyphs.dart` records the private-use glyph coverage from the regular face's Unicode cmap. When upgrading these fonts, regenerate that range table and check the same coverage in all four faces. The terminal uses this map to select the bundled icon font for non-Nerd primary fonts, including fonts with conflicting private-use characters.

`OFL.txt` preserves the JetBrains license and `NERD_FONTS_LICENSE.txt` preserves the Nerd Fonts license. Both notices are bundled as assets and registered in Flutter's license registry.

## SHA-256

| File | SHA-256 |
| --- | --- |
| JetBrainsMonoNerdFontMono-Bold.ttf | `5bdd4a873f3cd32f882d2c55545089123926e27707d5880fc9eaf84eb01b6686` |
| JetBrainsMonoNerdFontMono-BoldItalic.ttf | `d931df2928b3216892d35980cddcad9edade1b9c9cd2e09a6c2937139f474742` |
| JetBrainsMonoNerdFontMono-Italic.ttf | `ccd88b36d325e6a905edc8dd3f2522718d9690d9bed3fbb4684c7e746c34f846` |
| JetBrainsMonoNerdFontMono-Regular.ttf | `f01031f40e48dc29e1112e6b0b0450a2c6cd097f3f35cfff05c55cb311f8034c` |
