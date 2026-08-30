import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/core/logging/offline_diagnostic_logger.dart';
import 'package:serlink/database/database_recovery.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/import_export/application/automatic_vault_backup_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/application/sync_settings_service.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/local_device_info.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  late _InMemorySyncProvider remote;

  setUp(() {
    remote = _InMemorySyncProvider();
  });

  testWidgets('enabling WebDAV on an empty remote saves without a prompt', (
    tester,
  ) async {
    final harness = await _pumpUnlockedWorkspace(tester, remote);

    await _openWebDavDialog(tester);
    await _fillWebDavForm(tester);
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await _pumpUntilGone(
      tester,
      find.byKey(const ValueKey('webdav-save-button')),
    );

    expect(find.text('Remote already has another Serlink vault'), findsNothing);
    final saved = await harness.container
        .read(syncSettingsServiceProvider)
        .readWebDav();
    expect(saved?.enabled, isTrue);
  });

  testWidgets('enabling WebDAV on the same vault saves without a prompt', (
    tester,
  ) async {
    final harness = await _pumpUnlockedWorkspace(tester, remote);
    final service = harness.container
        .read(vaultSessionControllerProvider.notifier)
        .service;
    await SyncRunService(
      vault: service,
      records: InMemoryVaultRecordRepository(),
    ).pushEncryptedSnapshot(remote);

    await _openWebDavDialog(tester);
    await _fillWebDavForm(tester);
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await _pumpUntilGone(
      tester,
      find.byKey(const ValueKey('webdav-save-button')),
    );

    expect(find.text('Remote already has another Serlink vault'), findsNothing);
    final saved = await harness.container
        .read(syncSettingsServiceProvider)
        .readWebDav();
    expect(saved?.enabled, isTrue);
  });

  testWidgets('WebDAV vault mismatch cancel aborts the save', (tester) async {
    final harness = await _pumpUnlockedWorkspace(tester, remote);
    await _seedRemoteVault(remote);

    await _openWebDavDialog(tester);
    await _fillWebDavForm(tester);
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await _pumpUntilFound(
      tester,
      find.text('Remote already has another Serlink vault'),
    );

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    final saved = await harness.container
        .read(syncSettingsServiceProvider)
        .readWebDav();
    expect(saved, isNull);
    // The settings dialog stays open so the user can adjust the draft.
    expect(find.byKey(const ValueKey('webdav-save-button')), findsOneWidget);
  });

  testWidgets('WebDAV vault mismatch can keep local data and replace remote', (
    tester,
  ) async {
    final harness = await _pumpUnlockedWorkspace(tester, remote);
    await _seedRemoteVault(remote);
    final localVaultId = syncVaultId(
      harness.container
          .read(vaultSessionControllerProvider.notifier)
          .service
          .header!,
    );

    await _openWebDavDialog(tester);
    await _fillWebDavForm(tester);
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await _pumpUntilFound(
      tester,
      find.text('Remote already has another Serlink vault'),
    );

    await tester.tap(
      find.byKey(const ValueKey('webdav-mismatch-replace-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Replace the remote vault?'), findsOneWidget);

    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Replace'));
    await _pumpUntilGone(
      tester,
      find.byKey(const ValueKey('webdav-save-button')),
    );
    await tester.pumpAndSettle();

    final saved = await harness.container
        .read(syncSettingsServiceProvider)
        .readWebDav();
    expect(saved?.enabled, isTrue);
    expect(remote.manifest?.vaultId, localVaultId);
    // The vault stays unlocked; the workspace is still visible.
    expect(
      harness.container
          .read(vaultSessionControllerProvider)
          .requireValue
          .vaultState,
      VaultState.unlocked,
    );
  });

  testWidgets('WebDAV vault mismatch can restore this device from remote', (
    tester,
  ) async {
    final harness = await _pumpUnlockedWorkspace(tester, remote);
    await _seedRemoteVault(remote);

    await _openWebDavDialog(tester);
    await _fillWebDavForm(tester);
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await _pumpUntilFound(
      tester,
      find.text('Remote already has another Serlink vault'),
    );

    await tester.tap(
      find.byKey(const ValueKey('webdav-mismatch-restore-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Restore this device from the remote vault?'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(
        SerlinkFilledButton,
        'Restore This Device from Remote',
      ),
    );
    // Adoption writes the remote header locally and locks the vault. The
    // settings dialog closes and the settings page shows the locked state.
    await _pumpUntilGone(
      tester,
      find.byKey(const ValueKey('webdav-save-button')),
    );

    final locked = harness.container
        .read(vaultSessionControllerProvider)
        .requireValue;
    expect(locked.vaultState, VaultState.locked);
    expect(locked.notice, VaultSessionNotice.webDavRemoteVaultAdopted);

    // The unlock surface lives on the Hosts tab.
    await tester.tap(find.text('Hosts'));
    await _pumpUntilFound(tester, find.text('Unlock Vault'));

    // Unlocking with the remote passphrase pulls the remote snapshot.
    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'remote passphrase',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await _pumpUntilVaultState(tester, harness.container, VaultState.unlocked);

    final unlocked = harness.container
        .read(vaultSessionControllerProvider)
        .requireValue;
    expect(unlocked.failureMessage, isNull);
    final restored = await DriftVaultRecordRepository(
      harness.database,
    ).read(VaultRecordId('host:remote'));
    expect(restored, isNotNull);
  });
}

Future<void> _seedRemoteVault(_InMemorySyncProvider remote) async {
  final remoteVault = InMemoryVaultService(
    config: const VaultCryptoConfig.testing(),
  );
  await remoteVault.initialize(passphrase: 'remote passphrase');
  final remoteRecords = InMemoryVaultRecordRepository();
  await remoteRecords.upsert(
    await remoteVault.encryptRecord(
      id: VaultRecordId('host:remote'),
      type: 'host',
      plaintext: utf8.encode('{"hostname":"remote.example.test"}'),
    ),
  );
  await SyncRunService(
    vault: remoteVault,
    records: remoteRecords,
  ).pushEncryptedSnapshot(remote);
}

class _WebDavHarness {
  const _WebDavHarness({required this.container, required this.database});

  final ProviderContainer container;
  final SerlinkDatabase database;
}

Future<_WebDavHarness> _pumpUnlockedWorkspace(
  WidgetTester tester,
  _InMemorySyncProvider remote,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
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
            operatingSystem: 'linux',
            targetPlatform: TargetPlatform.linux,
          ),
        ),
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        syncSettingsServiceProvider.overrideWith(
          (ref) => _FakeRemoteSyncSettingsService(
            settings: ref.watch(syncSettingsRepositoryProvider),
            cloudKitSettings: ref.watch(cloudKitSyncSettingsRepositoryProvider),
            secrets: ref.watch(secretStoreProvider),
            cloudKitAvailable: false,
            remote: remote,
          ),
        ),
        webDavSyncProviderFactoryProvider.overrideWithValue(
          (_) async => remote,
        ),
        localDeviceInfoProvider.overrideWithValue(const _FakeLocalDeviceInfo()),
        offlineDiagnosticLoggerProvider.overrideWithValue(
          _NoopDiagnosticLogger(),
        ),
        automaticVaultBackupServiceProvider.overrideWith(
          (ref) async => _DisabledBackupService(),
        ),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        autoSyncEnabledProvider.overrideWithValue(false),
      ],
      child: const SerlinkApp(),
    ),
  );
  await _pumpUntilFound(tester, find.text('Create Vault'));

  final element = tester.element(find.byType(SerlinkApp));
  final container = ProviderScope.containerOf(element);
  await container.read(vaultSessionControllerProvider.future);
  await container
      .read(vaultSessionControllerProvider.notifier)
      .initialize(passphrase: 'local passphrase');
  await _pumpUntilFound(tester, find.text('I have saved it'));
  await tester.tap(find.text('I have saved it'));
  await tester.pumpAndSettle();

  return _WebDavHarness(container: container, database: database);
}

