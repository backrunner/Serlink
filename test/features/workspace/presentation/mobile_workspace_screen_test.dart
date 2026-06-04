import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/app/serlink_app.dart';
import 'package:serlink/database/serlink_database.dart';
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
}
