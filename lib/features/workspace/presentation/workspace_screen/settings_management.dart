part of '../workspace_screen.dart';

class _IOSLanguagePicker extends StatelessWidget {
  const _IOSLanguagePicker({required this.language, required this.onChanged});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = _languageItems(context.l10n);
    final t = context.tokens;
    return CupertinoButton(
      key: const ValueKey('settings-language-select'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () async {
        final result = await showCupertinoModalPopup<AppLanguage>(
          context: context,
          builder: (context) => CupertinoActionSheet(
            title: Text(context.l10n.settingsLanguageTitle),
            actions: [
              for (final item in items)
                CupertinoActionSheetAction(
                  isDefaultAction: item.value == language,
                  onPressed: () => Navigator.of(context).pop(item.value),
                  child: Text(item.label),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancelAction),
            ),
          ),
        );
        if (result != null) onChanged(result);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              items.firstWhere((item) => item.value == language).label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textSecondary, fontSize: 17),
            ),
          ),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_down, color: t.textMuted, size: 12),
        ],
      ),
    );
  }
}

class _IOSSettingsRow extends StatelessWidget {
  const _IOSSettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.action,
    this.leadingKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;
  final Key? leadingKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            action != null && MediaQuery.textScalerOf(context).scale(17) > 23;
        final description =
            subtitleWidget ??
            (subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ));
        final labels = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: t.textPrimary, fontSize: 17)),
            if (description != null) ...[
              const SizedBox(height: 3),
              description,
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox.square(
                  key: leadingKey,
                  dimension: 28,
                  child: Icon(icon, size: 21, color: t.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            labels,
                            Align(
                              alignment: Alignment.centerRight,
                              child: action,
                            ),
                          ],
                        )
                      : labels,
                ),
                if (!stacked && action != null) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.42,
                    ),
                    child: action!,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.action,
    this.subtitle,
    this.helpText,
    this.subtitleWidget,
    this.actionWidth,
    this.compactActionWidth,
    this.actionHeight,
    this.leadingKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? helpText;
  final Widget? subtitleWidget;
  final Widget? action;
  final double? actionWidth;
  final double? compactActionWidth;
  final double? actionHeight;
  final Key? leadingKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _IOSSettingsRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        subtitleWidget: subtitleWidget,
        action: action,
        leadingKey: leadingKey,
      );
    }
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    Widget rowTitle({bool compact = false}) {
      final label = Text(
        title,
        maxLines: compact ? 2 : null,
        overflow: compact ? TextOverflow.ellipsis : null,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
      );
      return helpText == null
          ? label
          : Tooltip(message: helpText!, child: label);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _settingsRowCompactBreakpoint;
        final desktopSubtitle =
            subtitleWidget ??
            (subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Text(subtitle!, style: subtitleStyle));
        if (!compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SerlinkListTile(
              minLeadingWidth: 28,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 2,
              ),
              subtitleGap: 1,
              leading: _SettingsRowIcon(icon: icon),
              title: rowTitle(),
              subtitle: desktopSubtitle,
              trailing: action == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: actionWidth == null
                          ? action
                          : SizedBox(width: actionWidth, child: action),
                    ),
            ),
          );
        }

        final effectiveSubtitle =
            subtitleWidget ??
            (subtitle == null || subtitle!.trim().isEmpty
                ? null
                : Tooltip(
                    message: subtitle!,
                    child: Text(
                      subtitle!,
                      maxLines: _settingsUseCompactControls(context) ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                  ));
        final configuredActionWidth = compactActionWidth ?? actionWidth;
        final slotWidth = math.min(
          configuredActionWidth ?? _settingsMobileActionWidth,
          configuredActionWidth ?? constraints.maxWidth * 0.42,
        );
        final actionSlot = action == null
            ? null
            : _SettingsActionSlot(
                width: slotWidth,
                height:
                    actionHeight ??
                    (configuredActionWidth == null
                        ? _settingsMobileActionHeight
                        : 40),
                alignment: Alignment.centerRight,
                child: _SettingsCompactControlsScope(
                  child: configuredActionWidth == null
                      ? action!
                      : SizedBox(width: slotWidth, child: action!),
                ),
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                child: _SettingsRowIcon(
                  key: leadingKey,
                  icon: icon,
                  compact: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowTitle(compact: true),
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

/// Borderless leading glyph for settings-style rows: a plain icon centered in
/// a fixed square slot so titles across rows stay aligned.
class _SettingsRowIcon extends StatelessWidget {
  const _SettingsRowIcon({super.key, required this.icon, this.compact = false});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: 28,
      child: Icon(icon, size: compact ? 17 : 18, color: t.textSecondary),
    );
  }
}

class _SettingsActionSlot extends StatelessWidget {
  const _SettingsActionSlot({
    required this.width,
    required this.height,
    required this.alignment,
    required this.child,
  });

  final double width;
  final double height;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      // Preserve compact controls at the default size, but leave room for
      // scaled select labels instead of clipping their internal FLabel.
      height:
          height * math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14),
      child: Align(alignment: alignment, child: child),
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

const double _settingsCompactBreakpoint = 700;
const double _settingsRowCompactBreakpoint = 560;
const double _settingsMobileActionWidth = 92;
const double _settingsMobileActionHeight = 32;
const double _settingsMobileSelectActionWidth = 112;
const double _settingsMobileSelectActionHeight = 40;
const double _settingsDesktopActionHeight = 36;

class _SettingsTextButton extends StatelessWidget {
  const _SettingsTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  }) : icon = null,
       label = null;

  const _SettingsTextButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final compact =
        _settingsUseCompactControls(context) ||
        _SettingsCompactControlsScope.of(context);
    return _SettingsControlButton(
      onPressed: onPressed,
      icon: icon,
      compact: compact,
      child: child ?? label!,
    );
  }
}

