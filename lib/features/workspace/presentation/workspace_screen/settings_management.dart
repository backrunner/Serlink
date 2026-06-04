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

class _SettingsStatusPill extends StatelessWidget {
  const _SettingsStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: label, color: color);
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.action,
    this.subtitle,
    this.subtitleWidget,
    this.actionWidth,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;
  final double? actionWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final desktopSubtitle =
            subtitleWidget ??
            (subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Text(subtitle!, style: subtitleStyle));
        if (!compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SerlinkListTile(
              minLeadingWidth: 28,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
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
              subtitle: desktopSubtitle,
              trailing: action == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: action,
                    ),
            ),
          );
        }

        final effectiveSubtitle =
            subtitleWidget ??
            (subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Text(
                    subtitle!,
                    maxLines: compact ? 2 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: subtitleStyle,
                  ));
        final slotWidth = math.min(
          actionWidth ?? 104.0,
          constraints.maxWidth * 0.48,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment: effectiveSubtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: effectiveSubtitle == null ? 0 : 2,
                ),
                child: SizedBox.square(
                  dimension: 30,
                  child: Icon(icon, size: 18, color: t.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    if (effectiveSubtitle != null) ...[
                      const SizedBox(height: 2),
                      effectiveSubtitle,
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 10),
                _SettingsActionSlot(width: slotWidth, child: action!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SettingsActionSlot extends StatelessWidget {
  const _SettingsActionSlot({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
    );
  }
}

class _SettingsTextButton extends StatelessWidget {
  const _SettingsTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.compactSize = SerlinkButtonSize.sm,
  }) : icon = null,
       label = null;

  const _SettingsTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  }) : child = null,
       compactSize = SerlinkButtonSize.sm;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final SerlinkButtonSize compactSize;

  @override
  Widget build(BuildContext context) {
    final size = _settingsUseCompactControls(context)
        ? compactSize
        : SerlinkButtonSize.lg;
    if (icon case final icon?) {
      return SerlinkTextButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label!,
        size: size,
      );
    }
    return SerlinkTextButton(onPressed: onPressed, size: size, child: child!);
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SerlinkSwitch(
      value: value,
      onChanged: onChanged,
      semanticsLabel: semanticsLabel,
      scale: _settingsUseCompactControls(context) ? 0.64 : 0.72,
    );
  }
}

bool _settingsUseCompactControls(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 700;
}

List<SerlinkSelectItem<AppLanguage>> _languageItems(AppLocalizations l10n) {
  return [
    SerlinkSelectItem(
      value: AppLanguage.system,
      label: l10n.settingsLanguageSystem,
      icon: Icons.computer_outlined,
    ),
    SerlinkSelectItem(
      value: AppLanguage.english,
      label: l10n.settingsLanguageEnglish,
      icon: Icons.language_outlined,
    ),
    SerlinkSelectItem(
      value: AppLanguage.simplifiedChinese,
      label: l10n.settingsLanguageChinese,
      icon: Icons.language_outlined,
    ),
    SerlinkSelectItem(
      value: AppLanguage.japanese,
      label: l10n.settingsLanguageJapanese,
      icon: Icons.language_outlined,
    ),
  ];
}

Future<void> _setAppLanguage(
  BuildContext context,
  WidgetRef ref,
  AppLanguage language,
) async {
  try {
    await ref.read(appLanguageProvider.notifier).setLanguage(language);
    if (context.mounted) {
      _showSnackBar(context, context.l10n.settingsLanguageSaved);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.settingsLanguageSaveFailed);
    }
  }
}

String _vaultStatusPillLabel(AppLocalizations l10n, VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreatedPill,
    VaultState.locked => l10n.settingsVaultLockedPill,
    VaultState.unlocked => l10n.settingsVaultUnlockedPill,
    null => l10n.settingsVaultLoadingPill,
  };
}

String _vaultStateLabel(AppLocalizations l10n, VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreated,
    VaultState.locked => l10n.settingsVaultLocked,
    VaultState.unlocked => l10n.settingsVaultUnlocked,
    null => l10n.settingsVaultPreparing,
  };
}

String _localUnlockLabel(AppLocalizations l10n, VaultSessionState? session) {
  if (session?.vaultState == VaultState.uninitialized) {
    return l10n.settingsLocalUnlockNeedsVault;
  }
  if (session?.localUnlockAvailable == true) {
    return l10n.settingsLocalUnlockEnabled;
  }
  return l10n.settingsLocalUnlockDisabled;
}

