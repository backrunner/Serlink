import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/database/serlink_database.dart';
import 'package:serlink/features/sftp/application/sftp_connection.dart';
import 'package:serlink/features/sftp/domain/sftp_entry.dart';
import 'package:serlink/features/transfers/application/transfer_queue_controller.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  testWidgets('iOS uses the mobile workspace shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
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
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
        child: const SerlinkApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is FHeader),
      findsOneWidget,
    );
    expect(find.byType(FBottomNavigationBar), findsOneWidget);
    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.text('Snippets'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Local Shell'), findsNothing);
  });

  testWidgets('iOS transfer tasks support workspace search', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = SerlinkDatabase(NativeDatabase.memory());
    final transferQueue = TransferQueueController();
    final connection = _CompletingSftpConnection();
    addTearDown(database.close);
    addTearDown(transferQueue.dispose);

    transferQueue.enqueueUpload(
      connection: connection,
      sourceMachineName: 'MacBook Pro',
      localPath: '/Users/ops/Downloads/release.zip',
      remotePath: '/srv/releases/release.zip',
    );
    transferQueue.enqueueDownload(
      connection: connection,
      sourceMachineName: 'Bastion',
      remotePath: '/var/log/nginx/access.log',
      localPath: '/tmp/access.log',
    );

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
          transferQueueControllerProvider.overrideWithValue(transferQueue),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          autoSyncEnabledProvider.overrideWithValue(false),
        ],
        child: const SerlinkApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfers'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-workspace-search-field')),
      findsOneWidget,
    );
    expect(find.text('release.zip'), findsOneWidget);
    expect(find.text('access.log'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('mobile-workspace-search-field')),
      'access',
    );
    await tester.pumpAndSettle();

    expect(find.text('release.zip'), findsNothing);
    expect(find.text('access.log'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('mobile-workspace-search-field')),
      'missing',
    );
    await tester.pumpAndSettle();

    expect(find.text('No Matches'), findsOneWidget);
    expect(
      find.text('No transfer tasks match the current workspace search.'),
      findsOneWidget,
    );
    expect(find.text('release.zip'), findsNothing);
    expect(find.text('access.log'), findsNothing);
  });
}

class _CompletingSftpConnection implements SftpConnection {
  @override
  Future<void> get done => Future.value();

  @override
  Future<void> chmod(String path, SftpPermissions permissions) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteDirectory(String path, {required bool recursive}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFile(String path) async {
    throw UnimplementedError();
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
        transferredBytes: 1024,
        totalBytes: 1024,
      ),
    );
  }

  @override
  Future<List<SftpEntry>> list(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<void> mkdir(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<SftpFilePreview> readTextPreview(
    String path, {
    int maxBytes = defaultSftpPreviewBytes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> rename(String oldPath, String newPath) async {
    throw UnimplementedError();
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
        transferredBytes: 1024,
        totalBytes: 1024,
      ),
    );
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    throw UnimplementedError();
  }
}
