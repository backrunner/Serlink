import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/logging/redactor.dart';

abstract interface class TelemetryService {
  Future<void> captureException(Object error, StackTrace stackTrace);
  Future<void> captureMessage(String message);
}

class SentryTelemetryService implements TelemetryService {
  const SentryTelemetryService();

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) {
    return Sentry.captureException(error, stackTrace: stackTrace);
  }

  @override
  Future<void> captureMessage(String message) {
    return Sentry.captureMessage(Redactor.redact(message));
  }
}
