import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';

/// Shell coloring is lexical, so incomplete commands remain editable.
final _tokens = RegExp(
  r'(?<comment>(?<![^\s;|&()])#[^\n]*)'
  r"|(?<sq>'[^']*'?)"
  r'|(?<dq>"(?:\\[\s\S]|[^"\\])*"?)'
  r'|(?<escape>\\[\s\S])'
  r'|(?<var>\$\{[^}\n]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*#!?$-])'
  r'|(?<flag>(?<!\S)--?[A-Za-z][A-Za-z0-9-]*)'
  r'|(?<operator>&&|\|\||[|;&<>()])'
  r'|(?<num>\b\d+\b)'
  r'|(?<word>\b[A-Za-z_][A-Za-z0-9_]*\b)',
  multiLine: true,
);

const _keywords = {
  'if',
  'then',
  'else',
  'elif',
  'fi',
  'for',
  'while',
  'until',
  'do',
  'done',
  'case',
  'esac',
  'function',
  'in',
  'select',
  'time',
  'coproc',
  'echo',
  'printf',
  'cd',
  'export',
  'local',
  'readonly',
  'declare',
  'typeset',
  'source',
  'set',
  'unset',
  'shift',
  'exit',
  'return',
  'exec',
  'eval',
  'trap',
  'read',
  'test',
  'true',
  'false',
  'sudo',
  'alias',
  'unalias',
  'wait',
  'break',
  'continue',
  'command',
  'builtin',
  'getopts',
  'kill',
  'pushd',
  'popd',
  'dirs',
};

class ShellCodeController extends TextEditingController {
  ShellCodeController({super.text});

  String? _cachedText;
  List<RegExpMatch> _matches = [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_cachedText != text) {
      _cachedText = text;
      _matches = _tokens.allMatches(text).toList();
    }
    final t = context.tokens;
    final spans = <TextSpan>[];
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    void append(int start, int end, Color? color) {
      if (start == end) return;
      final cuts = <int>{
        start,
        end,
        if (composing.start > start && composing.start < end) composing.start,
        if (composing.end > start && composing.end < end) composing.end,
      }.toList()..sort();
      for (var i = 0; i < cuts.length - 1; i++) {
        final from = cuts[i];
        final to = cuts[i + 1];
        spans.add(
          TextSpan(
            text: text.substring(from, to),
            style: TextStyle(
              color: color,
              decoration:
                  composing.isValid &&
                      from >= composing.start &&
                      to <= composing.end
                  ? TextDecoration.underline
                  : null,
            ),
          ),
        );
      }
    }

    var offset = 0;
    for (final match in _matches) {
      append(offset, match.start, null);
      final Color? color;
      if (match.namedGroup('comment') != null) {
        color = t.textMuted;
      } else if (match.namedGroup('sq') != null ||
          match.namedGroup('dq') != null) {
        color = t.statusSuccess;
      } else if (match.namedGroup('var') != null) {
        color = t.statusInfo;
      } else if (match.namedGroup('flag') != null) {
        color = t.accentSecondary;
      } else if (match.namedGroup('num') != null) {
        color = t.statusWarning;
      } else if (match.namedGroup('operator') != null ||
          _keywords.contains(match.namedGroup('word'))) {
        color = t.accentPrimary;
      } else {
        color = null;
      }
      append(match.start, match.end, color);
      offset = match.end;
    }
    append(offset, text.length, null);
    return TextSpan(style: style, children: spans);
  }

  /// Two-space indentation, including multi-line and reversed selections.
  void indent({bool outdent = false}) {
    final current = value;
    final selection = current.selection;
    if (!selection.isValid || !current.composing.isCollapsed) return;
    if (selection.isCollapsed && !outdent) {
      final lineStart = selection.start == 0
          ? 0
          : text.lastIndexOf('\n', selection.start - 1) + 1;
      final spaces = 2 - (selection.start - lineStart) % 2;
      final insert = ' ' * spaces;
      value = current.copyWith(
        text: text.replaceRange(selection.start, selection.end, insert),
        selection: TextSelection.collapsed(offset: selection.start + spaces),
        composing: TextRange.empty,
      );
      return;
    }
    final start = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    // A selection ending at the next line's start excludes that next line.
    final end =
        !selection.isCollapsed &&
            selection.end > 0 &&
            text[selection.end - 1] == '\n'
        ? selection.end - 1
        : selection.end;
    final edits = <(int, int, String)>[];
    for (var pos = start; pos <= end;) {
      var remove = 0;
      if (outdent) {
        if (pos < text.length && text[pos] == '\t') {
          remove = 1;
        } else {
          while (remove < 2 &&
              pos + remove < text.length &&
              text[pos + remove] == ' ') {
            remove++;
          }
        }
      }
      edits.add((pos, remove, outdent ? '' : '  '));
      final newline = text.indexOf('\n', pos);
      if (newline == -1) break;
      pos = newline + 1;
    }
    var updated = text;
    for (final (pos, count, insert) in edits.reversed) {
      updated = updated.replaceRange(pos, pos + count, insert);
    }
    int adjust(int original) {
      var result = original;
      for (final (pos, count, insert) in edits) {
        if (original >= pos) {
          result += insert.length - (original - pos).clamp(0, count);
        }
      }
      return result;
    }

    value = current.copyWith(
      text: updated,
      selection: TextSelection(
        baseOffset: adjust(selection.baseOffset),
        extentOffset: adjust(selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }
}

/// Preserve the current indentation only for a typed newline, never for paste
/// or an active IME composition.
class ShellIndentFormatter extends TextInputFormatter {
  const ShellIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!oldValue.selection.isValid ||
        !oldValue.composing.isCollapsed ||
        !newValue.composing.isCollapsed) {
      return newValue;
    }
    final start = oldValue.selection.start;
    final end = oldValue.selection.end;
    if (newValue.text != oldValue.text.replaceRange(start, end, '\n') ||
        newValue.selection.extentOffset != start + 1) {
      return newValue;
    }
    final lineStart = start == 0
        ? 0
        : oldValue.text.lastIndexOf('\n', start - 1) + 1;
    final prefix = oldValue.text.substring(lineStart, start);
    final indent = RegExp(r'^[ \t]*').stringMatch(prefix)!;
    if (indent.isEmpty) return newValue;
    return newValue.copyWith(
      text: newValue.text.replaceRange(start + 1, start + 1, indent),
      selection: TextSelection.collapsed(offset: start + 1 + indent.length),
    );
  }
}
