import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/design_system/design_system.dart';
import 'package:serlink/features/hosts/application/host_repository.dart';
import 'package:serlink/features/hosts/application/host_write_service.dart';
import 'package:serlink/features/hosts/domain/host.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/application/sftp_failure.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/ssh/application/known_host_repository.dart';
import 'package:serlink/features/sync/application/sync_delete_tombstone_repository.dart';
import 'package:serlink/features/sync/application/sync_device_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/terminal/application/terminal_modifier_latch.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:serlink/features/workspace/application/workspace_tab_controller.dart';
import 'package:serlink/features/settings/application/app_language_settings.dart';
import 'package:serlink/l10n/l10n.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

part 'workspace_smoke_test_fakes.dart';

void main() {
  testWidgets('settings prompts vault creation when iCloud has no vault', (
    tester,
  ) async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    addTearDown(database.close);
    addTearDown(transferQueue.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'macos',
              targetPlatform: TargetPlatform.macOS,
            ),
          ),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          cloudKitAvailabilityCheckProvider.overrideWithValue(
            () => Future.value(true),
          ),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _EmptySyncProvider(),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          appPackageInfoProvider.overrideWith((ref) async {
            return _testPackageInfo();
          }),
        ],
        child: const SerlinkApp(),
      ),
    );

    await _pumpUntilFound(tester, find.text('Create Vault'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('create a vault to start syncing'), findsOneWidget);
    expect(find.text('unlock the vault to continue syncing'), findsNothing);
  });

  testWidgets('workspace creates vault and shows empty hosts', (tester) async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    final sshService = _FakeSshSessionService();
    final transferQueue = TransferQueueController();
    final secretStore = InMemorySecretStore();
    String? copiedRecoveryKey;
    addTearDown(database.close);
    addTearDown(transferQueue.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedRecoveryKey = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'windows',
              targetPlatform: TargetPlatform.windows,
            ),
          ),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          sshSessionServiceProvider.overrideWithValue(sshService),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(secretStore),
          autoSyncEnabledProvider.overrideWithValue(false),
          cloudKitAvailabilityCheckProvider.overrideWithValue(
            () => Future.value(false),
          ),
          appPackageInfoProvider.overrideWith((ref) async {
            return _testPackageInfo();
          }),
        ],
        child: const SerlinkApp(),
      ),
    );
    await _pumpUntilFound(tester, find.text('Create Vault'));

    expect(find.text('Create Vault'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Recovery Key'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-key-warning')), findsOneWidget);
    expect(find.textContaining('shown only once'), findsOneWidget);
    expect(find.textContaining('cannot retrieve it'), findsOneWidget);
    expect(find.text('Copy Recovery Key'), findsOneWidget);
    expect(find.text('I have saved it'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recovery-key-copy-button')));
    await tester.pumpAndSettle();
    expect(copiedRecoveryKey, startsWith('SRLK-RK1-'));
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.text('I have saved it'));
    await tester.pumpAndSettle();

    expect(find.text('No Hosts'), findsOneWidget);
    expect(
      find.text('Import SSH config or add hosts to start a session.'),
      findsOneWidget,
    );
    expect(find.text('Files'), findsNothing);
    expect(
      find.byKey(const ValueKey('workspace-search-field')),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-search-field')), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-vault-recovery-button')),
      findsNothing,
    );
    expect(find.text('Recover / Reset'), findsNothing);
    expect(find.text('Lock'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('webdav-endpoint-field')),
      'http://dav.local/webdav',
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
      find.byKey(const ValueKey('webdav-enabled-row')),
    );
    await tester.tap(find.byKey(const ValueKey('webdav-enabled-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('webdav-save-button')),
    );
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Use HTTP WebDAV?'), findsOneWidget);
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Allow HTTP'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.textContaining('dav.local/serlink'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-data-exchange-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import / Export'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('settings-data-exchange-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Export OpenSSH config'), findsOneWidget);
    expect(find.text('Export identity metadata'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('data-exchange-close-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hosts'));
    await tester.pumpAndSettle();

    await _tapAddHost(tester);

    expect(find.text('Display name (optional)'), findsOneWidget);
    expect(find.text('Leave blank to use the hostname.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('host-hostname-field'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('host-display-name-field')))
            .dy,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Production Bastion',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'bastion.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-startup-commands-field')),
      'tmux attach || tmux',
    );
    expect(
      tester
          .widget<SerlinkTextField>(
            find.byKey(const ValueKey('host-password-field')),
          )
          .obscureText,
      isTrue,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('host-password-visibility-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('host-password-visibility-toggle')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SerlinkTextField>(
            find.byKey(const ValueKey('host-password-field')),
          )
          .obscureText,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Production Bastion'), findsOneWidget);
    expect(find.text('ops@bastion.internal:22'), findsOneWidget);

    await _openHostContextMenu(tester, 'Production Bastion');
    await tester.tap(find.text('Edit host'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Host'), findsOneWidget);
    expect(find.text('tmux attach || tmux'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Renamed Bastion',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'renamed.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-startup-commands-field')),
      'pwd\ncd /srv/app',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Bastion'), findsOneWidget);
    expect(find.text('ops@renamed.internal:22'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-host-button')));
    await tester.pumpAndSettle();
    expect(find.text('Jump hosts'), findsOneWidget);
    final jumpHostChip = find.widgetWithText(
      SerlinkChoiceChip,
      'Renamed Bastion',
    );
    await tester.ensureVisible(jumpHostChip);
    await tester.pumpAndSettle();
    await tester.tap(jumpHostChip);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SerlinkTextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await _openHostContextMenu(tester, 'Renamed Bastion');
    await tester.tap(find.text('Delete host'));
    await tester.pumpAndSettle();
    expect(find.text('Delete host?'), findsOneWidget);
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No Hosts'), findsOneWidget);

    await _tapAddHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Production Bastion',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'bastion.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-startup-commands-field')),
      'tmux attach || tmux',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terminal').first);
    await tester.pumpAndSettle();
    await tester.pump();
    expect(sshService.shell.writes, contains('tmux attach || tmux\n'));

    await tester.tap(_byTooltipLabel('Split right'));
    await tester.pumpAndSettle();
    expect(_byTooltipLabel('Close active pane'), findsNothing);
    expect(find.textContaining('Connected'), findsNothing);

    await tester.tap(_byTooltipLabel('Manage port forwarding'));
    await tester.pumpAndSettle();
    expect(find.text('Port Forwarding'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);
    expect(find.text('SOCKS Proxy'), findsOneWidget);
    await tester.tap(find.widgetWithText(SerlinkTextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(_byTooltipLabel('Open SFTP tab'));
    await tester.pumpAndSettle();
    expect(find.text('app.env'), findsOneWidget);
    expect(find.text('.hidden.env'), findsNothing);
    expect(find.textContaining('deploy:ops'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sftp-hidden-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('.hidden.env'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sftp-hidden-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('.hidden.env'), findsNothing);

    await tester.tap(find.text('app.env'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PORT=8080'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('remote-file-editor')),
      'PORT=9090\n',
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('app.env'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PORT=9090'), findsOneWidget);
    await tester.tap(find.widgetWithText(SerlinkTextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('sftp-search-field')),
      'app',
    );
    await tester.pumpAndSettle();
    expect(find.text('app.env'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('sftp-search-field')),
      'missing',
    );
    await tester.pumpAndSettle();
    expect(find.text('No Matches'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sftp-search-field')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sftp-new-folder-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-Folder name')),
      'releases',
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('releases'), findsOneWidget);
    final rootListCountAfterCreate = sshService.sftp.listCounts['/'] ?? 0;

    await tester.tap(find.text('releases'));
    await tester.pumpAndSettle();
    expect(find.text('Empty Folder'), findsOneWidget);
    expect(find.text('/releases'), findsOneWidget);
    expect(sshService.sftp.listCounts['/releases'], 1);

    await tester.tap(find.byKey(const ValueKey('sftp-parent-button')));
    await tester.pumpAndSettle();
    expect(find.text('/'), findsOneWidget);
    expect(find.text('releases'), findsOneWidget);
    expect(sshService.sftp.listCounts['/'], rootListCountAfterCreate);

    await tester.tap(find.byKey(const ValueKey('sftp-path-display')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sftp-path-field')),
      '/releases',
    );
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('/releases'), findsOneWidget);
    expect(find.text('Empty Folder'), findsOneWidget);
    expect(sshService.sftp.listCounts['/releases'], 2);

    await tester.tap(find.byKey(const ValueKey('sftp-path-display')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sftp-path-field')), '/');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.text('/'), findsOneWidget);
    expect(find.text('releases'), findsOneWidget);
    final rootListCountAfterPathInput = sshService.sftp.listCounts['/'] ?? 0;
    expect(rootListCountAfterPathInput, rootListCountAfterCreate + 1);

    await tester.tap(_byTooltipLabel('Refresh'));
    await tester.pumpAndSettle();
    expect(sshService.sftp.listCounts['/'], rootListCountAfterPathInput + 1);

    await tester.tap(_byTooltipLabel('Rename').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-New name')),
      'archive',
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('archive'), findsOneWidget);

    await tester.tap(_byTooltipLabel('Change permissions').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-Permissions (octal or symbolic)')),
      'rwx------',
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('rwx------'), findsOneWidget);

    await tester.tap(_byTooltipLabel('Move').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-Target path')),
      '/archive-moved',
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Move'));
    await tester.pumpAndSettle();
    expect(find.text('archive-moved'), findsOneWidget);

    await tester.tap(_byTooltipLabel('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete archive-moved?'), findsOneWidget);
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('archive-moved'), findsNothing);

    transferQueue.enqueueDownload(
      connection: sshService.sftp,
      remotePath: '/app.env',
      localPath: '/tmp/app.env',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();
    expect(find.text('app.env'), findsOneWidget);
    expect(find.text('completed'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Sync'), findsWidgets);
    expect(find.text('WebDAV'), findsOneWidget);
    expect(find.text('Known hosts'), findsOneWidget);
    expect(find.text('Credentials'), findsOneWidget);

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hosts'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Vault'), findsWidgets);
  });

  testWidgets('iOS offers Face ID unlock after vault creation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    final secretStore = InMemorySecretStore();
    addTearDown(database.close);
    addTearDown(transferQueue.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          platformCapabilitiesProvider.overrideWithValue(
            const _IOSWithoutCloudKitCapabilities(),
          ),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(secretStore),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
        child: const SerlinkApp(),
      ),
    );
    await _pumpUntilFound(tester, find.text('Create Vault'));

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await _pumpUntilFound(tester, find.text('Recovery Key'));
    expect(tester.takeException(), isNull);

    expect(find.text('Recovery Key'), findsOneWidget);
    expect(find.text('Enable Face ID unlock?'), findsNothing);

    await tester.tap(find.text('I have saved it'));
    await _pumpUntilFound(tester, find.text('Enable Face ID unlock?'));
    expect(tester.takeException(), isNull);

    expect(find.text('Enable Face ID unlock?'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SerlinkApp)),
    );
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Enable'));
    await _pumpUntil(
      tester,
      () =>
          container
              .read(vaultSessionControllerProvider)
              .value
              ?.localUnlockAvailable ==
          true,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(
      find.text('Face ID unlock enabled. Lock the vault to use Face ID.'),
      findsOneWidget,
    );
    final session = container.read(vaultSessionControllerProvider).value;
    expect(session?.localUnlockAvailable, isTrue);
  });

  testWidgets('sftp prompts for a default folder when root is unavailable', (
    tester,
  ) async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    final secretStore = InMemorySecretStore();
    final bootstrapVault = InMemoryVaultService(
      config: const VaultCryptoConfig.testing(),
    );
    final initialized = await bootstrapVault.initialize(
      passphrase: 'correct horse battery staple',
    );
    await DriftVaultHeaderStore(database).save(initialized.header);
    final records = DriftVaultRecordRepository(database);
    final hosts = EncryptedHostRepository(
      vault: bootstrapVault,
      records: records,
    );
    final identities = EncryptedIdentityRepository(
      vault: bootstrapVault,
      records: records,
    );
    final hostWriteService = HostWriteService(
      hosts: hosts,
      identities: identities,
      knownHosts: EncryptedKnownHostRepository(
        vault: bootstrapVault,
        records: records,
      ),
      tombstones: EncryptedSyncDeleteTombstoneRepository(
        vault: bootstrapVault,
        records: records,
      ),
      records: records,
      vault: bootstrapVault,
    );
    final host = await hostWriteService.createPasswordHost(
      const PasswordHostDraft(
        displayName: 'Restricted SFTP',
        hostname: 'restricted.internal',
        port: 22,
        username: 'ops',
        password: 'server-password',
        tags: {},
      ),
    );
    final sshService = _FakeSshSessionService()..sftp.deniedListPaths.add('/');

    addTearDown(database.close);
    addTearDown(transferQueue.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serlinkDatabaseProvider.overrideWithValue(database),
          platformCapabilitiesProvider.overrideWithValue(
            const PlatformCapabilities(
              operatingSystem: 'windows',
              targetPlatform: TargetPlatform.windows,
            ),
          ),
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          sshSessionServiceProvider.overrideWithValue(sshService),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(secretStore),
          autoSyncEnabledProvider.overrideWithValue(false),
          appPackageInfoProvider.overrideWith((ref) async {
            return _testPackageInfo();
          }),
        ],
        child: const SerlinkApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    await _pumpUntilFound(tester, find.text('Restricted SFTP'));

    await tester.tap(find.text('SFTP').first);
    await tester.pumpAndSettle();
    expect(find.text('Choose SFTP Start Folder'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('sftp-default-directory-field')),
      '/home/ops',
    );
    await tester.tap(
      find.byKey(const ValueKey('sftp-default-directory-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('/home/ops'), findsOneWidget);
    expect(find.text('home.env'), findsOneWidget);
    expect((await hosts.read(host.id))!.sftpDefaultDirectory, '/home/ops');
  });

  testWidgets('vault unlock exposes recovery code after repeated failures', (
    tester,
  ) async {
    final harness = await _pumpLockedVaultApp(tester);

    expect(find.text('Unlock Vault'), findsWidgets);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );

    await _submitVaultPassphrase(
      tester,
      'wrong passphrase',
      expectSuccess: false,
    );
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );

    await _submitVaultPassphrase(tester, 'still wrong', expectSuccess: false);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('vault-recovery-code-button')));
    await tester.pumpAndSettle();
    expect(find.text('Recovery Code'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('vault-recovery-code-field')),
      harness.recoveryKey.value,
    );
    await tester.tap(
      find.byKey(const ValueKey('vault-recovery-unlock-button')),
    );
    await _pumpUntilFound(tester, find.text('No Hosts'));
  });

  testWidgets('vault unlock keeps locked state while submitting', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SerlinkApp)),
    );
    final unlockFuture = container
        .read(vaultSessionControllerProvider.notifier)
        .unlock(passphrase: 'correct horse battery staple');
    final pendingState = container.read(vaultSessionControllerProvider);

    expect(pendingState.hasValue, isTrue);
    expect(pendingState.isLoading, isFalse);
    expect(pendingState.requireValue.vaultState, VaultState.locked);
    expect(pendingState.requireValue.isBusy, isTrue);

    await unlockFuture;
    await tester.pumpAndSettle();
    expect(find.text('No Hosts'), findsOneWidget);
  });

  testWidgets('vault reset requires typed confirmation from recovery dialog', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester);

    await _submitVaultPassphrase(
      tester,
      'wrong passphrase',
      expectSuccess: false,
    );
    await _submitVaultPassphrase(tester, 'still wrong', expectSuccess: false);
    await tester.tap(find.byKey(const ValueKey('vault-recovery-code-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vault-reset-entry-button')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Reset Vault'), findsOneWidget);
    expect(find.text('Reset Vault Permanently'), findsOneWidget);
    expect(
      find.text(
        'If this vault is synced, other devices using the same synced vault will also be reset and cleared.',
      ),
      findsOneWidget,
    );

    final resetButton = find.byKey(
      const ValueKey('vault-reset-confirm-button'),
    );
    expect(tester.widget<SerlinkFilledButton>(resetButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('vault-reset-confirmation-field')),
      'reset vault',
    );
    await tester.pump();
    expect(tester.widget<SerlinkFilledButton>(resetButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('vault-reset-confirmation-field')),
      'RESET VAULT',
    );
    await tester.pump();
    expect(
      tester.widget<SerlinkFilledButton>(resetButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('settings exposes recovery and reset while vault is locked', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final recoveryButton = find.byKey(
      const ValueKey('settings-vault-recovery-button'),
    );
    expect(recoveryButton, findsOneWidget);

    await tester.tap(recoveryButton);
    await tester.pumpAndSettle();
    expect(find.text('Recovery Code'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vault-reset-entry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Reset Vault'), findsOneWidget);
    expect(find.text('Reset Vault Permanently'), findsOneWidget);
  });

  testWidgets('settings shows Face ID unlock controls after enabling', (
    tester,
  ) async {
    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'windows',
        targetPlatform: TargetPlatform.windows,
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey('vault-passphrase-field'))
          .evaluate()
          .isEmpty,
    );

    await tester.tap(find.text('Settings'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('settings-local-unlock-switch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-local-unlock-switch')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enable Face ID unlock?'), findsOneWidget);

    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Enable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Face ID unlock enabled. Lock the vault to use Face ID.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-local-unlock-button')),
    );

    expect(
      find.byKey(const ValueKey('settings-local-unlock-button')),
      findsOneWidget,
    );
    expect(find.text('Use Face ID'), findsOneWidget);
  });

  testWidgets('mobile settings controls stay compact and readable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'android',
        targetPlatform: TargetPlatform.android,
      ),
      syncDevices: [
        SyncDeviceMetadata(
          id: 'mobile-device',
          displayName: 'Pixel Fold',
          platform: 'android',
          createdAt: DateTime.utc(2026, 6, 1),
          lastSeenAt: DateTime.utc(2026, 6, 28),
        ),
        SyncDeviceMetadata(
          id: 'desktop-device',
          displayName: 'Studio Mac',
          platform: 'macos',
          createdAt: DateTime.utc(2026, 6, 2),
          lastSeenAt: DateTime.utc(2026, 6, 29),
        ),
      ],
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SerlinkApp)),
    );
    container.read(syncConflictControllerProvider.notifier).setConflicts([
      SyncRecordConflict(
        id: VaultRecordId('host:mobile-conflict'),
        type: 'host',
        localRevision: 'local',
        remoteRevision: 'remote',
        title: 'Mobile conflict host',
        subtitle: 'Host - host:mobile-conflict',
      ),
    ], providerKind: SyncProviderKind.webDav);
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final languageSelect = find.byKey(
      const ValueKey('settings-language-select'),
    );
    expect(languageSelect, findsOneWidget);
    final selectRect = tester.getRect(languageSelect);
    expect(selectRect.width, greaterThanOrEqualTo(108));
    expect(selectRect.width, lessThanOrEqualTo(116));
    expect(selectRect.height, lessThanOrEqualTo(42));
    final languageIconRect = tester.getRect(
      find.byKey(const ValueKey('settings-language-icon')),
    );
    expect(
      (selectRect.center.dy - languageIconRect.center.dy).abs(),
      lessThanOrEqualTo(4),
    );

    await tester.tap(languageSelect);
    await tester.pumpAndSettle();
    final chineseOption = find.text('Simplified Chinese');
    expect(chineseOption, findsOneWidget);
    expect(tester.getRect(chineseOption).width, greaterThan(96));
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final localUnlockSwitch = find.byKey(
      const ValueKey('settings-local-unlock-switch'),
    );
    await tester.ensureVisible(localUnlockSwitch);
    await tester.pumpAndSettle();
    expect(localUnlockSwitch, findsOneWidget);
    final switchRect = tester.getRect(localUnlockSwitch);
    expect(switchRect.width, lessThanOrEqualTo(38));
    expect(switchRect.height, lessThanOrEqualTo(26));
    final localUnlockTitleRect = tester.getRect(find.text('Face ID unlock'));
    expect(
      (switchRect.center.dy - localUnlockTitleRect.center.dy).abs(),
      lessThanOrEqualTo(16),
    );

    final syncConflictButton = find.byKey(
      const ValueKey('settings-sync-conflicts-view-button'),
    );
    await tester.ensureVisible(syncConflictButton);
    await tester.pumpAndSettle();
    expect(syncConflictButton, findsOneWidget);
    expect(
      find.descendant(of: syncConflictButton, matching: find.text('View')),
      findsOneWidget,
    );
    expect(find.text('Use remote'), findsNothing);
    expect(find.text('Keep local'), findsNothing);

    final syncDevicesViewButton = find.byKey(
      const ValueKey('settings-sync-devices-view-button'),
    );
    await tester.ensureVisible(syncDevicesViewButton);
    await tester.pumpAndSettle();
    expect(syncDevicesViewButton, findsOneWidget);
    expect(find.text('2 devices registered.'), findsOneWidget);
    expect(find.textContaining('Last writer'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-sync-devices-reset-button')),
      findsNothing,
    );
    final devicesViewRect = tester.getRect(syncDevicesViewButton);
    expect(devicesViewRect.width, lessThanOrEqualTo(92));
    expect(devicesViewRect.height, lessThanOrEqualTo(32));

    await tester.tap(syncDevicesViewButton);
    await tester.pumpAndSettle();
    expect(find.text('Sync Devices'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sync-devices-dialog-reset-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('background privacy screen is off by default', (tester) async {
    await _pumpLockedVaultApp(tester);

    expect(find.text('Unlock Vault'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Unlock Vault'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('background privacy screen covers app when enabled', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester, protectBackground: true);

    expect(find.text('Unlock Vault'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.text('Unlock Vault'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('settings runtime exports diagnostic logs', (tester) async {
    await _pumpLockedVaultApp(tester);
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Diagnostic logs'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-diagnostic-log-export-button')),
      findsOneWidget,
    );
    expect(find.text('Debug logging'), findsNothing);
    expect(find.text('Crash reporting'), findsNothing);
  });

  testWidgets('settings shows app version in about section', (tester) async {
    await _pumpLockedVaultApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Serlink'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('https://github.com/backrunner/serlink'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-about-github-button')),
      findsOneWidget,
    );
    final versionLabel = find.byKey(
      const ValueKey('settings-about-version-label'),
    );
    expect(versionLabel, findsOneWidget);
    expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
    final appTitleRect = tester.getRect(find.text('Serlink'));
    final versionRect = tester.getRect(versionLabel);
    expect(versionRect.left, greaterThan(appTitleRect.right));
    expect(versionRect.center.dy, closeTo(appTitleRect.center.dy, 4));
  });

  testWidgets(
    'macOS App Store distribution hides local-only host affordances',
    (tester) async {
      await _pumpLockedVaultApp(
        tester,
        capabilities: const PlatformCapabilities(
          operatingSystem: 'macos',
          targetPlatform: TargetPlatform.macOS,
          distribution: SerlinkDistribution.appStore,
        ),
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('workspace-search-field')),
      );
      expect(_byTooltipLabel('Open local terminal tab'), findsNothing);
      expect(
        find.byKey(const ValueKey('workspace-search-field')),
        findsOneWidget,
      );

      await _tapAddHost(tester);

      expect(find.byKey(const ValueKey('host-password-field')), findsOneWidget);
      expect(find.text('Agent'), findsNothing);
    },
  );

  testWidgets('iOS add host form uses compact wide dialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    final headerAddHostButton = find.byKey(const ValueKey('add-host-button'));
    expect(headerAddHostButton, findsOneWidget);
    await tester.tap(headerAddHostButton);
    await tester.pumpAndSettle();

    final formFrame = find.byKey(const ValueKey('host-form-scroll-frame'));
    expect(formFrame, findsOneWidget);
    final frameRect = tester.getRect(formFrame);
    expect(frameRect.left, lessThan(24));
    expect(frameRect.width, greaterThanOrEqualTo(348));
    expect(frameRect.height, greaterThan(440));
    expect(frameRect.height, lessThanOrEqualTo(600));
    expect(
      tester.getRect(find.byKey(const ValueKey('host-save-button'))).bottom,
      lessThanOrEqualTo(844),
    );
  });

  testWidgets('iOS list header actions live in the mobile title bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    expect(find.byKey(const ValueKey('add-host-button')), findsOneWidget);
    final addHostRect = tester.getRect(
      find.byKey(const ValueKey('add-host-button')),
    );
    expect(addHostRect.width, 38);
    expect(addHostRect.height, 38);
    final headerTitleRow = find.byKey(
      const ValueKey('mobile-header-title-row'),
    );
    final headerTitle = find.descendant(
      of: headerTitleRow,
      matching: find.text('Hosts'),
    );
    expect(headerTitle, findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();

    final newSessionButton = find.byKey(
      const ValueKey('mobile-new-session-button'),
    );
    expect(newSessionButton, findsOneWidget);
    final newSessionRect = tester.getRect(newSessionButton);
    expect(newSessionRect.width, 38);
    expect(newSessionRect.height, 38);

    await tester.tap(find.text('Snippets'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-snippet-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-add-snippet-button')),
      findsOneWidget,
    );
  });

  testWidgets('iOS host rows reveal edit/delete on swipe', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await tester.tap(find.byKey(const ValueKey('add-host-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Swipe Delete Host',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'swipe-delete.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('Swipe Delete Host'), findsOneWidget);
    final hostRow = find.ancestor(
      of: find.text('Swipe Delete Host'),
      matching: find.byType(ListRow),
    );
    expect(hostRow, findsOneWidget);
    final hostTopGap =
        tester.getRect(hostRow).top -
        tester
            .getRect(find.byKey(const ValueKey('mobile-workspace-search-bar')))
            .bottom;
    expect(hostTopGap, inInclusiveRange(6, 10));

    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hosts'));
    await tester.pump();

    expect(find.text('Loading encrypted host records'), findsNothing);
    expect(find.text('Swipe Delete Host'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Swipe Delete Host'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit host'), findsNothing);
    expect(find.text('Delete host'), findsNothing);

    for (final keyPrefix in ['terminal', 'sftp']) {
      final buttonRect = tester.getRect(
        find.byKey(ValueKey('mobile-host-$keyPrefix-button')),
      );
      final iconRect = tester.getRect(
        find.byKey(ValueKey('mobile-host-$keyPrefix-icon')),
      );
      expect(buttonRect.width, 34);
      expect(buttonRect.height, 34);
      expect(
        (buttonRect.center.dx - iconRect.center.dx).abs(),
        lessThanOrEqualTo(0.5),
      );
      expect(
        (buttonRect.center.dy - iconRect.center.dy).abs(),
        lessThanOrEqualTo(0.5),
      );
    }

    await tester.drag(find.text('Swipe Delete Host'), const Offset(-130, 0));
    await tester.pumpAndSettle();
    final editButton = find.byKey(const ValueKey('mobile-host-edit-button'));
    final editIcon = find.byKey(const ValueKey('mobile-host-edit-icon'));
    final deleteButton = find.byKey(
      const ValueKey('mobile-host-delete-button'),
    );
    final deleteIcon = find.byKey(const ValueKey('mobile-host-delete-icon'));
    expect(editButton, findsOneWidget);
    expect(editIcon, findsOneWidget);
    expect(deleteButton, findsOneWidget);
    expect(deleteIcon, findsOneWidget);
    expect(
      find.descendant(of: editButton, matching: find.text('Edit host')),
      findsNothing,
    );
    expect(
      find.descendant(of: deleteButton, matching: find.text('Delete')),
      findsNothing,
    );
    final editButtonRect = tester.getRect(editButton);
    final editIconRect = tester.getRect(editIcon);
    final deleteButtonRect = tester.getRect(deleteButton);
    final deleteIconRect = tester.getRect(deleteIcon);
    final swipedHostRowRect = tester.getRect(hostRow);
    final hostEditGap = editButtonRect.left - swipedHostRowRect.right;
    final editDeleteGap = deleteButtonRect.left - editButtonRect.right;
    expect(editButtonRect.width, 44);
    expect(editButtonRect.height, 44);
    expect(deleteButtonRect.width, 44);
    expect(deleteButtonRect.height, 44);
    expect(editButtonRect.center.dx, lessThan(deleteButtonRect.center.dx));
    expect(hostEditGap, moreOrLessEquals(editDeleteGap, epsilon: 0.5));
    expect(hostEditGap, moreOrLessEquals(SerlinkSpacing.sm, epsilon: 0.5));
    expect(
      tester.widget<SerlinkPressable>(editButton).borderRadius,
      SerlinkRadii.dialog,
    );
    expect(
      tester.widget<SerlinkPressable>(deleteButton).borderRadius,
      SerlinkRadii.dialog,
    );
    expect(
      (editButtonRect.center.dx - editIconRect.center.dx).abs(),
      lessThanOrEqualTo(0.5),
    );
    expect(
      (editButtonRect.center.dy - editIconRect.center.dy).abs(),
      lessThanOrEqualTo(0.5),
    );
    expect(
      (deleteButtonRect.center.dx - deleteIconRect.center.dx).abs(),
      lessThanOrEqualTo(0.5),
    );
    expect(
      (deleteButtonRect.center.dy - deleteIconRect.center.dy).abs(),
      lessThanOrEqualTo(0.5),
    );

    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit Host'), findsOneWidget);

    await tester.tap(find.widgetWithText(SerlinkTextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Swipe Delete Host'), const Offset(-130, 0));
    await tester.pumpAndSettle();

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete host?'), findsOneWidget);
    expect(find.text('Swipe Delete Host'), findsOneWidget);
  });

  testWidgets('iOS SFTP pane keeps controls within the viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await _tapAddHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Mobile SFTP',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'mobile.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    await tester.tap(_byTooltipLabel('SFTP'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sftp-path-display')), findsOneWidget);
    expect(find.byKey(const ValueKey('sftp-search-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('sftp-hidden-toggle')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sftp-new-folder-button')),
      findsOneWidget,
    );
    expect(find.text('app.env'), findsOneWidget);
    expect(find.text('rw-r-----'), findsOneWidget);

    for (final finder in [
      find.byKey(const ValueKey('sftp-path-display')),
      find.byKey(const ValueKey('sftp-search-field')),
      find.byKey(const ValueKey('sftp-hidden-toggle')),
      find.byKey(const ValueKey('sftp-new-folder-button')),
      find.text('app.env'),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS terminal accessory sends control sequences to shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sshService = _FakeSshSessionService();

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
      sshService: sshService,
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await _tapAddHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Mobile Terminal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'terminal.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    await tester.tap(_byTooltipLabel('Terminal'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('terminal-viewport-clip')),
      findsOneWidget,
    );
    sshService.shell.writes.clear();

    await tester.tap(find.byKey(const ValueKey('terminal-key-tab')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-insert')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-delete')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-arrow-up')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-arrow-left')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-page-up')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-page-down')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-ctrl')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-arrow-right')));
    await tester.tap(
      find.byKey(const ValueKey('terminal-key-function-toggle')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-key-f1')));
    await tester.tap(find.byKey(const ValueKey('terminal-key-f12')));
    await tester.pump();

    expect(sshService.shell.writes, [
      terminalControlInputSequence(
        TerminalControlInputKey.tab,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.insert,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.delete,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.arrowUp,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.arrowLeft,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.pageUp,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.pageDown,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.arrowRight,
        const TerminalModifierLatch(ctrl: true),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.f1,
        const TerminalModifierLatch(),
      ),
      terminalControlInputSequence(
        TerminalControlInputKey.f12,
        const TerminalModifierLatch(),
      ),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact iOS terminal disables right split', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await _tapAddHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Mobile Split',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'split.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    await tester.tap(_byTooltipLabel('Terminal'));
    await tester.pumpAndSettle();

    final splitRight = find.byKey(
      const ValueKey('terminal-split-right-button'),
    );
    final splitDown = find.byKey(const ValueKey('terminal-split-down-button'));
    expect(splitRight, findsOneWidget);
    expect(splitDown, findsOneWidget);
    expect(_byTooltipLabel('Close pane'), findsNothing);

    await tester.tap(_byTooltipLabel('Split right'));
    await tester.pumpAndSettle();
    expect(_byTooltipLabel('Close pane'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS terminal accessory arranges navigation keys in two rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLockedVaultApp(
      tester,
      capabilities: const PlatformCapabilities(
        operatingSystem: 'ios',
        targetPlatform: TargetPlatform.iOS,
      ),
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');

    await _tapAddHost(tester);
    await tester.enterText(
      find.byKey(const ValueKey('host-display-name-field')),
      'Mobile Terminal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-hostname-field')),
      'terminal.internal',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-username-field')),
      'ops',
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-password-field')),
      'server-password',
    );
    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();

    await tester.tap(_byTooltipLabel('Terminal'));
    await tester.pumpAndSettle();

    final bar = tester.getRect(
      find.byKey(const ValueKey('terminal-accessory-bar')),
    );
    expect(bar.height, lessThanOrEqualTo(72));

    final ctrl = _rectForKey(tester, 'terminal-key-ctrl');
    final tab = _rectForKey(tester, 'terminal-key-tab');
    expect(ctrl.center.dy, lessThan(tab.center.dy));

    final insert = _rectForKey(tester, 'terminal-key-insert');
    final delete = _rectForKey(tester, 'terminal-key-delete');
    final home = _rectForKey(tester, 'terminal-key-home');
    final end = _rectForKey(tester, 'terminal-key-end');
    expect(insert.center.dy, closeTo(delete.center.dy, 1));
    expect(home.center.dy, closeTo(end.center.dy, 1));
    expect(insert.center.dy, lessThan(home.center.dy));
    expect(insert.center.dx, closeTo(home.center.dx, 1));
    expect(delete.center.dx, closeTo(end.center.dx, 1));

    final arrowUp = _rectForKey(tester, 'terminal-key-arrow-up');
    final arrowLeft = _rectForKey(tester, 'terminal-key-arrow-left');
    final arrowDown = _rectForKey(tester, 'terminal-key-arrow-down');
    final arrowRight = _rectForKey(tester, 'terminal-key-arrow-right');

    expect(arrowUp.center.dy, lessThan(arrowDown.center.dy));
    expect(arrowUp.center.dx, closeTo(arrowDown.center.dx, 1));
    expect(arrowLeft.center.dx, lessThan(arrowDown.center.dx));
    expect(arrowDown.center.dx, lessThan(arrowRight.center.dx));
    expect(arrowLeft.center.dy, closeTo(arrowDown.center.dy, 1));
    expect(arrowRight.center.dy, closeTo(arrowDown.center.dy, 1));

    final pageUp = _rectForKey(tester, 'terminal-key-page-up');
    final pageDown = _rectForKey(tester, 'terminal-key-page-down');
    expect(pageUp.center.dy, closeTo(pageDown.center.dy, 1));
    expect(pageUp.center.dx, lessThan(pageDown.center.dx));
    expect(pageDown.right, lessThanOrEqualTo(390));

    expect(find.byKey(const ValueKey('terminal-key-f1')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('terminal-key-function-toggle')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('terminal-key-f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('terminal-key-f12')), findsOneWidget);

    final f1 = _rectForKey(tester, 'terminal-key-f1');
    final f7 = _rectForKey(tester, 'terminal-key-f7');
    final f12 = _rectForKey(tester, 'terminal-key-f12');
    expect(f1.center.dy, lessThan(f7.center.dy));
    expect(f1.center.dx, closeTo(f7.center.dx, 1));
    expect(f12.right, lessThanOrEqualTo(390));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hosts show loading while encrypted records initialize after unlock',
    (tester) async {
      final database = SerlinkDatabase(NativeDatabase.memory());
      final transferQueue = TransferQueueController();
      final secretStore = InMemorySecretStore();
      final bootstrapVault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      final initialized = await bootstrapVault.initialize(
        passphrase: 'correct horse battery staple',
      );
      await DriftVaultHeaderStore(database).save(initialized.header);
      await DriftVaultRecordRepository(database).upsert(
        await bootstrapVault.encryptRecord(
          id: VaultRecordId('loading-test-record'),
          type: 'test',
          plaintext: utf8.encode('secret'),
        ),
      );
      final now = DateTime.utc(2026);
      final hosts = _DelayedHostRepository([
        HostConfig(
          id: HostId('persisted-host'),
          displayName: 'Persisted Bastion',
          hostname: 'persisted.internal',
          username: 'ops',
          port: 22,
          authKinds: const {HostAuthKind.password},
          tags: const {},
          trustState: HostTrustState.unknown,
          identityIds: const [],
          startupCommands: const [],
          jumpHostIds: const [],
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      addTearDown(database.close);
      addTearDown(transferQueue.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serlinkDatabaseProvider.overrideWithValue(database),
            platformCapabilitiesProvider.overrideWithValue(
              const PlatformCapabilities(
                operatingSystem: 'windows',
                targetPlatform: TargetPlatform.windows,
              ),
            ),
            vaultCryptoConfigProvider.overrideWithValue(
              const VaultCryptoConfig.testing(),
            ),
            hostRepositoryProvider.overrideWithValue(hosts),
            sshSessionServiceProvider.overrideWithValue(
              _FakeSshSessionService(),
            ),
            transferQueueControllerProvider.overrideWithValue(transferQueue),
            secretStoreProvider.overrideWithValue(secretStore),
            autoSyncEnabledProvider.overrideWithValue(false),
            cloudKitAvailabilityCheckProvider.overrideWithValue(
              () async => false,
            ),
            appPackageInfoProvider.overrideWith((ref) async {
              return _testPackageInfo();
            }),
          ],
          child: const SerlinkApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vault-passphrase-field')),
        'correct horse battery staple',
      );
      await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
      await _pumpUntil(tester, () => hosts.listRequested);
      await tester.pump();

      expect(find.text('Loading encrypted host records'), findsOneWidget);
      expect(find.text('Loading encrypted host records.'), findsNothing);
      expect(find.byType(SerlinkLoadingIndicator), findsOneWidget);
      expect(find.text('No Hosts'), findsNothing);

      hosts.completeList();
      await _pumpUntilFound(tester, find.text('Persisted Bastion'));

      expect(find.text('Persisted Bastion'), findsOneWidget);
      expect(find.text('ops@persisted.internal:22'), findsOneWidget);
    },
  );

  testWidgets('hosts can be sorted from the header menu', (tester) async {
    final hosts = _DelayedHostRepository([
      _hostConfig(
        id: 'zulu',
        displayName: 'Zulu Jump',
        hostname: 'zulu.internal',
        createdAt: DateTime.utc(2026, 6, 18, 10),
        lastConnectedAt: DateTime.utc(2026, 6, 20),
      ),
      _hostConfig(
        id: 'alpha',
        displayName: 'Alpha Bastion',
        hostname: 'alpha.internal',
        createdAt: DateTime.utc(2026, 6, 18, 12),
        lastConnectedAt: DateTime.utc(2026, 6, 21),
      ),
      _hostConfig(
        id: 'mid',
        displayName: 'Mid Recently Added',
        hostname: 'mid.internal',
        createdAt: DateTime.utc(2026, 6, 18, 14),
      ),
    ]);

    await _pumpLockedVaultApp(tester, hostRepository: hosts);
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    await _pumpUntil(tester, () => hosts.listRequested);
    hosts.completeList();
    await _pumpUntilFound(tester, find.text('Mid Recently Added'));

    _expectTextVerticalOrder(tester, [
      'Mid Recently Added',
      'Alpha Bastion',
      'Zulu Jump',
    ]);

    await tester.tap(find.byKey(const ValueKey('sort-hosts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort by name'));
    await tester.pumpAndSettle();

    _expectTextVerticalOrder(tester, [
      'Alpha Bastion',
      'Mid Recently Added',
      'Zulu Jump',
    ]);

    await tester.tap(find.byKey(const ValueKey('sort-hosts-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort by last connection'));
    await tester.pumpAndSettle();

    _expectTextVerticalOrder(tester, [
      'Alpha Bastion',
      'Zulu Jump',
      'Mid Recently Added',
    ]);
  });

  testWidgets('vault unlock error resets after switching workspace tabs', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester);
    final l10n = lookupSerlinkLocalizations(AppLanguage.english);

    await _submitVaultPassphrase(
      tester,
      'wrong passphrase',
      expectSuccess: false,
    );
    await _submitVaultPassphrase(tester, 'still wrong', expectSuccess: false);
    expect(find.text(l10n.vaultInvalidPassphraseError), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hosts'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Vault'), findsWidgets);
    expect(find.text(l10n.vaultInvalidPassphraseError), findsNothing);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );
  });
}

Future<_LockedVaultHarness> _pumpLockedVaultApp(
  WidgetTester tester, {
  PlatformCapabilities? capabilities,
  _FakeSshSessionService? sshService,
  HostRepository? hostRepository,
  List<SyncDeviceMetadata>? syncDevices,
  bool protectBackground = false,
}) async {
  final database = SerlinkDatabase(NativeDatabase.memory());
  final transferQueue = TransferQueueController();
  final secretStore = InMemorySecretStore();
  final privacySettings = _MemoryAppPrivacySettingsRepository(
    protectBackground,
  );
  final resolvedSshService = sshService ?? _FakeSshSessionService();
  final resolvedCapabilities =
      capabilities ??
      const PlatformCapabilities(
        operatingSystem: 'windows',
        targetPlatform: TargetPlatform.windows,
      );
  final bootstrapVault = InMemoryVaultService(
    config: const VaultCryptoConfig.testing(),
  );
  final initialized = await bootstrapVault.initialize(
    passphrase: 'correct horse battery staple',
  );
  await DriftVaultHeaderStore(database).save(initialized.header);
  await DriftVaultRecordRepository(database).upsert(
    await bootstrapVault.encryptRecord(
      id: VaultRecordId('test-record'),
      type: 'test',
      plaintext: utf8.encode('secret'),
    ),
  );

  addTearDown(database.close);
  addTearDown(transferQueue.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilitiesProvider.overrideWithValue(resolvedCapabilities),
        if (resolvedCapabilities.cloudKitSync) ...[
          cloudKitAvailabilityCheckProvider.overrideWithValue(
            () async => false,
          ),
          cloudKitSyncProviderFactoryProvider.overrideWithValue(
            () => _EmptySyncProvider(),
          ),
          cloudKitSyncChangesProvider.overrideWith((_) => const Stream.empty()),
        ],
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        if (hostRepository != null)
          hostRepositoryProvider.overrideWithValue(hostRepository),
        if (syncDevices != null)
          syncKnownDevicesProvider.overrideWith((ref) async => syncDevices),
        sshSessionServiceProvider.overrideWithValue(resolvedSshService),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(secretStore),
        appPrivacySettingsRepositoryProvider.overrideWithValue(privacySettings),
        autoSyncEnabledProvider.overrideWithValue(false),
        appPackageInfoProvider.overrideWith((ref) async {
          return _testPackageInfo();
        }),
      ],
      child: const SerlinkApp(),
    ),
  );
  await tester.pumpAndSettle();

  return _LockedVaultHarness(
    database: database,
    recoveryKey: initialized.recoveryKey,
  );
}

PackageInfo _testPackageInfo() {
  return PackageInfo(
    appName: 'Serlink',
    packageName: 'com.alkinum.serlink',
    version: '1.2.3',
    buildNumber: '45',
  );
}

Future<void> _submitVaultPassphrase(
  WidgetTester tester,
  String passphrase, {
  bool expectSuccess = true,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('vault-passphrase-field')),
    passphrase,
  );
  await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
  if (!expectSuccess) {
    await tester.pumpAndSettle();
    return;
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SerlinkApp)),
  );
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    final session = container.read(vaultSessionControllerProvider).value;
    if (session?.vaultState == VaultState.unlocked) {
      return;
    }
    if (session?.failureMessage case final failure?) {
      fail('Vault unlock failed: $failure');
    }
  }
  final session = container.read(vaultSessionControllerProvider).value;
  fail(
    'Timed out waiting for vault unlock. '
    'state=${session?.vaultState} busy=${session?.isBusy}',
  );
}

Future<void> _tapAddHost(WidgetTester tester) async {
  final headerAddHost = find.byKey(const ValueKey('add-host-button'));
  final emptyAddHost = find.byKey(const ValueKey('empty-add-host-button'));
  await _pumpUntil(
    tester,
    () =>
        headerAddHost.evaluate().isNotEmpty ||
        emptyAddHost.evaluate().isNotEmpty,
  );
  await tester.tap(
    headerAddHost.evaluate().isNotEmpty ? headerAddHost : emptyAddHost,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for predicate to become true');
}

Future<void> _openHostContextMenu(WidgetTester tester, String hostName) async {
  await tester.tap(find.text(hostName), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

Finder _byTooltipLabel(String label) => find.bySemanticsLabel(label);

Rect _rectForKey(WidgetTester tester, String key) {
  return tester.getRect(find.byKey(ValueKey<String>(key)));
}

void _expectTextVerticalOrder(WidgetTester tester, List<String> labels) {
  final tops = [
    for (final label in labels) tester.getTopLeft(find.text(label)).dy,
  ];
  for (var index = 0; index < tops.length - 1; index += 1) {
    expect(tops[index], lessThan(tops[index + 1]));
  }
}

HostConfig _hostConfig({
  required String id,
  required String displayName,
  required String hostname,
  required DateTime createdAt,
  DateTime? lastConnectedAt,
}) {
  return HostConfig(
    id: HostId(id),
    displayName: displayName,
    hostname: hostname,
    username: 'ops',
    port: 22,
    authKinds: const {HostAuthKind.password},
    tags: const {},
    trustState: HostTrustState.trusted,
    identityIds: const [],
    startupCommands: const [],
    jumpHostIds: const [],
    createdAt: createdAt,
    updatedAt: createdAt,
    lastConnectedAt: lastConnectedAt,
  );
}

class _DelayedHostRepository implements HostRepository {
  _DelayedHostRepository(this._hosts);

  final List<HostConfig> _hosts;
  final Completer<void> _listReady = Completer<void>();
  final Completer<void> _listRequested = Completer<void>();

  bool get listRequested => _listRequested.isCompleted;

  void completeList() {
    if (!_listReady.isCompleted) {
      _listReady.complete();
    }
  }

  @override
  Future<void> save(HostConfig host) {
    throw UnimplementedError();
  }

  @override
  Future<HostConfig?> read(HostId id) async {
    for (final host in _hosts) {
      if (host.id == id) {
        return host;
      }
    }
    return null;
  }

  @override
  Future<List<HostConfig>> list() async {
    if (!_listRequested.isCompleted) {
      _listRequested.complete();
    }
    await _listReady.future;
    return _hosts;
  }

  @override
  Future<void> delete(HostId id) {
    throw UnimplementedError();
  }
}
