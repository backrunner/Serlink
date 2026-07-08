abstract interface class TelemetryService {
  Future<void> captureException(Object error, StackTrace stackTrace);
  Future<void> captureMessage(String message);
}

class DisabledTelemetryService implements TelemetryService {
  const DisabledTelemetryService();

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) {
    return Future<void>.value();
  }

  @override
  Future<void> captureMessage(String message) {
    return Future<void>.value();
  }
}
