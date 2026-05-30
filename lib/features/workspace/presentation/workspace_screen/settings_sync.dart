part of '../workspace_screen.dart';

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection({required this.vaultState});

  final VaultState? vaultState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = vaultState == VaultState.unlocked;
    final webDav = canEdit ? ref.watch(webDavSyncSettingsProvider) : null;
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
            action: TextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, null),
              child: const Text('Configure'),
            ),
          ),
          data: (settings) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _webDavSettingsSubtitle(settings, autoSync),
            action: TextButton(
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

    return _SettingsSection(
      title: 'Sync',
      children: [
        webDavRow,
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
                  TextButton(
                    onPressed: () =>
                        _showSyncDevicesDialog(context, ref, devices),
                    child: Text(devices.isEmpty ? 'View' : 'Manage'),
                  ),
                  TextButton(
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
      action: TextButton(
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
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
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
        FilledButton(
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
          TextButton(
            onPressed: () => _reviewWebDavConflicts(context, ref, conflicts),
            child: const Text('Review'),
          ),
          TextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.useRemote,
            ),
            child: const Text('Use remote'),
          ),
          TextButton(
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
  await showDialog<void>(
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

class _SyncConflictReviewDialog extends ConsumerStatefulWidget {
  const _SyncConflictReviewDialog({required this.conflicts});

  final List<SyncRecordConflict> conflicts;

  @override
  ConsumerState<_SyncConflictReviewDialog> createState() =>
      _SyncConflictReviewDialogState();
}

class _SyncConflictReviewDialogState
    extends ConsumerState<_SyncConflictReviewDialog> {
  final Map<String, Map<String, bool>> _choices = {};
  var _saving = false;

  @override
  void initState() {
    super.initState();
    for (final conflict in widget.conflicts) {
      final fieldSet = conflict.fieldSet;
      if (fieldSet == null) {
        continue;
      }
      _choices[conflict.id.value] = {
        for (final field in fieldSet.fields) field.key: false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review sync conflicts'),
      content: SizedBox(
        width: 820,
        height: 520,
        child: ListView.separated(
          itemCount: widget.conflicts.length,
          separatorBuilder: (_, _) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final conflict = widget.conflicts[index];
            final fieldSet = conflict.fieldSet;
            if (fieldSet == null) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            if (!fieldSet.supportsFieldMerge) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            return _SyncConflictFieldCard(
              conflict: conflict,
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
              onChanged: (fieldKey, useRemote) {
                setState(() {
                  _choices.putIfAbsent(conflict.id.value, () => {})[fieldKey] =
                      useRemote;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: Text(_saving ? 'Applying' : 'Apply merge'),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
    });
    try {
      for (final conflict in widget.conflicts) {
        final fieldSet = conflict.fieldSet;
        if (fieldSet == null || !fieldSet.supportsFieldMerge) {
          continue;
        }
        final merged = ref
            .read(syncFieldMergeServiceProvider)
            .merge(
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
            );
        await ref
            .read(syncRunServiceProvider)
            .applyMergedRecord(recordId: conflict.id, mergedJson: merged);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await _resolveWebDavConflicts(
        context,
        ref,
        SyncConflictResolution.keepLocal,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

class _SyncConflictFieldCard extends StatelessWidget {
  const _SyncConflictFieldCard({
    required this.conflict,
    required this.fieldSet,
    required this.useRemoteByField,
    required this.onChanged,
  });

  final SyncRecordConflict conflict;
  final SyncConflictFieldSet fieldSet;
  final Map<String, bool> useRemoteByField;
  final void Function(String fieldKey, bool useRemote) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final field in fieldSet.fields) ...[
          Text(field.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Local',
                  value: describeConflictValue(field.localValue),
                  selected: !(useRemoteByField[field.key] ?? false),
                  onSelected: () => onChanged(field.key, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Remote',
                  value: describeConflictValue(field.remoteValue),
                  selected: useRemoteByField[field.key] ?? false,
                  onSelected: () => onChanged(field.key, true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ConflictChoiceTile extends StatelessWidget {
  const _ConflictChoiceTile({
    required this.title,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncConflictUnsupportedCard extends StatelessWidget {
  const _SyncConflictUnsupportedCard({required this.conflict});

  final SyncRecordConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'This record type currently requires whole-record resolution. Use the existing local or remote action for this conflict.',
        ),
      ],
    );
  }
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

String _syncDevicesSubtitle(List<SyncDeviceMetadata> devices) {
  if (devices.isEmpty) {
    return 'This device will be registered on first sync.';
  }
  if (devices.length == 1) {
    return '${devices.single.displayName} registered for encrypted sync.';
  }
  final latest = [...devices]
    ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  return '${devices.length} devices registered. Last writer: ${latest.first.displayName}.';
}

Future<void> _showSyncDevicesDialog(
  BuildContext context,
  WidgetRef ref,
  List<SyncDeviceMetadata> devices,
) async {
  final localDevice = await ref
      .read(syncDeviceServiceProvider)
      .readLocalDevice();
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _SyncDevicesDialog(
      devices: devices,
      localDeviceId: localDevice?.id,
      onDelete: (device) =>
          _deleteSyncDevice(context, dialogContext, ref, device),
    ),
  );
}

Future<void> _deleteSyncDevice(
  BuildContext pageContext,
  BuildContext dialogContext,
  WidgetRef ref,
  SyncDeviceMetadata device,
) async {
  final confirmed = await _confirmDialog(
    dialogContext,
    title: 'Remove ${device.displayName}?',
    body: 'This removes the encrypted sync device record from this vault.',
    confirmLabel: 'Remove',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(syncDeviceServiceProvider).deleteKnownDevice(device.id);
    ref.invalidate(syncKnownDevicesProvider);
    ref.read(autoSyncControllerProvider.notifier).requestSync();
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    if (pageContext.mounted) {
      _showSnackBar(pageContext, 'Sync device removed.');
    }
  } on SyncDeviceException catch (error) {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, error.message);
    }
  } on Object {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, 'Sync device could not be removed.');
    }
  }
}

Future<void> _rotateSyncDevice(BuildContext context, WidgetRef ref) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Reset sync device?',
    body:
        'This removes the current device registration from encrypted sync and creates a new local device identity. Other devices will see the old device as removed.',
    confirmLabel: 'Reset',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    await ref.read(syncDeviceServiceProvider).rotateLocalDeviceRegistration();
    ref.invalidate(syncKnownDevicesProvider);
    ref.invalidate(autoSyncControllerProvider);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    if (context.mounted) {
      _showSnackBar(
        context,
        'Sync device reset. A new registration will be created on the next sync.',
      );
    }
  } on SyncDeviceException catch (error) {
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Sync device could not be reset.');
    }
  }
}

class _SyncDevicesDialog extends StatelessWidget {
  const _SyncDevicesDialog({
    required this.devices,
    required this.localDeviceId,
    required this.onDelete,
  });

  final List<SyncDeviceMetadata> devices;
  final String? localDeviceId;
  final Future<void> Function(SyncDeviceMetadata device) onDelete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Devices'),
      content: SizedBox(
        width: 520,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            final isLocal = device.id == localDeviceId;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isLocal
                    ? '${device.displayName} (this device)'
                    : device.displayName,
              ),
              subtitle: Text(_syncDeviceSubtitle(device)),
              trailing: isLocal
                  ? null
                  : IconButton(
                      tooltip: 'Remove device',
                      onPressed: () => onDelete(device),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

String _syncDeviceSubtitle(SyncDeviceMetadata device) {
  return '${device.platform} / last seen ${_shortLocalDateTime(device.lastSeenAt)}';
}

String _shortLocalDateTime(DateTime value) {
  return value.toLocal().toIso8601String().split('.').first;
}

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebDavSyncDialog(initialSettings: settings),
  );
}

class _WebDavSyncDialog extends ConsumerStatefulWidget {
  const _WebDavSyncDialog({required this.initialSettings});

  final WebDavSyncSettings? initialSettings;

  @override
  ConsumerState<_WebDavSyncDialog> createState() => _WebDavSyncDialogState();
}

class _WebDavSyncDialogState extends ConsumerState<_WebDavSyncDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _basePathController;
  late bool _enabled;
  late bool _allowInsecureHttp;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _endpointController = TextEditingController(
      text: settings?.endpoint.toString() ?? '',
    );
    _usernameController = TextEditingController(text: settings?.username ?? '');
    _passwordController = TextEditingController();
    _basePathController = TextEditingController(
      text: settings?.basePath ?? '/serlink',
    );
    _enabled = settings?.enabled ?? true;
    _allowInsecureHttp = settings?.allowInsecureHttp ?? false;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV Sync'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('webdav-endpoint-field'),
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: 'https://example.com/webdav',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-password-field'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Password (leave blank to keep)'
                    : 'Password',
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-base-path-field'),
              controller: _basePathController,
              decoration: const InputDecoration(labelText: 'Base path'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('Enable WebDAV sync'),
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowInsecureHttp,
              title: const Text('Allow HTTP endpoint'),
              onChanged: (value) {
                setState(() {
                  _allowInsecureHttp = value ?? false;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: 'Use HTTP WebDAV?',
        body:
            'HTTP sync can expose metadata and credentials in transit. Use only for trusted local test servers.',
        confirmLabel: 'Allow HTTP',
        destructive: true,
      );
      if (!confirmed) {
        return;
      }
      allowInsecureHttp = true;
      if (mounted) {
        setState(() {
          _allowInsecureHttp = true;
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            WebDavSyncSettingsDraft(
              endpoint: _endpointController.text,
              username: _usernameController.text,
              password: _passwordController.text,
              basePath: _basePathController.text,
              allowInsecureHttp: allowInsecureHttp,
              enabled: _enabled,
            ),
          );
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings saved.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDialog(
      context,
      title: 'Remove WebDAV sync?',
      body: 'This removes the local WebDAV configuration and stored password.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(syncSettingsServiceProvider).deleteWebDav();
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings removed.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }
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
