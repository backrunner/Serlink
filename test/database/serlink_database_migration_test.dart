import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/database/serlink_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates v2 databases to v4 auxiliary and preference tables', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-database-migration-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File(p.join(tempDir.path, 'serlink.sqlite'));
    _createV2Database(file);

    final database = SerlinkDatabase(NativeDatabase(file));
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    expect(await _userVersion(file), 4);
    expect(
      await _tableNames(file),
      containsAll(<String>[
        'sync_staged_snapshots',
        'sync_staged_objects',
        'sync_pending_resets',
        'cloudkit_sync_shadow_settings',
        'local_cloudkit_sync_settings',
        'local_terminal_display_settings',
      ]),
    );
  });

  test('migrates v3 databases to v4 local preference tables', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'serlink-database-migration-test-',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File(p.join(tempDir.path, 'serlink.sqlite'));
    _createV3Database(file);

    final database = SerlinkDatabase(NativeDatabase(file));
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    expect(await _userVersion(file), 4);
    expect(
      await _tableNames(file),
      containsAll([
        'local_cloudkit_sync_settings',
        'local_terminal_display_settings',
      ]),
    );
  });
}

void _createV2Database(File file) {
  final database = sqlite3.open(file.path);
  try {
    database
      ..execute('''
CREATE TABLE vault_headers (
  id TEXT NOT NULL PRIMARY KEY,
  json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''')
      ..execute('''
CREATE TABLE encrypted_records (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  revision TEXT NOT NULL,
  nonce BLOB NOT NULL,
  mac BLOB NOT NULL,
  associated_data BLOB NOT NULL,
  ciphertext BLOB NOT NULL,
  updated_at INTEGER NOT NULL
)
''')
      ..execute('''
CREATE TABLE vault_backup_entries (
  id TEXT NOT NULL PRIMARY KEY,
  path TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  size_bytes INTEGER NOT NULL,
  source_schema_version INTEGER,
  target_schema_version INTEGER,
  automatic INTEGER NOT NULL DEFAULT 1 CHECK (automatic IN (0, 1))
)
''')
      ..execute('''
CREATE TABLE quarantined_records (
  id TEXT NOT NULL PRIMARY KEY,
  type TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  revision TEXT NOT NULL,
  nonce BLOB NOT NULL,
  mac BLOB NOT NULL,
  associated_data BLOB NOT NULL,
  ciphertext BLOB NOT NULL,
  quarantined_at INTEGER NOT NULL,
  reason TEXT NOT NULL
)
''')
      ..execute('PRAGMA user_version = 2');
  } finally {
    database.close();
  }
}

void _createV3Database(File file) {
  _createV2Database(file);
  final database = sqlite3.open(file.path);
  try {
    database
      ..execute('''
CREATE TABLE sync_staged_snapshots (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  manifest BLOB NOT NULL,
  manifest_fingerprint TEXT NOT NULL,
  protocol_version INTEGER NOT NULL,
  header_path TEXT,
  completed_at TEXT NOT NULL,
  PRIMARY KEY (provider_kind, vault_id)
)
''')
      ..execute('''
CREATE TABLE sync_staged_objects (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  path TEXT NOT NULL,
  bytes BLOB NOT NULL,
  PRIMARY KEY (provider_kind, vault_id, path),
  FOREIGN KEY (provider_kind, vault_id)
    REFERENCES sync_staged_snapshots(provider_kind, vault_id)
    ON DELETE CASCADE
)
''')
      ..execute('''
CREATE TABLE sync_pending_resets (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  marker BLOB NOT NULL,
  reset_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (provider_kind, vault_id)
)
''')
      ..execute('''
CREATE TABLE cloudkit_sync_shadow_settings (
  vault_id TEXT NOT NULL PRIMARY KEY,
  enabled INTEGER NOT NULL,
  updated_at TEXT NOT NULL
)
''')
      ..execute('PRAGMA user_version = 3');
  } finally {
    database.close();
  }
}

Future<int> _userVersion(File file) async {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return database.select('PRAGMA user_version').first.values.single as int;
  } finally {
    database.close();
  }
}

Future<Set<String>> _tableNames(File file) async {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return {
      for (final row in database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
  } finally {
    database.close();
  }
}
