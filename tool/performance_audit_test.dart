// Run explicitly with:
// flutter test tool/performance_audit_test.dart --reporter expanded --concurrency=1
// These are diagnostic probes, not release timing gates. All data is synthetic.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/application/host_store.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/terminal/application/terminal_buffer_search_controller.dart';
import 'package:serlink/features/transfers/data/encrypted_transfer_task_repository.dart';
import 'package:serlink/features/transfers/domain/transfer_task.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('terminal search time, notifications, and retained anchors', () {
    for (final lines in [1000, 5000, 10000]) {
      final terminal = Terminal(maxLines: lines + 24);
      terminal.write(List.filled(lines, 'needle audit log entry\r\n').join());
      final controller = TerminalController();
      final search = TerminalBufferSearchController(
        terminal: terminal,
        controller: controller,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (var i = 0; i < 3; i++) {
        search.search('needle');
      }
      final samples = <double>[];
      notifications = 0;
      for (var i = 0; i < 5; i++) {
        final watch = Stopwatch()..start();
        final result = search.refresh();
        watch.stop();
        expect(result.matchCount, lines);
        samples.add(watch.elapsedMicroseconds / 1000);
      }
      final refreshNotifications = notifications / samples.length;
      search.clear();
      final anchors = List.generate(
        terminal.buffer.height,
        (y) => terminal.buffer.lines[y].anchors.length,
      ).fold<int>(0, (sum, count) => sum + count);
      _report('terminal_search', {
        'matching_lines': lines,
        'refresh_median_ms': _median(samples),
        'notifications_per_refresh': refreshNotifications,
        'anchors_after_8_searches_and_clear': anchors,
      });
      controller.dispose();
    }
  });

  test('unrelated transfer saves and host summary reloads', () async {
    final vault = await _vault();
    addTearDown(vault.lock);
    final records = InMemoryVaultRecordRepository();
    final hosts = _CountingHosts(vault: vault, records: records);
    for (var i = 0; i < 1000; i++) {
      await hosts.save(_host(i));
    }
    final container = ProviderContainer(
      overrides: [
        vaultSessionControllerProvider.overrideWith(_UnlockedSession.new),
        hostRepositoryProvider.overrideWithValue(hosts),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(hostSummariesProvider(1), (_, _) {});
    addTearDown(subscription.close);
    await container.read(hostSummariesProvider(1).future);
    final transfers = EncryptedTransferTaskRepository(
      vault: vault,
      records: NotifyingVaultRecordRepository(
        inner: records,
        changes: container.read(vaultRecordChangeBusProvider),
      ),
    );
    final initialCalls = hosts.listCalls;
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await transfers.save(
        TransferTask(
          id: TransferTaskId('audit-transfer'),
          direction: TransferDirection.upload,
          localPath: '/synthetic/local',
          remotePath: '/synthetic/remote',
          state: TransferState.running,
          transferredBytes: i * 32768,
          createdAt: DateTime.utc(2026),
        ),
      );
      // Pace events so each invalidation can settle; this measures fan-out,
      // not network throughput or Riverpod's same-frame event coalescing.
      await container.pump();
      await container.read(hostSummariesProvider(1).future);
    }
    watch.stop();
    _report('host_invalidations', {
      'hosts': 1000,
      'paced_transfer_saves': 20,
      'host_list_reloads': hosts.listCalls - initialCalls,
      'elapsed_ms': watch.elapsedMicroseconds / 1000,
    });
  });

  test('sync object operations for unchanged and changed snapshots', () async {
    final directory = await Directory.systemTemp.createTemp('serlink-perf-');
    addTearDown(() => directory.delete(recursive: true));
    final provider = _CountingSyncProvider(directory);
    final vault = await _vault();
    addTearDown(vault.lock);
    final records = InMemoryVaultRecordRepository();
    final hosts = EncryptedHostRepository(vault: vault, records: records);
    for (var i = 0; i < 100; i++) {
      await hosts.save(_host(i));
    }
    final service = SyncRunService(vault: vault, records: records);
    await service.syncEncryptedSnapshot(provider);
    provider.resetCounts();
    await service.syncEncryptedSnapshot(provider);
    _report('sync_unchanged', provider.counts);
    await hosts.save(_host(0, displayName: 'Changed audit host'));
    provider.resetCounts();
    await service.syncEncryptedSnapshot(provider);
    _report('sync_one_host_changed', provider.counts);
  });

  test('record type query plan', () async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const query =
        'EXPLAIN QUERY PLAN SELECT * FROM encrypted_records '
        "WHERE type = 'host' ORDER BY type, id";
    final before = await database.customSelect(query).get();
    // This index exists only in the probe's temporary in-memory database.
    await database.customStatement(
      'CREATE INDEX audit_type_id ON encrypted_records(type, id)',
    );
    final after = await database.customSelect(query).get();
    _report('record_type_query', {
      'current': before.map((row) => row.data['detail']).toList(),
      'with_candidate_index': after.map((row) => row.data['detail']).toList(),
    });
  });
}

Future<InMemoryVaultService> _vault() async {
  final vault = InMemoryVaultService(config: const VaultCryptoConfig.testing());
  await vault.initialize(passphrase: 'synthetic performance audit');
  return vault;
}

HostConfig _host(int i, {String? displayName}) => HostConfig(
  id: HostId('audit-$i'),
  displayName: displayName ?? 'Audit host $i',
  hostname: 'host-$i.example.test',
  username: 'audit',
  port: 22,
  authKinds: const {HostAuthKind.password},
  tags: const {},
  trustState: HostTrustState.unknown,
  identityIds: const [],
  startupCommands: const [],
  jumpHostIds: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 1, displayName == null ? 1 : 2),
);

class _UnlockedSession extends VaultSessionController {
  @override
  Future<VaultSessionState> build() async => const VaultSessionState(
    vaultState: VaultState.unlocked,
    unlockGeneration: 1,
  );
}

class _CountingHosts extends EncryptedHostRepository {
  _CountingHosts({required super.vault, required super.records});
  int listCalls = 0;

  @override
  Future<List<HostConfig>> list() {
    listCalls++;
    return super.list();
  }
}

class _CountingSyncProvider extends LocalDirectorySyncProvider {
  _CountingSyncProvider(super.rootDirectory);
  int recordReads = 0;
  int recordWrites = 0;

  Map<String, Object?> get counts => {
    'hosts': 100,
    'record_object_reads': recordReads,
    'record_object_writes': recordWrites,
  };

  void resetCounts() {
    recordReads = 0;
    recordWrites = 0;
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) {
    if (ref.path.startsWith('records/')) recordReads++;
    return super.readObject(ref);
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) {
    if (ref.path.startsWith('records/')) recordWrites++;
    return super.writeObject(ref, bytes);
  }
}

double _median(List<double> samples) {
  final sorted = [...samples]..sort();
  return sorted[sorted.length ~/ 2];
}

void _report(String probe, Map<String, Object?> values) {
  // ignore: avoid_print
  print(jsonEncode({'probe': probe, ...values}));
}
