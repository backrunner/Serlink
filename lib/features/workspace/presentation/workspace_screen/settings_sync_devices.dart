part of '../workspace_screen.dart';

String _syncDevicesSubtitle(
  AppLocalizations l10n,
  List<SyncDeviceMetadata> devices,
) {
  if (devices.isEmpty) {
    return l10n.syncDevicesWillRegister;
  }
  if (devices.length == 1) {
    return l10n.syncDeviceSingleSubtitle(devices.single.displayName);
  }
  final latest = [...devices]
    ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  return l10n.syncDevicesMultipleSubtitle(
    devices.length,
    latest.first.displayName,
  );
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
  await showSerlinkDialog<void>(
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
  final l10n = pageContext.l10n;
  final confirmed = await _confirmDialog(
    dialogContext,
    title: l10n.syncDeviceRemoveTitle(device.displayName),
    body: l10n.syncDeviceRemoveBody,
    confirmLabel: l10n.removeAction,
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
      _showSnackBar(pageContext, l10n.syncDeviceRemovedSnack);
    }
  } on SyncDeviceException catch (error) {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, error.message);
    }
  } on Object {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, l10n.syncDeviceRemoveFailedSnack);
    }
  }
}

Future<void> _rotateSyncDevice(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await _confirmDialog(
    context,
    title: l10n.syncDeviceResetTitle,
    body: l10n.syncDeviceResetBody,
    confirmLabel: l10n.syncResetAction,
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
      _showSnackBar(context, l10n.syncDeviceResetSnack);
    }
  } on SyncDeviceException catch (error) {
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, l10n.syncDeviceResetFailedSnack);
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
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthSmall),
      title: Text(l10n.syncDevicesDialogTitle),
      content: SizedBox(
        width: 520,
        child: _DialogList(
          empty: _DialogState(
            icon: Icons.devices_other_outlined,
            title: l10n.syncDevicesEmptyTitle,
            body: l10n.syncDevicesEmptyBody,
          ),
          items: [
            for (final device in devices)
              _DialogListItem(
                icon: Icons.devices_outlined,
                title: device.id == localDeviceId
                    ? l10n.syncDeviceThisDevice(device.displayName)
                    : device.displayName,
                subtitle: _syncDeviceSubtitle(l10n, device),
                trailing: device.id == localDeviceId
                    ? null
                    : SerlinkIconButton(
                        tooltip: l10n.syncDeviceRemoveTooltip,
                        onPressed: () => onDelete(device),
                        icon: const Icon(Icons.delete_outline, size: 18),
                      ),
              ),
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.closeAction),
        ),
      ],
    );
  }
}

String _syncDeviceSubtitle(AppLocalizations l10n, SyncDeviceMetadata device) {
  return l10n.syncDeviceSubtitle(
    device.platform,
    _shortLocalDateTime(device.lastSeenAt),
  );
}

String _shortLocalDateTime(DateTime value) {
  return value.toLocal().toIso8601String().split('.').first;
}
