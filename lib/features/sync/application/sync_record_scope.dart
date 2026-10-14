import '../../../core/ids/entity_id.dart';

const syncSettingsRecordType = 'sync_settings';
const cloudKitSyncSettingsRecordValue = 'sync:cloudkit';
const webDavSyncSettingsRecordValue = 'sync:webdav';

final cloudKitSyncSettingsRecordId = VaultRecordId(
  cloudKitSyncSettingsRecordValue,
);
final webDavSyncSettingsRecordId = VaultRecordId(webDavSyncSettingsRecordValue);

bool isLocalOnlySyncRecord({required VaultRecordId id, required String type}) {
  // Older apps stored transfer history in the shared vault. Ignore those
  // records and their tombstones in both directions, including stale snapshots.
  return type == 'transfer_task' ||
      id.value.startsWith('transfer_task:') ||
      id.value.startsWith('sync:tombstone:transfer_task%3A') ||
      (type == syncSettingsRecordType &&
          (id == cloudKitSyncSettingsRecordId ||
              id == webDavSyncSettingsRecordId));
}
