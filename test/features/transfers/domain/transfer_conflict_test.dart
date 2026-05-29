import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/transfers/domain/transfer_conflict.dart';

void main() {
  test('generates stable remote rename candidates before extension', () {
    final next = nextRemoteConflictPath('/srv/app/config.env', {
      '/srv/app/config.env',
      '/srv/app/config copy.env',
    });

    expect(next, '/srv/app/config copy 2.env');
  });

  test('generates remote folder rename candidates', () {
    final next = nextRemoteConflictPath('/srv/app/releases', {
      '/srv/app/releases',
      '/srv/app/releases copy',
      '/srv/app/releases copy 2',
    });

    expect(next, '/srv/app/releases copy 3');
  });
}
