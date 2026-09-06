import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/l10n.dart';
import 'shell_code_controller.dart';

/// The saved snippet preview uses the same colors and preserves line breaks.
class ShellCodePreview extends StatelessWidget {
  const ShellCodePreview({super.key, required this.code, this.maxLines = 3});

  final String code;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final controller = ShellCodeController(text: code.trimRight());
    final span = controller.buildTextSpan(
      context: context,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.5,
        color: context.tokens.textSecondary,
      ),
      withComposing: false,
    );
    controller.dispose();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.tokens.surfaceSunken,
        borderRadius: SerlinkRadii.control,
      ),
      child: Text.rich(
        span,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Native text selection, undo and IME input with a shell-colored code canvas.
class SnippetCodeEditor extends StatefulWidget {
  const SnippetCodeEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.onToggleExpanded,
    this.enabled = true,
  });

  final ShellCodeController controller;
  final FocusNode focusNode;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final bool enabled;

  @override
  State<SnippetCodeEditor> createState() => _SnippetCodeEditorState();
}

class _SnippetCodeEditorState extends State<SnippetCodeEditor> {
  final _scroll = ScrollController();
  final _undo = UndoHistoryController();

  @override
  void dispose() {
    _scroll.dispose();
    _undo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final style = TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: const [
        'Menlo',
        'Cascadia Mono',
        'Consolas',
        'monospace',
      ],
      fontSize: 13,
      height: 1.6,
      color: t.textPrimary,
    );
    final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.controller, widget.focusNode]),
        builder: (context, _) {
          final text = widget.controller.text;
          final caret = widget.controller.selection.extentOffset.clamp(
            0,
            text.length,
          );
          final before = text.substring(0, caret);
          final line = '\n'.allMatches(before).length + 1;
          final column = caret - before.lastIndexOf('\n');
          return DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: SerlinkRadii.dialog,
              border: Border.all(
                color: widget.focusNode.hasFocus
                    ? t.accentPrimary.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: ClipRRect(
              borderRadius: SerlinkRadii.dialog,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
                    child: Row(
                      children: [
                        Icon(Icons.code_rounded, size: 16, color: t.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          l10n.snippetCommandLabel,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shell',
                          style: TextStyle(color: t.textMuted, fontSize: 11),
                        ),
                        const Spacer(),
                        SerlinkTooltip(
                          message: widget.expanded
                              ? l10n.snippetCollapseEditorTooltip
                              : l10n.snippetExpandEditorTooltip,
                          child: SerlinkIconButton(
                            key: const ValueKey('snippet-expand-editor-button'),
                            onPressed: widget.enabled
                                ? widget.onToggleExpanded
                                : null,
                            icon: Icon(
                              widget.expanded
                                  ? Icons.close_fullscreen_rounded
                                  : Icons.open_in_full_rounded,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 12, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final gutterWidth =
                              22.0 +
                              (text.split('\n').length.toString().length * 9);
                          final span = widget.controller.buildTextSpan(
                            context: context,
                            style: style,
                            withComposing: true,
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ExcludeSemantics(
                                child: SizedBox(
                                  width: gutterWidth,
                                  child: CustomPaint(
                                    painter: _LineNumberPainter(
                                      span: span,
                                      text: text,
                                      textWidth:
                                          (constraints.maxWidth - gutterWidth)
                                              .clamp(1, double.infinity),
                                      style: style,
                                      strut: strut,
                                      scaler: MediaQuery.textScalerOf(context),
                                      scroll: _scroll,
                                      activeLine: line,
                                      color: t.textMuted,
                                      activeColor: t.accentPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: CallbackShortcuts(
                                  bindings: {
                                    const SingleActivator(
                                      LogicalKeyboardKey.tab,
                                    ): () {
                                      if (widget.enabled) {
                                        widget.controller.indent();
                                      }
                                    },
                                    const SingleActivator(
                                      LogicalKeyboardKey.tab,
                                      shift: true,
                                    ): () {
                                      if (widget.enabled) {
                                        widget.controller.indent(outdent: true);
                                      }
                                    },
                                    const SingleActivator(
                                      LogicalKeyboardKey.escape,
                                    ): () =>
                                        widget.focusNode.nextFocus(),
                                  },
                                  child: Scrollbar(
                                    controller: _scroll,
                                    child: TextField(
                                      key: const ValueKey(
                                        'snippet-command-field',
                                      ),
                                      controller: widget.controller,
                                      focusNode: widget.focusNode,
                                      undoController: _undo,
                                      scrollController: _scroll,
                                      readOnly: !widget.enabled,
                                      expands: true,
                                      minLines: null,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      inputFormatters: const [
                                        ShellIndentFormatter(),
                                      ],
                                      style: style,
                                      strutStyle: strut,
                                      decoration:
                                          InputDecoration.collapsed(
                                            hintText:
                                                l10n.snippetCommandPlaceholder,
                                            hintStyle: style.copyWith(
                                              color: t.textMuted,
                                            ),
                                          ).copyWith(
                                            filled: false,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.snippetEditorKeysHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: t.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.snippetCursorPosition(line, column),
                          style: TextStyle(fontSize: 10, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Position logical line numbers using the same text layout as the field.
/// Wrapped continuation lines remain unnumbered; both scroll together.
class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.span,
    required this.text,
    required this.textWidth,
    required this.style,
    required this.strut,
    required this.scaler,
    required this.scroll,
    required this.activeLine,
    required this.color,
    required this.activeColor,
  }) : super(repaint: scroll);

  final TextSpan span;
  final String text;
  final double textWidth;
  final TextStyle style;
  final StrutStyle strut;
  final TextScaler scaler;
  final ScrollController scroll;
  final int activeLine;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      strutStyle: strut,
    )..layout(maxWidth: textWidth);
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var start = 0;
    var number = 1;
    while (start <= text.length) {
      final y =
          layout.getOffsetForCaret(TextPosition(offset: start), Rect.zero).dy -
          offset;
      if (y > size.height) break;
      if (y + layout.preferredLineHeight >= 0) {
        final label = TextPainter(
          text: TextSpan(
            text: '$number',
            style: style.copyWith(
              color: number == activeLine ? activeColor : color,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          strutStyle: strut,
        )..layout();
        label.paint(canvas, Offset(size.width - label.width - 12, y));
        label.dispose();
      }
      final next = text.indexOf('\n', start);
      if (next == -1) break;
      start = next + 1;
      number++;
    }
    canvas.restore();
    layout.dispose();
  }

  @override
  bool shouldRepaint(_LineNumberPainter old) =>
      span != old.span ||
      textWidth != old.textWidth ||
      scaler != old.scaler ||
      activeLine != old.activeLine ||
      color != old.color ||
      activeColor != old.activeColor;
}
