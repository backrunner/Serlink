import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/terminal/application/terminal_display_settings.dart';
import 'package:serlink/features/terminal/application/terminal_font_discovery.dart';
import 'package:xterm/xterm.dart';
import 'package:xterm/src/ui/painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader(bundledTerminalFontFamily);
    for (final face in ['Regular', 'Bold', 'Italic', 'BoldItalic']) {
      loader.addFont(
        rootBundle.load(
          'assets/fonts/jetbrains_mono_nerd/JetBrainsMonoNerdFontMono-$face.ttf',
        ),
      );
    }
    await loader.load();
    // Load a real non-Nerd font so this checks glyph fallback rather than
    // fallback from a missing font family or the test runner's Ahem font.
    final ordinary = FontLoader('Serlink Test Ordinary');
    ordinary.addFont(
      rootBundle.load('packages/forui/assets/fonts/inter/Inter.ttf'),
    );
    await ordinary.load();
  });

  test('bundled faces paint Nerd Font icons as single-cell glyphs', () async {
    // Powerline, Font Awesome, Octicons, Codicons and supplementary-plane MDI.
    const icons = [
      '\u{e0b0}',
      '\u{f07b}',
      '\u{f120}',
      '\u{f418}',
      '\u{ea60}',
      '\u{f0318}',
    ];
    for (final bold in [false, true]) {
      for (final italic in [false, true]) {
        final style = const TerminalDisplaySettings(fontSize: 24).textStyle
            .toTextStyle(color: Colors.white, bold: bold, italic: italic);
        final missingGlyph = await _paint('\u{10ffff}', style);
        final characterWidth = _width('M', style);
        for (final icon in icons) {
          expect(_width(icon, style), closeTo(characterWidth, 0.01));
          final glyph = await _paint(icon, style);
          expect(
            glyph,
            isNot(orderedEquals(missingGlyph)),
            reason:
                'U+${icon.runes.single.toRadixString(16)} must have an outline',
          );
          expect(glyph.any((byte) => byte != 0), isTrue);
        }
      }
    }
  });

  test(
    'missing primary family falls back to the bundled icon outlines',
    () async {
      const selected = TerminalDisplaySettings(
        fontFamily: 'Serlink unavailable system font',
        fontSize: 24,
      );
      final fallbackStyle = selected.textStyle.toTextStyle(color: Colors.white);
      final bundledStyle = fallbackStyle.copyWith(
        fontFamily: bundledTerminalFontFamily,
        fontFamilyFallback: const [],
      );
      for (final icon in ['\u{e0b0}', '\u{f120}', '\u{f0318}']) {
        expect(
          await _paint(icon, fallbackStyle),
          orderedEquals(await _paint(icon, bundledStyle)),
        );
      }
    },
  );

  test('Nerd Font icons consume one terminal column including MDI', () {
    final terminal = Terminal()..resize(80, 24);
    terminal.write('A\u{e0b0}\u{f07b}\u{f120}\u{f418}\u{ea60}\u{f0318}B');
    expect(terminal.buffer.cursorX, 8);
  });

  test('ordinary selected font keeps text and falls back for Nerd Font icons', () async {
    const selected = TerminalDisplaySettings(
      fontFamily: 'Serlink Test Ordinary',
      fontSize: 24,
    );
    for (final bold in [false, true]) {
      for (final italic in [false, true]) {
        final style = selected.textStyle.toTextStyle(
          color: Colors.white,
          bold: bold,
          italic: italic,
        );
        final ordinaryOnly = style.copyWith(fontFamilyFallback: const []);
        final bundledOnly = style.copyWith(
          fontFamily: bundledTerminalFontFamily,
          fontFamilyFallback: const [],
        );
        for (final icon in [
          '\u{e0b0}',
          '\u{f07b}',
          '\u{f120}',
          '\u{f418}',
          '\u{ea60}',
          '\u{f0318}',
        ]) {
          final iconStyle = selected.textStyle.toTextStyle(
            codePoint: icon.runes.single,
            color: Colors.white,
            bold: bold,
            italic: italic,
          );
          final painted = await _paint(icon, iconStyle);
          expect(
            painted,
            orderedEquals(await _paint(icon, bundledOnly)),
            reason:
                'Nerd Font icon U+${icon.runes.single.toRadixString(16)} must use the bundled fallback',
          );
          expect(
            painted,
            isNot(orderedEquals(await _paint(icon, ordinaryOnly))),
          );
          expect(
            await _paintTerminalCell(
              icon.runes.single,
              selected,
              bold: bold,
              italic: italic,
            ),
            orderedEquals(painted),
            reason: 'The terminal painter must apply the same glyph fallback',
          );
        }
        expect(
          await _paint('W', style),
          orderedEquals(await _paint('W', ordinaryOnly)),
        );
        expect(
          await _paint('W', style),
          isNot(orderedEquals(await _paint('W', bundledOnly))),
        );
        expect(
          await _paintTerminalCell(0x57, selected, bold: bold, italic: italic),
          orderedEquals(await _paint('W', ordinaryOnly)),
        );
      }
    }
  });
}

Future<Uint8List> _paintTerminalCell(
  int codePoint,
  TerminalDisplaySettings settings, {
  bool bold = false,
  bool italic = false,
}) async {
  final painter = TerminalPainter(
    theme: settings.terminalTheme,
    textStyle: settings.textStyle,
    textScaler: TextScaler.noScaling,
  );
  final cell = CellData(
    foreground: CellColor.rgb | 0xffffff,
    background: 0,
    flags: (bold ? CellFlags.bold : 0) | (italic ? CellFlags.italic : 0),
    content: codePoint | (1 << CellContent.widthShift),
  );
  final recorder = ui.PictureRecorder();
  painter.paintCellForeground(ui.Canvas(recorder), const Offset(8, 8), cell);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(pixels!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return bytes;
}

double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

Future<Uint8List> _paint(String text, TextStyle style) async {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Offset(8, 8));
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(pixels!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  painter.dispose();
  return bytes;
}
