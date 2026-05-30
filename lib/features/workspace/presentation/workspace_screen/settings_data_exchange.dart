part of '../workspace_screen.dart';

Future<void> _showDataExchangeDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool canImportHostData,
}) {
  return showDialog<void>(
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
    final scheme = Theme.of(context).colorScheme;
    final lockedSubtitle = 'Unlock the vault to use this action.';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
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
                        'Import / Export',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('data-exchange-close-button'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Backups stay available anytime. Host, identity, and SSH data require an unlocked vault.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _DataExchangeSection(
                  title: 'Export',
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.lock_outline,
                      title: 'Export encrypted backup',
                      subtitle: 'Encrypted vault records and header.',
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.dns_outlined,
                      title: 'Export host metadata',
                      subtitle: 'Host names, addresses, tags, and options.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportHostMetadata,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: 'Export OpenSSH config',
                      subtitle: 'Selected hosts as an OpenSSH config.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.badge_outlined,
                      title: 'Export identity metadata',
                      subtitle:
                          'Display names, hints, and public fingerprints.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportIdentityMetadata,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DataExchangeSection(
                  title: 'Import',
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.restore_outlined,
                      title: 'Import encrypted backup',
                      subtitle: 'Merge records from a Serlink backup.',
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: 'Import OpenSSH config',
                      subtitle: 'Create hosts from an ssh config file.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.verified_outlined,
                      title: 'Import known_hosts',
                      subtitle: 'Add fingerprints for existing hosts.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importKnownHosts,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.key_outlined,
                      title: 'Import OpenSSH certificate',
                      subtitle: 'Create an identity from key and certificate.',
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

class _DataExchangeSection extends StatelessWidget {
  const _DataExchangeSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DataExchangeActionTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveSubtitle = enabled ? subtitle : disabledSubtitle ?? subtitle;

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: Center(
                  child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectiveSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
