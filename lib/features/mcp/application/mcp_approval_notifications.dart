import 'package:flutter/services.dart';

/// macOS local notifications. Missing platform support falls back to the
/// in-app approval dialog; notification delivery never grants permission.
class McpApprovalNotifications {
  const McpApprovalNotifications();
  static const _channel = MethodChannel('serlink/mcp-approvals');

  Future<String> status() async => await _invoke('status') ?? 'unavailable';
  Future<String> requestPermission() async =>
      await _invoke('requestPermission') ?? 'unavailable';
  Future<void> openSettings() async => _invoke('openSettings');

  Future<String?> show(Map<String, Object> request) => _invoke('show', request);
  Future<void> dismiss(String id) async => _invoke('dismiss', {'id': id});

  Future<String?> _invoke(String method, [Map<String, Object>? args]) async {
    try {
      return await _channel.invokeMethod<String>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
