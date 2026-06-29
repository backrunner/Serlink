import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database/serlink_database.dart';
import '../database/database_recovery.dart';
import '../core/logging/offline_diagnostic_logger.dart';
import '../core/logging/redactor.dart';
import '../core/runtime/app_profile_lock.dart';
import '../features/diagnostics/application/diagnostic_bundle_service.dart';
import '../features/hosts/application/host_repository.dart';
import '../features/identities/application/identity_repository.dart';
import '../features/import_export/application/identity_metadata_export_service.dart';
import '../features/import_export/application/host_metadata_export_service.dart';
import '../features/import_export/application/open_ssh_config_export_service.dart';
import '../features/import_export/application/known_hosts_import_service.dart';
import '../features/import_export/application/open_ssh_certificate_import_service.dart';
import '../features/import_export/application/open_ssh_config_import_service.dart';
import '../features/import_export/application/automatic_vault_backup_service.dart';
import '../features/import_export/application/vault_backup_service.dart';
import '../features/import_export/application/vault_backup_restore_service.dart';
import '../features/security/application/security_modal_service.dart';
import '../features/security/presentation/flutter_security_modal_service.dart';
import '../features/settings/application/app_language_settings.dart';
import '../features/snippets/application/snippet_repository.dart';
import '../features/snippets/application/snippet_write_service.dart';
import '../features/snippets/domain/snippet.dart';
import '../features/sync/application/auto_sync_controller.dart';
import '../features/sync/application/cloudkit_encrypted_snapshot_prefetch_controller.dart';
import '../features/sync/application/encrypted_snapshot_staging.dart';
import '../features/sync/application/remote_vault_discovery_service.dart';
import '../features/sync/application/sync_delete_tombstone_repository.dart';
import '../features/sync/application/sync_device_service.dart';
import '../features/sync/application/sync_field_merge_service.dart';
import '../features/sync/application/sync_record_baseline_repository.dart';
import '../features/sync/application/sync_repair_service.dart';
import '../features/sync/application/sync_run_service.dart';
import '../features/sync/application/sync_settings_service.dart';
import '../features/sync/data/cloudkit_sync_provider.dart';
import '../features/sync/data/encrypted_snapshot_staging_repository.dart';
import '../features/sync/data/local_cloudkit_sync_settings_repository.dart';
import '../features/sync/data/local_sync_record_baseline_repository.dart';
import '../features/sync/data/local_webdav_sync_settings_repository.dart';
import '../features/sync/domain/sync_provider.dart';
import '../features/ssh/application/connection_profile_resolver.dart';
import '../features/ssh/application/encrypted_connection_profile_resolver.dart';
import '../features/ssh/application/host_key_verification_service.dart';
import '../features/ssh/application/known_host_repository.dart';
import '../features/terminal/application/terminal_display_settings.dart';
import '../features/terminal/data/local_terminal_display_settings_repository.dart';
import '../features/terminal/application/terminal_font_discovery.dart';
import '../features/transfers/application/transfer_queue_controller.dart';
import '../features/vault/application/in_memory_vault_service.dart';
import '../features/vault/application/vault_record_repository.dart';
import '../features/vault/application/vault_record_health_service.dart';
import '../features/vault/application/vault_service.dart';
import '../features/vault/data/drift_vault_repository.dart';
import '../l10n/l10n.dart';
import '../platform/document_gateway.dart';
import '../platform/flutter_secure_storage_secret_store.dart';
import '../platform/local_device_info.dart';
import '../platform/platform_capabilities.dart';
import '../platform/secret_store.dart';
import 'app_navigator.dart';

final serlinkDatabaseProvider = Provider<SerlinkDatabase>((ref) {
  final database = SerlinkDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

final vaultHeaderStoreProvider = Provider<VaultHeaderStore>((ref) {
  return DriftVaultHeaderStore(ref.watch(serlinkDatabaseProvider));
});

final vaultRecordChangeBusProvider = Provider<VaultRecordChangeBus>((ref) {
  final bus = VaultRecordChangeBus();
  ref.onDispose(() {
    unawaited(bus.close());
  });
  return bus;
});

final vaultRecordChangesProvider = StreamProvider<VaultRecordChange>((ref) {
  return ref.watch(vaultRecordChangeBusProvider).stream;
});

final _driftVaultRecordRepositoryProvider = Provider<VaultRecordRepository>((
  ref,
) {
  return DriftVaultRecordRepository(ref.watch(serlinkDatabaseProvider));
});

final vaultRecordRepositoryProvider = Provider<VaultRecordRepository>((ref) {
  return NotifyingVaultRecordRepository(
    inner: ref.watch(_driftVaultRecordRepositoryProvider),
    changes: ref.watch(vaultRecordChangeBusProvider),
  );
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return FlutterSecureStorageSecretStore();
});

final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return PlatformCapabilities.current();
});

final localDeviceInfoProvider = Provider<LocalDeviceInfo>((ref) {
  return const LocalDeviceInfo();
});

typedef CloudKitAvailabilityCheck = Future<bool> Function();
typedef SyncProviderFactory = SyncProvider Function();
typedef WebDavSyncProviderFactory =
    Future<SyncProvider> Function(SyncSettingsService service);

final cloudKitAvailabilityCheckProvider = Provider<CloudKitAvailabilityCheck>((
  ref,
) {
  return () => CloudKitSyncProvider.isAvailable();
});

final cloudKitSyncProviderFactoryProvider = Provider<SyncProviderFactory>((
  ref,
) {
  return () => CloudKitSyncProvider();
});

final webDavSyncProviderFactoryProvider = Provider<WebDavSyncProviderFactory>((
  ref,
) {
  return (service) => service.buildWebDavProvider();
});

final cloudKitSyncChangesProvider = StreamProvider<CloudKitSyncChange>((ref) {
  return CloudKitSyncProvider.watchRemoteChanges();
});

