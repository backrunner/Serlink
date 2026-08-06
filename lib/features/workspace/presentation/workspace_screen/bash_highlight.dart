part of '../workspace_screen.dart';

/// Lightweight bash syntax highlighting for the snippet command editor. The
/// tokenizer is a single regex pass per build: quoted strings are consumed as
/// whole tokens, so `#` or `$` inside quotes is never recolored by mistake.
final RegExp _bashTokenPattern = RegExp(
  r'(?<comment>(?:^|\s)#.*$)'
  r"|(?<sq>'[^']*')"
  r'|(?<dq>"[^"]*")'
  r'|(?<var>\$\{[^}\n]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@*#!?$-])'
  r'|(?<flag>(?:^|\s)--?[A-Za-z][A-Za-z0-9-]*)'
  r'|(?<num>\b\d+\b)'
  r'|(?<word>\b[A-Za-z_][A-Za-z0-9_]*\b)',
  multiLine: true,
);

const Set<String> _bashKeywords = {
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
  'history',
  'mapfile',
  'readarray',
  'let',
  'umask',
  'ulimit',
};

List<TextSpan> _bashHighlightSpans(
  String text,
  SerlinkTokens t,
  TextStyle? base,
) {
  final commentStyle = base?.copyWith(
    color: t.textMuted,
    fontStyle: FontStyle.italic,
  );
  final stringStyle = base?.copyWith(color: t.statusSuccess);
  final variableStyle = base?.copyWith(color: t.statusInfo);
  final flagStyle = base?.copyWith(color: t.accentSecondary);
  final numberStyle = base?.copyWith(color: t.statusWarning);
  final keywordStyle = base?.copyWith(
    color: t.accentPrimary,
    fontWeight: FontWeight.w600,
  );

  TextStyle? styleFor(RegExpMatch match) {
    if (match.namedGroup('comment') != null) {
      return commentStyle;
    }
    if (match.namedGroup('sq') != null || match.namedGroup('dq') != null) {
      return stringStyle;
    }
    if (match.namedGroup('var') != null) {
      return variableStyle;
    }
    if (match.namedGroup('flag') != null) {
      return flagStyle;
    }
    if (match.namedGroup('num') != null) {
      return numberStyle;
    }
    if (_bashKeywords.contains(match.namedGroup('word'))) {
      return keywordStyle;
    }
    return null;
  }

  final spans = <TextSpan>[];
  var offset = 0;
  for (final match in _bashTokenPattern.allMatches(text)) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    spans.add(TextSpan(text: match.group(0)!, style: styleFor(match)));
    offset = match.end;
  }
  if (offset < text.length) {
    spans.add(TextSpan(text: text.substring(offset)));
  }
  return spans;
}

/// Text controller that paints bash syntax colors while typing. Colors follow
/// the active theme via [BuildContext], so no manual theme wiring is needed.
class _BashHighlightController extends TextEditingController {
  _BashHighlightController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    return TextSpan(
      style: style,
      children: _bashHighlightSpans(text, context.tokens, style),
    );
  }
}
