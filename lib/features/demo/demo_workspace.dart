import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_dependencies.dart';
import '../../core/ids/entity_id.dart';
import '../../core/logging/offline_diagnostic_logger.dart';
import '../../database/database_recovery.dart';
import '../../database/serlink_database.dart';
import '../../platform/flutter_secure_storage_secret_store.dart';
import '../../platform/platform_capabilities.dart';
import '../hosts/domain/host.dart';
import '../identities/application/identity_write_service.dart';
import '../identities/domain/identity.dart';
import '../import_export/application/vault_backup_restore_service.dart';
import '../settings/application/app_language_settings.dart';
import '../sftp/application/sftp_connection.dart';
import '../snippets/domain/snippet.dart';
import '../sync/application/sync_device_service.dart';
import '../transfers/application/transfer_task_repository.dart';
import '../transfers/domain/transfer_task.dart';
import '../workspace/application/workspace_tab_controller.dart';
import '../workspace/domain/workspace_tab.dart';
import 'demo_file_system.dart';
import 'demo_ssh_service.dart';

class DemoCapabilities extends PlatformCapabilities {
  DemoCapabilities(PlatformCapabilities source)
    : super(
        operatingSystem: source.operatingSystem,
        targetPlatform: source.targetPlatform,
        distribution: source.distribution,
      );
  @override
  bool get isDemo => true;
  @override
  bool get cloudKitSync => false;
  @override
  bool get localTerminal => false;
  @override
  bool get sshAgentAuth => false;
  @override
  bool get sshConfigImport => false;
  @override
  bool get mcpServer => false;
  @override
  bool get mcpStdioHelper => false;
  @override
  bool get openLocalFile => false;
}

/// A standalone provider container: it has no parent, so no provider can fall
/// through into the user's vault, keychain, database or live connections.
class DemoWorkspace {
  DemoWorkspace._(this.container, this.database, this.temporary, this.ssh);
  final ProviderContainer container;
  final SerlinkDatabase database;
  final Directory temporary;
  final DemoSshService ssh;
  bool _disposed = false;

