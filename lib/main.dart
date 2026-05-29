import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app_dependencies.dart';
import 'app/serlink_app.dart';
import 'core/logging/redactor.dart';
import 'features/transfers/application/transfer_task_repository.dart';
import 'features/transfers/data/encrypted_transfer_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
        withScope: (scope) {
          scope.setTag('source', 'flutter');
        },
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('source', 'platform_dispatcher');
        },
      ),
    );
    return true;
  };

  final app = ProviderScope(
    overrides: [
      transferTaskRepositoryProvider.overrideWith((ref) {
        return EncryptedTransferTaskRepository(
          vault: ref.watch(vaultServiceProvider),
          records: ref.watch(vaultRecordRepositoryProvider),
        );
      }),
    ],
    child: const SerlinkApp(),
  );
  const dsn = String.fromEnvironment('SENTRY_DSN');
  final tracesSampleRate =
      double.tryParse(
        const String.fromEnvironment(
          'SENTRY_TRACES_SAMPLE_RATE',
          defaultValue: '0.1',
        ),
      ) ??
      0.1;

  if (dsn.isEmpty) {
    runZonedGuarded(() => runApp(app), (error, stack) {
      debugPrint('Unhandled error: ${Redactor.redact(error.toString())}');
    });
    return;
  }

  await SentryFlutter.init(
    (options) {
      options
        ..dsn = dsn
        ..tracesSampleRate = tracesSampleRate
        ..sendDefaultPii = false
        ..beforeSend = (event, hint) async => Redactor.redactSentryEvent(event);
    },
    appRunner: () {
      runZonedGuarded(() => runApp(app), (error, stack) {
        unawaited(Sentry.captureException(error, stackTrace: stack));
      });
    },
  );
}
