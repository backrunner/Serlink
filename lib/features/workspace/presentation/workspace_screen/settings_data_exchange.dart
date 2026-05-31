part of '../workspace_screen.dart';

Future<void> _showDataExchangeDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool canImportHostData,
}) {
  return showSerlinkDialog<void>(
    context: context,
    builder: (dialogContext) {
      Future<void> runAction(_DataExchangeAction action) async {
        Navigator.of(dialogContext).pop();
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) {
          return;
        }
        switch (action) {
          case _DataExchangeAction.exportVaultBackup:
            await _exportVaultBackup(context, ref);
          case _DataExchangeAction.exportHostMetadata:
            await _exportHostMetadata(context, ref);
          case _DataExchangeAction.exportOpenSshConfig:
            await _exportOpenSshConfig(context, ref);
          case _DataExchangeAction.exportIdentityMetadata:
            await _exportIdentityMetadata(context, ref);
          case _DataExchangeAction.importVaultBackup:
            await _importVaultBackup(context, ref);
          case _DataExchangeAction.importOpenSshConfig:
            await _importOpenSshConfig(context, ref);
          case _DataExchangeAction.importKnownHosts:
            await _importKnownHosts(context, ref);
          case _DataExchangeAction.importOpenSshCertificate:
            await _importOpenSshCertificate(context, ref);
        }
      }

      return _DataExchangeDialog(
        canImportHostData: canImportHostData,
        onActionSelected: (action) => unawaited(runAction(action)),
      );
    },
  );
}

enum _DataExchangeAction {
  exportVaultBackup,
  exportHostMetadata,
  exportOpenSshConfig,
  exportIdentityMetadata,
  importVaultBackup,
  importOpenSshConfig,
  importKnownHosts,
  importOpenSshCertificate,
}

class _DataExchangeDialog extends StatelessWidget {
  const _DataExchangeDialog({
    required this.canImportHostData,
    required this.onActionSelected,
  });

  final bool canImportHostData;
  final ValueChanged<_DataExchangeAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final lockedSubtitle = l10n.dataExchangeLockedSubtitle;

    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthDataExchange),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _adaptiveDialogWidth(context, _dialogWidthDataExchange),
          maxHeight: 720,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.dataExchangeTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    SerlinkIconButton(
                      key: const ValueKey('data-exchange-close-button'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.dataExchangeSubtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: 20),
                SurfaceSection(
                  title: l10n.dataExchangeExportSection,
                  dividerIndent: 52,
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.lock_outline,
                      title: l10n.dataExchangeExportBackupTitle,
                      subtitle: l10n.dataExchangeExportBackupSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.dns_outlined,
                      title: l10n.dataExchangeExportHostMetadataTitle,
                      subtitle: l10n.dataExchangeExportHostMetadataSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportHostMetadata,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: l10n.dataExchangeExportOpenSshConfigTitle,
                      subtitle: l10n.dataExchangeExportOpenSshConfigSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.badge_outlined,
                      title: l10n.dataExchangeExportIdentityMetadataTitle,
                      subtitle: l10n.dataExchangeExportIdentityMetadataSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportIdentityMetadata,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SurfaceSection(
                  title: l10n.dataExchangeImportSection,
                  dividerIndent: 52,
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.restore_outlined,
                      title: l10n.dataExchangeImportBackupTitle,
                      subtitle: l10n.dataExchangeImportBackupSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: l10n.dataExchangeImportOpenSshConfigTitle,
                      subtitle: l10n.dataExchangeImportOpenSshConfigSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.verified_outlined,
                      title: l10n.dataExchangeImportKnownHostsTitle,
                      subtitle: l10n.dataExchangeImportKnownHostsSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importKnownHosts,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.key_outlined,
                      title: l10n.dataExchangeImportOpenSshCertificateTitle,
                      subtitle:
                          l10n.dataExchangeImportOpenSshCertificateSubtitle,
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importOpenSshCertificate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataExchangeActionTile extends StatefulWidget {
  const _DataExchangeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.enabled = true,
    this.disabledSubtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool enabled;
  final String? disabledSubtitle;

  @override
  State<_DataExchangeActionTile> createState() =>
      _DataExchangeActionTileState();
}

class _DataExchangeActionTileState extends State<_DataExchangeActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final effectiveSubtitle = widget.enabled
        ? widget.subtitle
        : widget.disabledSubtitle ?? widget.subtitle;
    final interactive = widget.enabled;
    final foregroundOpacity = interactive ? 1.0 : 0.48;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: interactive && _hovered
                ? t.accentPrimary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: SerlinkRadii.control,
          ),
          child: Opacity(
            opacity: foregroundOpacity,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Icon(widget.icon, size: 20, color: t.textSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        effectiveSubtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right, size: 20, color: t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
