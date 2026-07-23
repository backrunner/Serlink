part of '../workspace_screen.dart';

const String _serlinkRepositoryUrl = 'https://github.com/backrunner/serlink';

class _SettingsSurface extends ConsumerWidget {
  const _SettingsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final vault = vaultSession.value;
    final vaultState = vault?.vaultState;
    final vaultBusy = vault?.isBusy == true || vaultSession.isLoading;
    final vaultBusyReason =
        vault?.busyReason ?? ref.watch(vaultSessionBusyReasonProvider);
    final vaultPreparingLabel = _vaultPreparingLabel(l10n, vaultBusyReason);
    final canImportHostData = vaultState == VaultState.unlocked;
    final language = ref.watch(appLanguageProvider).value ?? AppLanguage.system;
    final protectBackground = ref.watch(appProtectBackgroundProvider);
    final appPackageInfo = ref.watch(appPackageInfoProvider);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final sshConfigAutoImport = capabilities.sshConfigImport
        ? ref.watch(appSshConfigAutoImportProvider)
        : const AsyncData<bool>(false);
    final showInPageTitle = !capabilities.prefersMobileWorkspaceShell;
    final mobile = !showInPageTitle;
    final t = context.tokens;

    return ListView(
      padding: showInPageTitle
          ? const EdgeInsets.fromLTRB(24, 22, 24, 36)
          : const EdgeInsets.fromLTRB(16, _mobileSurfaceTopGap, 16, 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showInPageTitle) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsTitle,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: t.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.settingsSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _SettingsStatusPill(
                        label: _vaultStatusPillLabel(l10n, vaultState),
                        color: vaultState == VaultState.unlocked
                            ? t.accentPrimary
                            : t.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
                _SettingsSection(
                  title: l10n.settingsGeneralSection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.language_outlined,
                      leadingKey: mobile
                          ? const ValueKey('settings-language-icon')
                          : null,
                      title: l10n.settingsLanguageTitle,
                      subtitle: _settingsLanguageSubtitle(l10n, mobile),
                      action: SizedBox(
                        width: mobile ? _settingsMobileSelectActionWidth : 220,
                        child: SerlinkSelect<AppLanguage>(
                          key: const ValueKey('settings-language-select'),
                          value: language,
                          items: _languageItems(l10n),
                          hintText: l10n.selectAction,
                          searchHint: l10n.searchAction,
                          size: mobile
                              ? FTextFieldSizeVariant.sm
                              : FTextFieldSizeVariant.lg,
                          compact: mobile,
                          menuMinWidth: mobile ? 196 : null,
                          onChanged: (value) =>
                              unawaited(_setAppLanguage(context, ref, value)),
                        ),
                      ),
                      actionWidth: mobile
                          ? _settingsMobileSelectActionWidth
                          : 220,
                      actionHeight: mobile
                          ? _settingsMobileSelectActionHeight
                          : null,
                      actionVerticalOffset: mobile ? 3 : 0,
                    ),
                    if (capabilities.sshConfigImport)
                      _SettingsActionRow(
                        icon: Icons.settings_ethernet_outlined,
                        title: l10n.settingsSshConfigAutoImportTitle,
                        subtitle: sshConfigAutoImport.when(
                          data: (enabled) => enabled
                              ? l10n.settingsSshConfigAutoImportEnabled
                              : l10n.settingsSshConfigAutoImportDisabled,
                          loading: () =>
                              l10n.settingsSshConfigAutoImportDisabled,
                          error: (_, _) =>
                              l10n.settingsSshConfigAutoImportDisabled,
                        ),
                        action: _SettingsSwitch(
                          key: const ValueKey(
                            'settings-ssh-config-auto-import-switch',
                          ),
                          semanticsLabel:
                              l10n.settingsSshConfigAutoImportSemantics,
                          value: sshConfigAutoImport.value ?? false,
                          onChanged: sshConfigAutoImport.isLoading
                              ? null
                              : (value) => unawaited(
                                  _setSshConfigAutoImport(context, ref, value),
                                ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: l10n.settingsSecuritySection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.lock_outline,
                      title: l10n.settingsVaultTitle,
                      subtitle: _vaultStateLabel(
                        l10n,
                        vault,
                        vaultBusyReason,
                        mobile,
                      ),
                      subtitleWidget: vaultState == null
                          ? _DynamicStatusText(label: vaultPreparingLabel)
                          : null,
                      action: switch (vaultState) {
                        VaultState.unlocked => _SettingsTextButton(
                          onPressed: () => ref
                              .read(vaultSessionControllerProvider.notifier)
                              .lock(),
                          child: Text(l10n.settingsLockAction),
                        ),
                        VaultState.locked => _SettingsTextButton.icon(
                          key: const ValueKey('settings-vault-recovery-button'),
                          onPressed: () =>
                              _showVaultRecoveryCodeDialog(context),
                          icon: const Icon(Icons.key_outlined, size: 18),
                          label: Text(l10n.settingsRecoverResetAction),
                        ),
                        VaultState.uninitialized || null => null,
                      },
                    ),
                    _SettingsActionRow(
                      icon: Icons.fingerprint,
                      title: l10n.settingsLocalUnlockTitle,
                      subtitle: _localUnlockLabel(l10n, vault, mobile),
                      action:
                          vaultState == VaultState.unlocked &&
                              vault?.biometricUnlockSupported == true
                          ? _SettingsSwitch(
                              key: const ValueKey(
                                'settings-local-unlock-switch',
                              ),
                              semanticsLabel: l10n.settingsLocalUnlockSemantics,
                              value: vault?.localUnlockAvailable ?? false,
                              onChanged: (value) =>
                                  _setLocalVaultUnlock(context, ref, value),
                            )
                          : vault?.localUnlockAvailable == true
                          ? _SettingsTextButton.icon(
                              key: const ValueKey(
                                'settings-local-unlock-button',
                              ),
                              onPressed: vaultBusy
                                  ? null
                                  : () => ref
                                        .read(
                                          vaultSessionControllerProvider
                                              .notifier,
                                        )
                                        .unlockWithLocalKey(),
                              icon: const Icon(Icons.fingerprint, size: 18),
                              label: Text(l10n.settingsUnlockWithDeviceAction),
                            )
                          : null,
                    ),
                    _SettingsActionRow(
                      icon: Icons.visibility_off_outlined,
                      title: l10n.settingsBackgroundPrivacyTitle,
                      subtitle: (protectBackground.value ?? false)
                          ? l10n.settingsBackgroundPrivacyEnabled
                          : l10n.settingsBackgroundPrivacyDisabled,
                      action: _SettingsSwitch(
                        key: const ValueKey(
                          'settings-background-privacy-switch',
                        ),
                        semanticsLabel: l10n.settingsBackgroundPrivacySemantics,
                        value: protectBackground.value ?? false,
                        onChanged: protectBackground.isLoading
                            ? null
                            : (value) => unawaited(
                                _setProtectBackground(context, ref, value),
                              ),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.badge_outlined,
                      title: l10n.settingsCredentialsTitle,
                      subtitle: canImportHostData
                          ? null
                          : _settingsCredentialsLocked(l10n, mobile),
                      action: _SettingsTextButton(
                        onPressed: canImportHostData
                            ? () => _showIdentityManagerDialog(context, ref)
                            : null,
                        child: Text(l10n.settingsManageAction),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.verified_outlined,
                      title: l10n.settingsKnownHostsTitle,
                      subtitle: canImportHostData
                          ? null
                          : _settingsKnownHostsLocked(l10n, mobile),
                      action: _SettingsTextButton(
                        onPressed: canImportHostData
                            ? () => _showKnownHostsDialog(context, ref)
                            : null,
                        child: Text(l10n.settingsManageAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SyncSettingsSection(vaultState: vaultState),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: l10n.settingsDataSection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.import_export_outlined,
                      title: l10n.settingsImportExportTitle,
                      subtitle: _settingsImportExportSubtitle(l10n, mobile),
                      action: _SettingsTextButton(
                        key: const ValueKey('settings-data-exchange-button'),
                        onPressed: () => _showDataExchangeDialog(
                          context,
                          ref,
                          canImportHostData: canImportHostData,
                        ),
                        child: Text(l10n.settingsOpenAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: l10n.settingsRuntimeSection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.article_outlined,
                      title: l10n.settingsDiagnosticBundleTitle,
                      action: _SettingsTextButton(
                        key: const ValueKey(
                          'settings-diagnostic-log-export-button',
                        ),
                        onPressed: () => _exportDiagnosticBundle(context, ref),
                        child: Text(l10n.settingsExportAction),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: l10n.settingsAboutSection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.info_outline,
                      title: l10n.appTitle,
                      actionWidth: mobile ? 146 : 220,
                      action: SizedBox(
                        width: mobile ? 146 : 220,
                        child: _SettingsInlineValue(
                          key: const ValueKey('settings-about-version-label'),
                          text: _settingsAppVersionLabel(l10n, appPackageInfo),
                        ),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.code_outlined,
                      title: 'GitHub',
                      action: _SettingsTextButton.icon(
                        key: const ValueKey('settings-about-github-button'),
                        onPressed: () =>
                            unawaited(_openSerlinkRepository(context)),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(l10n.settingsOpenAction),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _settingsAppVersionLabel(
  AppLocalizations l10n,
  AsyncValue<PackageInfo> packageInfo,
) {
  return packageInfo.when(
    data: (info) {
      final version = info.version.trim().isEmpty ? '-' : info.version.trim();
      final buildNumber = info.buildNumber.trim();
      if (buildNumber.isEmpty) {
        return l10n.settingsAppVersionOnly(version);
      }
      return l10n.settingsAppVersionLabel(version, buildNumber);
    },
    loading: () => l10n.settingsAppVersionLoading,
    error: (_, _) => l10n.settingsAppVersionUnavailable,
  );
}

Future<void> _openSerlinkRepository(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(_serlinkRepositoryUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    _showSnackBar(context, context.l10n.settingsRepositoryOpenFailed);
  }
}

class _SettingsInlineValue extends StatelessWidget {
  const _SettingsInlineValue({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
      ),
    );
  }
}
