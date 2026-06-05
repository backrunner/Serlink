class TerminalModifierLatch {
  const TerminalModifierLatch({
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
  });

  final bool ctrl;
  final bool alt;
  final bool shift;

  bool get isActive => ctrl || alt || shift;
}

enum TerminalControlInputKey {
  escape,
  tab,
  enter,
  backspace,
  insert,
  delete,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  pageUp,
  pageDown,
  home,
  end,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
}

String applyTerminalModifierLatchToText(
  String text,
  TerminalModifierLatch modifiers,
) {
  if (!modifiers.isActive) {
    return text;
  }

  final rune = _singleAsciiRune(text);
  if (rune == null) {
    return text;
  }

  var output = String.fromCharCode(rune);
  if (modifiers.ctrl) {
    final controlCode = _controlCodeForRune(rune);
    if (controlCode == null) {
      return text;
    }
    output = String.fromCharCode(controlCode);
  } else if (modifiers.shift) {
    output = _shiftAscii(output);
  }

  if (modifiers.alt) {
    return '\x1b$output';
  }
  return output;
}

String terminalControlInputSequence(
  TerminalControlInputKey key,
  TerminalModifierLatch modifiers,
) {
  final modifierCode = _modifierCode(modifiers);
  return switch (key) {
    TerminalControlInputKey.escape => modifiers.alt ? '\x1b\x1b' : '\x1b',
    TerminalControlInputKey.tab => _tabSequence(modifiers, modifierCode),
    TerminalControlInputKey.enter => modifiers.alt ? '\x1b\r' : '\r',
    TerminalControlInputKey.backspace => _backspaceSequence(modifiers),
    TerminalControlInputKey.insert => _csiTilde('2', modifierCode),
    TerminalControlInputKey.delete => _csiTilde('3', modifierCode),
    TerminalControlInputKey.arrowUp => _csiArrow('A', modifierCode),
    TerminalControlInputKey.arrowDown => _csiArrow('B', modifierCode),
    TerminalControlInputKey.arrowRight => _csiArrow('C', modifierCode),
    TerminalControlInputKey.arrowLeft => _csiArrow('D', modifierCode),
    TerminalControlInputKey.pageUp => _csiTilde('5', modifierCode),
    TerminalControlInputKey.pageDown => _csiTilde('6', modifierCode),
    TerminalControlInputKey.home =>
      modifierCode == null ? '\x1b[H' : '\x1b[1;${modifierCode}H',
    TerminalControlInputKey.end =>
      modifierCode == null ? '\x1b[F' : '\x1b[1;${modifierCode}F',
    TerminalControlInputKey.f1 ||
    TerminalControlInputKey.f2 ||
    TerminalControlInputKey.f3 ||
    TerminalControlInputKey.f4 ||
    TerminalControlInputKey.f5 ||
    TerminalControlInputKey.f6 ||
    TerminalControlInputKey.f7 ||
    TerminalControlInputKey.f8 ||
    TerminalControlInputKey.f9 ||
    TerminalControlInputKey.f10 ||
    TerminalControlInputKey.f11 ||
    TerminalControlInputKey.f12 => _functionKeySequence(key, modifierCode),
  };
}

int? _singleAsciiRune(String text) {
  final runes = text.runes.toList(growable: false);
  if (runes.length != 1) {
    return null;
  }
  final rune = runes.single;
  if (rune > 0x7f) {
    return null;
  }
  return rune;
}

int? _controlCodeForRune(int rune) {
  final lower = rune >= 0x41 && rune <= 0x5a ? rune + 0x20 : rune;
  if (lower >= 0x61 && lower <= 0x7a) {
    return lower - 0x60;
  }
  return switch (rune) {
    0x20 || 0x40 || 0x32 => 0x00,
    0x5b || 0x33 => 0x1b,
    0x5c || 0x34 => 0x1c,
    0x5d || 0x35 => 0x1d,
    0x5e || 0x36 => 0x1e,
    0x5f || 0x37 => 0x1f,
    0x3f || 0x38 => 0x7f,
    _ => null,
  };
}

String _shiftAscii(String text) {
  final rune = text.codeUnitAt(0);
  if (rune >= 0x61 && rune <= 0x7a) {
    return String.fromCharCode(rune - 0x20);
  }
  return _shiftedAscii[text] ?? text;
}

String _csiArrow(String suffix, int? modifierCode) {
  return modifierCode == null ? '\x1b[$suffix' : '\x1b[1;$modifierCode$suffix';
}

String _csiTilde(String code, int? modifierCode) {
  return modifierCode == null ? '\x1b[$code~' : '\x1b[$code;$modifierCode~';
}

String _functionKeySequence(TerminalControlInputKey key, int? modifierCode) {
  final ss3Suffix = switch (key) {
    TerminalControlInputKey.f1 => 'P',
    TerminalControlInputKey.f2 => 'Q',
    TerminalControlInputKey.f3 => 'R',
    TerminalControlInputKey.f4 => 'S',
    _ => null,
  };
  if (ss3Suffix != null) {
    return modifierCode == null
        ? '\x1bO$ss3Suffix'
        : '\x1bO$modifierCode$ss3Suffix';
  }
  final csiCode = switch (key) {
    TerminalControlInputKey.f5 => '15',
    TerminalControlInputKey.f6 => '17',
    TerminalControlInputKey.f7 => '18',
    TerminalControlInputKey.f8 => '19',
    TerminalControlInputKey.f9 => '20',
    TerminalControlInputKey.f10 => '21',
    TerminalControlInputKey.f11 => '23',
    TerminalControlInputKey.f12 => '24',
    _ => throw ArgumentError.value(key, 'key', 'Expected a function key'),
  };
  return _csiTilde(csiCode, modifierCode);
}

String _tabSequence(TerminalModifierLatch modifiers, int? modifierCode) {
  if (modifiers.shift && !modifiers.ctrl && !modifiers.alt) {
    return '\x1b[Z';
  }
  if (modifierCode != null) {
    return '\x1b[1;${modifierCode}I';
  }
  return '\t';
}

String _backspaceSequence(TerminalModifierLatch modifiers) {
  final key = modifiers.ctrl ? '\b' : '\x7f';
  return modifiers.alt ? '\x1b$key' : key;
}

int? _modifierCode(TerminalModifierLatch modifiers) {
  if (modifiers.shift && modifiers.alt && modifiers.ctrl) {
    return 8;
  }
  if (modifiers.ctrl && modifiers.alt) {
    return 7;
  }
  if (modifiers.shift && modifiers.ctrl) {
    return 6;
  }
  if (modifiers.ctrl) {
    return 5;
  }
  if (modifiers.shift && modifiers.alt) {
    return 4;
  }
  if (modifiers.alt) {
    return 3;
  }
  if (modifiers.shift) {
    return 2;
  }
  return null;
}

const _shiftedAscii = <String, String>{
  '`': '~',
  '1': '!',
  '2': '@',
  '3': '#',
  '4': r'$',
  '5': '%',
  '6': '^',
  '7': '&',
  '8': '*',
  '9': '(',
  '0': ')',
  '-': '_',
  '=': '+',
  '[': '{',
  ']': '}',
  '\\': '|',
  ';': ':',
  "'": '"',
  ',': '<',
  '.': '>',
  '/': '?',
};
