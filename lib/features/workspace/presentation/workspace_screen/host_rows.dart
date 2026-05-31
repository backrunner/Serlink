part of '../workspace_screen.dart';

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.host,
    required this.onTerminal,
    required this.onSftp,
    required this.onEdit,
    required this.onDelete,
  });

  final HostSummary host;
  final VoidCallback onTerminal;
  final VoidCallback onSftp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subtitle = '${host.username}@${host.hostname}:${host.port}';
    final trustState = _visibleTrustState(host.trustState);

    return SerlinkContextMenu(
      actions: [
        SerlinkMenuAction(
          label: 'Edit host',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        SerlinkMenuAction(
          label: 'Delete host',
          icon: Icons.delete_outline,
          onPressed: onDelete,
        ),
      ],
      child: ListRow(
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
              onPressed: onTerminal,
              icon: Icons.terminal,
              label: 'Terminal',
              primary: true,
            ),
            const SizedBox(width: 10),
            _HostActionButton(
              onPressed: onSftp,
              icon: Icons.folder_open,
              label: 'SFTP',
            ),
          ],
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
    required this.onPressed,
    required this.icon,
    required this.label,
    this.primary = false,
  });

  static const double height = 34;

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final foreground = primary ? t.onAccent : t.textPrimary;
    return DecoratedBox(
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
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
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
          ),
        ),
      ),
    );
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
      HostTrustState.trusted => 'trusted',
      HostTrustState.unknown => 'verify',
      HostTrustState.changed => 'changed',
    };
    return StatusPill(label: label, color: color);
  }
}
