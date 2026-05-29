import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' as ssh;
import 'package:path/path.dart' as p;

import '../../../core/ids/entity_id.dart';
import '../application/sftp_connection.dart';
import '../application/sftp_failure.dart';
import '../domain/sftp_entry.dart';
import 'sftp_error_mapper.dart';

class DartSsh2SftpConnection implements SftpConnection {
  DartSsh2SftpConnection({
    required ssh.SftpClient sftpClient,
    ssh.SSHClient? sshClient,
    Future<void> Function()? onClose,
  }) : this._(sftpClient, sshClient, onClose);

  DartSsh2SftpConnection._(this._sftp, this._sshClient, this._onClose);

  final ssh.SftpClient _sftp;
  final ssh.SSHClient? _sshClient;
  final Future<void> Function()? _onClose;

  @override
  Future<void> get done => _sshClient?.done ?? Future.value();

  @override
  Future<List<SftpEntry>> list(String path) async {
    return _withMappedSftpErrors(() async {
      final names = await _sftp.listdir(path);
      return [
        for (final name in names)
          if (name.filename != '.' && name.filename != '..')
            mapName(path: path, name: name),
      ];
    });
  }

  @override
  Future<void> mkdir(String path) {
    return _withMappedSftpErrors(() => _sftp.mkdir(path));
  }

  @override
  Future<void> rename(String oldPath, String newPath) {
    return _withMappedSftpErrors(() => _sftp.rename(oldPath, newPath));
  }

