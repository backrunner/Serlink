import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/failure/app_failure.dart';
import '../../../core/ids/entity_id.dart';
import '../../sftp/application/sftp_connection.dart';
import '../../sftp/application/sftp_failure.dart';
import '../domain/transfer_task.dart';
import 'transfer_task_repository.dart';

final transferQueueControllerProvider = Provider<TransferQueueController>((
  ref,
) {
  final controller = TransferQueueController(
    repository: ref.watch(transferTaskRepositoryProvider),
  );
  unawaited(controller.restorePersistedTasks());
  ref.onDispose(() {
    unawaited(controller.dispose());
  });
  return controller;
});

final transferQueueStateProvider = StreamProvider<TransferQueueState>((ref) {
  return ref.watch(transferQueueControllerProvider).watchState();
});

class TransferQueueController {
  TransferQueueController({
    this.maxConcurrentTransfers = 2,
    TransferTaskRepository? repository,
  }) : _repository = repository ?? InMemoryTransferTaskRepository(),
       _state = const TransferQueueState(tasks: []);

  static const _uuid = Uuid();

  final int maxConcurrentTransfers;
  final TransferTaskRepository _repository;
  final StreamController<TransferQueueState> _stateController =
      StreamController<TransferQueueState>.broadcast();
  final List<_TransferOperation> _operations = [];
  final Map<TransferTaskId, StreamSubscription<TransferProgress>>
  _subscriptions = {};

  TransferQueueState _state;
  bool _restoreStarted = false;

  TransferQueueState get state => _state;

  Stream<TransferQueueState> watchState() async* {
    yield _state;
    yield* _stateController.stream;
  }

  Future<void> restorePersistedTasks() async {
    if (_restoreStarted) {
      return;
    }
    _restoreStarted = true;
    try {
      final now = DateTime.now().toUtc();
      final persisted = await _repository.list();
      final currentIds = {for (final task in _state.tasks) task.id.value};
      final restored = <TransferTask>[];
      for (final task in persisted) {
        if (currentIds.contains(task.id.value)) {
          continue;
        }
        restored.add(_markInterruptedIfActive(task, now));
      }
      if (restored.isEmpty) {
        return;
      }
      _setState(TransferQueueState(tasks: [...restored, ..._state.tasks]));
      for (final task in restored) {
        _persistTask(task);
      }
    } on Object {
      _restoreStarted = false;
    }
  }

  TransferTaskId enqueueUpload({
    required SftpConnection connection,
    TransferItemKind itemKind = TransferItemKind.file,
    required String localPath,
    required String remotePath,
  }) {
    return _enqueue(
      connection: connection,
      direction: TransferDirection.upload,
      itemKind: itemKind,
      localPath: localPath,
      remotePath: remotePath,
    );
  }

  TransferTaskId enqueueDownload({
    required SftpConnection connection,
    TransferItemKind itemKind = TransferItemKind.file,
    required String remotePath,
    required String localPath,
  }) {
    return _enqueue(
      connection: connection,
      direction: TransferDirection.download,
      itemKind: itemKind,
      localPath: localPath,
      remotePath: remotePath,
    );
  }

  Future<void> pause(TransferTaskId taskId) async {
    final task = _state.byId(taskId);
    if (task == null || task.state != TransferState.running) {
      return;
    }
    _subscriptions[taskId]?.pause();
    _replaceTask(task.copyWith(state: TransferState.paused));
  }

  Future<void> resume(TransferTaskId taskId) async {
    final task = _state.byId(taskId);
    if (task == null || task.state != TransferState.paused) {
      return;
    }
    _subscriptions[taskId]?.resume();
    _replaceTask(task.copyWith(state: TransferState.running));
  }

  Future<void> cancel(TransferTaskId taskId) async {
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    await _subscriptions.remove(taskId)?.cancel();
    _removeQueuedOperation(taskId);
    _replaceTask(
      task.copyWith(
        state: TransferState.canceled,
        completedAt: DateTime.now().toUtc(),
      ),
    );
    _pump();
  }

