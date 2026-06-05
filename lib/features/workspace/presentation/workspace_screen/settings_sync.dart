part of '../workspace_screen.dart';

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection({required this.vaultState});

  final VaultState? vaultState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canEdit = vaultState == VaultState.unlocked;
    final webDav = canEdit ? ref.watch(webDavSyncSettingsProvider) : null;
    final iCloudAvailable = ref.watch(iCloudAvailableProvider);
    final knownDevices = canEdit ? ref.watch(syncKnownDevicesProvider) : null;
    final conflicts = ref.watch(syncConflictControllerProvider);
    final autoSync = ref.watch(autoSyncControllerProvider);
    final lastFailure = autoSync.lastFailure;
    final repairPlan = lastFailure == null
        ? null
        : ref.watch(syncRepairServiceProvider).planFor(lastFailure);
    final webDavRow =
        webDav?.when(
          loading: () => _SettingsInfoRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: l10n.syncLoadingEncryptedSettings,
          ),
          error: (error, stackTrace) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _syncSettingsErrorMessage(l10n, error),
            action: _SettingsTextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, null),
              child: Text(l10n.syncConfigureAction),
            ),
          ),
          data: (settings) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _webDavSettingsSubtitle(l10n, settings, autoSync),
            action: _SettingsTextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, settings),
              child: Text(
                settings == null
                    ? l10n.syncConfigureAction
                    : l10n.syncEditAction,
              ),
            ),
          ),
        ) ??
        _SettingsInfoRow(
          icon: Icons.cloud_queue,
          title: 'WebDAV',
          subtitle: l10n.syncWebDavLocked,
        );

    final iCloudRow = iCloudAvailable.when<Widget?>(
      loading: () => _SettingsInfoRow(
        icon: Icons.cloud_outlined,
        title: 'iCloud',
        subtitle: l10n.syncICloudChecking,
      ),
      error: (error, stackTrace) => _SettingsInfoRow(
        icon: Icons.cloud_outlined,
        title: 'iCloud',
        subtitle: _syncSettingsErrorMessage(l10n, error),
      ),
      data: (available) {
        if (!available) {
          return null;
        }
        final cloudKit = canEdit
            ? ref.watch(cloudKitSyncSettingsProvider)
            : null;
        return cloudKit?.when(
              loading: () => _SettingsInfoRow(
                icon: Icons.cloud_outlined,
                title: 'iCloud',
                subtitle: l10n.syncLoadingEncryptedSettings,
              ),
              error: (error, stackTrace) => _SettingsInfoRow(
                icon: Icons.cloud_outlined,
                title: 'iCloud',
                subtitle: _syncSettingsErrorMessage(l10n, error),
              ),
              data: (settings) {
                final enabled = settings?.enabled ?? false;
                return _SettingsActionRow(
                  icon: Icons.cloud_outlined,
                  title: 'iCloud',
                  subtitle: _iCloudSettingsSubtitle(l10n, enabled, autoSync),
                  action: _SettingsSwitch(
                    value: enabled,
                    onChanged: (value) => _setICloudSync(context, ref, value),
                  ),
                );
              },
            ) ??
            _SettingsInfoRow(
              icon: Icons.cloud_outlined,
              title: 'iCloud',
              subtitle: l10n.syncICloudLocked,
            );
      },
    );

    return _SettingsSection(
      title: l10n.syncSectionTitle,
      children: [
        webDavRow,
        ?iCloudRow,
        if (repairPlan != null) _SyncRepairRow(plan: repairPlan),
        if (conflicts.isNotEmpty) _SyncConflictRow(conflicts: conflicts),
        if (knownDevices != null)
          knownDevices.when(
            loading: () => _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: l10n.syncDevicesTitle,
              subtitle: l10n.syncDevicesLoading,
            ),
            error: (error, stackTrace) => _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: l10n.syncDevicesTitle,
              subtitle: _syncSettingsErrorMessage(l10n, error),
            ),
            data: (devices) => _SettingsActionRow(
              icon: Icons.devices_outlined,
              title: l10n.syncDevicesTitle,
              subtitle: _syncDevicesSubtitle(l10n, devices),
              actionWidth: 188,
              action: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _SettingsTextButton(
                    onPressed: () =>
                        _showSyncDevicesDialog(context, ref, devices),
                    compactSize: SerlinkButtonSize.xs,
                    child: Text(
                      devices.isEmpty
                          ? l10n.syncViewAction
                          : l10n.settingsManageAction,
                    ),
                  ),
                  _SettingsTextButton(
                    onPressed: () => _rotateSyncDevice(context, ref),
                    compactSize: SerlinkButtonSize.xs,
                    child: Text(l10n.syncResetAction),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SyncRepairRow extends ConsumerWidget {
  const _SyncRepairRow({required this.plan});

  final SyncRepairPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _SettingsActionRow(
      icon: Icons.build_outlined,
      title: l10n.syncRepairTitle,
      subtitle: plan.message,
      action: _SettingsTextButton(
        onPressed: () => _repairWebDavSync(context, ref, plan),
        child: Text(l10n.syncRepairAction),
      ),
    );
  }
}

Future<void> _repairWebDavSync(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  if (plan.action == SyncRepairAction.reviewLocalClock) {
    await _reviewLocalClock(context, ref, plan);
    return;
  }
  if (plan.action == SyncRepairAction.trustWebDavCertificate) {
    await _trustWebDavCertificate(context, ref, plan);
    return;
  }
  final confirmed = await _confirmDialog(
    context,
    title: plan.title,
    body: plan.message,
    confirmLabel: context.l10n.syncRepairAction,
    destructive: plan.destructive,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final l10n = context.l10n;
  try {
    final provider = await ref
        .read(syncSettingsServiceProvider)
        .buildWebDavProvider();
    final result = await ref
        .read(syncRunServiceProvider)
        .runRepair(provider, plan.action);
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result);
    ref.invalidate(syncKnownDevicesProvider);
    if (context.mounted) {
      _showSnackBar(context, l10n.syncRemoteRepaired);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
}

Future<void> _trustWebDavCertificate(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  final lastFailure = ref.read(autoSyncControllerProvider).lastFailure;
  final certificate = lastFailure is SyncProviderException
      ? WebDavTlsCertificateDetails.tryParse(lastFailure.diagnostic)
      : null;
  if (certificate == null) {
    _showSnackBar(context, plan.message);
    return;
  }
  final l10n = context.l10n;
  final decision = await ref
      .read(securityModalServiceProvider)
      .confirmWebDavCertificate(certificate);
  if (decision != CertificateTrustDecision.trustAndSave) {
    return;
  }
  try {
    await ref
        .read(syncSettingsServiceProvider)
        .trustWebDavCertificate(certificate);
    ref.invalidate(webDavSyncSettingsProvider);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    if (context.mounted) {
      _showSnackBar(context, l10n.syncWebDavCertificateTrustSaved);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
}

Future<void> _reviewLocalClock(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  final lastFailure = ref.read(autoSyncControllerProvider).lastFailure;
  final certificate = lastFailure is SyncProviderException
      ? WebDavTlsCertificateDetails.tryParse(lastFailure.diagnostic)
      : null;
  await showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthSmall),
      title: Text(plan.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.message),
            const SizedBox(height: 12),
            Text(
              context.l10n.syncLocalTimeLabel(
                _shortLocalDateTime(DateTime.now()),
              ),
            ),
            if (certificate != null) ...[
              const SizedBox(height: 8),
              Text(context.l10n.syncEndpointLabel('${certificate.endpoint}')),
              const SizedBox(height: 8),
              Text(
                context.l10n.syncValidFromLabel(
                  _shortLocalDateTime(certificate.validFrom),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.syncValidUntilLabel(
                  _shortLocalDateTime(certificate.validUntil),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.doneAction),
        ),
      ],
    ),
  );
}

class _SyncConflictRow extends ConsumerWidget {
  const _SyncConflictRow({required this.conflicts});

  final List<SyncRecordConflict> conflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _SettingsActionRow(
      icon: Icons.report_problem_outlined,
      title: l10n.syncConflictsTitle,
      subtitle: l10n.syncConflictsSubtitle(conflicts.length),
      actionWidth: 286,
      action: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        children: [
          _SettingsTextButton(
            onPressed: () => _reviewWebDavConflicts(context, ref, conflicts),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncReviewAction),
          ),
          _SettingsTextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.useRemote,
            ),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncUseRemoteAction),
          ),
          _SettingsTextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.keepLocal,
            ),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncKeepLocalAction),
          ),
        ],
      ),
    );
  }
}

