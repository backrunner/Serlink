enum FailureSeverity { info, warning, recoverable, fatal }

class AppFailure {
  const AppFailure({
    required this.code,
    required this.message,
    this.diagnostic,
    this.severity = FailureSeverity.recoverable,
  });

  final String code;
  final String message;
  final String? diagnostic;
  final FailureSeverity severity;
}
