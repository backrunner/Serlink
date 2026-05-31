part of '../workspace_screen.dart';

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceSection(title: title, children: children);
  }
}

class _SettingsStatusPill extends StatelessWidget {
  const _SettingsStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: label, color: color);
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _SettingsActionRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: null,
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.action,
    this.subtitle,
    this.subtitleWidget,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SerlinkListTile(
        minLeadingWidth: 28,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        subtitleGap: 1,
        leading: SizedBox.square(
          dimension: 32,
          child: Icon(icon, size: 19, color: t.textSecondary),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: t.textPrimary,
          ),
        ),
        subtitle:
            subtitleWidget ??
            (subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Text(subtitle!, style: subtitleStyle)),
        trailing: action == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 16), child: action),
      ),
    );
  }
}

String _vaultStatusPillLabel(VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => 'Vault not created',
    VaultState.locked => 'Vault locked',
    VaultState.unlocked => 'Vault unlocked',
    null => 'Vault loading',
  };
}

String _vaultStateLabel(VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => 'Not created.',
    VaultState.locked => 'Locked. Existing connections keep running.',
    VaultState.unlocked => 'Unlocked for new connection profile resolution.',
    null => 'Preparing encrypted storage',
  };
}

String _localUnlockLabel(VaultSessionState? session) {
  if (session?.vaultState == VaultState.uninitialized) {
    return 'Create the vault before enabling device-protected unlock.';
  }
  if (session?.localUnlockAvailable == true) {
    return 'Enabled on this device through OS secure storage.';
  }
  return 'Disabled. Passphrase or recovery key is required after lock.';
}

