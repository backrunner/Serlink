import 'dart:async';

/// Request lifetime shared by the transport, approval UI and execution path.
/// Zone-local storage keeps concurrent MCP calls isolated without adding
/// transport parameters to every security dialog implementation.
class McpRequestContext {
  McpRequestContext({this.onWaiting, this.onApprovalFinished});

  static final _zoneKey = Object();
  static McpRequestContext? get current =>
      Zone.current[_zoneKey] as McpRequestContext?;

  final void Function()? onWaiting;
  final void Function()? onApprovalFinished;
  final Completer<void> _cancelled = Completer<void>();
  String? _reason;
  void Function()? validate;
  Future<void> get cancelled => _cancelled.future;

  void cancel([String reason = 'request_cancelled']) {
    if (_reason != null) return;
    _reason = reason;
    _cancelled.complete();
  }

  void checkActive() {
    if (_reason case final reason?) throw McpApprovalException(reason);
    validate?.call();
  }

  Future<T> run<T>(Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {_zoneKey: this});
}

class McpApprovalException implements Exception {
  const McpApprovalException(this.code);
  final String code;
  @override
  String toString() => code;
}
