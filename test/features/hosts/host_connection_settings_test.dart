import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/hosts/domain/host.dart';

void main() {
  test('new and legacy missing connection settings allow three retries', () {
    expect(const HostConnectionSettings().reconnectAttempts, 3);
    expect(HostConnectionSettings.fromJson({}).reconnectAttempts, 3);
  });

  test('round trip preserves explicit disabled and customized reconnect', () {
    for (final attempts in [0, 2, 10]) {
      final settings = HostConnectionSettings(reconnectAttempts: attempts);
      expect(HostConnectionSettings.fromJson(settings.toJson()), settings);
    }
  });
}
