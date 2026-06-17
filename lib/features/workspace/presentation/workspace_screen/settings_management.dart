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
    this.actionHeight,
    this.actionVerticalOffset = 0,
    this.leadingKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;
  final double? actionWidth;
  final double? actionHeight;
  final double actionVerticalOffset;
  final Key? leadingKey;

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
                    maxLines: 1,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: subtitleStyle,
                  ));
        final slotWidth = math.min(
          actionWidth ?? _settingsMobileActionWidth,
          actionWidth == null ? constraints.maxWidth * 0.42 : actionWidth!,
        );
        final actionSlot = action == null
            ? null
            : _SettingsActionSlot(
                width: slotWidth,
                height:
                    actionHeight ??
                    (actionWidth == null ? _settingsMobileActionHeight : 40),
                verticalOffset: actionVerticalOffset,
                alignment: Alignment.centerRight,
                child: _SettingsCompactControlsScope(child: action!),
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            crossAxisAlignment:
                (effectiveSubtitle == null || actionSlot != null)
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: effectiveSubtitle == null || actionSlot != null ? 0 : 2,
                ),
                child: SizedBox.square(
                  key: leadingKey,
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
              if (actionSlot != null) ...[
                const SizedBox(width: 10),
                actionSlot,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SettingsActionSlot extends StatelessWidget {
  const _SettingsActionSlot({
    required this.width,
    required this.height,
    required this.verticalOffset,
    required this.alignment,
    required this.child,
  });

  final double width;
  final double height;
  final double verticalOffset;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = Align(alignment: alignment, child: child);
    return SizedBox(
      width: width,
      height: height,
      child: verticalOffset == 0
          ? aligned
          : Transform.translate(
              offset: Offset(0, verticalOffset),
              child: aligned,
            ),
    );
  }
}

class _SettingsCompactControlsScope extends InheritedWidget {
  const _SettingsCompactControlsScope({required super.child});

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              _SettingsCompactControlsScope
            >() !=
        null;
  }

  @override
  bool updateShouldNotify(_SettingsCompactControlsScope oldWidget) => false;
}

const double _settingsMobileActionWidth = 92;
const double _settingsMobileActionHeight = 32;
const double _settingsMobileSelectActionWidth = 112;
const double _settingsMobileSelectActionHeight = 40;

class _SettingsTextButton extends StatelessWidget {
  const _SettingsTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.compactSize = SerlinkButtonSize.xs,
  }) : icon = null,
       label = null;

  const _SettingsTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  }) : child = null,
       compactSize = SerlinkButtonSize.xs;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final SerlinkButtonSize compactSize;

  @override
  Widget build(BuildContext context) {
    if (_settingsUseCompactControls(context) ||
        _SettingsCompactControlsScope.of(context)) {
      return _SettingsMobileButton(
        onPressed: onPressed,
        icon: icon,
        child: child ?? label!,
      );
    }
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

class _SettingsMobileButton extends StatelessWidget {
  const _SettingsMobileButton({
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: SerlinkPressable(
          onTap: onPressed,
          borderRadius: SerlinkRadii.control,
          hoverColor: t.accentPrimary.withValues(alpha: 0.08),
          pressedColor: t.accentPrimary.withValues(alpha: 0.16),
          child: SizedBox(
            width: _settingsMobileActionWidth,
            height: _settingsMobileActionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(size: 14, color: t.textPrimary),
                          child: icon!,
                        ),
                        const SizedBox(width: 4),
                      ],
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                        maxLines: 1,
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      scale: _settingsUseCompactControls(context) ? 0.6 : 0.72,
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

String _vaultStateLabel(AppLocalizations l10n, VaultState? state, bool mobile) {
  if (!mobile) {
    return _vaultStateLabelDesktop(l10n, state);
  }
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreated,
    VaultState.locked => _mobileText(l10n, zh: '已锁定', en: 'Locked', ja: 'ロック中'),
    VaultState.unlocked => _mobileText(
      l10n,
      zh: '已解锁',
      en: 'Unlocked',
      ja: '解除済み',
    ),
    null => l10n.settingsVaultPreparing,
  };
}

String _vaultStateLabelDesktop(AppLocalizations l10n, VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreated,
    VaultState.locked => l10n.settingsVaultLocked,
    VaultState.unlocked => l10n.settingsVaultUnlocked,
    null => l10n.settingsVaultPreparing,
  };
}

String _localUnlockLabel(
  AppLocalizations l10n,
  VaultSessionState? session,
  bool mobile,
) {
  if (mobile) {
    if (session?.vaultState == VaultState.uninitialized) {
      return _mobileText(
        l10n,
        zh: '需先创建保险库',
        en: 'Create vault first',
        ja: '先に作成',
      );
    }
    if (session?.localUnlockAvailable == true) {
      return _mobileText(
        l10n,
        zh: '可用设备解锁',
        en: 'Device unlock ready',
        ja: '端末解除可',
      );
    }
    return _mobileText(
      l10n,
      zh: '需密码或恢复密钥',
      en: 'Passphrase required',
      ja: 'パスフレーズ必須',
    );
  }
  if (session?.vaultState == VaultState.uninitialized) {
    return l10n.settingsLocalUnlockNeedsVault;
  }
  if (session?.localUnlockAvailable == true) {
    return l10n.settingsLocalUnlockEnabled;
  }
  return l10n.settingsLocalUnlockDisabled;
}

String _settingsLanguageSubtitle(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsLanguageSubtitle;
  }
  return _mobileText(l10n, zh: '应用语言', en: 'App language', ja: '表示言語');
}

String _settingsCredentialsLocked(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsCredentialsLocked;
  }
  return _mobileText(l10n, zh: '需解锁保险库', en: 'Unlock vault first', ja: '解除が必要');
}

String _settingsKnownHostsLocked(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsKnownHostsLocked;
  }
  return _mobileText(l10n, zh: '需解锁保险库', en: 'Unlock vault first', ja: '解除が必要');
}

String _settingsImportExportSubtitle(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsImportExportSubtitle;
  }
  return _mobileText(
    l10n,
    zh: '备份与 SSH 数据',
    en: 'Backups and SSH data',
    ja: 'バックアップと SSH',
  );
}

String _mobileText(
  AppLocalizations l10n, {
  required String zh,
  required String en,
  required String ja,
}) {
  return switch (l10n.localeName.split('_').first) {
    'zh' => zh,
    'ja' => ja,
    _ => en,
  };
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
    return localizedVaultExceptionMessage(l10n, error);
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
