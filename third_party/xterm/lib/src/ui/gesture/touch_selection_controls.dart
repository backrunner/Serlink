part of 'gesture_handler.dart';

class _TerminalTouchSelectionControls extends StatefulWidget {
  const _TerminalTouchSelectionControls({
    super.key,
    required this.buffer,
    required this.terminal,
    required this.scrollController,
    required this.view,
    required this.controller,
    required this.onDismiss,
  });

  final Buffer buffer;
  final Terminal terminal;
  final ScrollController scrollController;
  final TerminalViewState view;
  final TerminalController controller;
  final VoidCallback onDismiss;

  @override
  State<_TerminalTouchSelectionControls> createState() =>
      _TerminalTouchSelectionControlsState();
}

class _TerminalTouchSelectionControlsState
    extends State<_TerminalTouchSelectionControls> {
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_onOutput);
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_onOutput);
    super.dispose();
  }

  void _onOutput() {
    if (widget.terminal.buffer != widget.buffer ||
        widget.controller.selection == null) {
      widget.onDismiss();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([widget.controller, widget.scrollController]),
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final range = widget.controller.selection?.normalized;
          if (widget.terminal.buffer != widget.buffer ||
              range == null ||
              range.isCollapsed) {
            return const SizedBox.shrink();
          }
          final render = widget.view.renderTerminal;
          final start = render.getOffset(range.begin);
          final end = render.getOffset(range.end);
          final lineHeight = render.lineHeight;
          final height = constraints.maxHeight;
          if (end.dy + lineHeight <= 0 || start.dy >= height) {
            return const SizedBox.shrink();
          }
          final midX = (start.dx + end.dx) / 2;
          return Stack(children: [
            _handle(start, startHandle: true),
            _handle(end, startHandle: false),
            if (_dragOffset == null)
              CupertinoAdaptiveTextSelectionToolbar.buttonItems(
                anchors: TextSelectionToolbarAnchors(
                  primaryAnchor: Offset(midX, start.dy.clamp(0, height) - 8),
                  secondaryAnchor:
                      Offset(midX, (end.dy + lineHeight).clamp(0, height) + 8),
                ),
                buttonItems: [
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: () {
                      if (widget.terminal.buffer == widget.buffer &&
                          widget.controller.selection != null) {
                        Actions.invoke(context, CopySelectionTextIntent.copy);
                        widget.controller.clearSelection();
                      }
                      widget.onDismiss();
                    },
                  ),
                ],
              ),
          ]);
        });
      },
    );
  }

  Widget _handle(Offset cell, {required bool startHandle}) {
    final render = widget.view.renderTerminal;
    final lineHeight = render.lineHeight;
    final type = startHandle
        ? TextSelectionHandleType.left
        : TextSelectionHandleType.right;
    final controls = cupertinoTextSelectionControls;
    final origin = cell +
        Offset(0, lineHeight) -
        controls.getHandleAnchor(type, lineHeight);
    // Keep the grip easy to hit even when the selected word is short.
    const hitPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    return Positioned(
      key: ValueKey(type),
      left: origin.dx - hitPadding.left,
      top: origin.dy - hitPadding.top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (details) {
          final center = cell + Offset(0, lineHeight / 2);
          setState(() => _dragOffset =
              center - render.globalToLocal(details.globalPosition));
        },
        onPanUpdate: (details) {
          final range = widget.controller.selection?.normalized;
          if (range == null || _dragOffset == null) return;
          final point =
              render.globalToLocal(details.globalPosition) + _dragOffset!;
          final target = render.getCellOffset(point);
          final x = (point.dx / render.cellSize.width)
              .round()
              .clamp(0, widget.terminal.viewWidth);
          final line = widget.buffer.lines[target.y];
          final boundary = CellOffset(
            line.isWideContinuation(x) ? (startHandle ? x - 1 : x + 1) : x,
            target.y,
          );
          final begin = startHandle ? boundary : range.begin;
          final end = startHandle ? range.end : boundary;
          if (begin.isBefore(end)) {
            widget.controller.setSelection(
              widget.buffer.createAnchorFromOffset(begin),
              widget.buffer.createAnchorFromOffset(end),
            );
          }
        },
        onPanEnd: (_) => setState(() => _dragOffset = null),
        onPanCancel: () => setState(() => _dragOffset = null),
        child: Padding(
          padding: hitPadding,
          child: controls.buildHandle(context, type, lineHeight),
        ),
      ),
    );
  }
}