  static Future<DemoWorkspace> create({
    required PlatformCapabilities capabilities,
    AppLanguage language = AppLanguage.system,
  }) async {
    final temporary = await Directory.systemTemp.createTemp('serlink-demo-');
    final database = SerlinkDatabase(NativeDatabase.memory());
    final ssh = DemoSshService();
    final preferences = _DemoPreferences(language);
    final recovery = DatabaseRecoveryService(
      databaseFile: File('${temporary.path}/demo.sqlite'),
      automaticBackupDirectory: Directory('${temporary.path}/backups'),
      quarantineDirectory: Directory('${temporary.path}/quarantine'),
    );
    final container = ProviderContainer(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(
          DemoCapabilities(capabilities),
        ),
        serlinkDatabaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        appLanguageSettingsRepositoryProvider.overrideWithValue(preferences),
        appPrivacySettingsRepositoryProvider.overrideWithValue(preferences),
        offlineDiagnosticLoggerProvider.overrideWithValue(_DemoLogger()),
        sshSessionServiceProvider.overrideWithValue(ssh),
        autoSyncEnabledProvider.overrideWithValue(false),
        cloudKitAvailabilityCheckProvider.overrideWithValue(() async => false),
        cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        databaseRecoveryServiceProvider.overrideWith((_) async => recovery),
        vaultBackupRestoreServiceProvider.overrideWith(
          (_) async => VaultBackupRestoreService(
            recovery: recovery,
            temporaryDirectory: Directory('${temporary.path}/restore'),
          ),
        ),
      ],
    );
    final workspace = DemoWorkspace._(container, database, temporary, ssh);
    try {
      await workspace._seed();
      return workspace;
    } on Object {
      await workspace.dispose();
      rethrow;
    }
  }

  Future<void> _seed() async {
    final date = DateTime.now().toUtc();
    final transfers = container.read(transferTaskRepositoryProvider);
    await transfers.save(
      TransferTask(
        id: TransferTaskId('demo-transfer'),
        direction: TransferDirection.download,
        sourceHostId: HostId('demo-sandbox'),
        sourceMachineName: 'Review Sandbox',
        localPath: 'demo/README.txt',
        remotePath: '${DemoFileSystem.home}/README.txt',
        state: TransferState.completed,
        transferredBytes: 512,
        totalBytes: 512,
        createdAt: date,
        completedAt: date,
      ),
    );
    await container.read(vaultSessionControllerProvider.future);
    final controller = container.read(vaultSessionControllerProvider.notifier);
    await controller.initialize(passphrase: const Uuid().v4());
    controller.dismissRecoveryKey();
    final identity = await container
        .read(identityWriteServiceProvider)
        .create(
          const IdentityCreateDraft(
            kind: IdentityKind.password,
            displayName: 'Offline example credential',
            usernameHint: 'reviewer',
            password: 'offline-example-only',
          ),
        );
    for (final (id, name, tag) in [
      ('demo-sandbox', 'Review Sandbox', 'review'),
      ('demo-staging', 'Staging Workspace', 'staging'),
      ('demo-docs', 'Documentation Server', 'docs'),
    ]) {
      await container
          .read(hostRepositoryProvider)
          .save(
            HostConfig(
              id: HostId(id),
              displayName: name,
              hostname: '$id.invalid',
              username: 'reviewer',
              port: 22,
              authKinds: {HostAuthKind.password},
              tags: {'offline-demo', tag},
              trustState: HostTrustState.trusted,
              identityIds: [identity.id],
              startupCommands: [],
              jumpHostIds: [],
              sftpDefaultDirectory: DemoFileSystem.home,
              groupId: 'Demo',
              createdAt: date,
              updatedAt: date,
            ),
          );
    }
    final snippets = container.read(snippetRepositoryProvider);
    for (final (id, name, command) in [
      ('demo-help', 'Explore the demo', 'help'),
      ('demo-files', 'List workspace files', 'ls -la'),
      ('demo-log', 'Read application log', 'cat logs/application.log'),
      ('demo-system', 'System information', 'uname -a'),
    ]) {
      await snippets.save(
        CommandSnippet(
          id: SnippetId(id),
          name: name,
          command: command,
          tags: {'offline-demo'},
          confirmBeforeRun: false,
          createdAt: date,
          updatedAt: date,
        ),
      );
    }
    await container
        .read(syncDeviceRepositoryProvider)
        .save(
          SyncDeviceMetadata(
            id: 'demo-mac',
            displayName: 'Example MacBook',
            platform: 'macos',
            createdAt: date,
            lastSeenAt: date,
          ),
        );
    await container
        .read(syncDeviceRepositoryProvider)
        .save(
          SyncDeviceMetadata(
            id: 'demo-iphone',
            displayName: 'Example iPhone',
            platform: 'ios',
            createdAt: date,
            lastSeenAt: date,
          ),
        );
    final sandbox = (await container.read(hostRepositoryProvider).list())
        .firstWhere((host) => host.id.value == 'demo-sandbox');
    final tabs = container.read(workspaceTabControllerProvider.notifier);
    await tabs.openTerminal(sandbox.toSummary());
    tabs.openSftp(sandbox.toSummary());
    tabs.selectArea(WorkspaceArea.hosts);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await ssh.dispose();
    await database.close();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  }
}

class _DemoPreferences
    implements AppLanguageSettingsRepository, AppPrivacySettingsRepository {
  _DemoPreferences(this.language);
  AppLanguage language;
  bool protect = false;
  @override
  Future<AppLanguage> read() async => language;
  @override
  Future<void> save(AppLanguage value) async {
    language = value;
  }

  @override
  Future<bool> readProtectBackground() async => protect;
  @override
  Future<void> saveProtectBackground(bool enabled) async {
    protect = enabled;
  }
}

class _DemoLogger extends OfflineDiagnosticLogger {
  @override
  Future<void> record(
    String event, {
    DiagnosticLogLevel level = DiagnosticLogLevel.info,
    Map<String, Object?> details = const {},
  }) async {}
  @override
  Future<List<DiagnosticLogFile>> readLogFiles() async => const [];
}
