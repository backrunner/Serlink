import 'package:drift/drift.dart';

import '../../../database/serlink_database.dart';
import '../application/sync_settings_service.dart';

class LocalCloudKitSyncSettingsRepository
    implements CloudKitSyncSettingsRepository {
  const LocalCloudKitSyncSettingsRepository(this._database);

  static const _rowId = 'default';

  final SerlinkDatabase _database;

  @override
  Future<CloudKitSyncSettings?> readCloudKit() async {
    final rows = await _database
        .customSelect(
          '''
SELECT enabled, updated_at
FROM local_cloudkit_sync_settings
WHERE id = ?
''',
          variables: const [Variable(_rowId)],
          readsFrom: const {},
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return CloudKitSyncSettings(
      enabled: row.read<int>('enabled') != 0,
      updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
    );
  }

  @override
  Future<void> saveCloudKit(CloudKitSyncSettings settings) async {
    await _database.customStatement(
      '''
INSERT OR REPLACE INTO local_cloudkit_sync_settings (
  id,
  enabled,
  updated_at
) VALUES (?, ?, ?)
''',
      [
        _rowId,
        settings.enabled ? 1 : 0,
        settings.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> deleteCloudKit() async {
    await _database.customStatement(
      '''
DELETE FROM local_cloudkit_sync_settings
WHERE id = ?
''',
      [_rowId],
    );
  }
}
