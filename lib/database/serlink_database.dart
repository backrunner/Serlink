import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/runtime/app_profile_lock.dart';
import '../core/security/local_file_security.dart';
import 'database_recovery.dart';

part 'serlink_database.g.dart';

@DataClassName('VaultHeaderRow')
class VaultHeaders extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EncryptedRecordRow')
class EncryptedRecords extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get revision => text()();
  BlobColumn get nonce => blob()();
  BlobColumn get mac => blob()();
  BlobColumn get associatedData => blob()();
  BlobColumn get ciphertext => blob()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('VaultBackupEntryRow')
class VaultBackupEntries extends Table {
  TextColumn get id => text()();
  TextColumn get path => text()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sizeBytes => integer()();
  IntColumn get sourceSchemaVersion => integer().nullable()();
  IntColumn get targetSchemaVersion => integer().nullable()();
  BoolColumn get automatic => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('QuarantinedRecordRow')
class QuarantinedRecords extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get revision => text()();
  BlobColumn get nonce => blob()();
  BlobColumn get mac => blob()();
  BlobColumn get associatedData => blob()();
  BlobColumn get ciphertext => blob()();
  DateTimeColumn get quarantinedAt => dateTime()();
  TextColumn get reason => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    VaultHeaders,
    EncryptedRecords,
    VaultBackupEntries,
    QuarantinedRecords,
  ],
)
class SerlinkDatabase extends _$SerlinkDatabase {
  SerlinkDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  static const currentSchemaVersion = 5;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSyncAuxiliaryTables();
    },
    onUpgrade: (migrator, from, to) async {
      var current = from;
      if (current == 1 && to >= 2) {
        await transaction(() async {
          await migrator.createTable(vaultBackupEntries);
          await migrator.createTable(quarantinedRecords);
        });
        current = 2;
      }
      if (current == 2 && to >= 3) {
        await _createSyncAuxiliaryTables();
        current = 3;
      }
      if (current == 3 && to >= 4) {
        await _createLocalPreferenceTables();
        current = 4;
      }
      if (current == 4 && to >= 5) {
        await _createLocalWebDavSyncSettingsTable();
        current = 5;
      }
      if (current == to) {
        return;
      }
      throw DatabaseIntegrityException(
        'database.unsupported_migration',
        'Unsupported Serlink database migration.',
        diagnostic: 'from=$from to=$to',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createSyncAuxiliaryTables() async {
    await transaction(() async {
      await customStatement('''
CREATE TABLE IF NOT EXISTS sync_staged_snapshots (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  manifest BLOB NOT NULL,
  manifest_fingerprint TEXT NOT NULL,
  protocol_version INTEGER NOT NULL,
  header_path TEXT,
  completed_at TEXT NOT NULL,
  PRIMARY KEY (provider_kind, vault_id)
)
''');
      await customStatement('''
CREATE TABLE IF NOT EXISTS sync_staged_objects (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  path TEXT NOT NULL,
  bytes BLOB NOT NULL,
  PRIMARY KEY (provider_kind, vault_id, path),
  FOREIGN KEY (provider_kind, vault_id)
    REFERENCES sync_staged_snapshots(provider_kind, vault_id)
    ON DELETE CASCADE
)
''');
      await customStatement('''
CREATE TABLE IF NOT EXISTS sync_pending_resets (
  provider_kind TEXT NOT NULL,
  vault_id TEXT NOT NULL,
  marker BLOB NOT NULL,
  reset_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (provider_kind, vault_id)
)
''');
      await customStatement('''
CREATE TABLE IF NOT EXISTS cloudkit_sync_shadow_settings (
  vault_id TEXT NOT NULL PRIMARY KEY,
  enabled INTEGER NOT NULL,
  updated_at TEXT NOT NULL
)
''');
      await _createLocalPreferenceTables();
    });
  }

  Future<void> _createLocalPreferenceTables() async {
    await customStatement('''
CREATE TABLE IF NOT EXISTS local_cloudkit_sync_settings (
  id TEXT NOT NULL PRIMARY KEY,
  enabled INTEGER NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await _createLocalWebDavSyncSettingsTable();
    await customStatement('''
CREATE TABLE IF NOT EXISTS local_terminal_display_settings (
  id TEXT NOT NULL PRIMARY KEY,
  json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  Future<void> _createLocalWebDavSyncSettingsTable() async {
    await customStatement('''
CREATE TABLE IF NOT EXISTS local_webdav_sync_settings (
  id TEXT NOT NULL PRIMARY KEY,
  json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }
}

class SerlinkDatabasePaths {
  const SerlinkDatabasePaths({
    required this.directory,
    required this.databaseFile,
    required this.lockFile,
    required this.automaticBackupDirectory,
    required this.quarantineDirectory,
  });

  final Directory directory;
  final File databaseFile;
  final File lockFile;
  final Directory automaticBackupDirectory;
  final Directory quarantineDirectory;
}

Future<SerlinkDatabasePaths> resolveSerlinkDatabasePaths() async {
  final appDir = await getApplicationSupportDirectory();
  final dbDir = Directory(p.join(appDir.path, 'Serlink'));
  return SerlinkDatabasePaths(
    directory: dbDir,
    databaseFile: File(p.join(dbDir.path, 'serlink.sqlite')),
    lockFile: File(p.join(dbDir.path, 'serlink.lock')),
    automaticBackupDirectory: Directory(
      p.join(dbDir.path, 'backups', 'automatic'),
    ),
    quarantineDirectory: Directory(p.join(dbDir.path, 'quarantine')),
  );
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final paths = await resolveSerlinkDatabasePaths();
    await LocalFileSecurity.preparePrivateDirectory(paths.directory);
    await LocalFileSecurity.restrictFile(paths.databaseFile);
    final profileLock = AppProfileLock.acquire(paths.lockFile);
    await DatabaseMigrationPreflight(
      databaseFile: paths.databaseFile,
      automaticBackupDirectory: paths.automaticBackupDirectory,
    ).run(targetSchemaVersion: SerlinkDatabase.currentSchemaVersion);
    final database = NativeDatabase.createInBackground(
      paths.databaseFile,
    ).interceptWith(_CloseCallbackQueryInterceptor(profileLock.release));
    return database;
  });
}

class _CloseCallbackQueryInterceptor extends QueryInterceptor {
  _CloseCallbackQueryInterceptor(this._callback);

  final Future<void> Function() _callback;
  var _closed = false;

  @override
  Future<void> close(QueryExecutor inner) async {
    if (_closed) {
      return;
    }
    _closed = true;
    try {
      await inner.close();
    } finally {
      await _callback();
    }
  }
}
