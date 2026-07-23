import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/sync/application/sync_field_merge_service.dart';

void main() {
  test('host conflict exposes SSH config writeback choice', () {
    const service = SyncFieldMergeService();

    final fields = service.inspect(
      recordType: 'host',
      recordId: VaultRecordId('host:prod'),
      localJson: const {'writeBackToSshConfig': false},
      remoteJson: const {'writeBackToSshConfig': true},
    );

    expect(fields.supportsFieldMerge, isTrue);
    expect(fields.fields, hasLength(1));
    expect(fields.fields.single.key, 'writeBackToSshConfig');
    expect(fields.fields.single.localValue, isFalse);
    expect(fields.fields.single.remoteValue, isTrue);
  });
}