  Future<void> retry(TransferTaskId taskId) async {
    final task = _state.byId(taskId);
    if (task == null ||
        (task.state != TransferState.failed &&
            task.state != TransferState.canceled)) {
      return;
    }
    final operation = _operations
        .where((candidate) => candidate.task.id == taskId)
        .firstOrNull;
    if (operation == null) {
      return;
    }
    operation.task = task.copyWith(
      state: TransferState.queued,
      transferredBytes: 0,
      clearTotalBytes: true,
      clearBytesPerSecond: true,
      clearEta: true,
      clearFailure: true,
      clearStartedAt: true,
      clearUpdatedAt: true,
      clearCompletedAt: true,
    );
    _replaceTask(operation.task);
    _pump();
  }

  bool canRetry(TransferTaskId taskId) {
    final task = _state.byId(taskId);
    if (task == null ||
        (task.state != TransferState.failed &&
            task.state != TransferState.canceled)) {
      return false;
    }
    return _operations.any((operation) => operation.task.id == taskId);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _stateController.close();
  }

  TransferTaskId _enqueue({
    required SftpConnection connection,
    required TransferDirection direction,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    final now = DateTime.now().toUtc();
    final task = TransferTask(
      id: TransferTaskId(_uuid.v4()),
      direction: direction,
      itemKind: itemKind,
      localPath: localPath,
      remotePath: remotePath,
      state: TransferState.queued,
      transferredBytes: 0,
      createdAt: now,
    );
    _operations.add(_TransferOperation(connection: connection, task: task));
    _setState(TransferQueueState(tasks: [..._state.tasks, task]));
    _persistTask(task);
    _pump();
    return task.id;
  }

  void _pump() {
    final activeCount = _state.tasks
        .where(
          (task) =>
              task.state == TransferState.running ||
              task.state == TransferState.paused,
        )
        .length;
    var available = maxConcurrentTransfers - activeCount;
    if (available <= 0) {
      return;
    }

    for (final operation in _operations) {
      if (available <= 0) {
        break;
      }
      if (operation.task.state != TransferState.queued ||
          _subscriptions.containsKey(operation.task.id)) {
        continue;
      }
      _start(operation);
      available -= 1;
    }
  }

  void _start(_TransferOperation operation) {
    final now = DateTime.now().toUtc();
    final task = operation.task.copyWith(
      state: TransferState.running,
      startedAt: now,
      updatedAt: now,
      clearBytesPerSecond: true,
      clearEta: true,
      clearFailure: true,
      clearCompletedAt: true,
    );
    operation.task = task;
    _replaceTask(task);

    final stream = switch (task.direction) {
      TransferDirection.upload => operation.connection.upload(
        taskId: task.id,
        itemKind: task.itemKind,
        localPath: task.localPath,
        remotePath: task.remotePath,
      ),
      TransferDirection.download => operation.connection.download(
        taskId: task.id,
        itemKind: task.itemKind,
        remotePath: task.remotePath,
        localPath: task.localPath,
      ),
    };

    _subscriptions[task.id] = stream.listen(
      (progress) => _handleProgress(task.id, progress),
      onError: (Object error) => _handleError(task.id, error),
      onDone: () => _handleDone(task.id),
      cancelOnError: true,
    );
  }

  void _handleProgress(TransferTaskId taskId, TransferProgress progress) {
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    final now = DateTime.now().toUtc();
    final startedAt = task.startedAt ?? task.createdAt;
    final elapsedSeconds = now.difference(startedAt).inMilliseconds / 1000;
    final bytesPerSecond = elapsedSeconds <= 0
        ? task.bytesPerSecond
        : progress.transferredBytes / elapsedSeconds;
    final remainingBytes = progress.totalBytes == null
        ? null
        : progress.totalBytes! - progress.transferredBytes;
    final eta =
        remainingBytes == null || bytesPerSecond == null || bytesPerSecond <= 0
        ? null
        : Duration(seconds: (remainingBytes / bytesPerSecond).ceil());
    final completedAt = _isTerminal(progress.state) ? now : null;
    final updated = task.copyWith(
      state: progress.state,
      transferredBytes: progress.transferredBytes,
      totalBytes: progress.totalBytes,
      bytesPerSecond: bytesPerSecond,
      eta: eta,
      updatedAt: now,
      completedAt: completedAt,
    );
    _replaceTask(updated);
    if (_isTerminal(progress.state)) {
      // Terminal progress means the transfer completed on its own. Let the
      // source stream close normally so SFTP implementations do not interpret
      // this as a user-requested cancellation.
      _subscriptions.remove(taskId);
      _pump();
    }
  }

  void _handleError(TransferTaskId taskId, Object error) {
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    final failure = _failureFrom(error);
    _subscriptions.remove(taskId);
    _replaceTask(
      task.copyWith(
        state: TransferState.failed,
        clearEta: true,
        failure: failure,
        completedAt: DateTime.now().toUtc(),
      ),
    );
    _pump();
  }

  void _handleDone(TransferTaskId taskId) {
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    _subscriptions.remove(taskId);
    final transferred = task.transferredBytes;
    final total = task.totalBytes;
    if (task.state == TransferState.running ||
        task.state == TransferState.paused ||
        total == null ||
        transferred < total) {
      final now = DateTime.now().toUtc();
      _replaceTask(
        task.copyWith(
          state: TransferState.failed,
          clearEta: true,
          clearBytesPerSecond: true,
          failure: const AppFailure(
            code: 'transfer.interrupted',
            message: 'Transfer stopped before it finished.',
          ),
          updatedAt: now,
          completedAt: now,
        ),
      );
      _pump();
      return;
    }
    _replaceTask(
      task.copyWith(
        state: TransferState.completed,
        clearEta: true,
        completedAt: DateTime.now().toUtc(),
      ),
    );
    _pump();
  }

  void _replaceTask(TransferTask task) {
    for (final operation in _operations) {
      if (operation.task.id == task.id) {
        operation.task = task;
        break;
      }
    }
    _setState(
      TransferQueueState(
        tasks: [
          for (final existing in _state.tasks)
            if (existing.id == task.id) task else existing,
        ],
      ),
    );
    _persistTask(task);
  }

  void _removeQueuedOperation(TransferTaskId taskId) {
    for (final operation in _operations) {
      if (operation.task.id == taskId &&
          operation.task.state == TransferState.queued) {
        operation.task = operation.task.copyWith(
          state: TransferState.canceled,
          completedAt: DateTime.now().toUtc(),
        );
        break;
      }
    }
  }

  void _setState(TransferQueueState nextState) {
    _state = nextState;
    _stateController.add(nextState);
  }

  void _persistTask(TransferTask task) {
    unawaited(_saveTask(task));
  }

  Future<void> _saveTask(TransferTask task) async {
    try {
      await _repository.save(task);
    } on Object {
      // Transfer persistence is best-effort so vault locking never interrupts
      // already-established SSH/SFTP connections.
    }
  }
}

class _TransferOperation {
  _TransferOperation({required this.connection, required this.task});

  final SftpConnection connection;
  TransferTask task;
}

bool _isTerminal(TransferState state) {
  return switch (state) {
    TransferState.completed ||
    TransferState.failed ||
    TransferState.canceled => true,
    _ => false,
  };
}

AppFailure _failureFrom(Object error) {
  if (error is SftpFailure || error is SftpFailureException) {
    return sftpFailureFrom(error).toAppFailure();
  }
  return AppFailure(
    code: 'transfer.failed',
    message: 'Transfer failed.',
    diagnostic: error.toString(),
  );
}

TransferTask _markInterruptedIfActive(TransferTask task, DateTime now) {
  return switch (task.state) {
    TransferState.queued ||
    TransferState.running ||
    TransferState.paused => task.copyWith(
      state: TransferState.failed,
      clearEta: true,
      clearBytesPerSecond: true,
      failure: const AppFailure(
        code: 'transfer.interrupted',
        message: 'Transfer stopped before it finished.',
      ),
      updatedAt: now,
      completedAt: now,
    ),
    TransferState.completed ||
    TransferState.failed ||
    TransferState.canceled => task,
  };
}
