import 'dart:io';

class LocalFileSecurity {
  const LocalFileSecurity._();

  static Future<void> preparePrivateDirectory(Directory directory) async {
    await directory.create(recursive: true);
    await _chmod(directory.path, '700');
  }

  static Future<void> restrictFile(File file) async {
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await _chmod(file.path, '600');
  }

  static Future<void> restrictExistingFile(File file) async {
    if (await file.exists()) {
      await _chmod(file.path, '600');
    }
  }

  static Future<void> _chmod(String path, String mode) async {
    if (Platform.isWindows || Platform.isIOS) {
      return;
    }
    try {
      await Process.run('chmod', [mode, path]);
    } on Object {
      // Permission tightening is best-effort across sandboxed or unusual
      // desktop environments. The caller still proceeds with encrypted data.
    }
  }
}
