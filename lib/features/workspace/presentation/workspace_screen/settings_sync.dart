part of '../workspace_screen.dart';

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection({required this.vaultState});

  final VaultState? vaultState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canEdit = vaultState == VaultState.unlocked;
    final webDav = ref.watch(webDavSyncSettingsProvider);
    final iCloudAvailable = ref.watch(iCloudAvailableProvider);
    final knownDevices = canEdit ? ref.watch(syncKnownDevicesProvider) : null;
    final mobile = ref.watch(
      platformCapabilitiesProvider.select(
        (capabilities) => capabilities.prefersMobileWorkspaceShell,
      ),
    );
    final conflicts = ref.watch(syncConflictControllerProvider);
    final autoSync = ref.watch(autoSyncControllerProvider);
    final lastFailure = autoSync.lastFailure;
    final repairPlan = lastFailure == null
        ? null
        : ref.watch(syncRepairServiceProvider).planFor(lastFailure);
    final webDavRow = webDav.when(
      loading: () => _SettingsInfoRow(
        icon: Icons.cloud_queue,
        title: 'WebDAV',
        subtitle: l10n.syncLoadingSettings,
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
        subtitle: _webDavSettingsSubtitle(l10n, settings, autoSync, vaultState),
        action: _SettingsTextButton(
          onPressed: () => _showWebDavSyncDialog(context, ref, settings),
          child: Text(
            settings == null ? l10n.syncConfigureAction : l10n.syncEditAction,
          ),
        ),
      ),
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
        final cloudKit = ref.watch(cloudKitSyncSettingsProvider);
        return cloudKit.when(
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
              data: (settings) {
                final enabled = settings?.enabled ?? false;
                return _SettingsActionRow(
                  icon: Icons.cloud_outlined,
                  title: 'iCloud',
                  subtitle: _iCloudSettingsSubtitle(
                    l10n,
                    enabled,
                    autoSync,
                    vaultState,
                  ),
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
              subtitle: l10n.syncICloudChecking,
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
            data: (devices) {
              final viewButton = _SettingsTextButton(
                key: const ValueKey('settings-sync-devices-view-button'),
                onPressed: () => _showSyncDevicesDialog(
                  context,
                  ref,
                  devices,
                  allowReset: mobile,
                ),
                compactSize: SerlinkButtonSize.xs,
                child: Text(
                  mobile
                      ? l10n.syncViewAction
                      : devices.isEmpty
                      ? l10n.syncViewAction
                      : l10n.settingsManageAction,
                ),
              );
              return _SettingsActionRow(
                icon: Icons.devices_outlined,
                title: l10n.syncDevicesTitle,
                subtitle: _syncDevicesSubtitle(l10n, devices),
                actionWidth: mobile ? null : 188,
                action: mobile
                    ? viewButton
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          viewButton,
                          _SettingsTextButton(
                            key: const ValueKey(
                              'settings-sync-devices-reset-button',
                            ),
                            onPressed: () => _rotateSyncDevice(context, ref),
                            compactSize: SerlinkButtonSize.xs,
                            child: Text(l10n.syncResetAction),
                          ),
                        ],
                      ),
              );
            },
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
    final copy = _syncRepairCopy(l10n, plan);
    return _SettingsActionRow(
      icon: Icons.build_outlined,
      title: l10n.syncRepairTitle,
      subtitle: copy.message,
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
  final copy = _syncRepairCopy(context.l10n, plan);
  final confirmed = await _confirmDialog(
    context,
    title: copy.title,
    body: copy.message,
    confirmLabel: context.l10n.syncRepairAction,
    destructive: plan.destructive,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final l10n = context.l10n;
  try {
    final target = await _targetSyncProvider(ref);
    final provider = target?.provider;
    if (provider == null) {
      throw const SyncRunException(
        'sync.provider_missing',
        'No sync provider is enabled.',
      );
    }
    if (plan.action == SyncRepairAction.restoreLocalFromRemote) {
      await (await ref.read(
        automaticVaultBackupServiceProvider.future,
      )).createSnapshot(reason: 'before-remote-restore');
    }
    final result = await ref
        .read(syncRunServiceProvider)
        .runRepair(provider, plan.action);
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result, providerKind: target?.kind);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
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
    _showSnackBar(context, _syncRepairCopy(context.l10n, plan).message);
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
  final copy = _syncRepairCopy(context.l10n, plan);
  await showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthSmall),
      title: Text(copy.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.message),
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
            onPressed: () => _reviewSyncConflicts(context, ref, conflicts),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncReviewAction),
          ),
          _SettingsTextButton(
            onPressed: () => _resolveSyncConflicts(
              context,
              ref,
              SyncConflictResolution.useRemote,
              conflicts,
            ),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncUseRemoteAction),
          ),
          _SettingsTextButton(
            onPressed: () => _resolveSyncConflicts(
              context,
              ref,
              SyncConflictResolution.keepLocal,
              conflicts,
            ),
            compactSize: SerlinkButtonSize.xs,
            child: Text(l10n.syncKeepLocalAction),
          ),
        ],
      ),
    );
  }
}

