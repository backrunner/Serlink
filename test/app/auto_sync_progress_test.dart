import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sync/application/auto_sync_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test(
    'transfer changes coalesce without delaying host edits or starving sync',
    () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            autoSyncEnabledProvider.overrideWithValue(false),
            vaultSessionControllerProvider.overrideWith(_LockedSession.new),
            cloudKitSyncChangesProvider.overrideWith(
              (_) => const Stream.empty(),
            ),
            autoSyncControllerProvider.overrideWith(_RecordingAutoSync.new),
          ],
        );
        final listener = container.listen(
          autoSyncControllerProvider,
          (_, _) {},
        );
        final controller =
            container.read(autoSyncControllerProvider.notifier)
                as _RecordingAutoSync;
        final changes = container.read(vaultRecordChangeBusProvider);
        async.flushMicrotasks();
        void change(
          String type, {
          VaultRecordChangeOrigin origin = VaultRecordChangeOrigin.local,
        }) {
          changes.notify(
            VaultRecordChange(
              kind: VaultRecordChangeKind.upsert,
              id: VaultRecordId('$type:test'),
              type: type,
              origin: origin,
            ),
          );
          async.flushMicrotasks();
        }

        for (var i = 0; i < 19; i++) {
          change('transfer_task');
          async.elapse(const Duration(milliseconds: 100));
        }
        expect(controller.requests, 0);
        change('host');
        expect(controller.requests, 1);
        async.elapse(const Duration(milliseconds: 100));
        expect(controller.requests, 2);
        change('transfer_task', origin: VaultRecordChangeOrigin.remoteSync);
        async.elapse(const Duration(seconds: 2));
        expect(controller.requests, 2);
        change('transfer_task');
        listener.close();
        container.dispose();
        async.elapse(const Duration(seconds: 2));
        expect(controller.requests, 2);
      });
    },
  );
}

class _RecordingAutoSync extends AutoSyncController {
  int requests = 0;

  @override
  void requestSync({Duration? delay}) {
    requests++;
  }
}

class _LockedSession extends VaultSessionController {
  @override
  Future<VaultSessionState> build() async =>
      const VaultSessionState(vaultState: VaultState.locked);
}
