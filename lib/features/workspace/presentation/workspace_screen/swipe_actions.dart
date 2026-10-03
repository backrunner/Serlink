part of '../workspace_screen.dart';

class _SwipeRowAction {
  const _SwipeRowAction({
    required this.keyPrefix,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String keyPrefix;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;
}

class _SwipeActionsRow extends StatefulWidget {
  const _SwipeActionsRow({required this.child, required this.actions});

  final Widget child;
  final List<_SwipeRowAction> actions;

  @override
  State<_SwipeActionsRow> createState() => _SwipeActionsRowState();
}

class _SwipeActionsRowState extends State<_SwipeActionsRow> {
  double _dragOffset = 0;

  double get _revealWidth =>
      (_SwipeActionButton.side + SerlinkSpacing.sm) * widget.actions.length;

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = (_dragOffset + details.delta.dx).clamp(-_revealWidth, 0.0);
    if (next != _dragOffset) setState(() => _dragOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final open =
        velocity < -220 ||
        (_dragOffset < -_revealWidth * 0.45 && velocity < 220);
    setState(() => _dragOffset = open ? -_revealWidth : 0);
  }

  void _close() => setState(() => _dragOffset = 0);

  @override
  Widget build(BuildContext context) {
    final revealed = _dragOffset < 0;
    return ClipRRect(
      borderRadius: SerlinkRadii.dialog,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _close,
        child: Stack(
          children: [
            if (revealed)
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (
                      var index = 0;
                      index < widget.actions.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: SerlinkSpacing.sm),
                      _SwipeActionButton(
                        buttonKey: ValueKey(
                          '${widget.actions[index].keyPrefix}-button',
                        ),
                        iconKey: ValueKey(
                          '${widget.actions[index].keyPrefix}-icon',
                        ),
                        icon: widget.actions[index].icon,
                        semanticsLabel: widget.actions[index].label,
                        danger: widget.actions[index].danger,
                        onPressed: () {
                          _close();
                          widget.actions[index].onPressed();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: revealed ? _close : null,
                // A tap on an exposed row closes its actions before allowing
                // another tap to open a file or start a host session.
                child: AbsorbPointer(absorbing: revealed, child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.buttonKey,
    required this.onPressed,
    required this.icon,
    required this.iconKey,
    required this.semanticsLabel,
    this.danger = false,
  });

  static const double side = 44;

  final Key buttonKey;
  final VoidCallback onPressed;
  final IconData icon;
  final Key iconKey;
  final String semanticsLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final background = danger ? t.statusDangerFill : t.surfaceRaised;
    final foreground = danger ? t.onAccent : t.textPrimary;
    final borderColor = danger
        ? t.statusDanger.withValues(alpha: 0.7)
        : t.borderStrong;
    return Align(
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: SerlinkRadii.dialog,
            border: Border.all(color: borderColor),
            boxShadow: serlinkShadow(t, elevation: 6, opacity: 0.45),
          ),
          child: SerlinkPressable(
            key: buttonKey,
            onTap: onPressed,
            borderRadius: SerlinkRadii.dialog,
            hoverColor: danger
                ? Colors.white.withValues(alpha: 0.08)
                : t.accentPrimary.withValues(alpha: 0.08),
            pressedColor: danger
                ? Colors.black.withValues(alpha: 0.14)
                : t.accentPrimary.withValues(alpha: 0.14),
            child: SizedBox.square(
              dimension: side,
              child: Icon(icon, key: iconKey, size: 20, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
