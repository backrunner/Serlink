import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/application/sftp_failure.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/transfers/application/transfer_task_repository.dart';
import 'package:serlink/features/transfers/domain/transfer_task.dart';

void main() {
  late TransferQueueController queue;
  late _FakeSftpConnection connection;

  setUp(() {
    queue = TransferQueueController(maxConcurrentTransfers: 1);
    connection = _FakeSftpConnection();
  });

  tearDown(() async {
    await queue.dispose();
  });

  test('updates upload progress and completion', () async {
    final taskId = queue.enqueueUpload(
      connection: connection,
      localPath: '/local/app.log',
      remotePath: '/remote/app.log',
    );

    expect(queue.state.byId(taskId)!.state, TransferState.running);

    connection.emit(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 10,
        totalBytes: 100,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.byId(taskId)!.transferredBytes, 10);
    expect(queue.state.byId(taskId)!.totalBytes, 100);
    expect(queue.state.byId(taskId)!.bytesPerSecond, isNotNull);
    expect(queue.state.byId(taskId)!.eta, isNotNull);

    connection.emit(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: 100,
        totalBytes: 100,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.byId(taskId)!.state, TransferState.completed);
  });

  test(
    'enforces max concurrent transfers and starts next after completion',
    () async {
      final first = queue.enqueueUpload(
        connection: connection,
        localPath: '/local/a',
        remotePath: '/remote/a',
      );
      final second = queue.enqueueDownload(
        connection: connection,
        remotePath: '/remote/b',
        localPath: '/local/b',
      );

      expect(queue.state.byId(first)!.state, TransferState.running);
      expect(queue.state.byId(second)!.state, TransferState.queued);

      connection.emit(
        TransferProgress(
          taskId: first,
          state: TransferState.completed,
          transferredBytes: 1,
          totalBytes: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(queue.state.byId(second)!.state, TransferState.running);
    },
  );

  test('cancels and retries failed transfers', () async {
    final taskId = queue.enqueueUpload(
      connection: connection,
      localPath: '/local/a',
      remotePath: '/remote/a',
    );

    connection.fail(StateError('network'));
    await Future<void>.delayed(Duration.zero);

    expect(queue.state.byId(taskId)!.state, TransferState.failed);

    await queue.retry(taskId);

    expect(queue.state.byId(taskId)!.state, TransferState.running);

    await queue.cancel(taskId);

    expect(queue.state.byId(taskId)!.state, TransferState.canceled);
  });

  test('preserves typed SFTP transfer failures', () async {
    final taskId = queue.enqueueDownload(
      connection: connection,
      remotePath: '/remote/private.log',
      localPath: '/local/private.log',
    );

    connection.fail(
      SftpFailureException(
        SftpFailure.permissionDenied(diagnostic: 'remote denied'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final task = queue.state.byId(taskId)!;
    expect(task.state, TransferState.failed);
    expect(task.failure!.code, 'sftp.permission_denied');
    expect(task.failure!.message, 'Permission denied by the remote server.');
    expect(task.failure!.diagnostic, 'remote denied');
  });

  test('marks stream close without terminal progress as interrupted', () async {
    final taskId = queue.enqueueUpload(
      connection: connection,
      localPath: '/local/large.bin',
      remotePath: '/remote/large.bin',
    );

    connection.emit(
      TransferProgress(
        taskId: taskId,
        state: TransferState.running,
        transferredBytes: 5,
        totalBytes: 100,
      ),
    );
    await connection.closeStream();
    await Future<void>.delayed(Duration.zero);

    final task = queue.state.byId(taskId)!;
    expect(task.state, TransferState.failed);
    expect(task.failure!.code, 'transfer.interrupted');
  });

  test('queues directory transfers through the same transfer queue', () async {
    final uploadId = queue.enqueueUpload(
      connection: connection,
      itemKind: TransferItemKind.directory,
      localPath: '/local/releases',
      remotePath: '/remote/releases',
    );

    expect(queue.state.byId(uploadId)!.itemKind, TransferItemKind.directory);
    expect(connection.lastUploadKind, TransferItemKind.directory);

    connection.emit(
      TransferProgress(
        taskId: uploadId,
        state: TransferState.completed,
        transferredBytes: 1,
        totalBytes: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final downloadId = queue.enqueueDownload(
      connection: connection,
      itemKind: TransferItemKind.directory,
      remotePath: '/remote/logs',
      localPath: '/local/logs',
    );

    expect(queue.state.byId(downloadId)!.itemKind, TransferItemKind.directory);
    expect(connection.lastDownloadKind, TransferItemKind.directory);
  });

  test('persists completed transfer history', () async {
    final repository = InMemoryTransferTaskRepository();
    final firstQueue = TransferQueueController(
      maxConcurrentTransfers: 1,
      repository: repository,
    );
    addTearDown(firstQueue.dispose);
    final taskId = firstQueue.enqueueUpload(
      connection: connection,
      localPath: '/local/archive.tar',
      remotePath: '/remote/archive.tar',
    );

    connection.emit(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: 10,
        totalBytes: 10,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final restoredQueue = TransferQueueController(repository: repository);
    addTearDown(restoredQueue.dispose);
    await restoredQueue.restorePersistedTasks();

    final restored = restoredQueue.state.byId(taskId)!;
    expect(restored.state, TransferState.completed);
    expect(restored.localPath, '/local/archive.tar');
    expect(restored.remotePath, '/remote/archive.tar');
  });

  test(
    'marks persisted active transfers interrupted without retry operation',
    () async {
      final repository = InMemoryTransferTaskRepository();
      final taskId = TransferTaskId('persisted-running');
      await repository.save(
        TransferTask(
          id: taskId,
          direction: TransferDirection.download,
          localPath: '/local/current.log',
          remotePath: '/remote/current.log',
          state: TransferState.running,
          transferredBytes: 20,
          totalBytes: 100,
          createdAt: DateTime.utc(2026, 5, 27),
          startedAt: DateTime.utc(2026, 5, 27, 1),
        ),
      );

      final restoredQueue = TransferQueueController(repository: repository);
      addTearDown(restoredQueue.dispose);
      await restoredQueue.restorePersistedTasks();

      final restored = restoredQueue.state.byId(taskId)!;
      expect(restored.state, TransferState.failed);
      expect(restored.failure!.code, 'transfer.interrupted');
      expect(restoredQueue.canRetry(taskId), isFalse);
    },
  );
}

class _FakeSftpConnection implements SftpConnection {
  StreamController<TransferProgress>? _controller;
  final Completer<void> _done = Completer<void>();
  TransferItemKind? lastUploadKind;
  TransferItemKind? lastDownloadKind;

  void emit(TransferProgress progress) {
    _controller!.add(progress);
  }

  void fail(Object error) {
    _controller!.addError(error);
  }

  Future<void> closeStream() async {
    await _controller!.close();
  }

  @override
  Future<void> get done => _done.future;

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    lastUploadKind = itemKind;
    _controller = StreamController<TransferProgress>();
    return _controller!.stream;
  }

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    lastDownloadKind = itemKind;
    _controller = StreamController<TransferProgress>();
    return _controller!.stream;
  }

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {}

  @override
  Future<void> close() async {
    await _controller?.close();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  Future<List<SftpEntry>> list(String path) async => [];

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    return const SftpFilePreview(text: '', bytesRead: 0, truncated: false);
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {}

  @override
  Future<void> writeTextFile(String path, String contents) async {}
}
