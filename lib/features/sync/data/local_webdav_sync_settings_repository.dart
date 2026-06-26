import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/serlink_database.dart';
import '../application/sync_settings_service.dart';

class LocalWebDavSyncSettingsRepository implements SyncSettingsRepository {
  const LocalWebDavSyncSettingsRepository(this._database);

  static const _rowId = 'default';

  final SerlinkDatabase _database;

  @override
  Future<WebDavSyncSettings?> readWebDav() async {
    final rows = await _database
        .customSelect(
          '''
SELECT json
FROM local_webdav_sync_settings
WHERE id = ?
''',
          variables: const [Variable(_rowId)],
          readsFrom: const {},
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    return WebDavSyncSettings.fromJson(
      jsonDecode(rows.single.read<String>('json')) as Map<String, Object?>,
    );
  }

  @override
  Future<void> saveWebDav(WebDavSyncSettings settings) async {
    await _database.customStatement(
      '''
INSERT OR REPLACE INTO local_webdav_sync_settings (
  id,
  json,
  updated_at
) VALUES (?, ?, ?)
''',
      [
        _rowId,
        jsonEncode(settings.toJson()),
        settings.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> deleteWebDav() async {
    await _database.customStatement(
      '''
DELETE FROM local_webdav_sync_settings
WHERE id = ?
''',
      [_rowId],
    );
  }
}
