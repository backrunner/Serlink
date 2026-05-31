part of '../workspace_screen.dart';

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection({required this.vaultState});

  final VaultState? vaultState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          loading: () => const _SettingsInfoRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: 'Loading encrypted sync settings.',
          ),
          error: (error, stackTrace) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _syncSettingsErrorMessage(error),
            action: SerlinkTextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, null),
              child: const Text('Configure'),
            ),
          ),
          data: (settings) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _webDavSettingsSubtitle(settings, autoSync),
            action: SerlinkTextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, settings),
              child: Text(settings == null ? 'Configure' : 'Edit'),
            ),
          ),
        ) ??
        const _SettingsInfoRow(
          icon: Icons.cloud_queue,
          title: 'WebDAV',
          subtitle: 'Unlock the vault to configure encrypted sync.',
        );

    final iCloudRow = iCloudAvailable.when<Widget?>(
      loading: () => const _SettingsInfoRow(
        icon: Icons.cloud_outlined,
        title: 'iCloud',
        subtitle: 'Checking iCloud availability.',
      ),
      error: (error, stackTrace) => _SettingsInfoRow(
        icon: Icons.cloud_outlined,
        title: 'iCloud',
        subtitle: _syncSettingsErrorMessage(error),
      ),
      data: (available) {
        if (!available) {
          return null;
        }
        final cloudKit = canEdit
            ? ref.watch(cloudKitSyncSettingsProvider)
            : null;
        return cloudKit?.when(
              loading: () => const _SettingsInfoRow(
                icon: Icons.cloud_outlined,
                title: 'iCloud',
                subtitle: 'Loading encrypted sync settings.',
              ),
              error: (error, stackTrace) => _SettingsInfoRow(
                icon: Icons.cloud_outlined,
                title: 'iCloud',
                subtitle: _syncSettingsErrorMessage(error),
              ),
              data: (settings) {
                final enabled = settings?.enabled ?? false;
                return _SettingsActionRow(
                  icon: Icons.cloud_outlined,
                  title: 'iCloud',
                  subtitle: _iCloudSettingsSubtitle(enabled, autoSync),
                  action: SerlinkSwitch(
                    value: enabled,
                    onChanged: (value) => _setICloudSync(context, ref, value),
                  ),
                );
              },
            ) ??
            const _SettingsInfoRow(
              icon: Icons.cloud_outlined,
              title: 'iCloud',
              subtitle: 'Unlock the vault to sync through iCloud.',
            );
      },
    );

    return _SettingsSection(
      title: 'Sync',
      children: [
        webDavRow,
        ?iCloudRow,
        if (repairPlan != null) _SyncRepairRow(plan: repairPlan),
        if (conflicts.isNotEmpty) _SyncConflictRow(conflicts: conflicts),
        if (knownDevices != null)
          knownDevices.when(
            loading: () => const _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: 'Loading encrypted device records.',
            ),
            error: (error, stackTrace) => _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: _syncSettingsErrorMessage(error),
            ),
            data: (devices) => _SettingsActionRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: _syncDevicesSubtitle(devices),
              action: Wrap(
                spacing: 4,
                children: [
                  SerlinkTextButton(
                    onPressed: () =>
                        _showSyncDevicesDialog(context, ref, devices),
                    child: Text(devices.isEmpty ? 'View' : 'Manage'),
                  ),
                  SerlinkTextButton(
                    onPressed: () => _rotateSyncDevice(context, ref),
                    child: const Text('Reset'),
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
    return _SettingsActionRow(
      icon: Icons.build_outlined,
      title: 'Sync repair',
      subtitle: plan.message,
      action: SerlinkTextButton(
        onPressed: () => _repairWebDavSync(context, ref, plan),
        child: const Text('Repair'),
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
    confirmLabel: 'Repair',
    destructive: plan.destructive,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
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
      _showSnackBar(context, 'Remote sync repaired.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
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
      _showSnackBar(context, 'WebDAV certificate trust saved.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
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
            Text('Local time: ${_shortLocalDateTime(DateTime.now())}'),
            if (certificate != null) ...[
              const SizedBox(height: 8),
              Text('Endpoint: ${certificate.endpoint}'),
              const SizedBox(height: 8),
              Text('Valid from: ${_shortLocalDateTime(certificate.validFrom)}'),
              const SizedBox(height: 8),
              Text(
                'Valid until: ${_shortLocalDateTime(certificate.validUntil)}',
              ),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
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
    return _SettingsActionRow(
      icon: Icons.report_problem_outlined,
      title: 'Sync conflicts',
      subtitle:
          '${conflicts.length} encrypted record${conflicts.length == 1 ? '' : 's'} need review.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SerlinkTextButton(
            onPressed: () => _reviewWebDavConflicts(context, ref, conflicts),
            child: const Text('Review'),
          ),
          SerlinkTextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.useRemote,
            ),
            child: const Text('Use remote'),
          ),
          SerlinkTextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.keepLocal,
            ),
            child: const Text('Keep local'),
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
    title: useRemote ? 'Use remote records?' : 'Keep local records?',
    body: useRemote
        ? 'Remote encrypted records will replace conflicting local records before syncing.'
        : 'Local encrypted records will overwrite conflicting remote records.',
    confirmLabel: useRemote ? 'Use remote' : 'Keep local',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
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
        'Resolved sync conflicts. Synced ${result.recordsUploaded} encrypted records.',
      );
    }
  } on SyncRunConflictException catch (error) {
    ref
        .read(syncConflictControllerProvider.notifier)
        .setConflicts(error.conflicts);
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

Future<void> _setICloudSync(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  try {
    await ref.read(syncSettingsServiceProvider).saveCloudKit(enabled);
    ref.invalidate(cloudKitSyncSettingsProvider);
    if (enabled) {
      ref.read(autoSyncControllerProvider.notifier).requestSync();
    }
    if (context.mounted) {
      _showSnackBar(
        context,
        enabled ? 'iCloud sync enabled.' : 'iCloud sync paused.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

String _iCloudSettingsSubtitle(bool enabled, AutoSyncStatus autoSync) {
  if (!enabled) {
    return 'Paused. Encrypted records sync through your private iCloud database.';
  }
  return ['Enabled', _autoSyncStatusSubtitle(autoSync)].join(' · ');
}

String _webDavSettingsSubtitle(
  WebDavSyncSettings? settings,
  AutoSyncStatus autoSync,
) {
  if (settings == null) {
    return 'Not configured. Encrypted manifest and records only.';
  }
  final state = settings.enabled ? 'Enabled' : 'Paused';
  final security = settings.allowInsecureHttp ? 'HTTP allowed' : 'HTTPS';
  final sync = settings.enabled ? _autoSyncStatusSubtitle(autoSync) : null;
  return [
    state,
    security,
    '${settings.endpoint.host}${settings.basePath}',
    ?sync,
  ].join(' · ');
}

String _autoSyncStatusSubtitle(AutoSyncStatus status) {
  return switch (status.phase) {
    AutoSyncPhase.disabled => 'auto-sync waiting',
    AutoSyncPhase.idle =>
      status.lastCompletedAt == null
          ? 'auto-sync ready'
          : 'last synced ${_shortLocalDateTime(status.lastCompletedAt!)}',
    AutoSyncPhase.scheduled => 'auto-sync queued',
    AutoSyncPhase.syncing => 'syncing automatically',
    AutoSyncPhase.conflicts =>
      '${status.conflictCount} conflict${status.conflictCount == 1 ? '' : 's'}',
    AutoSyncPhase.failed => status.lastFailureMessage ?? 'auto-sync failed',
  };
}

String _syncSettingsErrorMessage(Object error) {
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
  return 'Sync settings could not be loaded.';
}