  @override
  Future<void> deleteFile(String path) {
    return _withMappedSftpErrors(() => _sftp.remove(path));
  }

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {
    await _withMappedSftpErrors(() async {
      if (recursive) {
        final entries = await list(path);
        for (final entry in entries) {
          if (entry.type == SftpEntryType.directory) {
            await deleteDirectory(entry.path, recursive: true);
          } else {
            await deleteFile(entry.path);
          }
        }
      }
      await _sftp.rmdir(path);
    });
  }

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {
    await _withMappedSftpErrors(() async {
      final mode = int.parse(permissions.octal, radix: 8);
      await _sftp.setStat(
        path,
        ssh.SftpFileAttrs(mode: ssh.SftpFileMode.value(mode)),
      );
    });
  }

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    return _withMappedSftpErrors(() async {
      ssh.SftpFile? remoteFile;
      try {
        remoteFile = await _sftp.open(path);
        final bytes = await remoteFile.readBytes(length: maxBytes + 1);
        final truncated = bytes.length > maxBytes;
        final visibleBytes = truncated
            ? Uint8List.sublistView(bytes, 0, maxBytes)
            : bytes;
        return SftpFilePreview(
          text: utf8.decode(visibleBytes, allowMalformed: true),
          bytesRead: visibleBytes.length,
          truncated: truncated,
        );
      } finally {
        await remoteFile?.close();
      }
    });
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    await _withMappedSftpErrors(() async {
      ssh.SftpFile? remoteFile;
      try {
        remoteFile = await _sftp.open(
          path,
          mode:
              ssh.SftpFileOpenMode.write |
              ssh.SftpFileOpenMode.create |
              ssh.SftpFileOpenMode.truncate,
        );
        final writer = remoteFile.write(
          Stream.value(Uint8List.fromList(utf8.encode(contents))),
        );
        await writer.done;
      } finally {
        await remoteFile?.close();
      }
    });
  }

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    final controller = StreamController<TransferProgress>();
    unawaited(
      _upload(
        taskId: taskId,
        itemKind: itemKind,
        localPath: localPath,
        remotePath: remotePath,
        controller: controller,
      ),
    );
    return controller.stream;
  }

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    final controller = StreamController<TransferProgress>();
    unawaited(
      _download(
        taskId: taskId,
        itemKind: itemKind,
        remotePath: remotePath,
        localPath: localPath,
        controller: controller,
      ),
    );
    return controller.stream;
  }

  @override
  Future<void> close() async {
    _sftp.close();
    await _onClose?.call();
    _sshClient?.close();
  }

  Future<void> _upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
    required StreamController<TransferProgress> controller,
  }) async {
    try {
      switch (itemKind) {
        case TransferItemKind.file:
          await _uploadFileTransfer(
            taskId: taskId,
            localPath: localPath,
            remotePath: remotePath,
            controller: controller,
          );
        case TransferItemKind.directory:
          await _uploadDirectoryTransfer(
            taskId: taskId,
            localPath: localPath,
            remotePath: remotePath,
            controller: controller,
          );
      }
    } on Object catch (error, stackTrace) {
      controller.addError(
        SftpFailureException(mapExternalSftpError(error)),
        stackTrace,
      );
    } finally {
      await controller.close();
    }
  }

  Future<void> _download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
    required StreamController<TransferProgress> controller,
  }) async {
    try {
      switch (itemKind) {
        case TransferItemKind.file:
          await _downloadFileTransfer(
            taskId: taskId,
            remotePath: remotePath,
            localPath: localPath,
            controller: controller,
          );
        case TransferItemKind.directory:
          await _downloadDirectoryTransfer(
            taskId: taskId,
            remotePath: remotePath,
            localPath: localPath,
            controller: controller,
          );
      }
    } on Object catch (error, stackTrace) {
      controller.addError(
        SftpFailureException(mapExternalSftpError(error)),
        stackTrace,
      );
    } finally {
      await controller.close();
    }
  }

  Future<void> _uploadFileTransfer({
    required TransferTaskId taskId,
    required String localPath,
    required String remotePath,
    required StreamController<TransferProgress> controller,
  }) async {
    final totalBytes = await File(localPath).length();
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 0,
        totalBytes: totalBytes,
      ),
    );
    await _uploadFileBytes(
      taskId: taskId,
      localPath: localPath,
      remotePath: remotePath,
      baseTransferredBytes: 0,
      totalBytes: totalBytes,
      controller: controller,
    );
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
  }

  Future<void> _uploadDirectoryTransfer({
    required TransferTaskId taskId,
    required String localPath,
    required String remotePath,
    required StreamController<TransferProgress> controller,
  }) async {
    final root = Directory(localPath);
    final files = <File>[];
    final directories = <Directory>[root];
    var totalBytes = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        directories.add(entity);
      } else if (entity is File) {
        files.add(entity);
        totalBytes += await entity.length();
      }
    }
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 0,
        totalBytes: totalBytes,
      ),
    );
    for (final directory in directories) {
      final relativePath = p.relative(directory.path, from: root.path);
      final remoteDirectory = relativePath == '.'
          ? remotePath
          : p.posix.join(remotePath, p.split(relativePath).join('/'));
      await _ensureRemoteDirectory(remoteDirectory);
    }
    var transferredBytes = 0;
    for (final file in files) {
      final relativePath = p.relative(file.path, from: root.path);
      final remoteFilePath = p.posix.join(
        remotePath,
        p.split(relativePath).join('/'),
      );
      await _uploadFileBytes(
        taskId: taskId,
        localPath: file.path,
        remotePath: remoteFilePath,
        baseTransferredBytes: transferredBytes,
        totalBytes: totalBytes,
        controller: controller,
      );
      transferredBytes += await file.length();
    }
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: totalBytes,
        totalBytes: totalBytes,
      ),
    );
  }

  Future<void> _uploadFileBytes({
    required TransferTaskId taskId,
    required String localPath,
    required String remotePath,
    required int baseTransferredBytes,
    required int totalBytes,
    required StreamController<TransferProgress> controller,
  }) async {
    ssh.SftpFile? remoteFile;
    try {
      final localFile = File(localPath);
      remoteFile = await _sftp.open(
        remotePath,
        mode:
            ssh.SftpFileOpenMode.write |
            ssh.SftpFileOpenMode.create |
            ssh.SftpFileOpenMode.truncate,
      );
      final writer = remoteFile.write(
        localFile.openRead().map(Uint8List.fromList),
        onProgress: (transferred) {
          controller.add(
            TransferProgress(
              taskId: taskId,
              state: TransferState.running,
              transferredBytes: baseTransferredBytes + transferred,
              totalBytes: totalBytes,
            ),
          );
        },
      );
      await writer.done;
    } finally {
      await remoteFile?.close();
    }
  }

  Future<void> _downloadFileTransfer({
    required TransferTaskId taskId,
    required String remotePath,
    required String localPath,
    required StreamController<TransferProgress> controller,
  }) async {
    final stat = await _sftp.stat(remotePath);
    final totalBytes = stat.size;
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 0,
        totalBytes: totalBytes,
      ),
    );
    await _downloadFileBytes(
      taskId: taskId,
      remotePath: remotePath,
      localPath: localPath,
      baseTransferredBytes: 0,
      fileBytes: totalBytes,
      aggregateTotalBytes: totalBytes,
      controller: controller,
    );
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: totalBytes ?? await File(localPath).length(),
        totalBytes: totalBytes,
      ),
    );
  }

  Future<void> _downloadDirectoryTransfer({
    required TransferTaskId taskId,
    required String remotePath,
    required String localPath,
    required StreamController<TransferProgress> controller,
  }) async {
    final tree = await _collectRemoteTree(remotePath);
    var totalBytes = 0;
    var hasUnknownSize = false;
    for (final file in tree.files) {
      final size = file.size;
      if (size == null) {
        hasUnknownSize = true;
      } else {
        totalBytes += size;
      }
    }
    final aggregateTotalBytes = hasUnknownSize ? null : totalBytes;
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 0,
        totalBytes: aggregateTotalBytes,
      ),
    );
    await Directory(localPath).create(recursive: true);
    for (final directory in tree.directories) {
      final relativePath = p.posix.relative(directory.path, from: remotePath);
      if (relativePath == '.') {
        continue;
      }
      await Directory(
        p.joinAll([localPath, ...p.posix.split(relativePath)]),
      ).create(recursive: true);
    }
    var transferredBytes = 0;
    for (final file in tree.files) {
      final relativePath = p.posix.relative(file.path, from: remotePath);
      final localFilePath = p.joinAll([
        localPath,
        ...p.posix.split(relativePath),
      ]);
      await _downloadFileBytes(
        taskId: taskId,
        remotePath: file.path,
        localPath: localFilePath,
        baseTransferredBytes: transferredBytes,
        fileBytes: file.size,
        aggregateTotalBytes: aggregateTotalBytes,
        controller: controller,
      );
      transferredBytes += file.size ?? await File(localFilePath).length();
    }
    controller.add(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: aggregateTotalBytes ?? transferredBytes,
        totalBytes: aggregateTotalBytes,
      ),
    );
  }

  Future<void> _downloadFileBytes({
    required TransferTaskId taskId,
    required String remotePath,
    required String localPath,
    required int baseTransferredBytes,
    required int? fileBytes,
    required int? aggregateTotalBytes,
    required StreamController<TransferProgress> controller,
  }) async {
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    final sink = localFile.openWrite();
    await _sftp.download(
      remotePath,
      sink,
      length: fileBytes == 0 ? null : fileBytes,
      closeDestination: true,
      onProgress: (transferred) {
        controller.add(
          TransferProgress(
            taskId: taskId,
            state: TransferState.running,
            transferredBytes: baseTransferredBytes + transferred,
            totalBytes: aggregateTotalBytes,
          ),
        );
      },
    );
  }

  Future<_RemoteTree> _collectRemoteTree(String rootPath) async {
    final directories = <SftpEntry>[
      SftpEntry(
        name: p.posix.basename(rootPath),
        path: rootPath,
        type: SftpEntryType.directory,
      ),
    ];
    final files = <SftpEntry>[];

    Future<void> collect(String path) async {
      final entries = await list(path);
      for (final entry in entries) {
        if (entry.type == SftpEntryType.directory) {
          directories.add(entry);
          await collect(entry.path);
        } else if (entry.type == SftpEntryType.file ||
            entry.type == SftpEntryType.symlink) {
          files.add(entry);
        }
      }
    }

    await collect(rootPath);
    return _RemoteTree(directories: directories, files: files);
  }

  Future<void> _ensureRemoteDirectory(String path) async {
    if (path == '/') {
      return;
    }
    try {
      await _sftp.mkdir(path);
    } on Object catch (error, stackTrace) {
      final ssh.SftpFileAttrs attrs;
      try {
        attrs = await _sftp.stat(path);
      } on Object {
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (attrs.type == ssh.SftpFileType.directory) {
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static SftpEntry mapName({required String path, required ssh.SftpName name}) {
    final attrs = name.attr;
    final entryPath = _joinRemotePath(path, name.filename);
    return SftpEntry(
      name: name.filename,
      path: entryPath,
      type: _mapType(attrs.type),
      size: attrs.size,
      modifiedAt: attrs.modifyTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              attrs.modifyTime! * 1000,
              isUtc: true,
            ),
      permissions: attrs.mode == null
          ? null
          : SftpPermissions(
              (attrs.mode!.value & 0x1ff).toRadixString(8).padLeft(4, '0'),
            ),
      owner: attrs.userID?.toString(),
      group: attrs.groupID?.toString(),
      isHidden: name.filename.startsWith('.'),
    );
  }
}

class _RemoteTree {
  const _RemoteTree({required this.directories, required this.files});

  final List<SftpEntry> directories;
  final List<SftpEntry> files;
}

Future<T> _withMappedSftpErrors<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on SftpFailureException {
    rethrow;
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(
      SftpFailureException(mapExternalSftpError(error)),
      stackTrace,
    );
  }
}

SftpEntryType _mapType(ssh.SftpFileType? type) {
  return switch (type) {
    ssh.SftpFileType.regularFile => SftpEntryType.file,
    ssh.SftpFileType.directory => SftpEntryType.directory,
    ssh.SftpFileType.symbolicLink => SftpEntryType.symlink,
    _ => SftpEntryType.unknown,
  };
}

String _joinRemotePath(String parent, String child) {
  if (parent == '/') {
    return '/$child';
  }
  return p.posix.join(parent, child);
}