/// Borderless action button shared by every settings row, so hover feedback,
/// icon sizing, and the 13px label stay identical on desktop and mobile.
class _SettingsControlButton extends StatelessWidget {
  const _SettingsControlButton({
    required this.onPressed,
    required this.child,
    required this.compact,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(44, 44),
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: onPressed == null ? t.textMuted : t.accentPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
          child: child,
        ),
      );
    }
    final enabled = onPressed != null;
    // Buttons hug their label in both layouts: no fixed width, just symmetric
    // horizontal padding, so the label sits centered inside the button (and
    // its hover background). The compact slot right-aligns the whole button,
    // which keeps every button on the same right edge.
    final label = Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
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
              const SizedBox(width: 5),
            ],
            DefaultTextStyle.merge(
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
              maxLines: 1,
              child: child,
            ),
          ],
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.54,
      child: SerlinkPressable(
        onTap: onPressed,
        borderRadius: SerlinkRadii.control,
        hoverColor: t.surfaceOverlay,
        pressedColor: t.textPrimary.withValues(alpha: 0.12),
        child: SizedBox(
          height: compact
              ? _settingsMobileActionHeight
              : _settingsDesktopActionHeight,
          child: label,
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
  return MediaQuery.sizeOf(context).width < _settingsCompactBreakpoint;
}

List<SerlinkSelectItem<AppLanguage>> _languageItems(AppLocalizations l10n) {
  return [
    SerlinkSelectItem(
      value: AppLanguage.system,
      label: l10n.settingsLanguageSystem,
    ),
    SerlinkSelectItem(
      value: AppLanguage.english,
      label: l10n.settingsLanguageEnglish,
    ),
    SerlinkSelectItem(
      value: AppLanguage.simplifiedChinese,
      label: l10n.settingsLanguageChinese,
    ),
    SerlinkSelectItem(
      value: AppLanguage.japanese,
      label: l10n.settingsLanguageJapanese,
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

Future<void> _setProtectBackground(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(appProtectBackgroundProvider.notifier)
        .setProtectBackground(enabled);
    if (context.mounted) {
      _showSnackBar(context, l10n.settingsBackgroundPrivacySaved);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, l10n.settingsBackgroundPrivacySaveFailed);
    }
  }
}

Future<void> _setSshConfigAutoImport(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(appSshConfigAutoImportProvider.notifier)
        .setAutoImport(enabled);
    if (context.mounted) {
      _showSnackBar(context, l10n.settingsSshConfigAutoImportSaved);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, l10n.settingsSshConfigAutoImportSaveFailed);
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

String _vaultStateLabel(
  AppLocalizations l10n,
  VaultSessionState? session,
  VaultSessionBusyReason? busyReason,
  bool mobile,
) {
  final state = session?.vaultState;
  if (!mobile) {
    return _vaultStateLabelDesktop(l10n, session, busyReason);
  }
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreated,
    VaultState.locked
        when busyReason == VaultSessionBusyReason.waitingForICloud =>
      l10n.settingsVaultWaitingICloud,
    VaultState.locked => l10n.settingsVaultLockedMobile,
    VaultState.unlocked => l10n.settingsVaultUnlockedMobile,
    null => _vaultPreparingLabel(l10n, busyReason),
  };
}

String _vaultStateLabelDesktop(
  AppLocalizations l10n,
  VaultSessionState? session,
  VaultSessionBusyReason? busyReason,
) {
  final state = session?.vaultState;
  return switch (state) {
    VaultState.uninitialized => l10n.settingsVaultNotCreated,
    VaultState.locked
        when busyReason == VaultSessionBusyReason.waitingForICloud =>
      l10n.settingsVaultWaitingICloud,
    VaultState.locked => l10n.settingsVaultLocked,
    VaultState.unlocked => l10n.settingsVaultUnlocked,
    null => _vaultPreparingLabel(l10n, busyReason),
  };
}

String _vaultPreparingLabel(
  AppLocalizations l10n,
  VaultSessionBusyReason? busyReason,
) {
  return switch (busyReason) {
    VaultSessionBusyReason.waitingForICloud => l10n.settingsVaultWaitingICloud,
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
      return l10n.settingsLocalUnlockNeedsVaultMobile;
    }
    if (session?.localUnlockAvailable == true) {
      return l10n.settingsLocalUnlockEnabledMobile;
    }
    if (session?.biometricUnlockSupported != true) {
      return l10n.settingsLocalUnlockUnavailableMobile;
    }
    return l10n.settingsLocalUnlockDisabledMobile;
  }
  if (session?.vaultState == VaultState.uninitialized) {
    return l10n.settingsLocalUnlockNeedsVault;
  }
  if (session?.localUnlockAvailable == true) {
    return l10n.settingsLocalUnlockEnabled;
  }
  if (session?.biometricUnlockSupported != true) {
    return l10n.settingsLocalUnlockUnavailable;
  }
  return l10n.settingsLocalUnlockDisabled;
}

String _settingsCredentialsLocked(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsCredentialsLocked;
  }
  return l10n.settingsCredentialsLockedMobile;
}

