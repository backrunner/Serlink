import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../../database/database_recovery.dart';
import '../../../database/serlink_database.dart';
import '../../vault/data/drift_vault_repository.dart';
import 'vault_backup_service.dart';

class VaultBackupRestoreService {
  const VaultBackupRestoreService({
    required this.recovery,
    required this.temporaryDirectory,
  });

  final DatabaseRecoveryService recovery;
  final Directory temporaryDirectory;

  Future<void> restoreFromBackupBytes(List<int> bytes) async {
    final bundle = VaultBackupBundle.fromBytes(bytes);
    await temporaryDirectory.create(recursive: true);
    final tempDbFile = File(
      p.join(
        temporaryDirectory.path,
        'serlink-restore-${DateTime.now().toUtc().microsecondsSinceEpoch}.sqlite',
      ),
    );
    final tempDatabase = SerlinkDatabase(NativeDatabase(tempDbFile));
    try {
      await VaultBackupService(
        headers: DriftVaultHeaderStore(tempDatabase),
        records: DriftVaultRecordRepository(tempDatabase),
      ).importBackup(bundle);
    } finally {
      await tempDatabase.close();
    }
    try {
      await recovery.replaceWithVerifiedDatabase(tempDbFile);
    } finally {
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    }
  }
}