Future<void> _reviewWebDavConflicts(
  BuildContext context,
  WidgetRef ref,
  List<SyncRecordConflict> conflicts,
) async {
  await showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SyncConflictReviewDialog(conflicts: conflicts),
  );
}

Future<void> _resolveWebDavConflicts(
  BuildContext context,
  WidgetRef ref,
  SyncConflictResolution resolution,
) async {
  final useRemote = resolution == SyncConflictResolution.useRemote;
  final confirmed = await _confirmDialog(
    context,
    title: useRemote
        ? context.l10n.syncUseRemoteTitle
        : context.l10n.syncKeepLocalTitle,
    body: useRemote
        ? context.l10n.syncUseRemoteBody
        : context.l10n.syncKeepLocalBody,
    confirmLabel: useRemote
        ? context.l10n.syncUseRemoteAction
        : context.l10n.syncKeepLocalAction,
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final l10n = context.l10n;
  try {
    final provider = await ref
        .read(syncSettingsServiceProvider)
        .buildWebDavProvider();
    final result = await ref
        .read(syncRunServiceProvider)
        .resolveConflicts(provider, resolution);
    ref.read(syncConflictControllerProvider.notifier).clear();
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result);
    ref.invalidate(syncKnownDevicesProvider);
    if (context.mounted) {
      _showSnackBar(
        context,
        l10n.syncConflictsResolvedSnack(result.recordsUploaded),
      );
    }
  } on SyncRunConflictException catch (error) {
    ref
        .read(syncConflictControllerProvider.notifier)
        .setConflicts(error.conflicts);
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
}

Future<void> _setICloudSync(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final l10n = context.l10n;
  try {
    await ref.read(syncSettingsServiceProvider).saveCloudKit(enabled);
    ref.invalidate(cloudKitSyncSettingsProvider);
    if (enabled) {
      ref.read(autoSyncControllerProvider.notifier).requestSync();
    }
    if (context.mounted) {
      _showSnackBar(
        context,
        enabled ? l10n.syncICloudEnabledSnack : l10n.syncICloudPausedSnack,
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
}

String _iCloudSettingsSubtitle(
  AppLocalizations l10n,
  bool enabled,
  AutoSyncStatus autoSync,
) {
  if (!enabled) {
    return l10n.syncPausedICloudSubtitle;
  }
  return [
    l10n.syncEnabledStatus,
    _autoSyncStatusSubtitle(l10n, autoSync),
  ].join(' · ');
}

String _webDavSettingsSubtitle(
  AppLocalizations l10n,
  WebDavSyncSettings? settings,
  AutoSyncStatus autoSync,
) {
  if (settings == null) {
    return l10n.syncWebDavNotConfiguredSubtitle;
  }
  final state = settings.enabled
      ? l10n.syncEnabledStatus
      : l10n.syncPausedStatus;
  final security = settings.allowInsecureHttp
      ? l10n.syncHttpAllowedStatus
      : l10n.syncHttpsStatus;
  final sync = settings.enabled
      ? _autoSyncStatusSubtitle(l10n, autoSync)
      : null;
  return [
    state,
    security,
    '${settings.endpoint.host}${settings.basePath}',
    ?sync,
  ].join(' · ');
}

String _autoSyncStatusSubtitle(AppLocalizations l10n, AutoSyncStatus status) {
  return switch (status.phase) {
    AutoSyncPhase.disabled => l10n.syncAutoSyncWaiting,
    AutoSyncPhase.idle =>
      status.lastCompletedAt == null
          ? l10n.syncAutoSyncReady
          : l10n.syncLastSynced(_shortLocalDateTime(status.lastCompletedAt!)),
    AutoSyncPhase.scheduled => l10n.syncAutoSyncQueued,
    AutoSyncPhase.syncing => l10n.syncSyncingAutomatically,
    AutoSyncPhase.conflicts => l10n.syncConflictCount(status.conflictCount),
    AutoSyncPhase.failed =>
      status.lastFailureMessage ?? l10n.syncAutoSyncFailed,
  };
}

String _syncSettingsErrorMessage(AppLocalizations l10n, Object error) {
  if (error is SyncSettingsException) {
    return error.message;
  }
  if (error is SyncDeviceException) {
    return error.message;
  }
  if (error is SyncRunException) {
    return error.message;
  }
  if (error is SyncProviderException) {
    return error.message;
  }
  if (error is VaultException) {
    return error.message;
  }
  return l10n.syncSettingsLoadFailed;
}
