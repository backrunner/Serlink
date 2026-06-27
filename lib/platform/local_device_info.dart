import 'package:flutter/services.dart';

class LocalDeviceInfo {
  const LocalDeviceInfo({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('serlink/platform');

  final MethodChannel _channel;

  Future<String?> displayName() async {
    try {
      return _normalizeDeviceName(
        await _channel.invokeMethod<String>('displayName'),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

String? _normalizeDeviceName(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
