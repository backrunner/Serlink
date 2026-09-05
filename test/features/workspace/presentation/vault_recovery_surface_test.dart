import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/database_recovery.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_record_health_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  testWidgets('local data damage offers backup restore as the primary action', (
    tester,
  ) async {
    await _pumpRecoverySurface(
      tester,
      const VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: VaultRecoveryStatus.vaultHeaderInvalid,
        failureMessage: 'Vault metadata is invalid: test detail',
      ),
    );

    expect(find.text('Local vault data is damaged'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-restore-latest-backup-button')),
      findsOneWidget,
    );
    expect(find.text('Restore from automatic backup'), findsOneWidget);
    expect(find.text('Import backup file'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-quarantine-records-button')),
      findsNothing,
    );

    // The raw failure detail stays collapsed behind the disclosure toggle.
    expect(find.text('View details'), findsOneWidget);
    expect(
      find.text('Vault metadata is invalid: test detail', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vault metadata is invalid: test detail', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Hide details'), findsOneWidget);
  });

  testWidgets('database damage uses the same local data copy', (tester) async {
    await _pumpRecoverySurface(
      tester,
      const VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: VaultRecoveryStatus.databaseCorrupt,
      ),
    );

    expect(find.text('Local vault data is damaged'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-restore-latest-backup-button')),
      findsOneWidget,
    );
  });

  testWidgets('remote damage points to sync settings without restore actions', (
    tester,
  ) async {
    await _pumpRecoverySurface(
      tester,
      const VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
        failureMessage: 'Remote vault data is missing.',
      ),
    );

    expect(find.text('Cloud sync data needs repair'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-restore-latest-backup-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('vault-import-recovery-backup-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('vault-recovery-reset-entry-button')),
      findsOneWidget,
    );
  });

  testWidgets('records damage offers quarantine as the primary action', (
    tester,
  ) async {
    await _pumpRecoverySurface(
      tester,
      VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: VaultRecoveryStatus.recordsCorrupt,
        recordHealthReport: VaultRecordHealthReport(
          validCount: 4,
          corruptRecords: [
            VaultRecordHealthIssue(
              id: VaultRecordId('host:broken'),
              type: 'host',
              revision: '1',
              code: 'record.authentication_failed',
              message: 'Record failed authentication.',
            ),
          ],
          unsupportedRecords: const [],
        ),
      ),
    );

    expect(find.text('Some vault records are damaged'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-quarantine-records-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('vault-restore-latest-backup-button')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpRecoverySurface(
  WidgetTester tester,
  VaultSessionState session,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final database = SerlinkDatabase(NativeDatabase.memory());
  final transferQueue = TransferQueueController();
  addTearDown(database.close);
  addTearDown(transferQueue.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            operatingSystem: 'ios',
            targetPlatform: TargetPlatform.iOS,
          ),
        ),
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        vaultSessionControllerProvider.overrideWith(
          () => _FakeVaultSessionController(session),
        ),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        autoSyncEnabledProvider.overrideWithValue(false),
      ],
      child: const SerlinkApp(),
    ),
  );
  await _pumpUntilFound(
    tester,
    find.byKey(const ValueKey('vault-recovery-reset-entry-button')),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

class _FakeVaultSessionController extends VaultSessionController {
  _FakeVaultSessionController(this._session);

  final VaultSessionState _session;

  @override
  Future<VaultSessionState> build() async => _session;
}
