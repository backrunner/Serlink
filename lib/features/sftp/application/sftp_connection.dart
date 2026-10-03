import 'dart:convert';

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
    this.isText = true,
  });

  factory SftpFilePreview.fromBytes(
    List<int> bytes, {
    required bool truncated,
  }) {
    final buffer = StringBuffer();
    final isPdf =
        bytes.length >= 5 &&
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '%PDF-';
    var isText =
        !isPdf &&
        !bytes.any(
          (byte) =>
              (byte < 32 && byte != 9 && byte != 10 && byte != 13) ||
              byte == 127,
        );
    if (isText) {
      try {
        final decoder = utf8.decoder.startChunkedConversion(
          StringConversionSink.fromStringSink(buffer),
        );
        decoder.add(bytes);
        // A bounded preview may end halfway through a UTF-8 character. Keep
        // the incomplete tail buffered instead of turning it into replacement
        // characters, while still rejecting malformed bytes elsewhere.
        if (!truncated) decoder.close();
      } on FormatException {
        isText = false;
      }
    }
    return SftpFilePreview(
      text: isText ? buffer.toString() : '',
      bytesRead: bytes.length,
      truncated: truncated,
      isText: isText,
    );
  }

  final String text;
  final int bytesRead;
  final bool truncated;
  final bool isText;
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