String _settingsKnownHostsLocked(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsKnownHostsLocked;
  }
  return l10n.settingsKnownHostsLockedMobile;
}

String _settingsImportExportSubtitle(AppLocalizations l10n, bool mobile) {
  if (!mobile) {
    return l10n.settingsImportExportSubtitle;
  }
  return l10n.settingsImportExportSubtitleMobile;
}

Future<void> _setLocalVaultUnlock(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  await _setLocalVaultUnlockWithPrompt(
    context,
    ref,
    enabled,
    title: null,
    body: null,
  );
}

Future<void> _setLocalVaultUnlockWithPrompt(
  BuildContext context,
  WidgetRef ref,
  bool enabled, {
  String? title,
  String? body,
}) async {
  final l10n = context.l10n;
  final confirmed = await _confirmDialog(
    context,
    title:
        title ??
        (enabled
            ? l10n.settingsEnableLocalUnlockTitle
            : l10n.settingsDisableLocalUnlockTitle),
    body:
        body ??
        (enabled
            ? l10n.settingsEnableLocalUnlockBody
            : l10n.settingsDisableLocalUnlockBody),
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
            SerlinkOutlinedButton.icon(
              key: const ValueKey('credentials-add-button'),
              onPressed: () => _addManagedIdentity(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.hostAddCredentialAction),
            ),
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

Future<void> _addManagedIdentity(BuildContext context, WidgetRef ref) async {
  final created = await showSerlinkFormDialog<Object?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _IdentityEditDialog(),
  );
  if (created is IdentityConfig && context.mounted) {
    Navigator.of(context).pop();
    _showSnackBar(context, context.l10n.credentialAddedSnack);
    await _showIdentityManagerDialog(context, ref);
  }
}

Future<void> _editManagedIdentity(
  BuildContext context,
  WidgetRef ref,
  IdentityConfig identity,
) async {
  final updated = await showSerlinkFormDialog<bool>(
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
