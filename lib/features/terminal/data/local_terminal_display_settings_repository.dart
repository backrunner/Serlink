import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/serlink_database.dart';
import '../application/terminal_display_settings.dart';

class LocalTerminalDisplaySettingsRepository
    implements TerminalDisplaySettingsRepository {
  const LocalTerminalDisplaySettingsRepository(this._database);

  static const _rowId = 'default';

  final SerlinkDatabase _database;

  @override
  Future<TerminalDisplaySettings?> read() async {
    final rows = await _database
        .customSelect(
          '''
SELECT json
FROM local_terminal_display_settings
WHERE id = ?
''',
          variables: const [Variable(_rowId)],
          readsFrom: const {},
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }
    return TerminalDisplaySettings.fromJson(
      jsonDecode(rows.single.read<String>('json')) as Map<String, Object?>,
    );
  }

  @override
  Future<void> save(TerminalDisplaySettings settings) async {
    await _database.customStatement(
      '''
INSERT OR REPLACE INTO local_terminal_display_settings (
  id,
  json,
  updated_at
) VALUES (?, ?, ?)
''',
      [
        _rowId,
        jsonEncode(settings.toJson()),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> delete() async {
    await _database.customStatement(
      '''
DELETE FROM local_terminal_display_settings
WHERE id = ?
''',
      [_rowId],
    );
  }
}
