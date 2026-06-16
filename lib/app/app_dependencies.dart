import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../database/serlink_database.dart';
import '../database/database_recovery.dart';
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
import '../features/sync/application/remote_vault_discovery_service.dart';
import '../features/sync/application/sync_delete_tombstone_repository.dart';
import '../features/sync/application/sync_device_service.dart';
import '../features/sync/application/sync_field_merge_service.dart';
import '../features/sync/application/sync_repair_service.dart';
import '../features/sync/application/sync_run_service.dart';
import '../features/sync/application/sync_settings_service.dart';
import '../features/sync/data/cloudkit_sync_provider.dart';
import '../features/sync/domain/sync_provider.dart';
import '../features/ssh/application/connection_profile_resolver.dart';
import '../features/ssh/application/encrypted_connection_profile_resolver.dart';
import '../features/ssh/application/host_key_verification_service.dart';
import '../features/ssh/application/known_host_repository.dart';
import '../features/terminal/application/terminal_display_settings.dart';
import '../features/terminal/application/terminal_font_discovery.dart';
import '../features/transfers/application/transfer_queue_controller.dart';
import '../features/vault/application/in_memory_vault_service.dart';
import '../features/vault/application/vault_record_repository.dart';
import '../features/vault/application/vault_record_health_service.dart';
import '../features/vault/application/vault_service.dart';
import '../features/vault/data/drift_vault_repository.dart';
import '../platform/document_gateway.dart';
import '../platform/flutter_secure_storage_secret_store.dart';
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
  return const FlutterSecureStorageSecretStore();
});

final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  return PlatformCapabilities.current();
});

typedef CloudKitAvailabilityCheck = Future<bool> Function();
typedef SyncProviderFactory = SyncProvider Function();

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

final cloudKitSyncChangesProvider = StreamProvider<CloudKitSyncChange>((ref) {
  return CloudKitSyncProvider.watchRemoteChanges();
});

final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final documentGatewayProvider = Provider<DocumentGateway>((ref) {
  return DocumentGateway(capabilities: ref.watch(platformCapabilitiesProvider));
});

final appLanguageSettingsRepositoryProvider =
    Provider<AppLanguageSettingsRepository>((ref) {
      return const FileAppLanguageSettingsRepository();
    });

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
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

final syncSettingsRepositoryProvider = Provider<SyncSettingsRepository>((ref) {
  ref.watch(
    vaultSessionControllerProvider.select(
      (state) => state.value?.unlockGeneration,
    ),
  );
  return EncryptedSyncSettingsRepository(
    vault: ref.watch(vaultSessionControllerProvider.notifier).service,
    records: ref.watch(vaultRecordRepositoryProvider),
  );
});

final syncSettingsServiceProvider = Provider<SyncSettingsService>((ref) {
  return SyncSettingsService(
    settings: ref.watch(syncSettingsRepositoryProvider),
    secrets: ref.watch(secretStoreProvider),
    cloudKitAvailable: ref.watch(platformCapabilitiesProvider).cloudKitSync,
  );
});

final webDavSyncSettingsProvider = FutureProvider<WebDavSyncSettings?>((ref) {
  final vaultSession = ref.watch(vaultSessionControllerProvider).value;
  if (vaultSession?.vaultState != VaultState.unlocked) {
    return null;
  }
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
  final vaultSession = ref.watch(vaultSessionControllerProvider).value;
  if (vaultSession?.vaultState != VaultState.unlocked) {
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
  return const Duration(seconds: 3);
});

final autoSyncIntervalDurationProvider = Provider<Duration>((ref) {
  return const Duration(minutes: 5);
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

  void _configure() {
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
    _requestDiscovery();
  }

  void _requestDiscovery() {
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
      _configure();
    }
  }

  bool get _shouldPoll {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return false;
    }
    final session = ref.read(vaultSessionControllerProvider).value;
    return session?.vaultState == VaultState.uninitialized && !session!.isBusy;
  }
}

class AutoSyncController extends Notifier<AutoSyncStatus> {
  Timer? _debounceTimer;
  Timer? _intervalTimer;
  bool _running = false;
  bool _rerunRequested = false;
  bool _configureQueued = false;
  var _failureCount = 0;

