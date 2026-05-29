import '../../../core/ids/entity_id.dart';
import '../domain/sftp_entry.dart';

enum TransferDirection { upload, download }

enum TransferItemKind { file, directory }

enum TransferState { queued, running, paused, completed, failed, canceled }

const defaultSftpPreviewBytes = 64 * 1024;

class SftpFilePreview {
  const SftpFilePreview({
    required this.text,
    required this.bytesRead,
    required this.truncated,
  });

  final String text;
  final int bytesRead;
  final bool truncated;
}

class TransferProgress {
  const TransferProgress({
    required this.taskId,
    required this.state,
    required this.transferredBytes,
    this.totalBytes,
  });

  final TransferTaskId taskId;
  final TransferState state;
  final int transferredBytes;
  final int? totalBytes;
}

abstract interface class SftpConnection {
  Future<void> get done;
  Future<List<SftpEntry>> list(String path);
  Future<void> mkdir(String path);
  Future<void> rename(String oldPath, String newPath);
  Future<void> deleteFile(String path);
  Future<void> deleteDirectory(String path, {required bool recursive});
  Future<void> chmod(String path, SftpPermissions permissions);
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  });
  Future<void> writeTextFile(String path, String contents);
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  });
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  });
  Future<void> close();
}
