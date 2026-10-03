part of '../workspace_screen.dart';

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.mobile,
    required this.host,
    required this.onTerminal,
    required this.onSftp,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool mobile;
  final HostSummary host;
  final VoidCallback onTerminal;
  final VoidCallback onSftp;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final subtitle = '${host.username}@${host.hostname}:${host.port}';
    final row = ListRow(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 18, color: t.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    mobile ||
                    constraints.maxWidth < 420 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                final title = Text(
                  host.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                );
                final address = Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: t.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
                final hasMetadata =
                    host.tags.isNotEmpty ||
                    host.trustState == HostTrustState.changed;
                final tags = host.tags.toList()..sort();
                final metadata = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (host.trustState == HostTrustState.changed) ...[
                      Text(
                        l10n.hostTrustChanged,
                        style: TextStyle(
                          color: t.statusDanger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tags.isNotEmpty) const SizedBox(height: 3),
                    ],
                    if (tags.isNotEmpty)
                      SerlinkTooltip(
                        message: tags.join(' · '),
                        child: Text(
                          tags.join(' · '),
                          key: ValueKey('host-tags-${host.id.value}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.textMuted, fontSize: 12),
                        ),
                      ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      title,
                      const SizedBox(height: SerlinkSpacing.xs),
                      address,
                      if (hasMetadata) ...[
                        const SizedBox(height: SerlinkSpacing.sm),
                        metadata,
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Flexible(flex: 2, child: title),
                    const SizedBox(width: 10),
                    Flexible(flex: 3, child: address),
                    if (hasMetadata) ...[
                      const SizedBox(width: SerlinkSpacing.sm),
                      Flexible(flex: 2, child: metadata),
                    ],
                  ],
                );
              },
            ),
          ),
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
      return _SwipeActionsRow(
        actions: [
          _SwipeRowAction(
            keyPrefix: 'mobile-host-edit',
            label: l10n.hostEditMenu,
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          _SwipeRowAction(
            keyPrefix: 'mobile-host-delete',
            label: l10n.hostsDeleteAction,
            icon: Icons.delete_outline,
            onPressed: onDelete,
            danger: true,
          ),
        ],
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
          label: l10n.hostDuplicateMenu,
          icon: Icons.copy_rounded,
          onPressed: onDuplicate,
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
    final controlHeight =
        iconOnly && Theme.of(context).platform == TargetPlatform.iOS
        ? 44.0
        : height;
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
        color: primary ? t.accentStrong : t.surfaceSunken,
        borderRadius: SerlinkRadii.control,
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
          width: iconOnly ? controlHeight : null,
          height: controlHeight,
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
