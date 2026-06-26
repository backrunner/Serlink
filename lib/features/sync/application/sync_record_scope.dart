import '../../../core/ids/entity_id.dart';

const syncSettingsRecordType = 'sync_settings';
const cloudKitSyncSettingsRecordValue = 'sync:cloudkit';

final cloudKitSyncSettingsRecordId = VaultRecordId(
  cloudKitSyncSettingsRecordValue,
);

bool isLocalOnlySyncRecord({required VaultRecordId id, required String type}) {
  return id == cloudKitSyncSettingsRecordId && type == syncSettingsRecordType;
}
