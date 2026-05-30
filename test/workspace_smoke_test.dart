import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/ssh/domain/connection_profile.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/vault/data/drift_vault_repository.dart';
import 'package:serlink/features/workspace/application/workspace_tab_controller.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';

part 'workspace_smoke_test_fakes.dart';

void main() {
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
          vaultCryptoConfigProvider.overrideWithValue(
            const VaultCryptoConfig.testing(),
          ),
          sshSessionServiceProvider.overrideWithValue(sshService),
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(secretStore),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
        child: const SerlinkApp(),
      ),
    );
    await tester.pumpAndSettle();

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
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Configure'));
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
    await tester.tap(find.byKey(const ValueKey('webdav-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Use HTTP WebDAV?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow HTTP'));
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

    await tester.tap(find.byKey(const ValueKey('empty-add-host-button')));
    await tester.pumpAndSettle();

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

    expect(find.text('Production Bastion'), findsOneWidget);
    expect(find.text('ops@bastion.internal:22'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit host'));
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

    await tester.tap(find.byTooltip('Delete host'));
    await tester.pumpAndSettle();
    expect(find.text('Delete host?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No Hosts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('empty-add-host-button')));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byTooltip('Split right'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close active pane'), findsOneWidget);
    expect(find.textContaining('Connected'), findsWidgets);

    await tester.tap(find.byTooltip('Manage port forwarding'));
    await tester.pumpAndSettle();
    expect(find.text('Port Forwarding'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);
    expect(find.text('SOCKS Proxy'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open SFTP tab'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('app.env'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PORT=9090'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('releases'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-New name')),
      'archive',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(find.text('archive'), findsOneWidget);

    await tester.tap(find.byTooltip('Change permissions').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-Octal permissions')),
      '0700',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('0700'), findsOneWidget);

    await tester.tap(find.byTooltip('Move').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-input-Target path')),
      '/archive-moved',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();
    expect(find.text('archive-moved'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Delete archive-moved?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
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

  testWidgets('vault unlock exposes recovery code after repeated failures', (
    tester,
  ) async {
    final harness = await _pumpLockedVaultApp(tester);

    expect(find.text('Unlock Vault'), findsWidgets);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );

    await _submitVaultPassphrase(tester, 'wrong passphrase');
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );

    await _submitVaultPassphrase(tester, 'still wrong');
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
    await tester.pumpAndSettle();

    expect(find.text('No Hosts'), findsOneWidget);
  });

  testWidgets('vault reset requires typed confirmation from recovery dialog', (
    tester,
  ) async {
    final harness = await _pumpLockedVaultApp(tester);

    await _submitVaultPassphrase(tester, 'wrong passphrase');
    await _submitVaultPassphrase(tester, 'still wrong');
    await tester.tap(find.byKey(const ValueKey('vault-recovery-code-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vault-reset-entry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Reset Vault'), findsOneWidget);
    expect(find.text('Reset Vault Permanently'), findsOneWidget);

    final resetButton = find.byKey(
      const ValueKey('vault-reset-confirm-button'),
    );
    expect(tester.widget<FilledButton>(resetButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('vault-reset-confirmation-field')),
      'reset vault',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(resetButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('vault-reset-confirmation-field')),
      'RESET VAULT',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(resetButton).onPressed, isNotNull);

    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Vault'), findsWidgets);
    expect(await DriftVaultHeaderStore(harness.database).read(), isNull);
    expect(await DriftVaultRecordRepository(harness.database).list(), isEmpty);
  });

  testWidgets('vault unlock error resets after switching workspace tabs', (
    tester,
  ) async {
    await _pumpLockedVaultApp(tester);

    await _submitVaultPassphrase(tester, 'wrong passphrase');
    await _submitVaultPassphrase(tester, 'still wrong');
    expect(find.text('Passphrase did not unlock the vault.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hosts'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Vault'), findsWidgets);
    expect(find.text('Passphrase did not unlock the vault.'), findsNothing);
    expect(
      find.byKey(const ValueKey('vault-recovery-code-button')),
      findsNothing,
    );
  });
}

Future<_LockedVaultHarness> _pumpLockedVaultApp(WidgetTester tester) async {
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
        serlinkDatabaseProvider.overrideWithValue(database),
        vaultCryptoConfigProvider.overrideWithValue(
          const VaultCryptoConfig.testing(),
        ),
        sshSessionServiceProvider.overrideWithValue(_FakeSshSessionService()),
        transferQueueControllerProvider.overrideWithValue(transferQueue),
        secretStoreProvider.overrideWithValue(secretStore),
        autoSyncEnabledProvider.overrideWithValue(false),
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

Future<void> _submitVaultPassphrase(
  WidgetTester tester,
  String passphrase,
) async {
  await tester.enterText(
    find.byKey(const ValueKey('vault-passphrase-field')),
    passphrase,
  );
  await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
  await tester.pumpAndSettle();
}
