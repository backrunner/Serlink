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
      final mode = int.parse(permissions.normalizedOctal, radix: 8);
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
    final transfer = _SftpTransferControl();
    final controller = StreamController<TransferProgress>(
      onPause: transfer.pause,
      onResume: transfer.resume,
      onCancel: transfer.cancel,
    );
    unawaited(
      _upload(
        taskId: taskId,
        itemKind: itemKind,
        localPath: localPath,
        remotePath: remotePath,
        transfer: transfer,
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
    final transfer = _SftpTransferControl();
    final controller = StreamController<TransferProgress>(
      onPause: transfer.pause,
      onResume: transfer.resume,
      onCancel: transfer.cancel,
    );
    unawaited(
      _download(
        taskId: taskId,
        itemKind: itemKind,
        remotePath: remotePath,
        localPath: localPath,
        transfer: transfer,
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
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    try {
      switch (itemKind) {
        case TransferItemKind.file:
          await _uploadFileTransfer(
            taskId: taskId,
            localPath: localPath,
            remotePath: remotePath,
            transfer: transfer,
            controller: controller,
          );
        case TransferItemKind.directory:
          await _uploadDirectoryTransfer(
            taskId: taskId,
            localPath: localPath,
            remotePath: remotePath,
            transfer: transfer,
            controller: controller,
          );
      }
    } on _SftpTransferCanceled {
      // Queue cancellation owns the visible task state.
    } on Object catch (error, stackTrace) {
      if (!transfer.isCanceled && !controller.isClosed) {
        controller.addError(
          SftpFailureException(mapExternalSftpError(error)),
          stackTrace,
        );
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<void> _download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    try {
      switch (itemKind) {
        case TransferItemKind.file:
          await _downloadFileTransfer(
            taskId: taskId,
            remotePath: remotePath,
            localPath: localPath,
            transfer: transfer,
            controller: controller,
          );
        case TransferItemKind.directory:
          await _downloadDirectoryTransfer(
            taskId: taskId,
            remotePath: remotePath,
            localPath: localPath,
            transfer: transfer,
            controller: controller,
          );
      }
    } on _SftpTransferCanceled {
      // Queue cancellation owns the visible task state.
    } on Object catch (error, stackTrace) {
      if (!transfer.isCanceled && !controller.isClosed) {
        controller.addError(
          SftpFailureException(mapExternalSftpError(error)),
          stackTrace,
        );
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  Future<void> _uploadFileTransfer({
    required TransferTaskId taskId,
    required String localPath,
    required String remotePath,
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    await transfer.waitIfPaused();
    final totalBytes = await File(localPath).length();
    _emitTransferProgress(
      controller,
      transfer,
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
      transfer: transfer,
      controller: controller,
    );
    transfer.markCompleted();
    _emitTransferProgress(
      controller,
      transfer,
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
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    await transfer.waitIfPaused();
    final root = Directory(localPath);
    final files = <File>[];
    final directories = <Directory>[root];
    var totalBytes = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      await transfer.waitIfPaused();
      if (entity is Directory) {
        directories.add(entity);
      } else if (entity is File) {
        files.add(entity);
        totalBytes += await entity.length();
      }
    }
    _emitTransferProgress(
      controller,
      transfer,
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
      await transfer.waitIfPaused();
      await _ensureRemoteDirectory(remoteDirectory);
    }
    var transferredBytes = 0;
    for (final file in files) {
      await transfer.waitIfPaused();
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
        transfer: transfer,
        controller: controller,
      );
      transferredBytes += await file.length();
    }
    for (final directory in directories.reversed) {
      await transfer.waitIfPaused();
      final relativePath = p.relative(directory.path, from: root.path);
      final remoteDirectory = relativePath == '.'
          ? remotePath
          : p.posix.join(remotePath, p.split(relativePath).join('/'));
      await _trySetRemoteModifiedTime(
        remoteDirectory,
        (await directory.stat()).modified,
      );
    }
    transfer.markCompleted();
    _emitTransferProgress(
      controller,
      transfer,
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
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    ssh.SftpFile? remoteFile;
    var completed = false;
    late final DateTime localModifiedAt;
    try {
      await transfer.waitIfPaused();
      final localFile = File(localPath);
      localModifiedAt = (await localFile.stat()).modified;
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
          _emitTransferProgress(
            controller,
            transfer,
            TransferProgress(
              taskId: taskId,
              state: TransferState.running,
              transferredBytes: baseTransferredBytes + transferred,
              totalBytes: totalBytes,
            ),
          );
        },
      );
      transfer.bindWriter(writer);
      await writer.done;
      transfer.throwIfCanceled();
      completed = true;
    } finally {
      await remoteFile?.close();
    }
    if (completed) {
      await _trySetRemoteModifiedTime(remotePath, localModifiedAt);
    }
  }

  Future<void> _downloadFileTransfer({
    required TransferTaskId taskId,
    required String remotePath,
    required String localPath,
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    await transfer.waitIfPaused();
    final stat = await _sftp.stat(remotePath);
    final totalBytes = stat.size;
    _emitTransferProgress(
      controller,
      transfer,
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
      remoteModifiedAt: _modifiedAtFromSftpSeconds(stat.modifyTime),
      transfer: transfer,
      controller: controller,
    );
    transfer.markCompleted();
    _emitTransferProgress(
      controller,
      transfer,
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
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    await transfer.waitIfPaused();
    final tree = await _collectRemoteTree(remotePath);
    var totalBytes = 0;
    var hasUnknownSize = false;
    for (final file in tree.files) {
      await transfer.waitIfPaused();
      final size = file.size;
      if (size == null) {
        hasUnknownSize = true;
      } else {
        totalBytes += size;
      }
    }
    final aggregateTotalBytes = hasUnknownSize ? null : totalBytes;
    _emitTransferProgress(
      controller,
      transfer,
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 0,
        totalBytes: aggregateTotalBytes,
      ),
    );
    await Directory(localPath).create(recursive: true);
    for (final directory in tree.directories) {
      await transfer.waitIfPaused();
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
      await transfer.waitIfPaused();
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
        remoteModifiedAt: file.modifiedAt,
        transfer: transfer,
        controller: controller,
      );
      transferredBytes += file.size ?? await File(localFilePath).length();
    }
    transfer.markCompleted();
    _emitTransferProgress(
      controller,
      transfer,
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
    DateTime? remoteModifiedAt,
    required _SftpTransferControl transfer,
    required StreamController<TransferProgress> controller,
  }) async {
    await transfer.waitIfPaused();
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    ssh.SftpFile? remoteFile;
    IOSink? sink;
    StreamSubscription<Uint8List>? subscription;
    final done = Completer<void>();
    var transferredBytes = 0;
    var completed = false;

    Future<void> fail(Object error, StackTrace stackTrace) async {
      if (!done.isCompleted) {
        done.completeError(error, stackTrace);
      }
      await subscription?.cancel();
    }

    try {
      remoteFile = await _sftp.open(
        remotePath,
        mode: ssh.SftpFileOpenMode.read,
      );
      sink = localFile.openWrite();
      subscription = remoteFile
          .read(length: fileBytes == 0 ? null : fileBytes)
          .listen(
            null,
            onError: (Object error, StackTrace stackTrace) {
              if (!done.isCompleted) {
                done.completeError(error, stackTrace);
              }
            },
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
            cancelOnError: true,
          );
      subscription.onData((chunk) {
        Future<void> writeChunk() async {
          try {
            await transfer.waitIfPaused();
            sink!.add(chunk);
            await sink.flush();
            transferredBytes += chunk.length;
            _emitTransferProgress(
              controller,
              transfer,
              TransferProgress(
                taskId: taskId,
                state: TransferState.running,
                transferredBytes: baseTransferredBytes + transferredBytes,
                totalBytes: aggregateTotalBytes,
              ),
            );
          } on Object catch (error, stackTrace) {
            await fail(error, stackTrace);
          }
        }

        subscription!.pause(writeChunk());
      });
      transfer.bindSubscription(
        subscription,
        onCanceled: () {
          if (!done.isCompleted) {
            done.completeError(const _SftpTransferCanceled());
          }
        },
      );
      await done.future;
      transfer.throwIfCanceled();
      completed = true;
    } finally {
      await subscription?.cancel();
      await sink?.close();
      await remoteFile?.close();
    }
    if (completed) {
      await _trySetLocalModifiedTime(localFile, remoteModifiedAt);
    }
  }

  Future<_RemoteTree> _collectRemoteTree(String rootPath) async {
    final rootAttrs = await _sftp.stat(rootPath);
    final directories = <SftpEntry>[
      SftpEntry(
        name: p.posix.basename(rootPath),
        path: rootPath,
        type: SftpEntryType.directory,
        modifiedAt: _modifiedAtFromSftpSeconds(rootAttrs.modifyTime),
        permissions: _permissionsFromSftpMode(rootAttrs.mode),
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

  Future<void> _trySetRemoteModifiedTime(
    String path,
    DateTime modifiedAt,
  ) async {
    try {
      final seconds = _sftpSecondsFromDateTime(modifiedAt);
      await _sftp.setStat(
        path,
        ssh.SftpFileAttrs(accessTime: seconds, modifyTime: seconds),
      );
    } on Object {
      // Timestamp preservation is best-effort because many SFTP servers reject
      // SETSTAT even when the file transfer itself succeeded.
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
      modifiedAt: _modifiedAtFromSftpSeconds(attrs.modifyTime),
      permissions: _permissionsFromSftpMode(attrs.mode),
      owner: attrs.userID?.toString(),
      group: attrs.groupID?.toString(),
      isHidden: name.filename.startsWith('.'),
    );
  }
}

DateTime? _modifiedAtFromSftpSeconds(int? seconds) {
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

SftpPermissions? _permissionsFromSftpMode(ssh.SftpFileMode? mode) {
  return mode == null
      ? null
      : SftpPermissions.fromOctal(
          (mode.value & 0xfff).toRadixString(8).padLeft(4, '0'),
        );
}

int _sftpSecondsFromDateTime(DateTime value) {
  return value.toUtc().millisecondsSinceEpoch ~/ 1000;
}

Future<void> _trySetLocalModifiedTime(
  FileSystemEntity entity,
  DateTime? modifiedAt,
) async {
  if (modifiedAt == null) {
    return;
  }
  try {
    switch (entity) {
      case File file:
        await file.setLastModified(modifiedAt);
      default:
        return;
    }
  } on Object {
    // Some platforms or target locations reject metadata writes; downloaded
    // contents should remain successful when timestamp restoration fails.
  }
}

class _RemoteTree {
  const _RemoteTree({required this.directories, required this.files});

  final List<SftpEntry> directories;
  final List<SftpEntry> files;
}

class _SftpTransferCanceled implements Exception {
  const _SftpTransferCanceled();
}

class _SftpTransferControl {
  final List<void Function()> _pauseCallbacks = [];
  final List<void Function()> _resumeCallbacks = [];
  final List<FutureOr<void> Function()> _cancelCallbacks = [];

  bool _paused = false;
  bool _canceled = false;
  bool _completed = false;
  Completer<void>? _resumeCompleter;
  Future<void>? _cancelFuture;

  bool get isCanceled => _canceled;

  void markCompleted() {
    _completed = true;
  }

  void pause() {
    if (_canceled || _completed || _paused) {
      return;
    }
    _paused = true;
    _resumeCompleter ??= Completer<void>();
    for (final callback in _pauseCallbacks) {
      callback();
    }
  }

  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    for (final callback in _resumeCallbacks) {
      callback();
    }
  }

  Future<void> cancel() {
    if (_completed) {
      return Future.value();
    }
    final existing = _cancelFuture;
    if (existing != null) {
      return existing;
    }
    _canceled = true;
    resume();
    final callbacks = List<FutureOr<void> Function()>.of(_cancelCallbacks);
    _cancelCallbacks.clear();
    _cancelFuture = Future.wait([
      for (final callback in callbacks) _ignoreCancelError(callback),
    ]).then((_) {});
    return _cancelFuture!;
  }

  Future<void> waitIfPaused() async {
    while (_paused && !_canceled) {
      await _resumeCompleter!.future;
    }
    throwIfCanceled();
  }

  void throwIfCanceled() {
    if (_canceled) {
      throw const _SftpTransferCanceled();
    }
  }

  void bindWriter(ssh.SftpFileWriter writer) {
    _pauseCallbacks.add(writer.pause);
    _resumeCallbacks.add(writer.resume);
    _cancelCallbacks.add(() => _abortWriter(writer));
    if (_paused) {
      writer.pause();
    }
    if (_canceled) {
      unawaited(_abortWriter(writer));
    }
  }

  void bindSubscription<T>(
    StreamSubscription<T> subscription, {
    void Function()? onCanceled,
  }) {
    _pauseCallbacks.add(subscription.pause);
    _resumeCallbacks.add(subscription.resume);
    _cancelCallbacks.add(() async {
      await subscription.cancel();
      onCanceled?.call();
    });
    if (_paused) {
      subscription.pause();
    }
    if (_canceled) {
      unawaited(_ignoreFuture(subscription.cancel()));
      onCanceled?.call();
    }
  }
}

Future<void> _ignoreCancelError(FutureOr<void> Function() callback) async {
  try {
    await callback();
  } on Object {
    // Transfer cancellation is best-effort; the queue state is already owned
    // by the caller and must not get stuck because a transport refused abort.
  }
}

Future<void> _abortWriter(ssh.SftpFileWriter writer) async {
  try {
    await writer.abort();
  } on StateError {
    // The writer may have completed between the cancel request and abort.
  }
}

Future<void> _ignoreFuture(Future<void> future) async {
  try {
    await future;
  } on Object {
    // Best-effort cleanup.
  }
}

void _emitTransferProgress(
  StreamController<TransferProgress> controller,
  _SftpTransferControl transfer,
  TransferProgress progress,
) {
  if (!transfer.isCanceled && !controller.isClosed) {
    controller.add(progress);
  }
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
