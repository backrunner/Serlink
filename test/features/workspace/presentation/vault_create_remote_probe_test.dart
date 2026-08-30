import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/sync/application/remote_vault_discovery_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  testWidgets('create form offers to restore an existing iCloud vault', (
    tester,
  ) async {
    final controller = await _pumpCreateSurface(tester, withRemoteVault: true);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'new local passphrase',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('An iCloud vault already exists'), findsOneWidget);
    expect(controller.initializeCalls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('icloud-vault-exists-restore-button')));
    await tester.pumpAndSettle();

    expect(controller.adoptedHeader, isNotNull);
    expect(controller.adoptedKind, SyncProviderKind.cloudKit);
    expect(
      controller.adoptedNotice,
      VaultSessionNotice.cloudKitRemoteVaultAdoptedAfterInitialize,
    );
    expect(controller.initializeCalls, isEmpty);
    expect(find.text('Unlock Vault'), findsOneWidget);
  });

  testWidgets('create form can create a new vault after confirmation', (
    tester,
  ) async {
    final controller = await _pumpCreateSurface(tester, withRemoteVault: true);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'new local passphrase',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('An iCloud vault already exists'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('icloud-vault-exists-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Replace iCloud sync data?'), findsOneWidget);
    expect(controller.initializeCalls, isEmpty);

    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Replace'));
    await tester.pumpAndSettle();

    expect(controller.initializeCalls, ['new local passphrase']);
    expect(controller.adoptedHeader, isNull);
  });

  testWidgets('create form cancel leaves the vault untouched', (tester) async {
    final controller = await _pumpCreateSurface(tester, withRemoteVault: true);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'new local passphrase',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();
    expect(find.text('An iCloud vault already exists'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.initializeCalls, isEmpty);
    expect(controller.adoptedHeader, isNull);
    expect(find.text('Create Vault'), findsWidgets);
  });

  testWidgets('create form initializes directly when no remote vault exists', (
    tester,
  ) async {
    final controller = await _pumpCreateSurface(tester, withRemoteVault: false);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'new local passphrase',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('An iCloud vault already exists'), findsNothing);
    expect(controller.initializeCalls, ['new local passphrase']);
  });
}

Future<_FakeVaultSessionController> _pumpCreateSurface(
  WidgetTester tester, {
  required bool withRemoteVault,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final database = SerlinkDatabase(NativeDatabase.memory());
  final transferQueue = TransferQueueController();
  addTearDown(database.close);
  addTearDown(transferQueue.dispose);

  final controller = _FakeVaultSessionController();
  if (withRemoteVault) {
    final remoteVault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    await remoteVault.initialize(passphrase: 'remote passphrase');
    final header = remoteVault.header!.copyWith(
      localUnlockProtectors: const [],
    );
    controller.probeResult = RemoteVaultDiscovery(
      header: header,
      manifest: RemoteManifest(
        vaultId: syncVaultId(header),
        protocolVersion: 1,
        encryptedPayload: const [1],
        headerPath: 'vault/headers/remote.json',
      ),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          const PlatformCapabilities(
            operatingSystem: 'linux',
            targetPlatform: TargetPlatform.linux,
          ),
        ),
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        vaultSessionControllerProvider.overrideWith(() => controller),
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        autoSyncEnabledProvider.overrideWithValue(false),
      ],
      child: const SerlinkApp(),
    ),
  );
  await _pumpUntilFound(tester, find.text('Create Vault'));
  return controller;
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
  RemoteVaultDiscovery? probeResult;
  final List<String> initializeCalls = [];
  VaultHeader? adoptedHeader;
  SyncProviderKind? adoptedKind;
  VaultSessionNotice? adoptedNotice;

  @override
  Future<VaultSessionState> build() async =>
      const VaultSessionState(vaultState: VaultState.uninitialized);

  @override
  Future<RemoteVaultDiscovery?> probeRemoteVaultBeforeInitialize() async =>
      probeResult;

  @override
  Future<void> initialize({required String passphrase}) async {
    initializeCalls.add(passphrase);
  }

  @override
  Future<void> adoptRemoteVaultHeader(
    VaultHeader header, {
    required SyncProviderKind kind,
    VaultSessionNotice? notice,
  }) async {
    adoptedHeader = header;
    adoptedKind = kind;
    adoptedNotice = notice;
    state = AsyncData(
      VaultSessionState(vaultState: VaultState.locked, notice: notice),
    );
  }
}
