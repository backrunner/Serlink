part of '../workspace_screen.dart';

class _SettingsSurface extends ConsumerWidget {
  const _SettingsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final vault = vaultSession.value;
    final vaultState = vault?.vaultState;
    final canImportHostData = vaultState == VaultState.unlocked;
    final language = ref.watch(appLanguageProvider).value ?? AppLanguage.system;

    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                _SettingsSection(
                  title: l10n.settingsGeneralSection,
                  children: [
                    _SettingsActionRow(
                      icon: Icons.language_outlined,
                      title: l10n.settingsLanguageTitle,
                      subtitle: l10n.settingsLanguageSubtitle,
                      action: SizedBox(
                        width: 220,
                        child: SerlinkSelect<AppLanguage>(
                          value: language,
                          items: _languageItems(l10n),
                          hintText: l10n.selectAction,
                          searchHint: l10n.searchAction,
                          onChanged: (value) =>
                              unawaited(_setAppLanguage(context, ref, value)),
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
                      subtitle: _vaultStateLabel(l10n, vaultState),
                      subtitleWidget: vaultState == null
                          ? _DynamicStatusText(
                              label: l10n.settingsVaultPreparing,
                            )
                          : null,
                      action: switch (vaultState) {
                        VaultState.unlocked => SerlinkTextButton(
                          onPressed: () => ref
                              .read(vaultSessionControllerProvider.notifier)
                              .lock(),
                          child: Text(l10n.settingsLockAction),
                        ),
                        VaultState.locked => SerlinkTextButton.icon(
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
                      icon: Icons.key_outlined,
                      title: l10n.settingsLocalUnlockTitle,
                      subtitle: _localUnlockLabel(l10n, vault),
                      action: vaultState == VaultState.unlocked
                          ? SerlinkSwitch(
                              key: const ValueKey(
                                'settings-local-unlock-switch',
                              ),
                              semanticsLabel: l10n.settingsLocalUnlockSemantics,
                              value: vault?.localUnlockAvailable ?? false,
                              onChanged: (value) =>
                                  _setLocalVaultUnlock(context, ref, value),
                            )
                          : vault?.localUnlockAvailable == true
                          ? SerlinkTextButton.icon(
                              key: const ValueKey(
                                'settings-local-unlock-button',
                              ),
                              onPressed: vaultSession.isLoading
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
                    _SettingsInfoRow(
                      icon: Icons.verified_user_outlined,
                      title: l10n.settingsHostKeyConfirmationTitle,
                    ),
                    _SettingsActionRow(
                      icon: Icons.badge_outlined,
                      title: l10n.settingsCredentialsTitle,
                      subtitle: canImportHostData
                          ? null
                          : l10n.settingsCredentialsLocked,
                      action: SerlinkTextButton(
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
                          : l10n.settingsKnownHostsLocked,
                      action: SerlinkTextButton(
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
                      subtitle: l10n.settingsImportExportSubtitle,
                      action: SerlinkTextButton(
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
                      icon: Icons.bug_report_outlined,
                      title: l10n.settingsDebugLoggingTitle,
                      action: SerlinkTextButton(
                        key: const ValueKey('settings-debug-log-export-button'),
                        onPressed: () => _exportRuntimeDebugLog(context, ref),
                        child: Text(l10n.settingsExportAction),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.support_agent_outlined,
                      title: l10n.settingsDiagnosticBundleTitle,
                      action: SerlinkTextButton(
                        key: const ValueKey(
                          'settings-diagnostic-info-export-button',
                        ),
                        onPressed: () => _exportDiagnosticBundle(context, ref),
                        child: Text(l10n.settingsExportAction),
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
