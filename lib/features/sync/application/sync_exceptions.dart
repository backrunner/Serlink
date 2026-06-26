class SyncRunException implements Exception {
  const SyncRunException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SyncRunException($code): $message';
}