  @override
  AutoSyncStatus build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _intervalTimer?.cancel();
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
      if (change.hasValue) {
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
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _debounceTimer?.cancel();
    state = state.copyWith(
      phase: AutoSyncPhase.scheduled,
      clearFailure: true,
      conflictCount: 0,
    );
    if (delay == Duration.zero) {
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            _run();
          }
        }),
      );
      return;
    }
    _debounceTimer = Timer(
      delay ?? ref.read(autoSyncDebounceDurationProvider),
      () {
        _debounceTimer = null;
        unawaited(_run());
      },
    );
  }

  void markConflictResolution(SyncRunResult result) {
    state = AutoSyncStatus(
      phase: AutoSyncPhase.idle,
      lastCompletedAt: result.completedAt,
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
      _intervalTimer?.cancel();
      _debounceTimer = null;
      _intervalTimer = null;
      if (!_running) {
        state = const AutoSyncStatus.disabled();
      }
      return;
    }

    _intervalTimer ??= Timer.periodic(
      ref.read(autoSyncIntervalDurationProvider),
      (_) => requestSync(delay: Duration.zero),
    );
    if (state.phase == AutoSyncPhase.disabled) {
      state = const AutoSyncStatus(phase: AutoSyncPhase.idle);
    }
    requestSync();
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
    if (!_canAttemptSync || _running) {
      return;
    }
    _running = true;
    state = state.copyWith(phase: AutoSyncPhase.syncing, clearFailure: true);
    try {
      final provider = await _activeSyncProvider();
      if (provider == null) {
        state = const AutoSyncStatus(phase: AutoSyncPhase.idle);
        return;
      }
      final result = await ref
          .read(syncRunServiceProvider)
          .syncEncryptedSnapshot(provider, reportConflicts: true);
      ref.read(syncConflictControllerProvider.notifier).clear();
      ref.invalidate(syncKnownDevicesProvider);
      _failureCount = 0;
      state = AutoSyncStatus(
        phase: AutoSyncPhase.idle,
        lastCompletedAt: result.completedAt,
        recordsUploaded: result.recordsUploaded,
        recordsDownloaded: result.recordsDownloaded,
      );
    } on SyncRunConflictException catch (error) {
      _failureCount = 0;
      ref
          .read(syncConflictControllerProvider.notifier)
          .setConflicts(error.conflicts);
      state = state.copyWith(
        phase: AutoSyncPhase.conflicts,
        conflictCount: error.conflicts.length,
      );
    } on SyncRunException catch (error) {
      if (error.code == 'sync.remote_vault_reset') {
        _failureCount = 0;
        _debounceTimer?.cancel();
        _intervalTimer?.cancel();
        _debounceTimer = null;
        _intervalTimer = null;
        _rerunRequested = false;
        await ref
            .read(vaultSessionControllerProvider.notifier)
            .applyRemoteReset();
        state = const AutoSyncStatus.disabled();
        return;
      }
      _failureCount += 1;
      state = state.copyWith(
        phase: AutoSyncPhase.failed,
        lastFailureMessage: _autoSyncFailureMessage(error),
        lastFailure: error,
      );
      requestSync(delay: _retryDelay(_failureCount));
    } on Object catch (error) {
      _failureCount += 1;
      state = state.copyWith(
        phase: AutoSyncPhase.failed,
        lastFailureMessage: _autoSyncFailureMessage(error),
        lastFailure: error,
      );
      requestSync(delay: _retryDelay(_failureCount));
    } finally {
      _running = false;
      if (_rerunRequested && _canAttemptSync) {
        _rerunRequested = false;
        requestSync(delay: Duration.zero);
      } else if (!_canAttemptSync) {
        _rerunRequested = false;
      }
    }
  }

  bool get _canAttemptSync {
    if (!ref.read(autoSyncEnabledProvider)) {
      return false;
    }
    final vaultSession = ref.read(vaultSessionControllerProvider).value;
    return vaultSession?.vaultState == VaultState.unlocked &&
        vaultSession?.isBusy == false;
  }

  Future<SyncProvider?> _activeSyncProvider() async {
    final cloudKit = await ref.read(cloudKitSyncSettingsProvider.future);
    if (cloudKit?.enabled ?? false) {
      return ref.read(cloudKitSyncProviderFactoryProvider)();
    }
    final webDav = await ref.read(webDavSyncSettingsProvider.future);
    if (webDav?.enabled ?? false) {
      return ref.read(syncSettingsServiceProvider).buildWebDavProvider();
    }
    return null;
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

final terminalDisplaySettingsRepositoryProvider =
    Provider<TerminalDisplaySettingsRepository>((ref) {
      return ref.watch(encryptedTerminalDisplaySettingsRepositoryProvider);
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
  @override
  List<SyncRecordConflict> build() {
    return const [];
  }

  void setConflicts(List<SyncRecordConflict> conflicts) {
    state = List<SyncRecordConflict>.unmodifiable(conflicts);
  }

  void clear() {
    state = const [];
  }
}

final securityModalServiceProvider = Provider<SecurityModalService>((ref) {
  return FlutterSecurityModalService(key: ref.watch(appNavigatorKeyProvider));
});

final diagnosticBundleServiceProvider = Provider<DiagnosticBundleService>((
  ref,
) {
  return DiagnosticBundleService(vault: ref.watch(vaultServiceProvider));
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
    this.recoveryStatus = VaultRecoveryStatus.healthy,
    this.recordHealthReport,
    this.recoveryKey,
    this.failureMessage,
    this.unlockFailureCount = 0,
    this.unlockGeneration = 0,
    this.isBusy = false,
  });

  final VaultState vaultState;
  final bool localUnlockAvailable;
  final VaultRecoveryStatus recoveryStatus;
  final VaultRecordHealthReport? recordHealthReport;
  final VaultRecoveryKey? recoveryKey;
  final String? failureMessage;
  final int unlockFailureCount;
  final int unlockGeneration;
  final bool isBusy;

  bool get localDataHealthy =>
      recoveryStatus == VaultRecoveryStatus.healthy &&
      !(recordHealthReport?.hasCorruptRecords ?? false);

  VaultSessionState copyWith({
    VaultState? vaultState,
    bool? localUnlockAvailable,
    VaultRecoveryKey? recoveryKey,
    bool clearRecoveryKey = false,
    VaultRecoveryStatus? recoveryStatus,
    VaultRecordHealthReport? recordHealthReport,
    bool clearRecordHealthReport = false,
    String? failureMessage,
    bool clearFailure = false,
    int? unlockFailureCount,
    bool clearUnlockFailures = false,
    int? unlockGeneration,
    bool? isBusy,
  }) {
    return VaultSessionState(
      vaultState: vaultState ?? this.vaultState,
      localUnlockAvailable: localUnlockAvailable ?? this.localUnlockAvailable,
      recoveryStatus: recoveryStatus ?? this.recoveryStatus,
      recordHealthReport: clearRecordHealthReport
          ? null
          : recordHealthReport ?? this.recordHealthReport,
      recoveryKey: clearRecoveryKey ? null : recoveryKey ?? this.recoveryKey,
      failureMessage: clearFailure
          ? null
          : failureMessage ?? this.failureMessage,
      unlockFailureCount: clearUnlockFailures
          ? 0
          : unlockFailureCount ?? this.unlockFailureCount,
      unlockGeneration: unlockGeneration ?? this.unlockGeneration,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class VaultSessionController extends AsyncNotifier<VaultSessionState> {
  InMemoryVaultService? _service;
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
    try {
      header = await ref.watch(vaultHeaderStoreProvider).read();
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
        header = await _discoverCloudKitVaultHeader();
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
    _service = _createService(header: header);
    final localUnlockAvailable = await service.hasLocalUnlock(
      secrets: ref.read(secretStoreProvider),
    );
    return VaultSessionState(
      vaultState: header == null ? VaultState.uninitialized : VaultState.locked,
      localUnlockAvailable: localUnlockAvailable,
    );
  }

  Future<VaultHeader?> _discoverCloudKitVaultHeader() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return null;
    }
    final available = await ref.read(cloudKitAvailabilityCheckProvider)();
    if (!available) {
      return null;
    }
    try {
      final discovery = await RemoteVaultDiscoveryService(
        ref.read(cloudKitSyncProviderFactoryProvider)(),
      ).discover();
      return discovery?.header;
    } on Object {
      rethrow;
    }
  }

  InMemoryVaultService _createService({VaultHeader? header}) {
    return InMemoryVaultService(
      config: ref.read(vaultCryptoConfigProvider),
      header: header,
    );
  }

  Future<void> initialize({required String passphrase}) async {
    final service = this.service as InMemoryVaultService;
    final previous =
        state.value ??
        const VaultSessionState(vaultState: VaultState.uninitialized);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
      ),
    );
    try {
      final result = await service.initialize(passphrase: passphrase);
      await ref.read(vaultHeaderStoreProvider).save(result.header);
      final syncFailure = await _bootstrapCloudKitSnapshotAfterInitialize();
      state = AsyncData(
        VaultSessionState(
          vaultState: VaultState.unlocked,
          recoveryKey: result.recoveryKey,
          failureMessage: syncFailure,
          unlockGeneration: previous.unlockGeneration + 1,
        ),
      );
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
    } on Object catch (error) {
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(error),
          clearRecoveryKey: true,
          isBusy: false,
        ),
      );
    }
  }

  Future<void> unlock({required String passphrase}) async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
      ),
    );
    try {
      await service.unlock(passphrase: passphrase);
      await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      state = AsyncData(await _unlockedState(previous));
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
    } on Object catch (error) {
      await _lockServiceIfUnlocked();
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(error),
          clearRecoveryKey: true,
          unlockFailureCount: previous.unlockFailureCount + 1,
          isBusy: false,
        ),
      );
    }
  }

  Future<String?> unlockWithRecoveryCode({required String recoveryCode}) async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
      ),
    );
    try {
      await service.unlockWithRecoveryKey(VaultRecoveryKey(recoveryCode));
      await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      state = AsyncData(await _unlockedState(previous));
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
      return null;
    } on Object catch (error) {
      await _lockServiceIfUnlocked();
      final message = _vaultFailureMessage(error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          clearRecoveryKey: true,
          isBusy: false,
        ),
      );
      return message;
    }
  }

  Future<void> unlockWithLocalKey() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      previous.copyWith(
        isBusy: true,
        clearFailure: true,
        clearRecoveryKey: true,
      ),
    );
    try {
      await service.unlockWithLocalKey(secrets: ref.read(secretStoreProvider));
      await _pullCloudKitSnapshotAfterUnlockIfNeeded();
      state = AsyncData(await _unlockedState(previous));
      _invalidateSyncStateProviders();
      unawaited(
        ref.read(transferQueueControllerProvider).restorePersistedTasks(),
      );
    } on Object catch (error) {
      await _lockServiceIfUnlocked();
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(error),
          clearRecoveryKey: true,
          isBusy: false,
        ),
      );
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
      final header = await _discoverCloudKitVaultHeader();
      if (header == null) {
        return;
      }
      final current = state.value;
      if (current?.vaultState != VaultState.uninitialized ||
          current?.isBusy == true) {
        return;
      }
      _cloudKitHeaderDiscovered = true;
      _service = _createService(header: header);
      final localUnlockAvailable = await service.hasLocalUnlock(
        secrets: ref.read(secretStoreProvider),
      );
      state = AsyncData(
        VaultSessionState(
          vaultState: VaultState.locked,
          localUnlockAvailable: localUnlockAvailable,
        ),
      );
    } on SyncRunException catch (error) {
      state = AsyncData(
        previous.copyWith(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
        ),
      );
    } on SyncProviderException catch (error) {
      state = AsyncData(
        previous.copyWith(
          vaultState: VaultState.locked,
          recoveryStatus: VaultRecoveryStatus.remoteCorrupt,
          failureMessage: error.message,
        ),
      );
    }
  }

  Future<void> _pullCloudKitSnapshotAfterUnlockIfNeeded() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return;
    }
    final records = ref.read(vaultRecordRepositoryProvider);
    final requireInitialPull = _cloudKitHeaderDiscovered;
    if (!requireInitialPull && (await records.list()).isNotEmpty) {
      return;
    }
    final header = service.header;
    if (header == null) {
      return;
    }

    final provider = ref.read(cloudKitSyncProviderFactoryProvider)();
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
      return;
    }
    if (manifest == null) {
      if (requireInitialPull) {
        throw const SyncRunException(
          'sync.remote_manifest_missing',
          'Remote sync manifest is missing.',
        );
      }
      return;
    }
    if (manifest.vaultId != syncVaultId(header)) {
      if (requireInitialPull) {
        throw const SyncRunException(
          'sync.remote_manifest_wrong_vault',
          'Remote sync data belongs to another vault.',
        );
      }
      return;
    }
    if (manifest.protocolVersion > 1) {
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
      ).pullEncryptedSnapshot(provider);
      await _commitCloudKitBootstrapSnapshot(
        header: header,
        records: await restoredRecords.list(),
      );
    } else {
      await SyncRunService(
        vault: service,
        records: records,
      ).pullEncryptedSnapshot(provider);
    }
    _cloudKitHeaderDiscovered = false;
    ref.invalidate(cloudKitSyncSettingsProvider);
    ref.invalidate(syncKnownDevicesProvider);
  }

  Future<String?> _bootstrapCloudKitSnapshotAfterInitialize() async {
    if (!ref.read(platformCapabilitiesProvider).cloudKitSync) {
      return null;
    }
    final available = await ref.read(cloudKitAvailabilityCheckProvider)();
    if (!available) {
      return 'iCloud sync is not available.';
    }
    try {
      final records = ref.read(vaultRecordRepositoryProvider);
      final provider = ref.read(cloudKitSyncProviderFactoryProvider)();
      if (await provider.readManifest() != null) {
        throw const SyncRunException(
          'sync.remote_manifest_exists',
          'iCloud already has a Serlink vault. Reset this local vault and restore the iCloud vault.',
        );
      }
      final syncSettings = SyncSettingsService(
        settings: EncryptedSyncSettingsRepository(
          vault: service,
          records: records,
        ),
        secrets: ref.read(secretStoreProvider),
        cloudKitAvailable: true,
      );
      await syncSettings.saveCloudKit(true);
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
      );
      await SyncRunService(
        vault: service,
        records: records,
        devices: devices,
      ).pushEncryptedSnapshot(provider);
      ref.invalidate(cloudKitSyncSettingsProvider);
      ref.invalidate(syncKnownDevicesProvider);
      return null;
    } on Object catch (error) {
      ref.invalidate(cloudKitSyncSettingsProvider);
      return _syncBootstrapFailureMessage(error);
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

  Future<VaultSessionState> _unlockedState(VaultSessionState previous) async {
    final health = VaultRecordHealthService(
      vault: service,
      records: ref.read(vaultRecordRepositoryProvider),
      quarantine: ref.read(vaultRecordQuarantineRepositoryProvider),
    );
    final report = await health.inspect();
    return previous.copyWith(
      vaultState: VaultState.unlocked,
      recoveryStatus: report.hasCorruptRecords
          ? VaultRecoveryStatus.recordsCorrupt
          : VaultRecoveryStatus.healthy,
      recordHealthReport: report,
      clearFailure: true,
      clearUnlockFailures: true,
      unlockGeneration: previous.unlockGeneration + 1,
      isBusy: false,
    );
  }

  Future<void> lock() async {
    await service.lock();
    final localUnlockAvailable = await service.hasLocalUnlock(
      secrets: ref.read(secretStoreProvider),
    );
    state = AsyncData(
      VaultSessionState(
        vaultState: VaultState.locked,
        localUnlockAvailable: localUnlockAvailable,
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
      final message = _vaultFailureMessage(error);
      state = AsyncData(
        previous.copyWith(
          failureMessage: message,
          clearRecoveryKey: true,
          isBusy: false,
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
      ),
    );
    try {
      await _tryQuarantineCurrentDatabase(reason: 'before-remote-reset');
      await _clearLocalVaultAfterReset();
    } on Object catch (error) {
      state = AsyncData(
        previous.copyWith(
          failureMessage: _vaultFailureMessage(error),
          clearRecoveryKey: true,
          isBusy: false,
        ),
      );
    }
  }

  Future<String?> restoreLatestAutomaticBackup() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(previous.copyWith(isBusy: true, clearFailure: true));
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
      final message = _recoveryFailureMessage(error);
      state = AsyncData(
        previous.copyWith(failureMessage: message, isBusy: false),
      );
      return message;
    }
  }

  Future<String?> restoreFromBackupBytes(List<int> bytes) async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(previous.copyWith(isBusy: true, clearFailure: true));
    try {
      await _closeDatabaseIfOpen();
      await (await ref.read(
        vaultBackupRestoreServiceProvider.future,
      )).restoreFromBackupBytes(bytes);
      await _reloadAfterDatabaseReplacement();
      return null;
    } on Object catch (error) {
      final message = _recoveryFailureMessage(error);
      state = AsyncData(
        previous.copyWith(failureMessage: message, isBusy: false),
      );
      return message;
    }
  }

  Future<String?> quarantineCorruptRecords() async {
    final previous =
        state.value ?? const VaultSessionState(vaultState: VaultState.unlocked);
    state = AsyncData(previous.copyWith(isBusy: true, clearFailure: true));
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
          clearFailure: true,
        ),
      );
      return null;
    } on Object catch (error) {
      final message = _recoveryFailureMessage(error);
      state = AsyncData(
        previous.copyWith(failureMessage: message, isBusy: false),
      );
      return message;
    }
  }

  Future<bool> enableLocalUnlock() async {
    final secrets = ref.read(secretStoreProvider);
    final header = await service.enableLocalUnlock(secrets: secrets);
    await ref.read(vaultHeaderStoreProvider).save(header);
    final localUnlockAvailable = await service.hasLocalUnlock(secrets: secrets);
    final current =
        state.value ?? const VaultSessionState(vaultState: VaultState.unlocked);
    state = AsyncData(
      current.copyWith(
        localUnlockAvailable: localUnlockAvailable,
        clearFailure: true,
      ),
    );
    return localUnlockAvailable;
  }

  Future<bool> disableLocalUnlock() async {
    final secrets = ref.read(secretStoreProvider);
    final header = await service.disableLocalUnlock(secrets: secrets);
    await ref.read(vaultHeaderStoreProvider).save(header);
    final localUnlockAvailable = await service.hasLocalUnlock(secrets: secrets);
    final current =
        state.value ?? const VaultSessionState(vaultState: VaultState.locked);
    state = AsyncData(
      current.copyWith(
        localUnlockAvailable: localUnlockAvailable,
        clearFailure: true,
      ),
    );
    return !localUnlockAvailable;
  }

  void dismissRecoveryKey() {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(current.copyWith(clearRecoveryKey: true));
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
      // The persisted header is about to be removed. A stale local unlock
      // secret cannot unlock anything once its matching header protector is gone.
    }
  }

  void _invalidateSyncStateProviders() {
    ref.invalidate(webDavSyncSettingsProvider);
    ref.invalidate(cloudKitSyncSettingsProvider);
    ref.invalidate(syncKnownDevicesProvider);
  }

  Future<void> _publishRemoteResetIfConfigured() async {
    var published = false;
    if (ref.read(platformCapabilitiesProvider).cloudKitSync &&
        await ref.read(cloudKitAvailabilityCheckProvider)()) {
      await SyncRunService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
      ).publishRemoteReset(ref.read(cloudKitSyncProviderFactoryProvider)());
      published = true;
    }
    final webDav = await _webDavProviderOrNull();
    if (webDav != null) {
      await SyncRunService(
        vault: service,
        records: ref.read(vaultRecordRepositoryProvider),
      ).publishRemoteReset(webDav);
      published = true;
    }
    if (published) {
      return;
    }
  }

  Future<SyncProvider?> _webDavProviderOrNull() async {
    try {
      final settings = await ref.read(syncSettingsServiceProvider).readWebDav();
      if (settings?.enabled != true) {
        return null;
      }
      return await ref.read(syncSettingsServiceProvider).buildWebDavProvider();
    } on Object {
      return null;
    }
  }

  Future<void> _clearLocalVaultAfterReset() async {
    await _clearLocalUnlockSecrets();
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

String _vaultFailureMessage(Object error) {
  if (error is VaultException) {
    return error.message;
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

String _recoveryFailureMessage(Object error) {
  if (error is DatabaseIntegrityException) {
    return error.message;
  }
  if (error is VaultException) {
    return error.message;
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
