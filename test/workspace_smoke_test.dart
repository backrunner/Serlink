import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/features/workspace/application/workspace_tab_controller.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';

void main() {
  testWidgets('workspace creates vault and shows empty hosts', (tester) async {
    final database = SerlinkDatabase(NativeDatabase.memory());
    final sshService = _FakeSshSessionService();
    final transferQueue = TransferQueueController();
    final secretStore = InMemorySecretStore();
    addTearDown(database.close);
    addTearDown(transferQueue.dispose);

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

    expect(find.text('Serlink'), findsOneWidget);
    expect(find.text('Create Vault'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('vault-passphrase-field')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const ValueKey('vault-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Recovery Key'), findsOneWidget);
    expect(find.text('I have saved it'), findsOneWidget);

    await tester.tap(find.text('I have saved it'));
    await tester.pumpAndSettle();

    expect(find.text('No Hosts'), findsOneWidget);
    expect(
      find.text('Import SSH config or add hosts to start a session.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byTooltip('Split terminal'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close split'), findsOneWidget);
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
}

class _FakeSshSessionService implements SshSessionService {
  final _MutableFakeSftpConnection sftp = _MutableFakeSftpConnection();
  final _FakeShellSession shell = _FakeShellSession();
  final List<String> remoteBindings = [];
  final List<String> dynamicBindings = [];

  @override
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile) async {
    return shell;
  }

  @override
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile) async {
    return sftp;
  }

  @override
  Future<void> startLocalForward({
    required SessionId sessionId,
    required int localPort,
    required String remoteHost,
    required int remotePort,
  }) async {}

  @override
  Future<void> stopLocalForward({required SessionId sessionId}) async {}

  @override
  Future<RemoteForwardBinding> startRemoteForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
    required String localHost,
    required int localPort,
  }) async {
    remoteBindings.add('$bindHost:$bindPort->$localHost:$localPort');
    return RemoteForwardBinding(
      bindHost: bindHost,
      bindPort: bindPort,
      localHost: localHost,
      localPort: localPort,
    );
  }

  @override
  Future<void> stopRemoteForward({required SessionId sessionId}) async {}

  @override
  Future<DynamicForwardBinding> startDynamicForward({
    required SessionId sessionId,
    required String bindHost,
    required int bindPort,
  }) async {
    dynamicBindings.add('$bindHost:$bindPort');
    return DynamicForwardBinding(bindHost: bindHost, bindPort: bindPort);
  }

  @override
  Future<void> stopDynamicForward({required SessionId sessionId}) async {}

  @override
  Future<void> testConnection(ConnectionProfileSnapshot profile) async {}
}

class _FakeShellSession implements SshShellSession {
  final List<String> writes = [];
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> resize({
    required int columns,
    required int rows,
    int? pixelWidth,
    int? pixelHeight,
  }) async {}

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(String.fromCharCodes(bytes));
  }
}

class _MutableFakeSftpConnection implements SftpConnection {
  final Map<String, SftpEntry> _entries = {
    '/app.env': const SftpEntry(
      name: 'app.env',
      path: '/app.env',
      type: SftpEntryType.file,
      size: 2400,
      permissions: SftpPermissions('0640'),
    ),
  };
  final Map<String, String> _fileContents = {'/app.env': 'PORT=8080\n'};
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {
    final entry = _entries[path]!;
    _entries[path] = SftpEntry(
      name: entry.name,
      path: entry.path,
      type: entry.type,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      permissions: permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {
    _entries.remove(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    _entries.remove(path);
    _fileContents.remove(path);
  }

  @override
  Stream<TransferProgress> download({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String remotePath,
    required String localPath,
  }) {
    return Stream<TransferProgress>.value(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: _entries[remotePath]?.size ?? 1,
        totalBytes: _entries[remotePath]?.size ?? 1,
      ),
    );
  }

  @override
  Future<List<SftpEntry>> list(String path) async {
    return [
      for (final entry in _entries.values)
        if (_parentOf(entry.path) == path) entry,
    ];
  }

  @override
  Future<void> mkdir(String path) async {
    _entries[path] = SftpEntry(
      name: path.split('/').last,
      path: path,
      type: SftpEntryType.directory,
      permissions: const SftpPermissions('0755'),
    );
  }

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    final text = _fileContents[path] ?? '';
    final bytes = text.codeUnits.length;
    if (bytes <= maxBytes) {
      return SftpFilePreview(text: text, bytesRead: bytes, truncated: false);
    }
    return SftpFilePreview(
      text: text.substring(0, maxBytes),
      bytesRead: maxBytes,
      truncated: true,
    );
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {
    final entry = _entries.remove(oldPath)!;
    final contents = _fileContents.remove(oldPath);
    if (contents != null) {
      _fileContents[newPath] = contents;
    }
    _entries[newPath] = SftpEntry(
      name: newPath.split('/').last,
      path: newPath,
      type: entry.type,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      permissions: entry.permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    _fileContents[path] = contents;
    final entry = _entries[path]!;
    _entries[path] = SftpEntry(
      name: entry.name,
      path: entry.path,
      type: entry.type,
      size: contents.codeUnits.length,
      modifiedAt: entry.modifiedAt,
      permissions: entry.permissions,
      owner: entry.owner,
      group: entry.group,
      isHidden: entry.isHidden,
    );
  }

  @override
  Stream<TransferProgress> upload({
    required TransferTaskId taskId,
    required TransferItemKind itemKind,
    required String localPath,
    required String remotePath,
  }) {
    return Stream<TransferProgress>.value(
      TransferProgress(
        taskId: taskId,
        state: TransferState.completed,
        transferredBytes: 1,
        totalBytes: 1,
      ),
    );
  }
}

String _parentOf(String path) {
  final index = path.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return path.substring(0, index);
}
