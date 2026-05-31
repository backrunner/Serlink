import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/ui/painter.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('terminal painter keeps foreground glyphs above adjacent backgrounds', () {
    final painter = _RecordingTerminalPainter();
    final line = BufferLine(2)
      ..setCellData(0, _cell(charCode: 0x41))
      ..setCellData(1, _cell(charCode: 0x42, background: _rgbCellColor(0)));
    final recorder = ui.PictureRecorder();

    painter.paintLine(ui.Canvas(recorder), Offset.zero, line);
    recorder.endRecording().dispose();

    expect(painter.calls, [
      'background:65',
      'background:66',
      'foreground:65',
      'foreground:66',
    ]);
  });
}

CellData _cell({
  required int charCode,
  int foreground = 0,
  int background = 0,
}) {
  return CellData(
    foreground: foreground,
    background: background,
    flags: 0,
    content: charCode | (1 << CellContent.widthShift),
  );
}

int _rgbCellColor(int value) {
  return CellColor.rgb | value;
}

class _RecordingTerminalPainter extends TerminalPainter {
  _RecordingTerminalPainter()
    : super(
        theme: TerminalThemes.defaultTheme,
        textStyle: const TerminalStyle(),
        textScaler: TextScaler.noScaling,
      );

  final List<String> calls = [];

  @override
  void paintCellBackground(
    ui.Canvas canvas,
    Offset offset,
    CellData cellData,
  ) {
    calls.add('background:${_charCode(cellData)}');
  }

  @override
  void paintCellForeground(
    ui.Canvas canvas,
    Offset offset,
    CellData cellData,
  ) {
    calls.add('foreground:${_charCode(cellData)}');
  }

  int _charCode(CellData cellData) {
    return cellData.content & CellContent.codepointMask;
  }
}
