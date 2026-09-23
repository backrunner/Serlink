part of '../workspace_screen.dart';

const String _serlinkRepositoryUrl = 'https://github.com/backrunner/serlink';

const EdgeInsets _settingsDesktopSurfacePadding = EdgeInsets.fromLTRB(
  SerlinkSpacing.xl,
  22,
  SerlinkSpacing.xl,
  36,
);
const double _settingsHeaderGap = 24;
const double _settingsSectionGap = 20;

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

    final generalSection = _SettingsSection(
      title: l10n.settingsGeneralSection,
      icon: Icons.tune_outlined,
      children: [
        _SettingsActionRow(
          icon: Icons.language_outlined,
          leadingKey: mobile ? const ValueKey('settings-language-icon') : null,
          title: l10n.settingsLanguageTitle,
          helpText: l10n.settingsLanguageSubtitle,
          action: capabilities.isIOS
              ? _IOSLanguagePicker(
                  language: language,
                  onChanged: (value) =>
                      unawaited(_setAppLanguage(context, ref, value)),
                )
              : SerlinkSelect<AppLanguage>(
                  key: const ValueKey('settings-language-select'),
                  value: language,
                  items: _languageItems(l10n),
                  hintText: l10n.selectAction,
                  searchHint: l10n.searchAction,
                  size: FTextFieldSizeVariant.sm,
                  compact: true,
                  menuMinWidth: 196,
                  onChanged: (value) =>
                      unawaited(_setAppLanguage(context, ref, value)),
                ),
          actionWidth: mobile ? null : 220,
          compactActionWidth: mobile ? _settingsMobileSelectActionWidth : 160,
          actionHeight: mobile ? _settingsMobileSelectActionHeight : null,
        ),
        if (capabilities.sshConfigImport)
          _SettingsActionRow(
            icon: Icons.settings_ethernet_outlined,
            title: l10n.settingsSshConfigAutoImportTitle,
            helpText: sshConfigAutoImport.when(
              data: (enabled) => enabled
                  ? l10n.settingsSshConfigAutoImportEnabled
                  : l10n.settingsSshConfigAutoImportDisabled,
              loading: () => l10n.settingsSshConfigAutoImportDisabled,
              error: (_, _) => l10n.settingsSshConfigAutoImportDisabled,
            ),
            action: _SettingsSwitch(
              key: const ValueKey('settings-ssh-config-auto-import-switch'),
              semanticsLabel: l10n.settingsSshConfigAutoImportSemantics,
              value: sshConfigAutoImport.value ?? false,
              onChanged: sshConfigAutoImport.isLoading
                  ? null
                  : (value) =>
                        unawaited(_setSshConfigAutoImport(context, ref, value)),
            ),
          ),
      ],
    );
    final securitySection = _SettingsSection(
      title: l10n.settingsSecuritySection,
      icon: Icons.shield_outlined,
      children: [
        _SettingsActionRow(
          icon: Icons.lock_outline,
          title: l10n.settingsVaultTitle,
          subtitle: _vaultStateLabel(l10n, vault, vaultBusyReason, true),
          helpText: _vaultStateLabel(l10n, vault, vaultBusyReason, false),
          subtitleWidget: vaultState == null
              ? _DynamicStatusText(label: vaultPreparingLabel)
              : null,
          action: switch (vaultState) {
            VaultState.unlocked => _SettingsTextButton(
              onPressed: () =>
                  ref.read(vaultSessionControllerProvider.notifier).lock(),
              child: Text(l10n.settingsLockAction),
            ),
            VaultState.locked => _SettingsTextButton.icon(
              key: const ValueKey('settings-vault-recovery-button'),
              onPressed: () => _showVaultRecoveryCodeDialog(context),
              icon: const Icon(Icons.key_outlined),
              label: Text(l10n.settingsRecoverResetAction),
            ),
            VaultState.uninitialized || null => null,
          },
        ),
        _SettingsActionRow(
          icon: Icons.fingerprint,
          title: l10n.settingsLocalUnlockTitle,
          subtitle: _localUnlockLabel(l10n, vault, true),
          helpText: _localUnlockLabel(l10n, vault, false),
          action:
              vaultState == VaultState.unlocked &&
                  vault?.biometricUnlockSupported == true
              ? _SettingsSwitch(
                  key: const ValueKey('settings-local-unlock-switch'),
                  semanticsLabel: l10n.settingsLocalUnlockSemantics,
                  value: vault?.localUnlockAvailable ?? false,
                  onChanged: (value) =>
                      _setLocalVaultUnlock(context, ref, value),
                )
              : vault?.localUnlockAvailable == true
              ? _SettingsTextButton.icon(
                  key: const ValueKey('settings-local-unlock-button'),
                  onPressed: vaultBusy
                      ? null
                      : () => ref
                            .read(vaultSessionControllerProvider.notifier)
                            .unlockWithLocalKey(),
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.settingsUnlockWithDeviceAction),
                )
              : null,
        ),
        _SettingsActionRow(
          icon: Icons.visibility_off_outlined,
          title: l10n.settingsBackgroundPrivacyTitle,
          helpText: (protectBackground.value ?? false)
              ? l10n.settingsBackgroundPrivacyEnabled
              : l10n.settingsBackgroundPrivacyDisabled,
          action: _SettingsSwitch(
            key: const ValueKey('settings-background-privacy-switch'),
            semanticsLabel: l10n.settingsBackgroundPrivacySemantics,
            value: protectBackground.value ?? false,
            onChanged: protectBackground.isLoading
                ? null
                : (value) =>
                      unawaited(_setProtectBackground(context, ref, value)),
          ),
        ),
        _SettingsActionRow(
          icon: Icons.badge_outlined,
          title: l10n.settingsCredentialsTitle,
          subtitle: canImportHostData
              ? null
              : _settingsCredentialsLocked(l10n, true),
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
              : _settingsKnownHostsLocked(l10n, true),
          action: _SettingsTextButton(
            onPressed: canImportHostData
                ? () => _showKnownHostsDialog(context, ref)
                : null,
            child: Text(l10n.settingsManageAction),
          ),
        ),
      ],
    );
    final dataSection = _SettingsSection(
      title: l10n.settingsDataSection,
      icon: Icons.inventory_2_outlined,
      children: [
        _SettingsActionRow(
          icon: Icons.import_export_outlined,
          title: l10n.settingsImportExportTitle,
          subtitle: _settingsImportExportSubtitle(l10n, true),
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
        _SettingsActionRow(
          icon: Icons.article_outlined,
          title: l10n.settingsDiagnosticBundleTitle,
          action: _SettingsTextButton(
            key: const ValueKey('settings-diagnostic-log-export-button'),
            onPressed: () => _exportDiagnosticBundle(context, ref),
            child: Text(l10n.settingsExportAction),
          ),
        ),
      ],
    );

    return ListView(
      key: const PageStorageKey('settings-scroll'),
      padding: showInPageTitle
          ? _settingsDesktopSurfacePadding
          : const EdgeInsets.fromLTRB(
              SerlinkSpacing.lg,
              _mobileSurfaceTopGap,
              SerlinkSpacing.lg,
              SerlinkSpacing.lg,
            ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showInPageTitle) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settingsTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      StatusPill(
                        label: _vaultStatusPillLabel(l10n, vaultState),
                        color: vaultState == VaultState.unlocked
                            ? t.accentPrimary
                            : t.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: _settingsHeaderGap),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final preferences = [generalSection, securitySection];
                    final services = [
                      _SyncSettingsSection(vaultState: vaultState),
                      if (capabilities.mcpServer) const _McpSettingsSection(),
                      dataSection,
                    ];
                    if (!mobile &&
                        constraints.maxWidth >= 900 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18) {
                      return Row(
                        key: const ValueKey('settings-columns'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SettingsSectionColumn(
                              children: preferences,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _SettingsSectionColumn(children: services),
                          ),
                        ],
                      );
                    }
                    return _SettingsSectionColumn(
                      children: [...preferences, ...services],
                    );
                  },
                ),
                const SizedBox(height: _settingsSectionGap),
                _SettingsAboutFooter(packageInfo: appPackageInfo),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSectionColumn extends StatelessWidget {
  const _SettingsSectionColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: _settingsSectionGap),
          children[i],
        ],
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: SerlinkRadii.dialog,
            child: ColoredBox(
              color: t.surfaceRaised,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 56,
                        color: t.borderSubtle,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: SerlinkRadii.workspace,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.accentPrimary.withValues(alpha: 0.08),
                      borderRadius: SerlinkRadii.control,
                    ),
                    child: Icon(icon, size: 16, color: t.accentPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: SerlinkSpacing.xs),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsAboutFooter extends StatelessWidget {
  const _SettingsAboutFooter({required this.packageInfo});

  final AsyncValue<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.hub_outlined, size: 20, color: t.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
                Text(
                  _settingsAppVersionLabel(l10n, packageInfo),
                  key: const ValueKey('settings-about-version-label'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SettingsTextButton.icon(
            key: const ValueKey('settings-about-github-button'),
            onPressed: () => unawaited(_openSerlinkRepository(context)),
            icon: const Icon(Icons.open_in_new),
            label: const Text('GitHub'),
          ),
        ],
      ),
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