Future<void> _setLocalVaultUnlock(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: enabled ? 'Enable local unlock?' : 'Disable local unlock?',
    body: enabled
        ? 'Serlink will store a random device key in OS secure storage. Your vault passphrase is not stored.'
        : 'This removes this device key from OS secure storage. Existing connections keep running.',
    confirmLabel: enabled ? 'Enable' : 'Disable',
    destructive: !enabled,
  );
  if (!confirmed) {
    return;
  }
  try {
    if (enabled) {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .enableLocalUnlock();
    } else {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .disableLocalUnlock();
    }
    if (context.mounted) {
      _showSnackBar(
        context,
        enabled ? 'Local unlock enabled.' : 'Local unlock disabled.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _showIdentityManagerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _IdentityManagerDialog(),
  );
}

class _IdentityManagerDialog extends ConsumerWidget {
  const _IdentityManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<IdentityConfig>>(
      future: ref.read(identityRepositoryProvider).list(),
      builder: (context, snapshot) {
        final identities = snapshot.data ?? const <IdentityConfig>[];
        return SerlinkDialog(
          title: const Text('Credentials'),
          content: SizedBox(
            width: 640,
            child: _DialogList(
              loading: snapshot.connectionState != ConnectionState.done,
              empty: const _DialogState(
                icon: Icons.badge_outlined,
                title: 'No credentials stored',
                body:
                    'Imported passwords, private keys, certificates, and identity metadata will appear here.',
              ),
              items: [
                for (final identity in identities)
                  _DialogListItem(
                    icon: Icons.badge_outlined,
                    title: identity.displayName,
                    subtitle: [
                      _identityKindLabel(identity.kind),
                      if (identity.usernameHint case final username?)
                        'user $username',
                      if (identity.certificatePrincipal case final principal?)
                        'principal $principal',
                    ].join(' · '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SerlinkIconButton(
                          tooltip: 'Edit credential',
                          onPressed: () =>
                              _editManagedIdentity(context, ref, identity),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        SerlinkIconButton(
                          tooltip: 'Delete credential',
                          onPressed: () =>
                              _deleteIdentity(context, ref, identity),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            SerlinkFilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _editManagedIdentity(
  BuildContext context,
  WidgetRef ref,
  IdentityConfig identity,
) async {
  final updated = await showSerlinkDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _IdentityEditDialog(identity: identity),
  );
  if (updated == true && context.mounted) {
    Navigator.of(context).pop();
    _showSnackBar(context, 'Credential updated.');
    await _showIdentityManagerDialog(context, ref);
  }
}

Future<void> _deleteIdentity(
  BuildContext context,
  WidgetRef ref,
  IdentityConfig identity,
) async {
  final hosts = await ref.read(hostRepositoryProvider).list();
  if (!context.mounted) {
    return;
  }
  final linkedHosts = [
    for (final host in hosts)
      if (host.identityIds.contains(identity.id)) host.displayName,
  ];
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete credential?',
    body: linkedHosts.isEmpty
        ? 'This removes the credential and its encrypted secret material.'
        : 'This credential is still linked to: ${linkedHosts.join(', ')}. '
              'Delete it only after removing those host links.',
    confirmLabel: linkedHosts.isEmpty ? 'Delete' : 'Close',
    destructive: linkedHosts.isEmpty,
  );
  if (!confirmed || linkedHosts.isNotEmpty) {
    return;
  }
  try {
    if (identity.secretRecordId case final secretRecordId?) {
      await ref
          .read(syncDeleteTombstoneRepositoryProvider)
          .save(
            SyncDeleteTombstone(
              targetRecordId: secretRecordId,
              targetRecordType: 'identity_secret',
              deletedAt: DateTime.now().toUtc(),
            ),
          );
      await ref.read(vaultRecordRepositoryProvider).delete(secretRecordId);
    }
    await ref
        .read(syncDeleteTombstoneRepositoryProvider)
        .save(
          SyncDeleteTombstone(
            targetRecordId: VaultRecordId('identity:${identity.id.value}'),
            targetRecordType: 'identity',
            deletedAt: DateTime.now().toUtc(),
          ),
        );
    await ref.read(identityRepositoryProvider).delete(identity.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSnackBar(context, 'Credential deleted.');
      await _showIdentityManagerDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Credential could not be deleted.');
    }
  }
}

Future<void> _showKnownHostsDialog(BuildContext context, WidgetRef ref) async {
  await showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _KnownHostsDialog(),
  );
}

class _KnownHostsDialog extends ConsumerWidget {
  const _KnownHostsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<KnownHostRecord>>(
      future: ref.read(knownHostRepositoryProvider).list(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <KnownHostRecord>[];
        return SerlinkDialog(
          title: const Text('Known Hosts'),
          content: SizedBox(
            width: 680,
            child: _DialogList(
              loading: snapshot.connectionState != ConnectionState.done,
              empty: const _DialogState(
                icon: Icons.verified_user_outlined,
                title: 'No trusted fingerprints',
                body:
                    'Host fingerprints accepted during connection review will be listed here.',
              ),
              items: [
                for (final record in records)
                  _DialogListItem(
                    icon: Icons.verified_user_outlined,
                    title: '${record.hostname}:${record.port}',
                    subtitle: '${record.algorithm} · ${record.fingerprint}',
                    trailing: SerlinkIconButton(
                      tooltip: 'Delete known host',
                      onPressed: () => _deleteKnownHost(context, ref, record),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            SerlinkFilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _deleteKnownHost(
  BuildContext context,
  WidgetRef ref,
  KnownHostRecord record,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete known host?',
    body:
        'This removes the stored fingerprint for ${record.hostname}:${record.port}. The next connection will require confirmation again.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref
        .read(syncDeleteTombstoneRepositoryProvider)
        .save(
          SyncDeleteTombstone(
            targetRecordId: VaultRecordId('known_host:${record.hostId.value}'),
            targetRecordType: 'known_host',
            deletedAt: DateTime.now().toUtc(),
          ),
        );
    await ref.read(knownHostRepositoryProvider).delete(record.hostId);
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSnackBar(context, 'Known host deleted.');
      await _showKnownHostsDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Known host could not be deleted.');
    }
  }
}
