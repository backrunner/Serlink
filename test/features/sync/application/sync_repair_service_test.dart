import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/sync/application/sync_repair_service.dart';
import 'package:serlink/features/sync/application/sync_run_service.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';

void main() {
  group('SyncRepairService', () {
    const service = SyncRepairService(sync: _NoopSyncRunService());

    test('offers initialization for missing remote manifest', () {
      final plan = service.planFor(
        const SyncRunException(
          'sync.remote_manifest_missing',
          'Remote sync manifest is missing.',
        ),
      );

      expect(plan?.action, SyncRepairAction.initializeEmptyRemote);
      expect(plan?.destructive, isFalse);
    });

    test('offers destructive rebuild for wrong remote vault', () {
      final plan = service.planFor(
        const SyncRunException(
          'sync.remote_manifest_wrong_vault',
          'Remote sync data belongs to another vault.',
        ),
      );

      expect(plan?.action, SyncRepairAction.rebuildRemoteFromLocal);
      expect(plan?.destructive, isTrue);
    });

    test('offers certificate trust for untrusted WebDAV certificate', () {
      final details = WebDavTlsCertificateDetails(
        endpoint: Uri.parse('https://dav.example.test'),
        fingerprint: 'SHA256:abc',
        algorithm: 'SHA256',
        subject: 'CN=dav.example.test',
        issuer: 'CN=Local CA',
        validFrom: DateTime.utc(2026),
        validUntil: DateTime.utc(2027),
        reason: 'untrusted',
      );

      final plan = service.planFor(
        SyncProviderException(
          'sync.provider.tls_certificate_failed',
          'WebDAV TLS certificate is untrusted.',
          diagnostic: details.toDiagnosticJson(),
        ),
      );

      expect(plan?.action, SyncRepairAction.trustWebDavCertificate);
      expect(plan?.destructive, isFalse);
    });

    test('offers clock review for not-yet-valid WebDAV certificate', () {
      final details = WebDavTlsCertificateDetails(
        endpoint: Uri.parse('https://dav.example.test'),
        fingerprint: 'SHA256:abc',
        algorithm: 'SHA256',
        subject: 'CN=dav.example.test',
        issuer: 'CN=Local CA',
        validFrom: DateTime.utc(2027),
        validUntil: DateTime.utc(2028),
        reason: 'not_yet_valid',
      );

      final plan = service.planFor(
        SyncProviderException(
          'sync.provider.tls_certificate_failed',
          'WebDAV TLS certificate is not valid yet.',
          diagnostic: details.toDiagnosticJson(),
        ),
      );

      expect(plan?.action, SyncRepairAction.reviewLocalClock);
      expect(plan?.destructive, isFalse);
      expect(plan?.message, contains('clock'));
    });

    test('ignores unrelated sync failures', () {
      final plan = service.planFor(
        const SyncRunException('sync.vault_locked', 'Unlock the vault.'),
      );

      expect(plan, isNull);
    });

    test('offers local restore when local data blocks remote rebuild', () {
      final plan = service.planFor(
        const SyncRunException(
          'sync.local_unhealthy',
          'Local vault data needs recovery before rebuilding remote sync.',
        ),
      );

      expect(plan?.action, SyncRepairAction.restoreLocalFromRemote);
      expect(plan?.destructive, isTrue);
    });
  });
}

class _NoopSyncRunService implements SyncRunService {
  const _NoopSyncRunService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
