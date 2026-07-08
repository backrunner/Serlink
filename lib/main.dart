import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_dependencies.dart';
import 'app/serlink_app.dart';
import 'features/transfers/application/transfer_task_repository.dart';
import 'features/transfers/data/encrypted_transfer_task_repository.dart';
import 'platform/app_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = ProviderScope(
    overrides: [
      transferTaskRepositoryProvider.overrideWith((ref) {
        return EncryptedTransferTaskRepository.lazy(
          // Avoid building a vault dependency while vault initialization is
          // restoring transfer history.
          vault: () =>
              ref.read(vaultSessionControllerProvider.notifier).service,
          records: ref.watch(vaultRecordRepositoryProvider),
        );
      }),
    ],
    child: const SerlinkApp(),
  );
  _runSerlinkApp(app);
}

void _runSerlinkApp(Widget app) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(AppWindow.activate());
  });
  runApp(app);
}