final encryptedSnapshotStagingRepositoryProvider =
    Provider<EncryptedSnapshotStagingRepository>((ref) {
      return EncryptedSnapshotStagingRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final pendingRemoteResetRepositoryProvider =
    Provider<PendingRemoteResetRepository>((ref) {
      return PendingRemoteResetRepository(ref.watch(serlinkDatabaseProvider));
    });

final cloudKitSyncShadowSettingsStoreProvider =
    Provider<CloudKitSyncShadowSettingsStore>((ref) {
      return CloudKitSyncShadowSettingsStore(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final syncRecordBaselineRepositoryProvider =
    Provider<SyncRecordBaselineRepository>((ref) {
      return LocalSyncRecordBaselineRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final offlineDiagnosticLoggerProvider = Provider<OfflineDiagnosticLogger>((
  ref,
) {
  return OfflineDiagnosticLogger();
});

final documentGatewayProvider = Provider<DocumentGateway>((ref) {
  return DocumentGateway(capabilities: ref.watch(platformCapabilitiesProvider));
});

final appLanguageSettingsRepositoryProvider =
    Provider<AppLanguageSettingsRepository>((ref) {
      return const FileAppLanguageSettingsRepository();
    });

final appPrivacySettingsRepositoryProvider =
    Provider<AppPrivacySettingsRepository>((ref) {
      return const FileAppLanguageSettingsRepository();
    });

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

final appProtectBackgroundProvider =
    AsyncNotifierProvider<AppProtectBackgroundController, bool>(
      AppProtectBackgroundController.new,
    );

class AppLanguageController extends AsyncNotifier<AppLanguage> {
  @override
  Future<AppLanguage> build() async {
    try {
      return await ref.watch(appLanguageSettingsRepositoryProvider).read();
    } on Object {
      return AppLanguage.system;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    final previous = state;
    state = AsyncData(language);
    try {
      await ref.read(appLanguageSettingsRepositoryProvider).save(language);
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

class AppProtectBackgroundController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref
          .watch(appPrivacySettingsRepositoryProvider)
          .readProtectBackground();
    } on Object {
      return false;
    }
  }

  Future<void> setProtectBackground(bool enabled) async {
    final previous = state;
    state = AsyncData(enabled);
    try {
      await ref
          .read(appPrivacySettingsRepositoryProvider)
          .saveProtectBackground(enabled);
    } on Object catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final vaultCryptoConfigProvider = Provider<VaultCryptoConfig>((ref) {
  return const VaultCryptoConfig();
});

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  return EncryptedHostRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return EncryptedIdentityRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final vaultBackupServiceProvider = Provider<VaultBackupService>((ref) {
  return VaultBackupService(
    headers: ref.watch(vaultHeaderStoreProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final databaseRecoveryServiceProvider = FutureProvider<DatabaseRecoveryService>(
  (ref) async {
    final paths = await resolveSerlinkDatabasePaths();
    return DatabaseRecoveryService(
      databaseFile: paths.databaseFile,
      automaticBackupDirectory: paths.automaticBackupDirectory,
      quarantineDirectory: paths.quarantineDirectory,
    );
  },
);

final automaticVaultBackupServiceProvider =
    FutureProvider<AutomaticVaultBackupService>((ref) async {
      return AutomaticVaultBackupService(
        recovery: await ref.watch(databaseRecoveryServiceProvider.future),
      );
    });

final vaultBackupRestoreServiceProvider =
    FutureProvider<VaultBackupRestoreService>((ref) async {
      final paths = await resolveSerlinkDatabasePaths();
      return VaultBackupRestoreService(
        recovery: await ref.watch(databaseRecoveryServiceProvider.future),
        temporaryDirectory: Directory('${paths.directory.path}/restore'),
      );
    });

final vaultRecordQuarantineRepositoryProvider =
    Provider<VaultRecordQuarantineRepository>((ref) {
      return DriftVaultRecordQuarantineRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final vaultRecordHealthServiceProvider = Provider<VaultRecordHealthService>((
  ref,
) {
  return VaultRecordHealthService(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
    quarantine: ref.watch(vaultRecordQuarantineRepositoryProvider),
  );
});

final hostMetadataExportServiceProvider = Provider<HostMetadataExportService>((
  ref,
) {
  return HostMetadataExportService(hosts: ref.watch(hostRepositoryProvider));
});

final openSshConfigExportServiceProvider = Provider<OpenSshConfigExportService>(
  (ref) {
    return OpenSshConfigExportService(hosts: ref.watch(hostRepositoryProvider));
  },
);

final identityMetadataExportServiceProvider =
    Provider<IdentityMetadataExportService>((ref) {
      return IdentityMetadataExportService(
        identities: ref.watch(identityRepositoryProvider),
      );
    });

final knownHostsImportServiceProvider = Provider<KnownHostsImportService>((
  ref,
) {
  return KnownHostsImportService(
    hosts: ref.watch(hostRepositoryProvider),
    knownHosts: ref.watch(knownHostRepositoryProvider),
  );
});

final openSshConfigImportServiceProvider = Provider<OpenSshConfigImportService>(
  (ref) {
    return OpenSshConfigImportService(
      hosts: ref.watch(hostRepositoryProvider),
      identities: ref.watch(identityRepositoryProvider),
      records: ref.watch(vaultRecordRepositoryProvider),
      vault: ref.watch(vaultServiceProvider),
    );
  },
);

final openSshCertificateImportServiceProvider =
    Provider<OpenSshCertificateImportService>((ref) {
      return OpenSshCertificateImportService(
        identities: ref.watch(identityRepositoryProvider),
        records: ref.watch(vaultRecordRepositoryProvider),
        vault: ref.watch(vaultServiceProvider),
      );
    });

final knownHostRepositoryProvider = Provider<KnownHostRepository>((ref) {
  return EncryptedKnownHostRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final snippetRepositoryProvider = Provider<SnippetRepository>((ref) {
  return EncryptedSnippetRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final snippetWriteServiceProvider = Provider<SnippetWriteService>((ref) {
  return SnippetWriteService(
    snippets: ref.watch(snippetRepositoryProvider),
    tombstones: ref.watch(syncDeleteTombstoneRepositoryProvider),
  );
});

final snippetsProvider = FutureProvider.autoDispose
    .family<List<CommandSnippet>, int>((ref, unlockGeneration) async {
      final vaultSession = await ref.watch(
        vaultSessionControllerProvider.future,
      );
      if (vaultSession.vaultState != VaultState.unlocked ||
          vaultSession.unlockGeneration != unlockGeneration) {
        return Completer<List<CommandSnippet>>().future;
      }
      ref.watch(vaultRecordChangesProvider);
      final snippets = await ref.watch(snippetRepositoryProvider).list();
      ref.keepAlive();
      return snippets;
    });

final _localWebDavSyncSettingsRepositoryProvider =
    Provider<SyncSettingsRepository>((ref) {
      return LocalWebDavSyncSettingsRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final syncSettingsRepositoryProvider = Provider<SyncSettingsRepository>((ref) {
  return ref.watch(_localWebDavSyncSettingsRepositoryProvider);
});

final _localCloudKitSyncSettingsRepositoryProvider =
    Provider<CloudKitSyncSettingsRepository>((ref) {
      return LocalCloudKitSyncSettingsRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final cloudKitSyncSettingsRepositoryProvider =
    Provider<CloudKitSyncSettingsRepository>((ref) {
      return ref.watch(_localCloudKitSyncSettingsRepositoryProvider);
    });

final syncSettingsServiceProvider = Provider<SyncSettingsService>((ref) {
  return SyncSettingsService(
    settings: ref.watch(syncSettingsRepositoryProvider),
    cloudKitSettings: ref.watch(cloudKitSyncSettingsRepositoryProvider),
    secrets: ref.watch(secretStoreProvider),
    cloudKitAvailable: ref.watch(platformCapabilitiesProvider).cloudKitSync,
  );
});

final webDavSyncSettingsProvider = FutureProvider<WebDavSyncSettings?>((ref) {
  return ref.watch(syncSettingsServiceProvider).readWebDav();
});

final iCloudAvailableProvider = FutureProvider<bool>((ref) {
  if (!ref.watch(platformCapabilitiesProvider).cloudKitSync) {
    return false;
  }
  return ref.watch(cloudKitAvailabilityCheckProvider)();
});

final cloudKitSyncSettingsProvider = FutureProvider<CloudKitSyncSettings?>((
  ref,
) {
  if (!ref.watch(platformCapabilitiesProvider).cloudKitSync) {
    return null;
  }
  return ref.watch(syncSettingsServiceProvider).readCloudKit();
});

final syncDeviceRepositoryProvider = Provider<SyncDeviceRepository>((ref) {
  return EncryptedSyncDeviceRepository(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final syncDeviceServiceProvider = Provider<SyncDeviceService>((ref) {
  return SyncDeviceService(
    devices: ref.watch(syncDeviceRepositoryProvider),
    secrets: ref.watch(secretStoreProvider),
    tombstones: ref.watch(syncDeleteTombstoneRepositoryProvider),
    displayNameResolver: ref.watch(localDeviceInfoProvider).displayName,
  );
});

final syncKnownDevicesProvider = FutureProvider<List<SyncDeviceMetadata>>((
  ref,
) {
  return ref.watch(syncDeviceServiceProvider).listKnownDevices();
});

final syncRunServiceProvider = Provider<SyncRunService>((ref) {
  return SyncRunService(
    vault: ref.watch(vaultServiceProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
    devices: ref.watch(syncDeviceServiceProvider),
    baselines: ref.watch(syncRecordBaselineRepositoryProvider),
    diagnosticLogger: ref.watch(offlineDiagnosticLoggerProvider),
    localDataHealthy: () async {
      final session = ref.read(vaultSessionControllerProvider).value;
      return session?.localDataHealthy ?? false;
    },
  );
});

final syncFieldMergeServiceProvider = Provider<SyncFieldMergeService>((ref) {
  return const SyncFieldMergeService();
});

final syncRepairServiceProvider = Provider<SyncRepairService>((ref) {
  return SyncRepairService(sync: ref.watch(syncRunServiceProvider));
});

final syncDeleteTombstoneRepositoryProvider =
    Provider<SyncDeleteTombstoneRepository>((ref) {
      return EncryptedSyncDeleteTombstoneRepository(
        vault: ref.watch(vaultServiceProvider),
        records: ref.watch(vaultRecordRepositoryProvider),
      );
    });

final autoSyncDebounceDurationProvider = Provider<Duration>((ref) {
  return Duration.zero;
});

final autoSyncIntervalDurationProvider = Provider<Duration>((ref) {
  return Duration.zero;
});

final autoSyncEnabledProvider = Provider<bool>((ref) {
  return true;
});

final autoSyncControllerProvider =
    NotifierProvider<AutoSyncController, AutoSyncStatus>(
      AutoSyncController.new,
    );

final cloudKitVaultDiscoveryIntervalProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 5);
});

final cloudKitVaultDiscoveryControllerProvider =
    NotifierProvider<CloudKitVaultDiscoveryController, void>(
      CloudKitVaultDiscoveryController.new,
    );

final cloudKitEncryptedSnapshotPrefetchIntervalProvider = Provider<Duration>((
  ref,
) {
  return const Duration(minutes: 5);
});

final cloudKitEncryptedSnapshotPrefetchControllerProvider =
    NotifierProvider<CloudKitEncryptedSnapshotPrefetchNotifier, void>(
      CloudKitEncryptedSnapshotPrefetchNotifier.new,
    );

enum _CloudKitUnlockSyncOutcome { skipped, synced, remoteReset }

enum VaultSessionBusyReason { waitingForICloud }

enum VaultSessionNotice { cloudKitRemoteVaultAdopted }

class _CloudKitBootstrapResult {
  const _CloudKitBootstrapResult({
    this.adoptedRemoteHeader,
    this.notice,
    this.failureMessage,
  });

  final VaultHeader? adoptedRemoteHeader;
  final VaultSessionNotice? notice;
  final String? failureMessage;
}

class CloudKitVaultDiscoveryController extends Notifier<void> {
  Timer? _timer;
  bool _running = false;

  @override
  void build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    ref.listen<AsyncValue<VaultSessionState>>(
      vaultSessionControllerProvider,
      (_, _) => _configure(),
    );
    ref.listen<AsyncValue<CloudKitSyncSettings?>>(
      cloudKitSyncSettingsProvider,
      (_, _) => _configure(),
    );
    ref.listen<AsyncValue<CloudKitSyncChange>>(cloudKitSyncChangesProvider, (
      _,
      change,
    ) {
      if (change.hasValue) {
        _requestDiscovery();
      }
    });
    unawaited(Future<void>.microtask(_configure));
  }

  void _configure({bool requestNow = true}) {
    if (!ref.mounted) {
      return;
    }
    if (!_shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(
      ref.read(cloudKitVaultDiscoveryIntervalProvider),
      (_) => _requestDiscovery(),
    );
    if (requestNow) {
      _requestDiscovery();
    }
  }

  void _requestDiscovery() {
    if (!ref.mounted) {
      return;
    }
    if (_running || !_shouldPoll) {
      return;
    }
    unawaited(_discover());
  }

  void refreshNow() {
    _requestDiscovery();
  }

  Future<void> _discover() async {
    _running = true;
    try {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .refreshCloudKitVaultDiscovery();
    } finally {
      _running = false;
      _configure(requestNow: false);
    }
  }

  bool get _shouldPoll {
    if (!ref.mounted) {
      return false;
    }
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return false;
    }
    final session = ref.read(vaultSessionControllerProvider).value;
    return session?.vaultState == VaultState.uninitialized && !session!.isBusy;
  }
}

class CloudKitEncryptedSnapshotPrefetchNotifier extends Notifier<void> {
  Timer? _timer;
  CloudKitEncryptedSnapshotPrefetchController? _controller;

  bool get isRunning => _controller?.isRunning == true;

  @override
  void build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    ref.listen<AsyncValue<VaultSessionState>>(
      vaultSessionControllerProvider,
      (_, _) => _configure(),
    );
    ref.listen<AsyncValue<CloudKitSyncChange>>(cloudKitSyncChangesProvider, (
      _,
      change,
    ) {
      if (change.hasValue) {
        requestPrefetch();
      }
    });
    unawaited(Future<void>.microtask(_configure));
  }

  void refreshNow() {
    requestPrefetch();
  }

  void _configure() {
    if (!ref.mounted) {
      return;
    }
    if (!_shouldRun) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(
      ref.read(cloudKitEncryptedSnapshotPrefetchIntervalProvider),
      (_) => requestPrefetch(),
    );
    requestPrefetch();
  }

  void requestPrefetch() {
    if (!ref.mounted) {
      return;
    }
    if (!_shouldRun) {
      return;
    }
    final session = ref.read(vaultSessionControllerProvider).value;
    final controller = _controller?.isRunning == true
        ? _controller!
        : _createController();
    _controller = controller;
    controller.request(
      header: ref.read(vaultSessionControllerProvider.notifier).service.header,
      vaultState: session?.vaultState ?? VaultState.uninitialized,
    );
  }

  CloudKitEncryptedSnapshotPrefetchController _createController() {
    return CloudKitEncryptedSnapshotPrefetchController(
      capabilities: ref.read(platformCapabilitiesProvider),
      cloudKitAvailable: ref.read(cloudKitAvailabilityCheckProvider),
      providerFactory: ref.read(cloudKitSyncProviderFactoryProvider),
      staging: ref.read(encryptedSnapshotStagingRepositoryProvider),
      pendingResets: ref.read(pendingRemoteResetRepositoryProvider),
      shadowSettings: ref.read(cloudKitSyncShadowSettingsStoreProvider),
      shouldAcceptSnapshot: _shouldAcceptSnapshot,
    );
  }

  bool _shouldAcceptSnapshot(String vaultId) {
    if (!ref.mounted) {
      return false;
    }
    final session = ref.read(vaultSessionControllerProvider).value;
    final header = ref
        .read(vaultSessionControllerProvider.notifier)
        .service
        .header;
    return session?.vaultState == VaultState.locked &&
        session?.isBusy == false &&
        header != null &&
        syncVaultId(header) == vaultId;
  }

  bool get _shouldRun {
    if (!ref.mounted) {
      return false;
    }
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return false;
    }
    final session = ref.read(vaultSessionControllerProvider).value;
    return session?.vaultState == VaultState.locked &&
        session?.isBusy == false &&
        ref.read(vaultSessionControllerProvider.notifier).service.header !=
            null;
  }
}

class AutoSyncController extends Notifier<AutoSyncStatus> {
  Timer? _debounceTimer;
  bool _running = false;
  bool _rerunRequested = false;
  bool _configureQueued = false;
  Duration? _retryDelayAfterRun;
  var _failureCount = 0;

  @override
  AutoSyncStatus build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    ref.listen<AsyncValue<VaultSessionState>>(
      vaultSessionControllerProvider,
      (_, _) => _scheduleConfigure(),
    );
    ref.listen<AsyncValue<CloudKitSyncChange>>(cloudKitSyncChangesProvider, (
      _,
      change,
    ) {
      if (change.hasValue) {
        requestSync(delay: Duration.zero);
      }
    });
    ref.listen<AsyncValue<VaultRecordChange>>(vaultRecordChangesProvider, (
      _,
      change,
    ) {
      if (change.hasValue &&
          change.value?.origin == VaultRecordChangeOrigin.local) {
        _scheduleConfigure();
        requestSync(delay: Duration.zero);
      }
    });
    _scheduleConfigure();
    return const AutoSyncStatus.disabled();
  }

  void requestSync({Duration? delay}) {
    if (!_canAttemptSync || state.phase == AutoSyncPhase.conflicts) {
      return;
    }
    final Duration effectiveDelay =
        delay ?? ref.read(autoSyncDebounceDurationProvider);
    if (_running) {
      _rerunRequested = true;
      return;
    }
    if (state.phase == AutoSyncPhase.scheduled &&
        _debounceTimer == null &&
        effectiveDelay == Duration.zero) {
      return;
    }
    _retryDelayAfterRun = null;
    _debounceTimer?.cancel();
    state = state.copyWith(
      phase: AutoSyncPhase.scheduled,
      clearFailure: true,
      conflictCount: 0,
    );
    if (effectiveDelay == Duration.zero) {
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            _run();
          }
        }),
      );
      return;
    }
    _debounceTimer = Timer(effectiveDelay, () {
      _debounceTimer = null;
      unawaited(_run());
    });
  }

  void markConflictResolution(
    SyncRunResult result, {
    SyncProviderKind? providerKind,
  }) {
    _invalidateSyncedMetadataProviders();
    state = AutoSyncStatus(
      phase: AutoSyncPhase.idle,
      lastCompletedAt: result.completedAt,
      lastProviderKind: providerKind,
      recordsUploaded: result.recordsUploaded,
      recordsDownloaded: result.recordsDownloaded,
    );
  }

  void _configure() {
    if (!ref.mounted) {
      return;
    }
    if (!_canAttemptSync) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _retryDelayAfterRun = null;
      if (!_running) {
        state = const AutoSyncStatus.disabled();
      }
      return;
    }

    if (state.phase == AutoSyncPhase.disabled) {
      state = const AutoSyncStatus(phase: AutoSyncPhase.idle);
    }
    requestSync(delay: Duration.zero);
  }

  void _scheduleConfigure() {
    if (_configureQueued) {
      return;
    }
    _configureQueued = true;
    unawaited(
      Future<void>.microtask(() {
        _configureQueued = false;
        if (ref.mounted) {
          _configure();
        }
      }),
    );
  }

  Future<void> _run() async {
    if (!ref.mounted || !_canAttemptSync || _running) {
      return;
    }
    _running = true;
    state = state.copyWith(phase: AutoSyncPhase.syncing, clearFailure: true);
    SyncProviderKind? providerKind;
    var providers = <SyncProvider>[];
    try {
      providers = await _activeSyncProviders();
      if (!ref.mounted) {
        return;
      }
      if (providers.isEmpty) {
        state = const AutoSyncStatus(phase: AutoSyncPhase.idle);
        return;
      }
      final result = await _syncAllEnabledProviders(providers, (kind) {
        providerKind = kind;
      });
      if (!ref.mounted) {
        return;
      }
      ref.read(syncConflictControllerProvider.notifier).clear();
      _invalidateSyncedMetadataProviders();
      _failureCount = 0;
      _retryDelayAfterRun = null;
      state = AutoSyncStatus(
        phase: AutoSyncPhase.idle,
        lastCompletedAt: result.completedAt,
        lastProviderKind: providerKind,
        recordsUploaded: result.recordsUploaded,
        recordsDownloaded: result.recordsDownloaded,
      );
    } on SyncRunConflictException catch (error) {
      if (!ref.mounted) {
        return;
      }
      _failureCount = 0;
      _retryDelayAfterRun = null;
      ref
          .read(syncConflictControllerProvider.notifier)
          .setConflicts(error.conflicts, providerKind: providerKind);
      state = state.copyWith(
        phase: AutoSyncPhase.conflicts,
        lastProviderKind: providerKind,
        conflictCount: error.conflicts.length,
      );
    } on SyncDeviceException catch (error) {
      if (!ref.mounted) {
        return;
      }
      if (error.code == 'sync.device.revoked') {
        try {
          await _disableSyncAfterLocalDeviceRevoked();
        } on Object catch (disableError) {
          if (!ref.mounted) {
            return;
          }
          final failedAt = DateTime.now().toUtc();
          _failureCount += 1;
          state = state.copyWith(
            phase: AutoSyncPhase.failed,
            lastFailedAt: failedAt,
            lastFailureMessage: _autoSyncFailureMessage(disableError),
            lastFailure: disableError,
            lastProviderKind: providerKind,
          );
          _retryDelayAfterRun = _retryDelay(_failureCount);
          return;
        }
        if (!ref.mounted) {
          return;
        }
        state = const AutoSyncStatus.disabled();
        return;
      }
      final failedAt = DateTime.now().toUtc();
      _failureCount += 1;
      state = state.copyWith(
        phase: AutoSyncPhase.failed,
        lastFailedAt: failedAt,
        lastFailureMessage: _autoSyncFailureMessage(error),
        lastFailure: error,
        lastProviderKind: providerKind,
      );
      _retryDelayAfterRun = _retryDelay(_failureCount);
    } on SyncRunException catch (error) {
      if (!ref.mounted) {
        return;
      }
      if (error.code == 'sync.remote_vault_reset') {
        _failureCount = 0;
        _debounceTimer?.cancel();
        _debounceTimer = null;
        _rerunRequested = false;
        _retryDelayAfterRun = null;
        try {
          await _publishRemoteResetToOtherProviders(
            providers,
            resetProviderKind: providerKind,
          );
        } on Object catch (resetError) {
          if (!ref.mounted) {
            return;
          }
          final failedAt = DateTime.now().toUtc();
          _failureCount += 1;
          state = state.copyWith(
            phase: AutoSyncPhase.failed,
            lastFailedAt: failedAt,
            lastFailureMessage: _autoSyncFailureMessage(resetError),
            lastFailure: resetError,
            lastProviderKind: providerKind,
          );
          _retryDelayAfterRun = _retryDelay(_failureCount);
          return;
        }
        if (!ref.mounted) {
          return;
        }
        await ref
            .read(vaultSessionControllerProvider.notifier)
            .applyRemoteReset();
        if (!ref.mounted) {
          return;
        }
        state = const AutoSyncStatus.disabled();
        return;
      }
      final failedAt = DateTime.now().toUtc();
      _failureCount += 1;
      state = state.copyWith(
        phase: AutoSyncPhase.failed,
        lastFailedAt: failedAt,
        lastFailureMessage: _autoSyncFailureMessage(error),
        lastFailure: error,
        lastProviderKind: providerKind,
      );
      _retryDelayAfterRun = _retryDelay(_failureCount);
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      final failedAt = DateTime.now().toUtc();
      _failureCount += 1;
      state = state.copyWith(
        phase: AutoSyncPhase.failed,
        lastFailedAt: failedAt,
        lastFailureMessage: _autoSyncFailureMessage(error),
        lastFailure: error,
        lastProviderKind: providerKind,
      );
      _retryDelayAfterRun = _retryDelay(_failureCount);
    } finally {
      _running = false;
      if (!ref.mounted) {
        _rerunRequested = false;
        _retryDelayAfterRun = null;
      } else {
        final retryDelay = _retryDelayAfterRun;
        final canAttemptSync = _canAttemptSync;
        if (retryDelay != null && canAttemptSync) {
          _retryDelayAfterRun = null;
          _rerunRequested = false;
          _scheduleRetry(retryDelay);
        } else if (_rerunRequested && canAttemptSync) {
          _rerunRequested = false;
          requestSync(delay: Duration.zero);
        } else if (!canAttemptSync) {
          _rerunRequested = false;
          _retryDelayAfterRun = null;
        }
      }
    }
  }

  Future<void> _disableSyncAfterLocalDeviceRevoked() async {
    _failureCount = 0;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _rerunRequested = false;
    _retryDelayAfterRun = null;
    await ref.read(syncSettingsServiceProvider).disableAllSync();
    if (!ref.mounted) {
      return;
    }
    await ref.read(syncDeviceServiceProvider).forgetLocalDeviceRegistration();
    if (!ref.mounted) {
      return;
    }
    _invalidateSyncedMetadataProviders();
  }

  void _scheduleRetry(Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      _debounceTimer = null;
      if (ref.mounted) {
        unawaited(_run());
      }
    });
  }

  bool get _canAttemptSync {
    if (!ref.mounted) {
      return false;
    }
    if (!ref.read(autoSyncEnabledProvider)) {
      return false;
    }
    final vaultSession = ref.read(vaultSessionControllerProvider).value;
    return vaultSession?.vaultState == VaultState.unlocked &&
        vaultSession?.isBusy == false;
  }

  Future<SyncRunResult> _syncAllEnabledProviders(
    List<SyncProvider> providers,
    void Function(SyncProviderKind kind) onProvider,
  ) async {
    var totalUploaded = 0;
    var totalDownloaded = 0;
    var totalUnchanged = 0;
    SyncRunResult? latest;
    final syncedProviders = <SyncProvider>[];
    var localChangedAfterEarlierProvider = false;
    for (final provider in providers) {
      final kind = (await provider.capabilities()).kind;
      if (!ref.mounted) {
        break;
      }
      onProvider(kind);
      final result = await ref
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(provider, reportConflicts: true);
      totalUploaded += result.recordsUploaded;
      totalDownloaded += result.recordsDownloaded;
      totalUnchanged += result.recordsUnchanged;
      latest = result;
      if (result.recordsDownloaded > 0 && syncedProviders.isNotEmpty) {
        localChangedAfterEarlierProvider = true;
      }
      syncedProviders.add(provider);
    }
    if (localChangedAfterEarlierProvider) {
      for (final provider in syncedProviders) {
        final kind = (await provider.capabilities()).kind;
        if (!ref.mounted) {
          break;
        }
        onProvider(kind);
        final result = await ref
            .read(syncRunServiceProvider)
            .syncEncryptedSnapshot(provider, reportConflicts: true);
        totalUploaded += result.recordsUploaded;
        totalDownloaded += result.recordsDownloaded;
        totalUnchanged += result.recordsUnchanged;
        latest = result;
      }
    }
    final completedAt = latest?.completedAt ?? DateTime.now().toUtc();
    return SyncRunResult(
      recordsUploaded: totalUploaded,
      recordsDownloaded: totalDownloaded,
      recordsUnchanged: totalUnchanged,
      headerUploaded: latest?.headerUploaded ?? false,
      completedAt: completedAt,
      writerDevice: latest?.writerDevice,
      remoteDevice: latest?.remoteDevice,
    );
  }

  Future<void> _publishRemoteResetToOtherProviders(
    List<SyncProvider> providers, {
    required SyncProviderKind? resetProviderKind,
  }) async {
    if (resetProviderKind == null) {
      return;
    }
    if (!ref.mounted) {
      return;
    }
    final service = ref.read(syncRunServiceProvider);
    for (final provider in providers) {
      final kind = (await provider.capabilities()).kind;
      if (!ref.mounted) {
        return;
      }
      if (kind == resetProviderKind) {
        continue;
      }
      await service.publishRemoteReset(provider);
    }
  }

  Future<List<SyncProvider>> _activeSyncProviders() async {
    final providers = <SyncProvider>[];
    final cloudKit = await ref.read(cloudKitSyncSettingsProvider.future);
    if (!ref.mounted) {
      return providers;
    }
    if (cloudKit?.enabled ?? false) {
      providers.add(ref.read(cloudKitSyncProviderFactoryProvider)());
    }
    final webDav = await ref.read(webDavSyncSettingsProvider.future);
    if (!ref.mounted) {
      return providers;
    }
    if (webDav?.enabled ?? false) {
      providers.add(
        await ref.read(webDavSyncProviderFactoryProvider)(
          ref.read(syncSettingsServiceProvider),
        ),
      );
    }
    return providers;
  }

  void _invalidateSyncedMetadataProviders() {
    ref.invalidate(webDavSyncSettingsProvider);
    ref.invalidate(cloudKitSyncSettingsProvider);
    ref.invalidate(syncKnownDevicesProvider);
  }
}

Duration _retryDelay(int failureCount) {
  final seconds = switch (failureCount) {
    <= 1 => 10,
    2 => 30,
    3 => 60,
    4 => 120,
    _ => 300,
  };
  return Duration(seconds: seconds);
}

String _autoSyncFailureMessage(Object error) {
  if (error is SyncRunException) {
    return error.message;
  }
  if (error is SyncDeviceException) {
    return error.message;
  }
  if (error is SyncProviderException) {
    return error.message;
  }
  if (error is SyncSettingsException) {
    return error.message;
  }
  return 'Automatic sync failed.';
}

final encryptedTerminalDisplaySettingsRepositoryProvider =
    Provider<EncryptedTerminalDisplaySettingsRepository>((ref) {
      return EncryptedTerminalDisplaySettingsRepository(
        vault: ref.watch(vaultServiceProvider),
        records: ref.watch(vaultRecordRepositoryProvider),
      );
    });

final _localTerminalDisplaySettingsRepositoryProvider =
    Provider<TerminalDisplaySettingsRepository>((ref) {
      return LocalTerminalDisplaySettingsRepository(
        ref.watch(serlinkDatabaseProvider),
      );
    });

final terminalDisplaySettingsRepositoryProvider =
    Provider<TerminalDisplaySettingsRepository>((ref) {
      final primary = ref.watch(
        _localTerminalDisplaySettingsRepositoryProvider,
      );
      final vaultSession = ref.watch(vaultSessionControllerProvider).value;
      if (vaultSession?.vaultState != VaultState.unlocked) {
        return primary;
      }
      return MigratingTerminalDisplaySettingsRepository(
        primary: primary,
        legacy: ref.watch(encryptedTerminalDisplaySettingsRepositoryProvider),
      );
    });

final terminalHostDisplaySettingsRepositoryProvider =
    Provider<TerminalHostDisplaySettingsRepository>((ref) {
      return ref.watch(encryptedTerminalDisplaySettingsRepositoryProvider);
    });

final terminalFontDiscoveryProvider = Provider<TerminalFontDiscovery>((ref) {
  return const TerminalFontDiscovery();
});

final terminalFontCatalogProvider = FutureProvider<TerminalFontCatalog>((ref) {
  return ref.watch(terminalFontDiscoveryProvider).discover();
});

final terminalDisplaySettingsProvider =
    AsyncNotifierProvider<
      TerminalDisplaySettingsController,
      TerminalDisplaySettings
    >(TerminalDisplaySettingsController.new);

class TerminalDisplaySettingsController
    extends AsyncNotifier<TerminalDisplaySettings> {
  @override
  Future<TerminalDisplaySettings> build() async {
    try {
      final saved = await ref
          .watch(terminalDisplaySettingsRepositoryProvider)
          .read();
      if (saved != null) {
        return saved;
      }
    } on Object {
      // A locked or unavailable vault should not block terminal startup.
    }

    try {
      final catalog = await ref.watch(terminalFontCatalogProvider.future);
      return TerminalDisplaySettings(fontFamily: catalog.preferredFontFamily);
    } on Object {
      return const TerminalDisplaySettings();
    }
  }

  void setTheme(SerlinkTerminalThemeId themeId) {
    _update(_current.copyWith(themeId: themeId));
  }

  void setFontSize(double fontSize) {
    _update(_current.copyWith(fontSize: fontSize.clamp(10, 24).toDouble()));
  }

  void setLineHeight(double lineHeight) {
    _update(
      _current.copyWith(lineHeight: lineHeight.clamp(1.0, 1.5).toDouble()),
    );
  }

  void setFontFamily(String fontFamily) {
    final normalized = fontFamily.trim();
    if (normalized.isEmpty) {
      return;
    }
    _update(_current.copyWith(fontFamily: normalized));
  }

  void setScrollbackLines(int scrollbackLines) {
    _update(
      _current.copyWith(scrollbackLines: scrollbackLines.clamp(1000, 100000)),
    );
  }

  void setSettings(TerminalDisplaySettings settings) {
    _update(settings);
  }

  TerminalDisplaySettings get _current {
    return state.value ?? const TerminalDisplaySettings();
  }

  void _update(TerminalDisplaySettings next) {
    state = AsyncData(next);
    unawaited(_save(next));
  }

  Future<void> _save(TerminalDisplaySettings settings) async {
    try {
      await ref.read(terminalDisplaySettingsRepositoryProvider).save(settings);
    } on Object {
      // Runtime terminal settings stay active even when encrypted persistence
      // cannot be written, for example after the vault is locked.
    }
  }
}

final syncConflictControllerProvider =
    NotifierProvider<SyncConflictController, List<SyncRecordConflict>>(
      SyncConflictController.new,
    );

class SyncConflictController extends Notifier<List<SyncRecordConflict>> {
  SyncProviderKind? _providerKind;

  SyncProviderKind? get providerKind => _providerKind;

  @override
  List<SyncRecordConflict> build() {
    _providerKind = null;
    return const [];
  }

  void setConflicts(
    List<SyncRecordConflict> conflicts, {
    SyncProviderKind? providerKind,
  }) {
    _providerKind = providerKind;
    state = List<SyncRecordConflict>.unmodifiable(conflicts);
  }

  void clear() {
    _providerKind = null;
    state = const [];
  }
}

final securityModalServiceProvider = Provider<SecurityModalService>((ref) {
  return FlutterSecurityModalService(key: ref.watch(appNavigatorKeyProvider));
});

final diagnosticBundleServiceProvider = Provider<DiagnosticBundleService>((
  ref,
) {
  return DiagnosticBundleService(
    vault: ref.watch(vaultServiceProvider),
    logFileReader: ref.watch(offlineDiagnosticLoggerProvider).readLogFiles,
  );
});

final hostKeyVerificationServiceProvider = Provider<HostKeyVerificationService>(
  (ref) {
    return PersistingHostKeyVerificationService(
      knownHosts: ref.watch(knownHostRepositoryProvider),
      confirmUnknownHostKey: ref
          .watch(securityModalServiceProvider)
          .confirmHostKey,
    );
  },
);

final vaultSessionControllerProvider =
    AsyncNotifierProvider<VaultSessionController, VaultSessionState>(
      VaultSessionController.new,
    );

final vaultSessionBusyReasonProvider =
    NotifierProvider<VaultSessionBusyReasonController, VaultSessionBusyReason?>(
      VaultSessionBusyReasonController.new,
    );

class VaultSessionBusyReasonController
    extends Notifier<VaultSessionBusyReason?> {
  @override
  VaultSessionBusyReason? build() => null;

  void waitForICloud() {
    state = VaultSessionBusyReason.waitingForICloud;
  }

  void clear() {
    state = null;
  }
}

final vaultServiceProvider = Provider<VaultService>((ref) {
  ref.watch(
    vaultSessionControllerProvider.select(
      (state) => state.value?.unlockGeneration,
    ),
  );
  return ref.watch(vaultSessionControllerProvider.notifier).service;
});

class VaultSessionState {
  const VaultSessionState({
    required this.vaultState,
    this.localUnlockAvailable = false,
    this.biometricUnlockSupported = false,
    this.recoveryStatus = VaultRecoveryStatus.healthy,
    this.recordHealthReport,
    this.recoveryKey,
    this.failureMessage,
    this.notice,
    this.unlockFailureCount = 0,
    this.unlockGeneration = 0,
    this.isBusy = false,
    this.busyReason,
  });

  final VaultState vaultState;
  final bool localUnlockAvailable;
  final bool biometricUnlockSupported;
  final VaultRecoveryStatus recoveryStatus;
  final VaultRecordHealthReport? recordHealthReport;
  final VaultRecoveryKey? recoveryKey;
  final String? failureMessage;
  final VaultSessionNotice? notice;
  final int unlockFailureCount;
  final int unlockGeneration;
  final bool isBusy;
  final VaultSessionBusyReason? busyReason;

  bool get localDataHealthy =>
      recoveryStatus == VaultRecoveryStatus.healthy &&
      !(recordHealthReport?.hasCorruptRecords ?? false);

  VaultSessionState copyWith({
    VaultState? vaultState,
    bool? localUnlockAvailable,
    bool? biometricUnlockSupported,
    VaultRecoveryKey? recoveryKey,
    bool clearRecoveryKey = false,
    VaultRecoveryStatus? recoveryStatus,
    VaultRecordHealthReport? recordHealthReport,
    bool clearRecordHealthReport = false,
    String? failureMessage,
    bool clearFailure = false,
    VaultSessionNotice? notice,
    bool clearNotice = false,
    int? unlockFailureCount,
    bool clearUnlockFailures = false,
    int? unlockGeneration,
    bool? isBusy,
    VaultSessionBusyReason? busyReason,
    bool clearBusyReason = false,
  }) {
    return VaultSessionState(
      vaultState: vaultState ?? this.vaultState,
      localUnlockAvailable: localUnlockAvailable ?? this.localUnlockAvailable,
      biometricUnlockSupported:
          biometricUnlockSupported ?? this.biometricUnlockSupported,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      recordHealthReport: clearRecordHealthReport
          ? null
          : recordHealthReport ?? this.recordHealthReport,
      recoveryKey: clearRecoveryKey ? null : recoveryKey ?? this.recoveryKey,
      failureMessage: clearFailure
          ? null
          : failureMessage ?? this.failureMessage,
      notice: clearNotice ? null : notice ?? this.notice,
      unlockFailureCount: clearUnlockFailures
          ? 0
          : unlockFailureCount ?? this.unlockFailureCount,
      unlockGeneration: unlockGeneration ?? this.unlockGeneration,
      isBusy: isBusy ?? this.isBusy,
      busyReason: clearBusyReason ? null : busyReason ?? this.busyReason,
    );
  }
}

class VaultSessionController extends AsyncNotifier<VaultSessionState> {
  InMemoryVaultService? _service;
  Future<void>? _localUnlockFuture;
  bool _cloudKitHeaderDiscovered = false;

  VaultService get service {
    return _service ??= _createService();
  }

  @override
  Future<VaultSessionState> build() {
    return _loadInitialState();
  }

  Future<VaultSessionState> _loadInitialState() async {
    _cloudKitHeaderDiscovered = false;
    VaultHeader? header;
    bool loadedFromLocalStore;
    try {
      header = await ref.watch(vaultHeaderStoreProvider).read();
      loadedFromLocalStore = header != null;
    } on DatabaseIntegrityException catch (error) {
      return VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: error.recoveryStatus,
        failureMessage: error.message,
      );
    } on Object catch (error) {
      return VaultSessionState(
        vaultState: VaultState.locked,
        recoveryStatus: VaultRecoveryStatus.vaultHeaderInvalid,
        failureMessage: _vaultStructuralFailureMessage(error),
      );
    }
    if (header == null) {
      try {
        header = await _discoverCloudKitVaultHeader(
          reportWaiting: true,
          deferBusyReason: true,
        );
        if (header != null) {
          _cloudKitHeaderDiscovered = true;
        }
      } on SyncRunException catch (error) {
        return VaultSessionState(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
        );
      } on SyncProviderException catch (error) {
        return VaultSessionState(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
        );
      }
    }
    header = await _sanitizeLoadedHeader(header, persist: loadedFromLocalStore);
    _service = _createService(header: header);
    final localUnlockStatus = await _localUnlockHeaderStatus(header);
    final initialState = VaultSessionState(
      vaultState: header == null ? VaultState.uninitialized : VaultState.locked,
      localUnlockAvailable: localUnlockStatus.available,
      biometricUnlockSupported: localUnlockStatus.supported,
      notice: _cloudKitHeaderDiscovered
          ? VaultSessionNotice.cloudKitRemoteVaultAdopted
          : null,
    );
    if (header != null && localUnlockStatus.available) {
      return _attemptAutomaticLocalUnlock(initialState);
    }
    return initialState;
  }

  Future<VaultHeader?> _discoverCloudKitVaultHeader({
    bool reportWaiting = false,
    bool deferBusyReason = false,
  }) async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return null;
    }
    if (await _cloudKitSyncDisabledLocally()) {
      return null;
    }
    final available = await ref.read(cloudKitAvailabilityCheckProvider)();
    if (!available) {
      return null;
    }
    if (reportWaiting) {
      _markWaitingForICloud(deferred: deferBusyReason);
    }
    try {
      final discovery = await RemoteVaultDiscoveryService(
        ref.read(cloudKitSyncProviderFactoryProvider)(),
      ).discover();
      return discovery?.header;
    } on Object {
      rethrow;
    } finally {
      if (reportWaiting) {
        _clearBusyReason(deferred: deferBusyReason);
      }
    }
  }

  InMemoryVaultService _createService({VaultHeader? header}) {
    return InMemoryVaultService(
      config: ref.read(vaultCryptoConfigProvider),
      header: header,
    );
  }

  Future<bool> _cloudKitSyncDisabledLocally() async {
    try {
      final settings = await _readLocalCloudKitSyncSettings();
      return settings?.enabled == false;
    } on Object {
      return false;
    }
  }

  Future<CloudKitSyncSettings?> _readLocalCloudKitSyncSettings() {
    return ref
        .read(_localCloudKitSyncSettingsRepositoryProvider)
        .readCloudKit();
  }

  Future<CloudKitSyncSettings?> _readCloudKitSyncSettingsForUnlockedVault() {
    return MigratingCloudKitSyncSettingsRepository(
      primary: ref.read(_localCloudKitSyncSettingsRepositoryProvider),
      legacy: EncryptedSyncSettingsRepository(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
      ),
    ).readCloudKit();
  }

  Future<WebDavSyncSettings?> _readWebDavSyncSettingsForUnlockedVault() {
    return MigratingWebDavSyncSettingsRepository(
      primary: ref.read(_localWebDavSyncSettingsRepositoryProvider),
      legacy: EncryptedSyncSettingsRepository(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
      ),
    ).readWebDav();
  }

  Future<void> _saveLocalCloudKitSyncSetting(bool enabled) {
    return ref
        .read(_localCloudKitSyncSettingsRepositoryProvider)
        .saveCloudKit(
          CloudKitSyncSettings(
            enabled: enabled,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> _deleteLocalCloudKitSyncSetting() {
    return ref
        .read(_localCloudKitSyncSettingsRepositoryProvider)
        .deleteCloudKit();
  }

  Future<void> initialize({required String passphrase}) async {
    final service = this.service as InMemoryVaultService;
    _clearBusyReason();
    final previous =
        state.value ??
        const VaultSessionState(vaultState: VaultState.uninitialized);
    _recordVaultEvent(
      'vault.initialize.start',
      details: {'previousState': previous.vaultState.name},
    );
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearNotice: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      final result = await service.initialize(passphrase: passphrase);
      await ref.read(vaultHeaderStoreProvider).save(result.header);
      final bootstrap = await _bootstrapCloudKitSnapshotAfterInitialize();
      if (bootstrap.adoptedRemoteHeader != null) {
        final header = bootstrap.adoptedRemoteHeader!;
        await _commitCloudKitBootstrapSnapshot(
          header: header,
          records: const [],
        );
        await service.lock();
        _service = _createService(header: header);
        _cloudKitHeaderDiscovered = true;
        final localUnlockStatus = await _localUnlockStatus();
        state = AsyncData(
          VaultSessionState(
            vaultState: VaultState.locked,
            localUnlockAvailable: localUnlockStatus.available,
            biometricUnlockSupported: localUnlockStatus.supported,
            notice: bootstrap.notice,
          ),
        );
        _invalidateSyncStateProviders();
        _recordVaultEvent(
          'vault.initialize.success',
          details: {'adoptedRemoteHeader': true},
        );
        _clearBusyReason();
        return;
      }
      final localUnlockStatus = await _localUnlockStatus();
      state = AsyncData(
        VaultSessionState(
          vaultState: VaultState.unlocked,
          localUnlockAvailable: localUnlockStatus.available,
          biometricUnlockSupported: localUnlockStatus.supported,
          recoveryKey: result.recoveryKey,
          failureMessage: bootstrap.failureMessage,
          unlockGeneration: previous.unlockGeneration + 1,
        ),
      );
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      _recordVaultEvent(
        'vault.initialize.success',
        details: {'adoptedRemoteHeader': false},
      );
      _clearBusyReason();
    } on Object catch (error) {
      _clearBusyReason();
      _recordVaultEvent(
        'vault.initialize.failure',
        level: DiagnosticLogLevel.error,
        details: _vaultSessionErrorDetails(error),
      );
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(ref, error),
          clearNotice: true,
          clearRecoveryKey: true,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
    }
  }

  Future<void> unlock({required String passphrase}) async {
    _clearBusyReason();
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    _recordVaultEvent(
      'vault.unlock.start',
      details: {
        'method': 'passphrase',
        'previousState': previous.vaultState.name,
        'failureCount': previous.unlockFailureCount,
      },
    );
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearNotice: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      await service.unlock(passphrase: passphrase);
      final cloudKitSync = await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      if (cloudKitSync == _CloudKitUnlockSyncOutcome.remoteReset) {
        _recordVaultEvent(
          'vault.unlock.success',
          details: {'method': 'passphrase', 'cloudKitSync': cloudKitSync.name},
        );
        _clearBusyReason();
        return;
      }
      state = AsyncData(await _unlockedState(previous));
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      _recordVaultEvent(
        'vault.unlock.success',
        details: {'method': 'passphrase', 'cloudKitSync': cloudKitSync.name},
      );
      _clearBusyReason();
    } on Object catch (error) {
      _clearBusyReason();
      await _lockServiceIfUnlocked();
      _recordVaultEvent(
        'vault.unlock.failure',
        level: DiagnosticLogLevel.error,
        details: {'method': 'passphrase', ..._vaultSessionErrorDetails(error)},
      );
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(ref, error),
          clearNotice: true,
          clearRecoveryKey: true,
          unlockFailureCount: previous.unlockFailureCount + 1,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
    }
  }

  Future<String?> unlockWithRecoveryCode({required String recoveryCode}) async {
    _clearBusyReason();
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    _recordVaultEvent(
      'vault.unlock.start',
      details: {
        'method': 'recoveryCode',
        'previousState': previous.vaultState.name,
      },
    );
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearNotice: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      await service.unlockWithRecoveryKey(VaultRecoveryKey(recoveryCode));
      final cloudKitSync = await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      if (cloudKitSync == _CloudKitUnlockSyncOutcome.remoteReset) {
        _recordVaultEvent(
          'vault.unlock.success',
          details: {
            'method': 'recoveryCode',
            'cloudKitSync': cloudKitSync.name,
          },
        );
        _clearBusyReason();
        return null;
      }
      state = AsyncData(await _unlockedState(previous));
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      _recordVaultEvent(
        'vault.unlock.success',
        details: {'method': 'recoveryCode', 'cloudKitSync': cloudKitSync.name},
      );
      _clearBusyReason();
      return null;
    } on Object catch (error) {
      _clearBusyReason();
      await _lockServiceIfUnlocked();
      final message = _vaultFailureMessage(ref, error);
      _recordVaultEvent(
        'vault.unlock.failure',
        level: DiagnosticLogLevel.error,
        details: {
          'method': 'recoveryCode',
          ..._vaultSessionErrorDetails(error),
        },
      );
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          clearNotice: true,
          clearRecoveryKey: true,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
      return message;
    }
  }

  Future<void> unlockWithLocalKey() {
    final pending = _localUnlockFuture;
    if (pending != null) {
      return pending;
    }
    late final Future<void> future;
    future = _unlockWithLocalKeyOnce().whenComplete(() {
      if (identical(_localUnlockFuture, future)) {
        _localUnlockFuture = null;
      }
    });
    _localUnlockFuture = future;
    return future;
  }

  Future<void> _unlockWithLocalKeyOnce() async {
    _clearBusyReason();
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    if (previous.vaultState == VaultState.unlocked) {
      return;
    }
    _recordVaultEvent(
      'vault.unlock.start',
      details: {
        'method': 'localKey',
        'previousState': previous.vaultState.name,
      },
    );
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearNotice: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      await service.unlockWithLocalKey(secrets: ref.read(secretStoreProvider));
      final cloudKitSync = await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      if (cloudKitSync == _CloudKitUnlockSyncOutcome.remoteReset) {
        _recordVaultEvent(
          'vault.unlock.success',
          details: {'method': 'localKey', 'cloudKitSync': cloudKitSync.name},
        );
        _clearBusyReason();
        return;
      }
      state = AsyncData(
        await _unlockedState(
          previous,
          localUnlockStatus: (supported: true, available: true),
        ),
      );
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      _recordVaultEvent(
        'vault.unlock.success',
        details: {'method': 'localKey', 'cloudKitSync': cloudKitSync.name},
      );
      _clearBusyReason();
    } on Object catch (error) {
      _clearBusyReason();
      await _lockServiceIfUnlocked();
      _recordVaultEvent(
        'vault.unlock.failure',
        level: DiagnosticLogLevel.error,
        details: {'method': 'localKey', ..._vaultSessionErrorDetails(error)},
      );
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(ref, error),
          clearNotice: true,
          clearRecoveryKey: true,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
    }
  }

  Future<VaultSessionState> _attemptAutomaticLocalUnlock(
    VaultSessionState previous,
  ) async {
    if (previous.vaultState != VaultState.locked) {
      return previous;
    }
    _recordVaultEvent(
      'vault.unlock.start',
      details: {
        'method': 'localKey',
        'automatic': true,
        'previousState': previous.vaultState.name,
      },
    );
    try {
      await service.unlockWithLocalKey(secrets: ref.read(secretStoreProvider));
      final cloudKitSync = await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      if (cloudKitSync == _CloudKitUnlockSyncOutcome.remoteReset) {
        _recordVaultEvent(
          'vault.unlock.success',
          details: {
            'method': 'localKey',
            'automatic': true,
            'cloudKitSync': cloudKitSync.name,
          },
        );
        _clearBusyReason();
        return const VaultSessionState(vaultState: VaultState.uninitialized);
      }
      final next = await _unlockedState(
        previous,
        localUnlockStatus: (supported: true, available: true),
      );
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      _recordVaultEvent(
        'vault.unlock.success',
        details: {
          'method': 'localKey',
          'automatic': true,
          'cloudKitSync': cloudKitSync.name,
        },
      );
      _clearBusyReason();
      return next;
    } on Object catch (error) {
      _clearBusyReason();
      await _lockServiceIfUnlocked();
      _recordVaultEvent(
        'vault.unlock.failure',
        level: DiagnosticLogLevel.error,
        details: {
          'method': 'localKey',
          'automatic': true,
          ..._vaultSessionErrorDetails(error),
        },
      );
      return previous.copyWith(isBusy: false, clearBusyReason: true);
    }
  }

  Future<void> refreshCloudKitVaultDiscovery() async {
    final previous = state.value;
    if (previous == null ||
        previous.vaultState != VaultState.uninitialized ||
        previous.isBusy) {
      return;
    }
    try {
      final header = await _discoverCloudKitVaultHeader(reportWaiting: true);
      if (header == null) {
        return;
      }
      final current = state.value;
      if (current?.vaultState != VaultState.uninitialized ||
          current?.isBusy == true) {
        return;
      }
      _cloudKitHeaderDiscovered = true;
      final sanitized = await _sanitizeLoadedHeader(header, persist: false);
      _service = _createService(header: sanitized);
      final localUnlockStatus = await _localUnlockStatus();
      state = AsyncData(
        VaultSessionState(
          vaultState: VaultState.locked,
          localUnlockAvailable: localUnlockStatus.available,
          biometricUnlockSupported: localUnlockStatus.supported,
          notice: VaultSessionNotice.cloudKitRemoteVaultAdopted,
        ),
      );
    } on SyncRunException catch (error) {
      state = AsyncData(
        previous.copyWith(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
          clearNotice: true,
        ),
      );
    } on SyncProviderException catch (error) {
      state = AsyncData(
        previous.copyWith(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
          clearNotice: true,
        ),
      );
    } finally {
      _clearBusyReason();
    }
  }

  Future<_CloudKitUnlockSyncOutcome>
  _pullCloudKitSnapshotAfterUnlockIfNeeded() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    final records = ref.read(vaultRecordRepositoryProvider);
    final requireInitialPull = _cloudKitHeaderDiscovered;
    final header = service.header;
    if (header == null) {
      return _CloudKitUnlockSyncOutcome.skipped;
    }

    _markWaitingForICloud();
    final provider = ref.read(cloudKitSyncProviderFactoryProvider)();
    final vaultId = syncVaultId(header);
    if (!requireInitialPull) {
      if (await _cloudKitSyncExplicitlyDisabledForUnlockedVault()) {
        await _clearCloudKitLockedCache(vaultId);
        return _CloudKitUnlockSyncOutcome.skipped;
      }
    }
    final pendingReset = await _pendingCloudKitRemoteReset();
    if (pendingReset == _CloudKitUnlockSyncOutcome.remoteReset) {
      return pendingReset;
    }
    final reset = await _existingCloudKitRemoteReset(provider);
    if (reset == _CloudKitUnlockSyncOutcome.remoteReset) {
      return reset;
    }
    final staged = await _pullStagedCloudKitSnapshotAfterUnlock(
      header: header,
      records: records,
      requireInitialPull: requireInitialPull,
    );
    if (staged != _CloudKitUnlockSyncOutcome.skipped) {
      return staged;
    }
    final RemoteManifest? manifest;
    try {
      manifest = await provider.readManifest();
    } on Object {
      if (requireInitialPull) {
        throw const SyncRunException(
          'sync.remote_manifest_unavailable',
          'Remote sync manifest could not be read.',
        );
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (manifest == null) {
      if (requireInitialPull) {
        throw const SyncRunException(
          'sync.remote_manifest_missing',
          'Remote sync manifest is missing.',
        );
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (manifest.vaultId != syncVaultId(header)) {
      if (requireInitialPull) {
        throw const SyncRunException(
          'sync.remote_manifest_wrong_vault',
          'Remote sync data belongs to another vault.',
        );
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (manifest.protocolVersion > 1) {
      if (!requireInitialPull) {
        return _CloudKitUnlockSyncOutcome.skipped;
      }
      throw const SyncRunException(
        'sync.remote_protocol_unsupported',
        'Remote sync data was written by a newer Serlink version.',
      );
    }

    if (requireInitialPull) {
      final restoredRecords = InMemoryVaultRecordRepository();
      await SyncRunService(
        vault: service,
        records: restoredRecords,
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).pullEncryptedSnapshot(provider);
      await _commitCloudKitBootstrapSnapshot(
        header: header,
        records: await restoredRecords.list(),
      );
    } else {
      final outcome = await _pullExistingCloudKitSnapshotAfterUnlock(
        records,
        provider,
      );
      if (outcome != _CloudKitUnlockSyncOutcome.synced) {
        return outcome;
      }
    }
    _cloudKitHeaderDiscovered = false;
    ref.invalidate(webDavSyncSettingsProvider);
    ref.invalidate(cloudKitSyncSettingsProvider);
    ref.invalidate(syncKnownDevicesProvider);
    return _CloudKitUnlockSyncOutcome.synced;
  }

  void _markWaitingForICloud({bool deferred = false}) {
    if (deferred) {
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            _markWaitingForICloud();
          }
        }),
      );
      return;
    }
    ref.read(vaultSessionBusyReasonProvider.notifier).waitForICloud();
    final current = state.value;
    if (current == null || !current.isBusy) {
      return;
    }
    state = AsyncData(
      current.copyWith(busyReason: VaultSessionBusyReason.waitingForICloud),
    );
  }

  void _clearBusyReason({bool deferred = false}) {
    if (deferred) {
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            _clearBusyReason();
          }
        }),
      );
      return;
    }
    ref.read(vaultSessionBusyReasonProvider.notifier).clear();
  }

  Future<bool> _cloudKitSyncExplicitlyDisabledForUnlockedVault() async {
    try {
      final settings = await _readCloudKitSyncSettingsForUnlockedVault();
      return settings?.enabled == false;
    } on Object {
      return false;
    }
  }

  Future<_CloudKitUnlockSyncOutcome> _pendingCloudKitRemoteReset() async {
    final header = service.header;
    if (header == null) {
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    final vaultId = syncVaultId(header);
    final pendingResets = ref.read(pendingRemoteResetRepositoryProvider);
    final PendingRemoteReset? pending;
    try {
      pending = await pendingResets.read(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: vaultId,
      );
    } on Object {
      await _tryClearCloudKitLockedCache(vaultId);
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (pending == null) {
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    await _handleCloudKitRemoteReset(vaultId: vaultId);
    return _CloudKitUnlockSyncOutcome.remoteReset;
  }

  Future<_CloudKitUnlockSyncOutcome> _pullStagedCloudKitSnapshotAfterUnlock({
    required VaultHeader header,
    required VaultRecordRepository records,
    required bool requireInitialPull,
  }) async {
    final vaultId = syncVaultId(header);
    final staging = ref.read(encryptedSnapshotStagingRepositoryProvider);
    final StagedEncryptedSnapshot? staged;
    try {
      staged = await staging.read(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: vaultId,
      );
    } on Object {
      await _tryClearCloudKitLockedCache(vaultId);
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (staged == null || staged.manifest.vaultId != vaultId) {
      if (staged != null) {
        await _tryClearCloudKitLockedCache(vaultId);
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    if (!_stagedSnapshotContainsManifestObjects(staged)) {
      await _tryClearCloudKitLockedCache(vaultId);
      return _CloudKitUnlockSyncOutcome.skipped;
    }
    try {
      final liveManifest = await ref
          .read(cloudKitSyncProviderFactoryProvider)()
          .readManifest();
      final liveManifestMatches =
          liveManifest != null &&
          liveManifest.vaultId == vaultId &&
          liveManifest.protocolVersion <= 1 &&
          liveManifest.headerPath == staged.manifest.headerPath &&
          manifestFingerprint(liveManifest) == staged.manifestFingerprint;
      if (!liveManifestMatches) {
        await staging.clear(
          providerKind: SyncProviderKind.cloudKit,
          vaultId: vaultId,
        );
        return _CloudKitUnlockSyncOutcome.skipped;
      }
    } on Object {
      // A completed staging snapshot can still unblock unlock while CloudKit is
      // temporarily unreachable. Auto-sync will reconcile after unlock.
    }
    final stagedProvider = StagedSnapshotSyncProvider(staged);
    final outcome = requireInitialPull
        ? await _pullInitialStagedCloudKitSnapshotAfterUnlock(
            header: header,
            provider: stagedProvider,
          )
        : await _pullExistingCloudKitSnapshotAfterUnlock(
            records,
            stagedProvider,
          );
    if (outcome == _CloudKitUnlockSyncOutcome.synced) {
      await staging.clear(
        providerKind: SyncProviderKind.cloudKit,
        vaultId: vaultId,
      );
      await ref
          .read(pendingRemoteResetRepositoryProvider)
          .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    } else if (outcome == _CloudKitUnlockSyncOutcome.skipped) {
      await _tryClearCloudKitLockedCache(vaultId);
    }
    return outcome;
  }

  bool _stagedSnapshotContainsManifestObjects(StagedEncryptedSnapshot staged) {
    final requiredPaths = <String>{};
    final manifest = staged.manifest;
    if (manifest.headerPath case final headerPath?) {
      requiredPaths.add(headerPath);
    }
    requiredPaths.addAll(manifest.snapshotObjectPaths);
    return requiredPaths.every(staged.objects.containsKey);
  }

  Future<_CloudKitUnlockSyncOutcome>
  _pullInitialStagedCloudKitSnapshotAfterUnlock({
    required VaultHeader header,
    required SyncProvider provider,
  }) async {
    final restoredRecords = InMemoryVaultRecordRepository();
    try {
      await SyncRunService(
        vault: service,
        records: restoredRecords,
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).pullEncryptedSnapshot(provider);
      await _commitCloudKitBootstrapSnapshot(
        header: header,
        records: await restoredRecords.list(),
      );
      _cloudKitHeaderDiscovered = false;
      ref.invalidate(webDavSyncSettingsProvider);
      ref.invalidate(cloudKitSyncSettingsProvider);
      ref.invalidate(syncKnownDevicesProvider);
      return _CloudKitUnlockSyncOutcome.synced;
    } on SyncRunException catch (error) {
      if (error.code == 'sync.remote_vault_reset') {
        await _handleCloudKitRemoteReset(vaultId: syncVaultId(header));
        return _CloudKitUnlockSyncOutcome.remoteReset;
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    } on Object {
      return _CloudKitUnlockSyncOutcome.skipped;
    }
  }

  Future<_CloudKitUnlockSyncOutcome> _existingCloudKitRemoteReset(
    SyncProvider provider,
  ) async {
    try {
      if (await SyncRunService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).isRemoteReset(provider)) {
        final header = service.header;
        await _handleCloudKitRemoteReset(
          vaultId: header == null ? null : syncVaultId(header),
        );
        return _CloudKitUnlockSyncOutcome.remoteReset;
      }
    } on Object {
      // A transient marker read failure should not block unlocking. The
      // follow-up pull/auto-sync path will retry and surface persistent errors.
    }
    return _CloudKitUnlockSyncOutcome.skipped;
  }

  Future<_CloudKitUnlockSyncOutcome> _pullExistingCloudKitSnapshotAfterUnlock(
    VaultRecordRepository records,
    SyncProvider provider,
  ) async {
    try {
      final pull =
          await SyncRunService(
            vault: service,
            records: records,
            diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
          ).pullEncryptedSnapshot(
            provider,
            missingManifestOk: true,
            reportConflicts: true,
          );
      if (pull.hasConflicts) {
        ref
            .read(syncConflictControllerProvider.notifier)
            .setConflicts(pull.conflicts);
      } else {
        ref.read(syncConflictControllerProvider.notifier).clear();
      }
      ref.invalidate(webDavSyncSettingsProvider);
      ref.invalidate(cloudKitSyncSettingsProvider);
      ref.invalidate(syncKnownDevicesProvider);
      return _CloudKitUnlockSyncOutcome.synced;
    } on SyncRunException catch (error) {
      if (error.code == 'sync.remote_vault_reset') {
        final header = service.header;
        await _handleCloudKitRemoteReset(
          vaultId: header == null ? null : syncVaultId(header),
        );
        return _CloudKitUnlockSyncOutcome.remoteReset;
      }
      return _CloudKitUnlockSyncOutcome.skipped;
    } on Object {
      return _CloudKitUnlockSyncOutcome.skipped;
    }
  }

  Future<void> _handleCloudKitRemoteReset({String? vaultId}) async {
    await _tryQuarantineCurrentDatabase(reason: 'before-remote-reset');
    if (vaultId != null) {
      await _clearCloudKitLockedCache(vaultId);
      await ref.read(cloudKitSyncShadowSettingsStoreProvider).delete(vaultId);
    }
    await _clearLocalVaultAfterReset();
  }

  Future<void> _clearCloudKitLockedCache(String vaultId) async {
    await ref
        .read(encryptedSnapshotStagingRepositoryProvider)
        .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
    await ref
        .read(pendingRemoteResetRepositoryProvider)
        .clear(providerKind: SyncProviderKind.cloudKit, vaultId: vaultId);
  }

  Future<void> _tryClearCloudKitLockedCache(String vaultId) async {
    try {
      await _clearCloudKitLockedCache(vaultId);
    } on Object {
      // Locked prefetch cache is auxiliary. A cleanup failure should not make
      // unlock worse; the normal CloudKit pull path can still proceed.
    }
  }

  Future<_CloudKitBootstrapResult>
  _bootstrapCloudKitSnapshotAfterInitialize() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return const _CloudKitBootstrapResult();
    }
    if (await _cloudKitSyncDisabledLocally()) {
      return const _CloudKitBootstrapResult();
    }
    final available = await ref.read(cloudKitAvailabilityCheckProvider)();
    if (!available) {
      return const _CloudKitBootstrapResult(
        failureMessage: 'iCloud sync is not available.',
      );
    }
    _markWaitingForICloud();
    try {
      final records = ref.read(vaultRecordRepositoryProvider);
      final provider = ref.read(cloudKitSyncProviderFactoryProvider)();
      final remote = await RemoteVaultDiscoveryService(provider).discover();
      if (remote != null) {
        await _saveLocalCloudKitSyncSetting(true);
        await ref
            .read(cloudKitSyncShadowSettingsStoreProvider)
            .save(vaultId: syncVaultId(remote.header), enabled: true);
        ref.invalidate(cloudKitSyncSettingsProvider);
        ref.invalidate(syncKnownDevicesProvider);
        return _CloudKitBootstrapResult(
          adoptedRemoteHeader: remote.header,
          notice: VaultSessionNotice.cloudKitRemoteVaultAdopted,
        );
      }
      await _saveLocalCloudKitSyncSetting(true);
      final tombstones = EncryptedSyncDeleteTombstoneRepository(
        vault: service,
        records: records,
      );
      final devices = SyncDeviceService(
        devices: EncryptedSyncDeviceRepository(
          vault: service,
          records: records,
        ),
        secrets: ref.read(secretStoreProvider),
        tombstones: tombstones,
        displayNameResolver: ref.read(localDeviceInfoProvider).displayName,
      );
      await SyncRunService(
        vault: service,
        records: records,
        devices: devices,
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).publishInitialEncryptedSnapshot(provider);
      final header = service.header;
      if (header != null) {
        await ref
            .read(cloudKitSyncShadowSettingsStoreProvider)
            .save(vaultId: syncVaultId(header), enabled: true);
      }
      ref.invalidate(cloudKitSyncSettingsProvider);
      ref.invalidate(syncKnownDevicesProvider);
      return const _CloudKitBootstrapResult();
    } on Object catch (error) {
      await _clearCloudKitSyncSettingAfterBootstrapFailure();
      ref.invalidate(cloudKitSyncSettingsProvider);
      return _CloudKitBootstrapResult(
        failureMessage: _syncBootstrapFailureMessage(error),
      );
    }
  }

  Future<void> _clearCloudKitSyncSettingAfterBootstrapFailure() async {
    try {
      await _deleteLocalCloudKitSyncSetting();
    } on Object {
      // The user-facing bootstrap failure is more useful than a secondary
      // cleanup error. Automatic sync will be reconfigured on the next state
      // refresh regardless.
    }
  }

  Future<void> _commitCloudKitBootstrapSnapshot({
    required VaultHeader header,
    required List<VaultRecordEnvelope> records,
  }) {
    final database = ref.read(serlinkDatabaseProvider);
    return database.transaction(() async {
      final recordRepository = ref.read(_driftVaultRecordRepositoryProvider);
      await recordRepository.clear();
      for (final record in records) {
        await recordRepository.upsert(record);
      }
      await ref.read(vaultHeaderStoreProvider).save(header);
    });
  }

  Future<void> _lockServiceIfUnlocked() async {
    if (service.state == VaultState.unlocked) {
      await service.lock();
    }
  }

  Future<VaultSessionState> _unlockedState(
    VaultSessionState previous, {
    ({bool supported, bool available})? localUnlockStatus,
  }) async {
    await _migrateUnlockedSyncSettings();
    await _refreshCloudKitShadowSetting();
    final health = VaultRecordHealthService(
      vault: service,
      records: ref.read(vaultRecordRepositoryProvider),
      quarantine: ref.read(vaultRecordQuarantineRepositoryProvider),
    );
    final report = await health.inspect();
    final resolvedLocalUnlockStatus =
        localUnlockStatus ?? await _localUnlockStatus();
    return previous.copyWith(
      vaultState: VaultState.unlocked,
      localUnlockAvailable: resolvedLocalUnlockStatus.available,
      biometricUnlockSupported: resolvedLocalUnlockStatus.supported,
      recoveryStatus: report.hasCorruptRecords
          ? VaultRecoveryStatus.recordsCorrupt
          : VaultRecoveryStatus.healthy,
      recordHealthReport: report,
      clearFailure: true,
      clearNotice: true,
      clearUnlockFailures: true,
      unlockGeneration: previous.unlockGeneration + 1,
      isBusy: false,
      clearBusyReason: true,
    );
  }

  Future<void> _migrateUnlockedSyncSettings() async {
    try {
      await _readWebDavSyncSettingsForUnlockedVault();
    } on Object {
      // Legacy encrypted sync settings are optional migration data. A damaged
      // old record must not prevent vault unlock.
    }
  }

  Future<({bool supported, bool available})> _localUnlockStatus() async {
    final secrets = ref.read(secretStoreProvider);
    final capabilities = await secrets.capabilities();
    final supported =
        capabilities.available &&
        capabilities.deviceLocal &&
        capabilities.biometricGate;
    return (
      supported: supported,
      available: supported && await service.hasLocalUnlock(secrets: secrets),
    );
  }

  Future<({bool supported, bool available})> _localUnlockHeaderStatus(
    VaultHeader? header,
  ) async {
    final secrets = ref.read(secretStoreProvider);
    final capabilities = await secrets.capabilities();
    final supported =
        capabilities.available &&
        capabilities.deviceLocal &&
        capabilities.biometricGate;
    return (
      supported: supported,
      available: supported && _hasSupportedLocalUnlockProtector(header),
    );
  }

  Future<VaultHeader?> _sanitizeLoadedHeader(
    VaultHeader? header, {
    required bool persist,
  }) async {
    if (header == null) {
      return null;
    }
    final supportedProtectors = <VaultLocalUnlockProtector>[
      for (final protector in header.localUnlockProtectors)
        if (protector.protection ==
            VaultLocalUnlockProtection.biometricCurrentSet)
          protector,
    ];
    if (supportedProtectors.length == header.localUnlockProtectors.length) {
      return header;
    }
    final secrets = ref.read(secretStoreProvider);
    for (final protector in header.localUnlockProtectors) {
      if (protector.protection ==
          VaultLocalUnlockProtection.biometricCurrentSet) {
        continue;
      }
      try {
        await secrets.delete(protector.secretRef);
      } on Object {
        // Cleanup is best effort. The sanitized header will no longer point at
        // the stale secret even if the device store fails to delete it.
      }
    }
    final sanitized = header.copyWith(
      localUnlockProtectors: supportedProtectors,
    );
    if (persist) {
      await ref.read(vaultHeaderStoreProvider).save(sanitized);
    }
    return sanitized;
  }

  Future<void> _refreshCloudKitShadowSetting() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return;
    }
    final header = service.header;
    if (header == null || service.state != VaultState.unlocked) {
      return;
    }
    try {
      final settings = await _readCloudKitSyncSettingsForUnlockedVault();
      if (settings == null) {
        return;
      }
      final vaultId = syncVaultId(header);
      await ref
          .read(cloudKitSyncShadowSettingsStoreProvider)
          .save(vaultId: vaultId, enabled: settings.enabled);
      if (!settings.enabled) {
        await _clearCloudKitLockedCache(vaultId);
      }
    } on Object {
      // Shadow settings are only a locked-state optimization hint.
    }
  }

  Future<void> lock() async {
    await service.lock();
    final localUnlockStatus = await _localUnlockStatus();
    state = AsyncData(
      VaultSessionState(
        vaultState: VaultState.locked,
        localUnlockAvailable: localUnlockStatus.available,
        biometricUnlockSupported: localUnlockStatus.supported,
      ),
    );
  }

  Future<String?> resetVault() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      if (previous.recoveryStatus == VaultRecoveryStatus.databaseCorrupt ||
          previous.recoveryStatus == VaultRecoveryStatus.vaultHeaderInvalid) {
        await _closeDatabaseIfOpen();
        final recovery = await ref.read(databaseRecoveryServiceProvider.future);
        await recovery.quarantineCurrentDatabase(reason: 'before-reset');
        await recovery.deleteMainDatabaseFiles();
        await _reloadAfterDatabaseReplacement();
        return null;
      }
      await _publishRemoteResetIfConfigured();
      await _tryQuarantineCurrentDatabase(reason: 'before-reset');
      await _clearLocalVaultAfterReset();
      return null;
    } on Object catch (error) {
      final message = _vaultFailureMessage(ref, error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          clearRecoveryKey: true,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
      return message;
    }
  }

  Future<void> applyRemoteReset() async {
    final previous = state.value;
    if (previous == null || previous.vaultState == VaultState.uninitialized) {
      return;
    }
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
        clearBusyReason: true,
      ),
    );
    try {
      await _tryQuarantineCurrentDatabase(reason: 'before-remote-reset');
      await _clearLocalVaultAfterReset();
    } on Object catch (error) {
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(ref, error),
          clearRecoveryKey: true,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
    }
  }

  Future<String?> restoreLatestAutomaticBackup() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearBusyReason: true,
      ),
    );
    try {
      final recovery = await ref.read(databaseRecoveryServiceProvider.future);
      final backup = await recovery.latestAutomaticBackup();
      if (backup == null) {
        throw const DatabaseIntegrityException(
          'database.backup_missing',
          'No automatic vault backup is available.',
        );
      }
      await _closeDatabaseIfOpen();
      await recovery.restoreFromBackup(backup);
      await _reloadAfterDatabaseReplacement();
      return null;
    } on Object catch (error) {
      final message = _recoveryFailureMessage(ref, error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
      return message;
    }
  }

  Future<String?> restoreFromBackupBytes(List<int> bytes) async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearBusyReason: true,
      ),
    );
    try {
      await _closeDatabaseIfOpen();
      await (await ref.read(
        vaultBackupRestoreServiceProvider.future,
      )).restoreFromBackupBytes(bytes);
      await _reloadAfterDatabaseReplacement();
      return null;
    } on Object catch (error) {
      final message = _recoveryFailureMessage(ref, error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
      return message;
    }
  }

  Future<String?> quarantineCorruptRecords() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.unlocked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearBusyReason: true,
      ),
    );
    try {
      final backups = await ref.read(
        automaticVaultBackupServiceProvider.future,
      );
      SyncProvider? remote;
      try {
        remote = await ref
            .read(syncSettingsServiceProvider)
            .activeSyncProvider();
      } on Object {
        remote = null;
      }
      final health = VaultRecordHealthService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
        quarantine: ref.read(vaultRecordQuarantineRepositoryProvider),
        backups: backups,
        remote: remote,
      );
      final report = await health.quarantineCorruptRecords();
      state = AsyncData(
        previous.copyWith(
          recoveryStatus: report.hasCorruptRecords
              ? VaultRecoveryStatus.recordsCorrupt
              : VaultRecoveryStatus.healthy,
          recordHealthReport: report,
          isBusy: false,
          clearBusyReason: true,
          clearFailure: true,
        ),
      );
      return null;
    } on Object catch (error) {
      final message = _recoveryFailureMessage(ref, error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          isBusy: false,
          clearBusyReason: true,
        ),
      );
      return message;
    }
  }

  Future<bool> enableLocalUnlock() async {
    final secrets = ref.read(secretStoreProvider);
    final header = await service.enableLocalUnlock(secrets: secrets);
    await ref.read(vaultHeaderStoreProvider).save(header);
    final localUnlockStatus = await _localUnlockStatus();
    final current =
        state.value ?? const VaultSessionState(vaultState: VaultState.unlocked);
    state = AsyncData(
      current.copyWith(
        localUnlockAvailable: localUnlockStatus.available,
        biometricUnlockSupported: localUnlockStatus.supported,
        clearFailure: true,
      ),
    );
    return localUnlockStatus.available;
  }

  Future<bool> disableLocalUnlock() async {
    final secrets = ref.read(secretStoreProvider);
    final header = await service.disableLocalUnlock(secrets: secrets);
    await ref.read(vaultHeaderStoreProvider).save(header);
    final localUnlockStatus = await _localUnlockStatus();
    final current =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      current.copyWith(
        localUnlockAvailable: localUnlockStatus.available,
        biometricUnlockSupported: localUnlockStatus.supported,
        clearFailure: true,
      ),
    );
    return !localUnlockStatus.available;
  }

  void dismissRecoveryKey() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(clearRecoveryKey: true));
  }

  void dismissNotice(VaultSessionNotice notice) {
    final current = state.value;
    if (current?.notice != notice) {
      return;
    }
    state = AsyncData(current!.copyWith(clearNotice: true));
  }

  void resetUnlockFailureState() {
    final current = state.value;
    if (current == null ||
        current.vaultState != VaultState.locked ||
        (current.failureMessage == null && current.unlockFailureCount == 0)) {
      return;
    }
    state = AsyncData(
      current.copyWith(clearFailure: true, clearUnlockFailures: true),
    );
  }

  Future<void> _clearLocalUnlockSecrets() async {
    final header = service.header;
    if (header == null || header.localUnlockProtectors.isEmpty) {
      return;
    }
    try {
      await service.disableLocalUnlock(secrets: ref.read(secretStoreProvider));
    } on Object {
      // The persisted header is about to be removed. A stale biometric unlock
      // secret cannot unlock anything once its matching header protector is gone.
    }
  }

  void _invalidateSyncStateProviders() {
    ref.invalidate(webDavSyncSettingsProvider);
    ref.invalidate(cloudKitSyncSettingsProvider);
    ref.invalidate(syncKnownDevicesProvider);
  }

  void _recordVaultEvent(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) {
    unawaited(
      ref
          .read(offlineDiagnosticLoggerProvider)
          .record(event, level: level, details: details),
    );
  }

  Map<String, Object?> _vaultSessionErrorDetails(Object error) {
    return switch (error) {
      VaultException(:final code) => {
        'errorType': 'VaultException',
        'code': code,
      },
      SyncRunException(:final code) => {
        'errorType': 'SyncRunException',
        'code': code,
      },
      SyncProviderException(:final code, :final statusCode) => {
        'errorType': 'SyncProviderException',
        'code': code,
        ...statusCode == null ? const {} : {'statusCode': statusCode},
      },
      DatabaseIntegrityException(:final code) => {
        'errorType': 'DatabaseIntegrityException',
        'code': code,
      },
      _ => {'errorType': error.runtimeType.toString()},
    };
  }

  Future<void> _publishRemoteResetIfConfigured() async {
    if (await _cloudKitResetTargetExists()) {
      await SyncRunService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).publishRemoteReset(ref.read(cloudKitSyncProviderFactoryProvider)());
    }
    final webDav = await _webDavProviderOrNull();
    if (webDav != null) {
      await SyncRunService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
        diagnosticLogger: ref.read(offlineDiagnosticLoggerProvider),
      ).publishRemoteReset(webDav);
    }
  }

  Future<bool> _cloudKitResetTargetExists() async {
    final header = service.header;
    if (header == null ||
        !ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return false;
    }
    if (!await ref.read(cloudKitAvailabilityCheckProvider)()) {
      return false;
    }
    final manifest = await ref
        .read(cloudKitSyncProviderFactoryProvider)()
        .readManifest();
    return manifest?.vaultId == syncVaultId(header);
  }

  Future<SyncProvider?> _webDavProviderOrNull() async {
    try {
      final settings = await ref.read(syncSettingsServiceProvider).readWebDav();
      if (settings?.enabled != true) {
        return null;
      }
      return await ref.read(webDavSyncProviderFactoryProvider)(
        ref.read(syncSettingsServiceProvider),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _clearLocalVaultAfterReset() async {
    final header = service.header;
    final vaultId = header == null ? null : syncVaultId(header);
    await _clearLocalUnlockSecrets();
    if (vaultId != null) {
      await _clearCloudKitLockedCache(vaultId);
      await ref.read(cloudKitSyncShadowSettingsStoreProvider).delete(vaultId);
    }
    await ref.read(vaultRecordRepositoryProvider).clear();
    await ref.read(vaultHeaderStoreProvider).clear();
    await service.lock();
    _cloudKitHeaderDiscovered = false;
    _service = _createService();
    ref.read(syncConflictControllerProvider.notifier).clear();
    state = const AsyncData(
      VaultSessionState(vaultState: VaultState.uninitialized),
    );
  }

  Future<void> _closeDatabaseIfOpen() async {
    try {
      await ref.read(serlinkDatabaseProvider).close();
    } on Object {
      // The database may already be unavailable because recovery mode was
      // entered during provider construction.
    }
  }

  Future<void> _tryQuarantineCurrentDatabase({required String reason}) async {
    try {
      final recovery = await ref
          .read(databaseRecoveryServiceProvider.future)
          .timeout(const Duration(seconds: 2));
      await recovery
          .quarantineCurrentDatabase(reason: reason)
          .timeout(const Duration(seconds: 2));
    } on Object {
      // Reset is an explicit destructive operation. File-level quarantine is
      // best-effort here because tests and in-memory databases may not have a
      // filesystem-backed profile to copy.
    }
  }

  Future<void> _reloadAfterDatabaseReplacement() async {
    ref.invalidate(serlinkDatabaseProvider);
    ref.invalidate(vaultHeaderStoreProvider);
    ref.invalidate(_driftVaultRecordRepositoryProvider);
    ref.invalidate(vaultRecordRepositoryProvider);
    ref.invalidate(vaultRecordHealthServiceProvider);
    _service = null;
    state = AsyncData(await _loadInitialState());
  }
}

bool _hasSupportedLocalUnlockProtector(VaultHeader? header) {
  return header?.localUnlockProtectors.any(
        (protector) =>
            protector.protection ==
            VaultLocalUnlockProtection.biometricCurrentSet,
      ) ??
      false;
}

String _vaultFailureMessage(Ref ref, Object error) {
  if (error is VaultException) {
    return localizedVaultExceptionMessage(_currentLocalizations(ref), error);
  }
  if (error is SyncRunException) {
    return error.message;
  }
  if (error is SyncProviderException) {
    return error.message;
  }
  if (error is AppProfileLockException) {
    return 'This Serlink profile is already open in another window.';
  }
  return 'Vault operation failed: ${Redactor.redact(error.toString())}';
}

String _vaultStructuralFailureMessage(Object error) {
  if (error is DatabaseIntegrityException) {
    return error.message;
  }
  return 'Vault metadata is invalid: ${Redactor.redact(error.toString())}';
}

String _recoveryFailureMessage(Ref ref, Object error) {
  if (error is DatabaseIntegrityException) {
    return error.message;
  }
  if (error is VaultException) {
    return localizedVaultExceptionMessage(_currentLocalizations(ref), error);
  }
  return 'Vault recovery failed: ${Redactor.redact(error.toString())}';
}

String _syncBootstrapFailureMessage(Object error) {
  if (error is SyncRunException) {
    return error.message;
  }
  if (error is SyncProviderException) {
    return error.message;
  }
  if (error is SyncSettingsException) {
    return error.message;
  }
  return 'Initial iCloud sync failed.';
}

AppLocalizations _currentLocalizations(Ref ref) {
  return lookupSerlinkLocalizations(
    ref.read(appLanguageProvider).value ?? AppLanguage.system,
  );
}

final encryptedConnectionProfileResolverProvider =
    Provider<ConnectionProfileResolver>((ref) {
      final capabilities = ref.watch(platformCapabilitiesProvider);
      return EncryptedConnectionProfileResolver(
        hosts: ref.watch(hostRepositoryProvider),
        identities: ref.watch(identityRepositoryProvider),
        records: ref.watch(vaultRecordRepositoryProvider),
        vault: ref.watch(vaultServiceProvider),
        sshAgentAuthAvailable: capabilities.sshAgentAuth,
        hardwareKeyAuthAvailable: capabilities.hardwareKeyAuth,
      );
    });
