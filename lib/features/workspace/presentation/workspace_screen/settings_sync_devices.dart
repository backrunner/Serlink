part of '../workspace_screen.dart';

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
    return SerlinkDialog(
      title: const Text('Sync Devices'),
      content: SizedBox(
        width: 520,
        child: _DialogList(
          empty: const _DialogState(
            icon: Icons.devices_other_outlined,
            title: 'No sync devices yet',
            body:
                'This device will be registered here after the first successful encrypted sync.',
          ),
          items: [
            for (final device in devices)
              _DialogListItem(
                icon: Icons.devices_outlined,
                title: device.id == localDeviceId
                    ? '${device.displayName} (this device)'
                    : device.displayName,
                subtitle: _syncDeviceSubtitle(device),
                trailing: device.id == localDeviceId
                    ? null
                    : SerlinkIconButton(
                        tooltip: 'Remove device',
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
