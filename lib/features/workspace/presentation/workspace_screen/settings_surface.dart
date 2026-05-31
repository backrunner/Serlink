part of '../workspace_screen.dart';

class _SettingsSurface extends ConsumerWidget {
  const _SettingsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final vault = vaultSession.value;
    final vaultState = vault?.vaultState;
    final canImportHostData = vaultState == VaultState.unlocked;

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
                            'Settings',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: t.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Security, sync, import/export, and runtime controls.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _SettingsStatusPill(
                      label: _vaultStatusPillLabel(vaultState),
                      color: vaultState == VaultState.unlocked
                          ? t.accentPrimary
                          : t.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsSection(
                  title: 'Security',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.lock_outline,
                      title: 'Vault',
                      subtitle: _vaultStateLabel(vaultState),
                      subtitleWidget: vaultState == null
                          ? const _DynamicStatusText(
                              label: 'Preparing encrypted storage',
                            )
                          : null,
                      action: switch (vaultState) {
                        VaultState.unlocked => SerlinkTextButton(
                          onPressed: () => ref
                              .read(vaultSessionControllerProvider.notifier)
                              .lock(),
                          child: const Text('Lock'),
                        ),
                        VaultState.locked => SerlinkTextButton.icon(
                          key: const ValueKey('settings-vault-recovery-button'),
                          onPressed: () =>
                              _showVaultRecoveryCodeDialog(context),
                          icon: const Icon(Icons.key_outlined, size: 18),
                          label: const Text('Recover / Reset'),
                        ),
                        VaultState.uninitialized || null => null,
                      },
                    ),
                    _SettingsActionRow(
                      icon: Icons.key_outlined,
                      title: 'Local unlock',
                      subtitle: _localUnlockLabel(vault),
                      action: vaultState == VaultState.unlocked
                          ? SerlinkSwitch(
                              semanticsLabel: 'Enable local unlock',
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
                              label: const Text('Unlock with device'),
                            )
                          : null,
                    ),
                    const _SettingsInfoRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Host key confirmation',
                    ),
                    _SettingsActionRow(
                      icon: Icons.badge_outlined,
                      title: 'Credentials',
                      subtitle: canImportHostData
                          ? null
                          : 'Unlock the vault to review encrypted credentials.',
                      action: SerlinkTextButton(
                        onPressed: canImportHostData
                            ? () => _showIdentityManagerDialog(context, ref)
                            : null,
                        child: const Text('Manage'),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.verified_outlined,
                      title: 'Known hosts',
                      subtitle: canImportHostData
                          ? null
                          : 'Unlock the vault to review trusted host fingerprints.',
                      action: SerlinkTextButton(
                        onPressed: canImportHostData
                            ? () => _showKnownHostsDialog(context, ref)
                            : null,
                        child: const Text('Manage'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SyncSettingsSection(vaultState: vaultState),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: 'Data',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.import_export_outlined,
                      title: 'Import / Export',
                      subtitle:
                          'Backups, OpenSSH files, certificates, known_hosts, and metadata.',
                      action: SerlinkTextButton(
                        key: const ValueKey('settings-data-exchange-button'),
                        onPressed: () => _showDataExchangeDialog(
                          context,
                          ref,
                          canImportHostData: canImportHostData,
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: 'Runtime',
                  children: [
                    const _SettingsInfoRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Debug logging',
                    ),
                    const _SettingsInfoRow(
                      icon: Icons.health_and_safety_outlined,
                      title: 'Crash reporting',
                    ),
                    _SettingsActionRow(
                      icon: Icons.support_agent_outlined,
                      title: 'Diagnostic bundle',
                      action: SerlinkTextButton(
                        onPressed: () => _exportDiagnosticBundle(context, ref),
                        child: Text('Export'),
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
