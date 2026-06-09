import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/security/local_file_security.dart';

enum VaultRecoveryStatus {
  healthy,
  databaseCorrupt,
  vaultHeaderInvalid,
  recordsCorrupt,
  remoteCorrupt,
}

class DatabaseIntegrityException implements Exception {
  const DatabaseIntegrityException(
    this.code,
    this.message, {
    this.path,
    this.diagnostic,
  });

  final String code;
  final String message;
  final String? path;
  final String? diagnostic;

  VaultRecoveryStatus get recoveryStatus {
    return switch (code) {
      'database.integrity_failed' ||
      'database.not_a_database' ||
      'database.open_failed' ||
      'database.backup_failed' => VaultRecoveryStatus.databaseCorrupt,
      _ => VaultRecoveryStatus.databaseCorrupt,
    };
  }

  @override
  String toString() {
    final path = this.path == null ? '' : ', path: ${this.path}';
    final diagnostic = this.diagnostic == null
        ? ''
        : ', diagnostic: ${this.diagnostic}';
    return 'DatabaseIntegrityException($code$path$diagnostic): $message';
  }
}

class DatabaseBackupEntry {
  const DatabaseBackupEntry({
    required this.path,
    required this.reason,
    required this.createdAt,
    required this.sizeBytes,
    this.sourceSchemaVersion,
    this.targetSchemaVersion,
  });

  final String path;
  final String reason;
  final DateTime createdAt;
  final int sizeBytes;
  final int? sourceSchemaVersion;
  final int? targetSchemaVersion;

  String get sidecarPath => '$path.json';

  Map<String, Object?> toJson() {
    return {
      'path': path,
      'reason': reason,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'sizeBytes': sizeBytes,
      'sourceSchemaVersion': sourceSchemaVersion,
      'targetSchemaVersion': targetSchemaVersion,
    };
  }

