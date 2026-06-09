import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/database/database_recovery.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File databaseFile;
  late Directory backupsDir;
  late Directory quarantineDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'serlink-database-recovery-test-',
    );
    databaseFile = File(p.join(tempDir.path, 'serlink.sqlite'));
    backupsDir = Directory(p.join(tempDir.path, 'backups', 'automatic'));
    quarantineDir = Directory(p.join(tempDir.path, 'quarantine'));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DatabaseMigrationPreflight', () {
    test('maps non-SQLite files to database.not_a_database', () async {
      await databaseFile.writeAsString('not a sqlite database', flush: true);

      final preflight = DatabaseMigrationPreflight(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
      );

      await expectLater(
        preflight.run(targetSchemaVersion: 2),
        throwsA(
          isA<DatabaseIntegrityException>().having(
            (error) => error.code,
            'code',
            'database.not_a_database',
          ),
        ),
      );
    });

    test('rejects unsupported future schema versions', () async {
      _withDatabase(databaseFile, (database) {
        database.execute('PRAGMA user_version = 99');
      });

      final preflight = DatabaseMigrationPreflight(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
      );

      await expectLater(
        preflight.run(targetSchemaVersion: 2),
        throwsA(
          isA<DatabaseIntegrityException>().having(
            (error) => error.code,
            'code',
            'database.unsupported_version',
          ),
        ),
      );
    });

    test('creates a verified snapshot before migration', () async {
      _withDatabase(databaseFile, (database) {
        database
          ..execute('CREATE TABLE markers (value TEXT NOT NULL)')
          ..execute("INSERT INTO markers (value) VALUES ('before')")
          ..execute('PRAGMA user_version = 1');
      });

      final preflight = DatabaseMigrationPreflight(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
        now: () => DateTime.utc(2026, 6, 9, 1, 2, 3),
      );

      await preflight.run(targetSchemaVersion: 2);

      final backups = await DatabaseRecoveryService(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
        quarantineDirectory: quarantineDir,
      ).listAutomaticBackups();
      expect(backups, hasLength(1));
      expect(backups.single.reason, 'before-db-v1-to-v2');
      expect(backups.single.sourceSchemaVersion, 1);
      expect(backups.single.targetSchemaVersion, 2);
      expect(await File(backups.single.sidecarPath).exists(), isTrue);
      expect(_readMarker(File(backups.single.path)), 'before');
    });
  });

  group('DatabaseRecoveryService', () {
    test('restores the main database from an automatic backup', () async {
      _withDatabase(databaseFile, (database) {
        database
          ..execute('CREATE TABLE markers (value TEXT NOT NULL)')
          ..execute("INSERT INTO markers (value) VALUES ('original')")
          ..execute('PRAGMA user_version = 2');
      });

      final recovery = DatabaseRecoveryService(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
        quarantineDirectory: quarantineDir,
        now: () => DateTime.utc(2026, 6, 9, 2, 0),
      );
      final backup = await recovery.createSnapshot(reason: 'automatic');

      _withDatabase(databaseFile, (database) {
        database.execute("UPDATE markers SET value = 'changed'");
      });

      await recovery.restoreFromBackup(backup);

      expect(_readMarker(databaseFile), 'original');
      final backups = await recovery.listAutomaticBackups();
      expect(
        backups.map((entry) => entry.reason),
        containsAll(<String>['automatic', 'before-restore']),
      );
    });

    test('keeps current database when replacement is invalid', () async {
      _withDatabase(databaseFile, (database) {
        database
          ..execute('CREATE TABLE markers (value TEXT NOT NULL)')
          ..execute("INSERT INTO markers (value) VALUES ('safe')")
          ..execute('PRAGMA user_version = 2');
      });
      final invalidReplacement = File(p.join(tempDir.path, 'invalid.sqlite'));
      await invalidReplacement.writeAsString('not sqlite', flush: true);

      final recovery = DatabaseRecoveryService(
        databaseFile: databaseFile,
        automaticBackupDirectory: backupsDir,
        quarantineDirectory: quarantineDir,
      );

      await expectLater(
        recovery.replaceWithVerifiedDatabase(invalidReplacement),
        throwsA(isA<DatabaseIntegrityException>()),
      );

      expect(_readMarker(databaseFile), 'safe');
    });
  });
}

void _withDatabase(File file, void Function(Database database) body) {
  final database = sqlite3.open(file.path);
  try {
    body(database);
  } finally {
    database.close();
  }
}

String _readMarker(File file) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return database.select('SELECT value FROM markers').single.values.single
        as String;
  } finally {
    database.close();
  }
}