Future<void> _openWebDavDialog(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Configure'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Configure'));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('webdav-endpoint-field')),
    findsOneWidget,
  );
}

Future<void> _fillWebDavForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('webdav-endpoint-field')),
    'https://dav.example.test/webdav',
  );
  await tester.enterText(
    find.byKey(const ValueKey('webdav-username-field')),
    'sync-user',
  );
  await tester.enterText(
    find.byKey(const ValueKey('webdav-password-field')),
    'sync-password',
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('webdav-save-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder to disappear');
}

Future<void> _pumpUntilVaultState(
  WidgetTester tester,
  ProviderContainer container,
  VaultState expected,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    final state = container.read(vaultSessionControllerProvider).requireValue;
    if (state.vaultState == expected || state.failureMessage != null) {
      return;
    }
  }
  fail('Timed out waiting for vault state $expected');
}

/// Sync settings service that keeps real persistence (including the keychain
/// password) but points provider construction at an in-memory remote.
class _FakeRemoteSyncSettingsService extends SyncSettingsService {
  _FakeRemoteSyncSettingsService({
    required super.settings,
    required super.cloudKitSettings,
    required super.secrets,
    required super.cloudKitAvailable,
    required this.remote,
  });

  final SyncProvider remote;

  @override
  Future<SyncProvider> buildWebDavProviderFromDraft(
    WebDavSyncSettingsDraft draft,
  ) async {
    // Keep the real draft validation, then swap in the fake remote.
    await super.buildWebDavProviderFromDraft(draft);
    return remote;
  }
}

