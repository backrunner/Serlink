import 'dart:io';

import '../../../database/database_recovery.dart';

class AutomaticVaultBackupService {
  const AutomaticVaultBackupService({
    required this.recovery,
    this.maxBackups = 10,
  });

  final DatabaseRecoveryService recovery;
  final int maxBackups;

  Future<DatabaseBackupEntry> createSnapshot({required String reason}) async {
    final entry = await recovery.createSnapshot(reason: reason);
    await prune();
    return entry;
  }

  Future<List<DatabaseBackupEntry>> list() {
    return recovery.listAutomaticBackups();
  }

  Future<DatabaseBackupEntry?> latest() {
    return recovery.latestAutomaticBackup();
  }

  Future<void> prune() async {
    final backups = await recovery.listAutomaticBackups();
    if (backups.length <= maxBackups) {
      return;
    }
    for (final backup in backups.skip(maxBackups)) {
      await _deleteIfExists(backup.path);
      await _deleteIfExists(backup.sidecarPath);
    }
  }
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