Future<void> _setLocalVaultUnlock(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final l10n = context.l10n;
  final confirmed = await _confirmDialog(
    context,
    title: enabled
        ? l10n.settingsEnableLocalUnlockTitle
        : l10n.settingsDisableLocalUnlockTitle,
    body: enabled
        ? l10n.settingsEnableLocalUnlockBody
        : l10n.settingsDisableLocalUnlockBody,
    confirmLabel: enabled
        ? l10n.settingsEnableAction
        : l10n.settingsDisableAction,
    destructive: !enabled,
  );
  if (!confirmed) {
    return;
  }
  try {
    bool updated;
    if (enabled) {
      updated = await ref
          .read(vaultSessionControllerProvider.notifier)
          .enableLocalUnlock();
    } else {
      updated = await ref
          .read(vaultSessionControllerProvider.notifier)
          .disableLocalUnlock();
    }
    if (context.mounted) {
      _showSnackBar(
        context,
        enabled
            ? updated
                  ? l10n.settingsLocalUnlockEnabledSnack
                  : l10n.settingsLocalUnlockVerifyFailedSnack
            : updated
            ? l10n.settingsLocalUnlockDisabledSnack
            : l10n.settingsLocalUnlockStillAvailableSnack,
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _localUnlockErrorMessage(l10n, error));
    }
  }
}

String _localUnlockErrorMessage(AppLocalizations l10n, Object error) {
  if (error is VaultException) {
    return error.message;
  }
  return l10n.settingsLocalUnlockUpdateFailed;
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
    final l10n = context.l10n;
    final capabilities = ref.watch(platformCapabilitiesProvider);
    return FutureBuilder<List<IdentityConfig>>(
      future: ref.read(identityRepositoryProvider).list(),
      builder: (context, snapshot) {
        final identities = [
          for (final identity in snapshot.data ?? const <IdentityConfig>[])
            if (_identitySupportedByCapabilities(identity, capabilities))
              identity,
        ];
        return SerlinkDialog(
          maxWidth: _adaptiveDialogWidth(context, _dialogWidthManagement),
          title: Text(l10n.credentialsDialogTitle),
          content: SizedBox(
            width: 640,
            child: _DialogList(
              loading: snapshot.connectionState != ConnectionState.done,
              empty: _DialogState(
                icon: Icons.badge_outlined,
                title: l10n.credentialsEmptyTitle,
                body: l10n.credentialsEmptyBody,
              ),
              items: [
                for (final identity in identities)
                  _DialogListItem(
                    icon: Icons.badge_outlined,
                    title: identity.displayName,
                    subtitle: [
                      _identityKindLabel(l10n, identity.kind),
                      if (identity.usernameHint case final username?)
                        l10n.identityUserLabel(username),
                      if (identity.certificatePrincipal case final principal?)
                        l10n.identityPrincipalLabel(principal),
                    ].join(' · '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SerlinkIconButton(
                          tooltip: l10n.credentialsEditTooltip,
                          onPressed: () =>
                              _editManagedIdentity(context, ref, identity),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        SerlinkIconButton(
                          tooltip: l10n.credentialsDeleteTooltip,
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
              child: Text(l10n.doneAction),
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
    _showSnackBar(context, context.l10n.credentialUpdatedSnack);
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
    title: context.l10n.credentialDeleteTitle,
    body: linkedHosts.isEmpty
        ? context.l10n.credentialDeleteBody
        : context.l10n.credentialDeleteLinkedBody(linkedHosts.join(', ')),
    confirmLabel: linkedHosts.isEmpty
        ? context.l10n.deleteAction
        : context.l10n.closeAction,
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
      _showSnackBar(context, context.l10n.credentialDeletedSnack);
      await _showIdentityManagerDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.credentialDeleteFailedSnack);
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
    final l10n = context.l10n;
    return FutureBuilder<List<KnownHostRecord>>(
      future: ref.read(knownHostRepositoryProvider).list(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <KnownHostRecord>[];
        return SerlinkDialog(
          maxWidth: _adaptiveDialogWidth(context, _dialogWidthWide),
          title: Text(l10n.knownHostsDialogTitle),
          content: SizedBox(
            width: 680,
            child: _DialogList(
              loading: snapshot.connectionState != ConnectionState.done,
              empty: _DialogState(
                icon: Icons.verified_user_outlined,
                title: l10n.knownHostsEmptyTitle,
                body: l10n.knownHostsEmptyBody,
              ),
              items: [
                for (final record in records)
                  _DialogListItem(
                    icon: Icons.verified_user_outlined,
                    title: '${record.hostname}:${record.port}',
                    subtitle: '${record.algorithm} · ${record.fingerprint}',
                    trailing: SerlinkIconButton(
                      tooltip: l10n.knownHostDeleteTooltip,
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
              child: Text(l10n.doneAction),
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
    title: context.l10n.knownHostDeleteTitle,
    body: context.l10n.knownHostDeleteBody('${record.hostname}:${record.port}'),
    confirmLabel: context.l10n.deleteAction,
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
      _showSnackBar(context, context.l10n.knownHostDeletedSnack);
      await _showKnownHostsDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.knownHostDeleteFailedSnack);
    }
  }
}
