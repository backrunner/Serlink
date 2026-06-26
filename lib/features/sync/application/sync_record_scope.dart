import '../../../core/ids/entity_id.dart';

const syncSettingsRecordType = 'sync_settings';
const cloudKitSyncSettingsRecordValue = 'sync:cloudkit';
const webDavSyncSettingsRecordValue = 'sync:webdav';

final cloudKitSyncSettingsRecordId = VaultRecordId(
  cloudKitSyncSettingsRecordValue,
);
final webDavSyncSettingsRecordId = VaultRecordId(webDavSyncSettingsRecordValue);

bool isLocalOnlySyncRecord({required VaultRecordId id, required String type}) {
  return type == syncSettingsRecordType &&
      (id == cloudKitSyncSettingsRecordId || id == webDavSyncSettingsRecordId);
}
