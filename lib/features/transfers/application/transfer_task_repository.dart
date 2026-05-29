import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/entity_id.dart';
import '../domain/transfer_task.dart';

final transferTaskRepositoryProvider = Provider<TransferTaskRepository>((ref) {
  return InMemoryTransferTaskRepository();
});

abstract interface class TransferTaskRepository {
  Future<void> save(TransferTask task);
  Future<List<TransferTask>> list();
  Future<void> delete(TransferTaskId id);
  Future<void> clear();
}

class InMemoryTransferTaskRepository implements TransferTaskRepository {
  final Map<String, TransferTask> _tasks = {};

  @override
  Future<void> save(TransferTask task) async {
    _tasks[task.id.value] = task;
  }

  @override
  Future<List<TransferTask>> list() async {
    final tasks = _tasks.values.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return tasks;
  }

  @override
  Future<void> delete(TransferTaskId id) async {
    _tasks.remove(id.value);
  }

  @override
  Future<void> clear() async {
    _tasks.clear();
  }
}
