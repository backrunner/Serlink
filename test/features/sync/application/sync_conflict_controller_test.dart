import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';

void main() {
  test('sync conflict controller stores and clears current conflicts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(syncConflictControllerProvider.notifier);
    controller.setConflicts([
      SyncRecordConflict(
        id: VaultRecordId('host:1'),
        type: 'host',
        localRevision: 'local',
        remoteRevision: 'remote',
      ),
    ]);

    expect(container.read(syncConflictControllerProvider), hasLength(1));

    controller.clear();

    expect(container.read(syncConflictControllerProvider), isEmpty);
  });
}
