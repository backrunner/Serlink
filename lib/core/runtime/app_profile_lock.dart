import 'dart:io';

class AppProfileLockException implements Exception {
  const AppProfileLockException(this.path);

  final String path;

  @override
  String toString() {
    return 'Serlink profile is already open by another process: $path';
  }
}

class AppProfileLock {
  AppProfileLock._(this.path, this._file);

  final String path;
  final RandomAccessFile? _file;

  static AppProfileLock acquire(File file) {
    if (Platform.isIOS) {
      file.createSync(recursive: true);
      return AppProfileLock._(file.path, null);
    }
    try {
      file.createSync(recursive: true);
      final handle = file.openSync(mode: FileMode.write);
      try {
        handle.lockSync(FileLock.exclusive);
        handle.truncateSync(0);
        handle.writeStringSync(
          'pid=$pid\nlockedAt=${DateTime.now().toUtc().toIso8601String()}\n',
        );
        handle.flushSync();
        return AppProfileLock._(file.path, handle);
      } on Object {
        handle.closeSync();
        throw AppProfileLockException(file.path);
      }
    } on AppProfileLockException {
      rethrow;
    } on Object {
      throw AppProfileLockException(file.path);
    }
  }

  Future<void> release() async {
    await _file?.close();
  }
}