/// Automatic backups need real filesystem access, which widget tests cannot
/// perform inside the fake-async zone; adoption treats snapshot failures as
/// best-effort, so failing here is safe.
class _DisabledBackupService extends AutomaticVaultBackupService {
  _DisabledBackupService()
    : super(
        recovery: DatabaseRecoveryService(
          databaseFile: File('unused.db'),
          automaticBackupDirectory: Directory('unused-backups'),
          quarantineDirectory: Directory('unused-quarantine'),
        ),
      );

  @override
  Future<DatabaseBackupEntry> createSnapshot({required String reason}) {
    throw UnimplementedError('automatic backups are disabled in tests');
  }
}

/// The real [LocalDeviceInfo] goes through a platform channel that never
/// completes inside the widget-test fake zone.
class _FakeLocalDeviceInfo extends LocalDeviceInfo {
  const _FakeLocalDeviceInfo();

  @override
  Future<String?> displayName() async => null;
}

/// The real [OfflineDiagnosticLogger] writes through path_provider and dart:io,
/// which never complete inside the widget-test fake zone.
class _NoopDiagnosticLogger extends OfflineDiagnosticLogger {
  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) async {}
}

/// In-memory [SyncProvider] with the same semantics as
/// LocalDirectorySyncProvider, so widget tests never touch dart:io inside the
/// fake-async zone.
class _InMemorySyncProvider implements SyncProvider {
  RemoteManifest? manifest;
  final Map<String, List<int>> objects = {};

  @override
  Future<ProviderCapabilities> capabilities() async {
    return const ProviderCapabilities(
      kind: SyncProviderKind.local,
      supportsConditionalWrites: false,
      requiresTls: false,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() async => manifest;

  @override
  Future<void> writeManifest(RemoteManifest value) async {
    manifest = value;
  }

  @override
  Future<void> writeManifestIfUnchanged(
    RemoteManifest value,
    RemoteManifest? expectedCurrent,
  ) async {
    final current = manifest;
    final unchanged = current == null
        ? expectedCurrent == null
        : expectedCurrent != null && _sameBytes(current, expectedCurrent);
    if (!unchanged) {
      throw const SyncProviderException(
        'sync.provider.conflict',
        'Remote sync data changed while syncing.',
      );
    }
    manifest = value;
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    final refs = [
      for (final path in objects.keys)
        if (prefix == null || path.startsWith(prefix)) RemoteObjectRef(path),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return refs;
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    final bytes = objects[ref.path];
    if (bytes == null) {
      throw const SyncProviderException(
        'sync.provider.not_found',
        'Sync object was not found.',
      );
    }
    return bytes;
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    objects[ref.path] = List<int>.of(bytes);
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    objects.remove(ref.path);
  }

  static bool _sameBytes(RemoteManifest a, RemoteManifest b) {
    final aBytes = a.toBytes();
    final bBytes = b.toBytes();
    if (aBytes.length != bBytes.length) {
      return false;
    }
    for (var i = 0; i < aBytes.length; i += 1) {
      if (aBytes[i] != bBytes[i]) {
        return false;
      }
    }
    return true;
  }
}