Future<void> _reviewSyncConflicts(
  BuildContext context,
  WidgetRef ref,
  List<SyncRecordConflict> conflicts,
) async {
  final result = await showSerlinkDialog<SyncRunResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SyncConflictReviewDialog(conflicts: conflicts),
  );
  if (result != null && context.mounted) {
    _showSnackBar(
      context,
      context.l10n.syncConflictsResolvedSnack(result.recordsUploaded),
    );
  }
}

Future<void> _resolveSyncConflicts(
  BuildContext context,
  WidgetRef ref,
  SyncConflictResolution resolution,
  List<SyncRecordConflict> conflicts,
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
  final resolved = await _applySyncConflictResolution(
    context,
    ref,
    resolution,
    conflicts,
  );
  if (resolved != null && context.mounted) {
    _showSnackBar(
      context,
      context.l10n.syncConflictsResolvedSnack(resolved.recordsUploaded),
    );
  }
}

Future<SyncRunResult?> _applySyncConflictResolution(
  BuildContext context,
  WidgetRef ref,
  SyncConflictResolution resolution,
  List<SyncRecordConflict> acceptedConflicts,
) async {
  final l10n = context.l10n;
  ({SyncProvider provider, SyncProviderKind kind})? target;
  try {
    target = await _targetSyncProvider(ref);
    final provider = target?.provider;
    if (provider == null) {
      throw const SyncRunException(
        'sync.provider_missing',
        'No sync provider is enabled.',
      );
    }
    final result = await ref
        .read(syncRunServiceProvider)
        .resolveConflicts(
          provider,
          resolution,
          acceptedConflicts: acceptedConflicts,
        );
    ref.read(syncConflictControllerProvider.notifier).clear();
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result, providerKind: target?.kind);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    ref.invalidate(syncKnownDevicesProvider);
    return result;
  } on SyncRunConflictException catch (error) {
    ref
        .read(syncConflictControllerProvider.notifier)
        .setConflicts(error.conflicts, providerKind: target?.kind);
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
  return null;
}

Future<SyncRunResult?> _applySyncConflictMerges(
  BuildContext context,
  WidgetRef ref,
  List<SyncMergedConflict> merges,
) async {
  final l10n = context.l10n;
  ({SyncProvider provider, SyncProviderKind kind})? target;
  try {
    target = await _targetSyncProvider(ref);
    final provider = target?.provider;
    if (provider == null) {
      throw const SyncRunException(
        'sync.provider_missing',
        'No sync provider is enabled.',
      );
    }
    final result = await ref
        .read(syncRunServiceProvider)
        .applyMergedConflicts(provider, merges: merges);
    ref.read(syncConflictControllerProvider.notifier).clear();
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result, providerKind: target?.kind);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    ref.invalidate(syncKnownDevicesProvider);
    return result;
  } on SyncRunConflictException catch (error) {
    ref
        .read(syncConflictControllerProvider.notifier)
        .setConflicts(error.conflicts, providerKind: target?.kind);
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(l10n, error));
    }
  }
  return null;
}

Future<({SyncProvider provider, SyncProviderKind kind})?> _targetSyncProvider(
  WidgetRef ref,
) async {
  final conflictProviderKind = ref
      .read(syncConflictControllerProvider.notifier)
      .providerKind;
  final failedProviderKind = ref
      .read(autoSyncControllerProvider)
      .lastProviderKind;
  final preferred = await _syncProviderForKind(
    ref,
    conflictProviderKind ?? failedProviderKind,
  );
  if (preferred != null) {
    return preferred;
  }
  final provider = await ref
      .read(syncSettingsServiceProvider)
      .activeSyncProvider();
  if (provider == null) {
    return null;
  }
  return (provider: provider, kind: (await provider.capabilities()).kind);
}

Future<({SyncProvider provider, SyncProviderKind kind})?> _syncProviderForKind(
  WidgetRef ref,
  SyncProviderKind? kind,
) async {
  return switch (kind) {
    SyncProviderKind.cloudKit =>
      ref.read(platformCapabilitiesProvider).cloudKitSync &&
              (await ref.read(syncSettingsServiceProvider).readCloudKit())
                      ?.enabled ==
                  true
          ? (
              provider: ref.read(cloudKitSyncProviderFactoryProvider)(),
              kind: SyncProviderKind.cloudKit,
            )
          : null,
    SyncProviderKind.webDav =>
      (await ref.read(syncSettingsServiceProvider).readWebDav())?.enabled ==
              true
          ? (
              provider: await ref.read(webDavSyncProviderFactoryProvider)(
                ref.read(syncSettingsServiceProvider),
              ),
              kind: SyncProviderKind.webDav,
            )
          : null,
    _ => null,
  };
}

