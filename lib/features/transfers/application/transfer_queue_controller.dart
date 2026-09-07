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
    DateTime Function()? now,
  }) : _repository = repository ?? InMemoryTransferTaskRepository(),
       _now = now ?? DateTime.now,
       _state = const TransferQueueState(tasks: []);

  static const _uuid = Uuid();

  final int maxConcurrentTransfers;
  final TransferTaskRepository _repository;
  final DateTime Function() _now;
  final StreamController<TransferQueueState> _stateController =
      StreamController<TransferQueueState>.broadcast();
  final List<_TransferOperation> _operations = [];
  final Map<TransferTaskId, StreamSubscription<TransferProgress>>
  _subscriptions = {};
  final Map<TransferTaskId, TransferTask> _pendingTaskSaves = {};
  final Map<TransferTaskId, TransferTask> _checkpoints = {};
  final Map<TransferTaskId, TransferProgress> _pendingProgress = {};
  final Map<TransferTaskId, Timer> _progressTimers = {};
  Timer? _checkpointTimer;
  static const _progressInterval = Duration(milliseconds: 100);
  static const _checkpointInterval = Duration(seconds: 1);
  Future<void> _pendingPersistence = Future<void>.value();

  TransferQueueState _state;
  bool _restoreStarted = false;
  bool _disposed = false;
  int _restoreGeneration = 0;

  TransferQueueState get state => _state;

  Stream<TransferQueueState> watchState() async* {
    yield _state;
    yield* _stateController.stream;
  }

  Future<void> restorePersistedTasks() async {
    if (_restoreStarted || _disposed) {
      return;
    }
    _restoreStarted = true;
    final generation = _restoreGeneration;
    try {
      final now = _now().toUtc();
      final persisted = await _repository.list();
      if (_disposed || generation != _restoreGeneration) {
        return;
      }
      final currentIds = {for (final task in _state.tasks) task.id.value};
      final restored = <TransferTask>[];
      final interrupted = <TransferTask>[];
      for (final task in persisted) {
        if (currentIds.contains(task.id.value)) {
          continue;
        }
        final updated = _markInterruptedIfActive(task, now);
        restored.add(updated);
        if (!identical(updated, task)) interrupted.add(updated);
      }
      if (restored.isEmpty) {
        return;
      }
      _setState(TransferQueueState(tasks: [...restored, ..._state.tasks]));
      for (final task in interrupted) {
        _persistTask(task);
      }
    } on Object {
      _restoreStarted = false;
    }
  }

  TransferTaskId enqueueUpload({
    required SftpConnection connection,
    TransferItemKind itemKind = TransferItemKind.file,
    HostId? sourceHostId,
    String? sourceMachineName,
    required String localPath,
    required String remotePath,
  }) {
    return _enqueue(
      connection: connection,
      direction: TransferDirection.upload,
      itemKind: itemKind,
      sourceHostId: sourceHostId,
      sourceMachineName: sourceMachineName,
      localPath: localPath,
      remotePath: remotePath,
    );
  }

  TransferTaskId enqueueDownload({
    required SftpConnection connection,
    TransferItemKind itemKind = TransferItemKind.file,
    HostId? sourceHostId,
    String? sourceMachineName,
    required String remotePath,
    required String localPath,
  }) {
    return _enqueue(
      connection: connection,
      direction: TransferDirection.download,
      itemKind: itemKind,
      sourceHostId: sourceHostId,
      sourceMachineName: sourceMachineName,
      localPath: localPath,
      remotePath: remotePath,
    );
  }

  Future<void> pause(TransferTaskId taskId) async {
    _flushProgress(taskId);
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
    _flushProgress(taskId);
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    await _subscriptions.remove(taskId)?.cancel();
    _removeQueuedOperation(taskId);
    _replaceTask(
      task.copyWith(state: TransferState.canceled, completedAt: _now().toUtc()),
    );
    _pump();
  }

  Future<void> delete(TransferTaskId taskId) async {
    _discardProgress(taskId);
    _checkpoints.remove(taskId);
    final task = _state.byId(taskId);
    if (task == null) {
      return;
    }
    await _subscriptions.remove(taskId)?.cancel();
    _operations.removeWhere((operation) => operation.task.id == taskId);
    _setState(
      TransferQueueState(
        tasks: [
          for (final existing in _state.tasks)
            if (existing.id != taskId) existing,
        ],
      ),
    );
    await _deletePersistedTask(taskId);
    if (!_isTerminal(task.state)) {
      _pump();
    }
  }

  Future<void> clear() async {
    for (final taskId in _progressTimers.keys.toList()) {
      _discardProgress(taskId);
    }
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    _checkpoints.clear();
    _restoreGeneration += 1;
    final subscriptions = _subscriptions.values.toList();
    _subscriptions.clear();
    _operations.clear();
    _setState(const TransferQueueState(tasks: []));
    final persistence = _clearPersistedTasks();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await persistence;
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
    if (_disposed) {
      return;
    }
    // Disposal schedules the latest checkpoint. Call flushPersistence before
    // shutting down the repository when durable completion is required.
    unawaited(flushPersistence());
    _disposed = true;
    final subscriptions = _subscriptions.values.toList();
    _subscriptions.clear();
    _operations.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await _stateController.close();
  }

  /// Waits for already queued history writes without changing transfer state.
  Future<void> flushPersistence() {
    for (final taskId in _progressTimers.keys.toList()) {
      _flushProgress(taskId);
    }
    _flushCheckpoints();
    return _pendingPersistence;
  }

  TransferTaskId _enqueue({
    required SftpConnection connection,
    required TransferDirection direction,
    required TransferItemKind itemKind,
    HostId? sourceHostId,
    String? sourceMachineName,
    required String localPath,
    required String remotePath,
  }) {
    final now = _now().toUtc();
    final task = TransferTask(
      id: TransferTaskId(_uuid.v4()),
      direction: direction,
      itemKind: itemKind,
      sourceHostId: sourceHostId,
      sourceMachineName: _normalizedSourceMachineName(sourceMachineName),
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
    if (_disposed) {
      return;
    }
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
    final now = _now().toUtc();
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
    if (_disposed) return;
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) return;
    if (progress.state != task.state || _isTerminal(progress.state)) {
      _discardProgress(taskId);
      _applyProgress(taskId, progress);
    } else if (_progressTimers.containsKey(taskId)) {
      _pendingProgress[taskId] = progress;
    } else {
      _applyProgress(taskId, progress);
      _scheduleProgress(taskId);
    }
  }

  void _scheduleProgress(TransferTaskId taskId) {
    _progressTimers[taskId] = Timer(_progressInterval, () {
      _progressTimers.remove(taskId);
      final progress = _pendingProgress.remove(taskId);
      if (progress != null && !_disposed) {
        _applyProgress(taskId, progress);
        _scheduleProgress(taskId);
      }
    });
  }

  void _discardProgress(TransferTaskId taskId) {
    _progressTimers.remove(taskId)?.cancel();
    _pendingProgress.remove(taskId);
  }

  void _flushProgress(TransferTaskId taskId) {
    final progress = _pendingProgress[taskId];
    _discardProgress(taskId);
    if (progress != null) _applyProgress(taskId, progress);
  }

  void _applyProgress(TransferTaskId taskId, TransferProgress progress) {
    final task = _state.byId(taskId);
    if (task == null || _isTerminal(task.state)) {
      return;
    }
    final now = _now().toUtc();
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
    _replaceTask(updated, progressOnly: progress.state == task.state);
    if (_isTerminal(progress.state)) {
      // Terminal progress means the transfer completed on its own. Let the
      // source stream close normally so SFTP implementations do not interpret
      // this as a user-requested cancellation.
      _subscriptions.remove(taskId);
      _pump();
    }
  }

  void _handleError(TransferTaskId taskId, Object error) {
    _flushProgress(taskId);
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
        completedAt: _now().toUtc(),
      ),
    );
    _pump();
  }

  void _handleDone(TransferTaskId taskId) {
    _flushProgress(taskId);
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
      final now = _now().toUtc();
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
        completedAt: _now().toUtc(),
      ),
    );
    _pump();
  }

  void _replaceTask(TransferTask task, {bool progressOnly = false}) {
    if (task.state == TransferState.completed) {
      _operations.removeWhere((operation) => operation.task.id == task.id);
    }
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
    if (progressOnly) {
      _checkpoints[task.id] = task;
      _checkpointTimer ??= Timer(_checkpointInterval, _flushCheckpoints);
    } else {
      _persistTask(task);
    }
  }

  void _removeQueuedOperation(TransferTaskId taskId) {
    for (final operation in _operations) {
      if (operation.task.id == taskId &&
          operation.task.state == TransferState.queued) {
        operation.task = operation.task.copyWith(
          state: TransferState.canceled,
          completedAt: _now().toUtc(),
        );
        break;
      }
    }
  }

  void _setState(TransferQueueState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    _stateController.add(nextState);
  }

  void _persistTask(TransferTask task) {
    if (_disposed) {
      return;
    }
    _checkpoints.remove(task.id);
    if (_checkpoints.isEmpty) {
      _checkpointTimer?.cancel();
      _checkpointTimer = null;
    }
    final alreadyPending = _pendingTaskSaves.containsKey(task.id);
    _pendingTaskSaves[task.id] = task;
    if (alreadyPending) {
      return;
    }
    // Keep only the latest progress while encryption or disk writes are busy.
    unawaited(
      _enqueuePersistence(() async {
        final latest = _pendingTaskSaves.remove(task.id);
        if (latest != null) {
          await _repository.save(latest);
        }
      }),
    );
  }

  void _flushCheckpoints() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    final tasks = _checkpoints.values.toList();
    _checkpoints.clear();
    for (final task in tasks) {
      _persistTask(task);
    }
  }

  Future<void> _enqueuePersistence(Future<void> Function() action) {
    final result = _pendingPersistence.then((_) => action()).catchError((
      Object _,
    ) {
      // Locking the vault must not interrupt established transfers.
    });
    _pendingPersistence = result;
    return result;
  }

  Future<void> _deletePersistedTask(TransferTaskId taskId) {
    _pendingTaskSaves.remove(taskId);
    return _enqueuePersistence(() => _repository.delete(taskId));
  }

  Future<void> _clearPersistedTasks() {
    _pendingTaskSaves.clear();
    return _enqueuePersistence(_repository.clear);
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

String? _normalizedSourceMachineName(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
