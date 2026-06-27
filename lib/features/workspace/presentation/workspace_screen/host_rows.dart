part of '../workspace_screen.dart';

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.mobile,
    required this.host,
    required this.onTerminal,
    required this.onSftp,
    required this.onEdit,
    required this.onDelete,
  });

  final bool mobile;
  final HostSummary host;
  final VoidCallback onTerminal;
  final VoidCallback onSftp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final subtitle = '${host.username}@${host.hostname}:${host.port}';
    final trustState = _visibleTrustState(host.trustState);
    final row = ListRow(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 18, color: t.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 2,
                  child: Text(
                    host.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 3,
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (host.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  for (final tag in host.tags.take(2)) ...[
                    SerlinkTag(label: tag),
                    const SizedBox(width: 6),
                  ],
                  if (host.tags.length > 2)
                    SerlinkTag(label: '+${host.tags.length - 2}'),
                ],
              ],
            ),
          ),
          if (trustState != null) ...[
            const SizedBox(width: 12),
            _TrustText(state: trustState),
          ],
          const SizedBox(width: 12),
          _HostActionButton(
            key: mobile ? const ValueKey('mobile-host-terminal-button') : null,
            onPressed: onTerminal,
            icon: Icons.terminal,
            iconKey: mobile
                ? const ValueKey('mobile-host-terminal-icon')
                : null,
            label: l10n.hostTerminalAction,
            primary: true,
            iconOnly: mobile,
          ),
          const SizedBox(width: 10),
          _HostActionButton(
            key: mobile ? const ValueKey('mobile-host-sftp-button') : null,
            onPressed: onSftp,
            icon: Icons.folder_open,
            iconKey: mobile ? const ValueKey('mobile-host-sftp-icon') : null,
            label: l10n.hostSftpAction,
            iconOnly: mobile,
          ),
        ],
      ),
    );
    if (mobile) {
      return _SwipeHostActionsRow(
        onEdit: onEdit,
        onDelete: onDelete,
        child: row,
      );
    }

    return SerlinkContextMenu(
      actions: [
        SerlinkMenuAction(
          label: l10n.hostEditMenu,
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        SerlinkMenuAction(
          label: l10n.hostDeleteMenu,
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
      ],
      child: row,
    );
  }
}

class _SwipeHostActionsRow extends StatefulWidget {
  const _SwipeHostActionsRow({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  static const double _actionGap = SerlinkSpacing.sm;
  static const double revealWidth = _SwipeHostAction.side * 2 + _actionGap * 2;

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SwipeHostActionsRow> createState() => _SwipeHostActionsRowState();
}

class _SwipeHostActionsRowState extends State<_SwipeHostActionsRow> {
  double _dragOffset = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = (_dragOffset + details.delta.dx).clamp(
      -_SwipeHostActionsRow.revealWidth,
      0.0,
    );
    if (next == _dragOffset) {
      return;
    }
    setState(() => _dragOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final open =
        velocity < -220 ||
        (_dragOffset < -_SwipeHostActionsRow.revealWidth * 0.45 &&
            velocity < 220);
    setState(() => _dragOffset = open ? -_SwipeHostActionsRow.revealWidth : 0);
  }

  void _handleEdit() {
    setState(() => _dragOffset = 0);
    widget.onEdit();
  }

  void _handleDelete() {
    setState(() => _dragOffset = 0);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: SerlinkRadii.dialog,
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SwipeHostAction(
                      buttonKey: const ValueKey('mobile-host-edit-button'),
                      onPressed: _handleEdit,
                      icon: Icons.edit_outlined,
                      iconKey: const ValueKey('mobile-host-edit-icon'),
                      semanticsLabel: context.l10n.hostEditMenu,
                    ),
                    const SizedBox(width: _SwipeHostActionsRow._actionGap),
                    _SwipeHostAction(
                      buttonKey: const ValueKey('mobile-host-delete-button'),
                      onPressed: _handleDelete,
                      icon: Icons.delete_outline,
                      iconKey: const ValueKey('mobile-host-delete-icon'),
                      semanticsLabel: context.l10n.hostsDeleteAction,
                      danger: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeHostAction extends StatelessWidget {
  const _SwipeHostAction({
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
    final background = danger ? t.statusDanger : t.surfaceRaised;
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

HostTrustState? _visibleTrustState(HostTrustState state) {
  return switch (state) {
    HostTrustState.unknown => null,
    HostTrustState.trusted || HostTrustState.changed => state,
  };
}

class _HostActionButton extends StatelessWidget {
  const _HostActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.iconKey,
    this.primary = false,
    this.iconOnly = false,
  });

  static const double height = 34;

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Key? iconKey;
  final bool primary;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final foreground = primary ? t.onAccent : t.textPrimary;
    final iconWidget = Icon(icon, key: iconKey, size: 16, color: foreground);
    final content = iconOnly
        ? Center(child: iconWidget)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: primary ? serlinkAccentGradient(t) : null,
        color: primary ? null : t.surfaceRaised,
        borderRadius: SerlinkRadii.control,
        border: Border.all(
          color: primary
              ? t.accentPrimary.withValues(alpha: 0.5)
              : t.borderStrong,
        ),
      ),
      child: SerlinkPressable(
        onTap: onPressed,
        borderRadius: SerlinkRadii.control,
        hoverColor: primary
            ? Colors.white.withValues(alpha: 0.08)
            : t.accentPrimary.withValues(alpha: 0.08),
        pressedColor: primary
            ? Colors.black.withValues(alpha: 0.1)
            : t.accentPrimary.withValues(alpha: 0.14),
        child: SizedBox(
          width: iconOnly ? height : null,
          height: height,
          child: content,
        ),
      ),
    );
    if (!iconOnly) {
      return button;
    }
    return SerlinkTooltip(message: label, child: button);
  }
}

class _TrustText extends StatelessWidget {
  const _TrustText({required this.state});

  final HostTrustState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (state) {
      HostTrustState.trusted => t.statusSuccess,
      HostTrustState.unknown => t.statusWarning,
      HostTrustState.changed => t.statusDanger,
    };
    final label = switch (state) {
      HostTrustState.trusted => context.l10n.hostTrustTrusted,
      HostTrustState.unknown => context.l10n.hostTrustVerify,
      HostTrustState.changed => context.l10n.hostTrustChanged,
    };
    return StatusPill(label: label, color: color);
  }
}
