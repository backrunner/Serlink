import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/runtime/app_profile_lock.dart';
import '../core/security/local_file_security.dart';

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

@DriftDatabase(tables: [VaultHeaders, EncryptedRecords])
class SerlinkDatabase extends _$SerlinkDatabase {
  SerlinkDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;
}

class SerlinkDatabasePaths {
  const SerlinkDatabasePaths({
    required this.directory,
    required this.databaseFile,
    required this.lockFile,
  });

  final Directory directory;
  final File databaseFile;
  final File lockFile;
}

Future<SerlinkDatabasePaths> resolveSerlinkDatabasePaths() async {
  final appDir = await getApplicationSupportDirectory();
  final dbDir = Directory(p.join(appDir.path, 'Serlink'));
  return SerlinkDatabasePaths(
    directory: dbDir,
    databaseFile: File(p.join(dbDir.path, 'serlink.sqlite')),
    lockFile: File(p.join(dbDir.path, 'serlink.lock')),
  );
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final paths = await resolveSerlinkDatabasePaths();
    await LocalFileSecurity.preparePrivateDirectory(paths.directory);
    await LocalFileSecurity.restrictFile(paths.databaseFile);
    final profileLock = AppProfileLock.acquire(paths.lockFile);
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