Future<void> _setICloudSync(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final l10n = context.l10n;
  try {
    if (enabled) {
      await ensureRemoteSyncCompatibleForEnable(
        ref.read(cloudKitSyncProviderFactoryProvider)(),
      );
    }
    await ref.read(syncSettingsServiceProvider).saveCloudKit(enabled);
    final header = ref
        .read(vaultSessionControllerProvider.notifier)
        .service
        .header;
    if (header != null) {
      final vaultId = syncVaultId(header);
      await ref
          .read(cloudKitSyncShadowSettingsStoreProvider)
          .save(vaultId: vaultId, enabled: enabled);
      if (!enabled) {
        await ref
            .read(encryptedSnapshotStagingRepositoryProvider)
            .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
        await ref
            .read(pendingRemoteResetRepositoryProvider)
            .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
      }
    }
    ref.invalidate(cloudKitSyncSettingsProvider);
    if (enabled) {
      if (header == null) {
        await ref
            .read(vaultSessionControllerProvider.notifier)
            .refreshCloudKitVaultDiscovery();
      }
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
  VaultState? vaultState,
) {
  if (!enabled) {
    return l10n.syncPausedICloudSubtitle;
  }
  return _autoSyncStatusSubtitle(l10n, autoSync, vaultState);
}

String _webDavSettingsSubtitle(
  AppLocalizations l10n,
  WebDavSyncSettings? settings,
  AutoSyncStatus autoSync,
  VaultState? vaultState,
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
      ? _autoSyncStatusSubtitle(l10n, autoSync, vaultState)
      : null;
  return [
    state,
    security,
    '${settings.endpoint.host}${settings.basePath}',
    ?sync,
  ].join(' · ');
}

String _autoSyncStatusSubtitle(
  AppLocalizations l10n,
  AutoSyncStatus status,
  VaultState? vaultState,
) {
  return switch (status.phase) {
    AutoSyncPhase.disabled => switch (vaultState) {
      VaultState.uninitialized => l10n.syncAutoSyncNeedsVault,
      VaultState.locked => l10n.syncAutoSyncNeedsUnlock,
      _ => l10n.syncAutoSyncWaiting,
    },
    AutoSyncPhase.idle =>
      status.lastCompletedAt == null
          ? l10n.syncAutoSyncReady
          : l10n.syncLastSynced(
              _syncLastCompletedTime(status.lastCompletedAt!),
            ),
    AutoSyncPhase.scheduled => l10n.syncAutoSyncQueued,
    AutoSyncPhase.syncing => l10n.syncSyncingAutomatically,
    AutoSyncPhase.conflicts => l10n.syncConflictCount(status.conflictCount),
    AutoSyncPhase.failed => _autoSyncFailureSubtitle(l10n, status),
  };
}

String _autoSyncFailureSubtitle(AppLocalizations l10n, AutoSyncStatus status) {
  final failedAt = status.lastFailedAt;
  final failureStatus = failedAt == null
      ? l10n.syncAutoSyncFailed
      : l10n.syncLastFailed(_syncLastCompletedTime(failedAt));
  final message = status.lastFailureMessage;
  if (message == null || message.isEmpty) {
    return failureStatus;
  }
  return '$failureStatus · $message';
}

String _syncLastCompletedTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final datePrefix = _isSameLocalDay(local, now)
      ? ''
      : '${_fourDigits(local.year)}-${_twoDigits(local.month)}-'
            '${_twoDigits(local.day)} ';
  return '$datePrefix${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:'
      '${_twoDigits(local.second)}';
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _fourDigits(int value) => value.toString().padLeft(4, '0');

({String title, String message}) _syncRepairCopy(
  AppLocalizations l10n,
  SyncRepairPlan plan,
) {
  return switch (plan.action) {
    SyncRepairAction.reviewLocalClock => (
      title: l10n.syncRepairClockTitle,
      message: l10n.syncRepairClockBody,
    ),
    SyncRepairAction.trustWebDavCertificate => (
      title: l10n.syncRepairTrustCertificateTitle,
      message: l10n.syncRepairTrustCertificateBody,
    ),
    SyncRepairAction.initializeEmptyRemote => (
      title: l10n.syncRepairInitializeRemoteTitle,
      message: l10n.syncRepairInitializeRemoteBody,
    ),
    SyncRepairAction.rebuildRemoteFromLocal => (
      title: plan.destructive
          ? l10n.syncRepairReplaceRemoteTitle
          : l10n.syncRepairRemoteRebuildTitle,
      message: plan.destructive
          ? l10n.syncRepairReplaceRemoteBody
          : l10n.syncRepairRemoteRebuildBody,
    ),
    SyncRepairAction.restoreLocalFromRemote => (
      title: l10n.syncRepairRestoreLocalTitle,
      message: l10n.syncRepairRestoreLocalBody,
    ),
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
    return localizedVaultExceptionMessage(l10n, error);
  }
  return l10n.syncSettingsLoadFailed;
}