  factory DatabaseBackupEntry.fromJson(Map<String, Object?> json) {
    return DatabaseBackupEntry(
      path: json['path'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sizeBytes: json['sizeBytes'] as int,
      sourceSchemaVersion: json['sourceSchemaVersion'] as int?,
      targetSchemaVersion: json['targetSchemaVersion'] as int?,
    );
  }
}

class DatabaseMigrationPreflight {
  const DatabaseMigrationPreflight({
    required this.databaseFile,
    required this.automaticBackupDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final File databaseFile;
  final Directory automaticBackupDirectory;
  final DateTime Function() _now;

  Future<void> run({required int targetSchemaVersion}) async {
    if (!await databaseFile.exists()) {
      return;
    }
    final database = _openDatabase(databaseFile, writeable: true);
    try {
      final userVersion = _readUserVersion(database, databaseFile.path);
      if (userVersion > targetSchemaVersion) {
        throw DatabaseIntegrityException(
          'database.unsupported_version',
          'This Serlink database was created by a newer app version.',
          path: databaseFile.path,
          diagnostic: 'userVersion=$userVersion target=$targetSchemaVersion',
        );
      }
      _runQuickCheck(database, databaseFile.path);
      if (userVersion == 0) {
        return;
      }
      if (userVersion < targetSchemaVersion) {
        await DatabaseRecoveryService.snapshotOnly(
          databaseFile: databaseFile,
          automaticBackupDirectory: automaticBackupDirectory,
          now: _now,
        ).createSnapshot(
          reason: 'before-db-v$userVersion-to-v$targetSchemaVersion',
          sourceSchemaVersion: userVersion,
          targetSchemaVersion: targetSchemaVersion,
          openDatabase: database,
        );
      }
    } finally {
      database.close();
    }
  }
}

class DatabaseRecoveryService {
  const DatabaseRecoveryService({
    required this.databaseFile,
    required this.automaticBackupDirectory,
    required this.quarantineDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  const DatabaseRecoveryService._snapshotOnly({
    required this.databaseFile,
    required this.automaticBackupDirectory,
    DateTime Function()? now,
  }) : quarantineDirectory = null,
       _now = now ?? DateTime.now;

  final File databaseFile;
  final Directory automaticBackupDirectory;
  final Directory? quarantineDirectory;
  final DateTime Function() _now;

  Future<DatabaseBackupEntry> createSnapshot({
    required String reason,
    int? sourceSchemaVersion,
    int? targetSchemaVersion,
    Database? openDatabase,
  }) async {
    if (!await databaseFile.exists()) {
      throw DatabaseIntegrityException(
        'database.backup_failed',
        'Cannot back up a missing database file.',
        path: databaseFile.path,
      );
    }
    await automaticBackupDirectory.create(recursive: true);
    final createdAt = _now().toUtc();
    final backupFile = File(
      p.join(
        automaticBackupDirectory.path,
        '${_timestamp(createdAt)}-$reason.sqlite',
      ),
    );
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    final database =
        openDatabase ?? _openDatabase(databaseFile, writeable: true);
    var shouldDispose = openDatabase == null;
    try {
      database.execute('VACUUM INTO ?', [backupFile.path]);
      await LocalFileSecurity.restrictExistingFile(backupFile);
      final entry = DatabaseBackupEntry(
        path: backupFile.path,
        reason: reason,
        createdAt: createdAt,
        sizeBytes: await backupFile.length(),
        sourceSchemaVersion:
            sourceSchemaVersion ??
            _readUserVersion(database, databaseFile.path),
        targetSchemaVersion: targetSchemaVersion,
      );
      await File(
        entry.sidecarPath,
      ).writeAsString(jsonEncode(entry.toJson()), flush: true);
      await LocalFileSecurity.restrictExistingFile(File(entry.sidecarPath));
      return entry;
    } on DatabaseIntegrityException {
      rethrow;
    } on Object catch (error) {
      throw DatabaseIntegrityException(
        'database.backup_failed',
        'Database backup failed.',
        path: databaseFile.path,
        diagnostic: error.toString(),
      );
    } finally {
      if (shouldDispose) {
        database.close();
      }
    }
  }

  Future<List<DatabaseBackupEntry>> listAutomaticBackups() async {
    if (!await automaticBackupDirectory.exists()) {
      return const [];
    }
    final entries = <DatabaseBackupEntry>[];
    await for (final entity in automaticBackupDirectory.list()) {
      if (entity is! File || !entity.path.endsWith('.sqlite.json')) {
        continue;
      }
      try {
        final json = jsonDecode(await entity.readAsString());
        entries.add(DatabaseBackupEntry.fromJson(json as Map<String, Object?>));
      } on Object {
        continue;
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<DatabaseBackupEntry?> latestAutomaticBackup() async {
    final backups = await listAutomaticBackups();
    return backups.isEmpty ? null : backups.first;
  }

  Future<void> restoreFromBackup(DatabaseBackupEntry entry) async {
    final backup = File(entry.path);
    if (!await backup.exists()) {
      throw DatabaseIntegrityException(
        'database.restore_failed',
        'Selected database backup is missing.',
        path: entry.path,
      );
    }
    await replaceWithVerifiedDatabase(backup);
  }

  Future<void> replaceWithVerifiedDatabase(File replacement) async {
    final safetyCopy = await _createBeforeRestoreSafetyCopy();
    try {
      _verifyBackup(replacement);
      await databaseFile.parent.create(recursive: true);
      await _deleteIfExists(File('${databaseFile.path}-wal'));
      await _deleteIfExists(File('${databaseFile.path}-shm'));
      await replacement.copy(databaseFile.path);
      await LocalFileSecurity.restrictExistingFile(databaseFile);
      final restored = _openDatabase(databaseFile, writeable: true);
      try {
        _runQuickCheck(restored, databaseFile.path);
      } finally {
        restored.close();
      }
    } on Object {
      await _rollbackRestore(safetyCopy);
      rethrow;
    }
  }

  Future<void> quarantineCurrentDatabase({required String reason}) async {
    final quarantineDirectory = this.quarantineDirectory;
    if (quarantineDirectory == null) {
      return;
    }
    await quarantineDirectory.create(recursive: true);
    final stamp = _timestamp(_now().toUtc());
    final targetDirectory = Directory(
      p.join(quarantineDirectory.path, '$stamp-$reason'),
    );
    await targetDirectory.create(recursive: true);
    for (final suffix in const ['', '-wal', '-shm']) {
      final source = File('${databaseFile.path}$suffix');
      if (await source.exists()) {
        await source.copy(
          p.join(targetDirectory.path, p.basename(source.path)),
        );
      }
    }
  }

  Future<void> deleteMainDatabaseFiles() async {
    for (final suffix in const ['', '-wal', '-shm']) {
      await _deleteIfExists(File('${databaseFile.path}$suffix'));
    }
  }

  Future<DatabaseBackupEntry?> _createBeforeRestoreSafetyCopy() async {
    try {
      return await createSnapshot(reason: 'before-restore');
    } on Object {
      await quarantineCurrentDatabase(reason: 'before-restore');
      return null;
    }
  }

  Future<void> _rollbackRestore(DatabaseBackupEntry? safetyCopy) async {
    if (safetyCopy == null) {
      await quarantineCurrentDatabase(reason: 'restore-failed');
      return;
    }
    final backup = File(safetyCopy.path);
    if (!await backup.exists()) {
      await quarantineCurrentDatabase(reason: 'restore-failed');
      return;
    }
    await _deleteIfExists(File('${databaseFile.path}-wal'));
    await _deleteIfExists(File('${databaseFile.path}-shm'));
    await backup.copy(databaseFile.path);
    await LocalFileSecurity.restrictExistingFile(databaseFile);
  }

  void _verifyBackup(File backup) {
    final database = _openDatabase(backup, writeable: false);
    try {
      _runQuickCheck(database, backup.path);
    } finally {
      database.close();
    }
  }

  static DatabaseRecoveryService snapshotOnly({
    required File databaseFile,
    required Directory automaticBackupDirectory,
    DateTime Function()? now,
  }) {
    return DatabaseRecoveryService._snapshotOnly(
      databaseFile: databaseFile,
      automaticBackupDirectory: automaticBackupDirectory,
      now: now,
    );
  }
}

Database _openDatabase(File file, {required bool writeable}) {
  try {
    return sqlite3.open(
      file.path,
      mode: writeable ? OpenMode.readWrite : OpenMode.readOnly,
    );
  } on SqliteException catch (error) {
    throw _mapSqliteException(error, file.path);
  }
}

int _readUserVersion(Database database, String path) {
  try {
    final row = database.select('PRAGMA user_version').first;
    return row.values.first as int;
  } on SqliteException catch (error) {
    throw _mapSqliteException(error, path);
  }
}

void _runQuickCheck(Database database, String path) {
  try {
    final rows = database.select('PRAGMA quick_check');
    final failures = [
      for (final row in rows)
        if (row.values.first != 'ok') row.values.first.toString(),
    ];
    if (failures.isNotEmpty) {
      throw DatabaseIntegrityException(
        'database.integrity_failed',
        'Serlink database integrity check failed.',
        path: path,
        diagnostic: failures.join('\n'),
      );
    }
  } on DatabaseIntegrityException {
    rethrow;
  } on SqliteException catch (error) {
    throw _mapSqliteException(error, path);
  }
}

DatabaseIntegrityException _mapSqliteException(
  SqliteException error,
  String path,
) {
  final code = switch (error.resultCode) {
    SqlError.SQLITE_NOTADB => 'database.not_a_database',
    SqlError.SQLITE_CORRUPT => 'database.integrity_failed',
    SqlError.SQLITE_CANTOPEN => 'database.open_failed',
    _ => 'database.open_failed',
  };
  final message = switch (code) {
    'database.not_a_database' => 'Serlink database file is not a database.',
    'database.integrity_failed' => 'Serlink database is corrupted.',
    _ => 'Serlink database could not be opened.',
  };
  return DatabaseIntegrityException(
    code,
    message,
    path: path,
    diagnostic: error.toString(),
  );
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

String _timestamp(DateTime dateTime) {
  final utc = dateTime.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}
