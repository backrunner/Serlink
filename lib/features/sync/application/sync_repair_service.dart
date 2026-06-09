import '../domain/sync_provider.dart';
import '../domain/webdav_tls_certificate_details.dart';
import 'sync_run_service.dart';

enum SyncRepairAction {
  initializeEmptyRemote,
  rebuildRemoteFromLocal,
  restoreLocalFromRemote,
  trustWebDavCertificate,
  reviewLocalClock,
}

class SyncRepairPlan {
  const SyncRepairPlan({
    required this.action,
    required this.title,
    required this.message,
    required this.destructive,
  });

  final SyncRepairAction action;
  final String title;
  final String message;
  final bool destructive;
}

class SyncRepairService {
  const SyncRepairService({required SyncRunService sync});

  SyncRepairPlan? planFor(Object error) {
    if (error is! SyncRunException) {
      if (error is SyncProviderException) {
        final certificate = WebDavTlsCertificateDetails.tryParse(
          error.diagnostic,
        );
        if (error.code == 'sync.provider.tls_certificate_failed' &&
            certificate != null) {
          if (certificate.requiresClockReview) {
            return const SyncRepairPlan(
              action: SyncRepairAction.reviewLocalClock,
              title: 'Check local clock',
              message:
                  'The WebDAV certificate is not valid yet. Check this device clock and time zone, then let automatic sync retry.',
              destructive: false,
            );
          }
          return const SyncRepairPlan(
            action: SyncRepairAction.trustWebDavCertificate,
            title: 'Trust WebDAV certificate?',
            message:
                'The WebDAV server uses an untrusted certificate. Review the fingerprint before saving trust for this endpoint.',
            destructive: false,
          );
        }
        return switch (error.code) {
          'sync.provider.partial_upload' ||
          'sync.provider.not_found' ||
          'sync.provider.manifest_invalid' => const SyncRepairPlan(
            action: SyncRepairAction.rebuildRemoteFromLocal,
            title: 'Repair remote sync?',
            message:
                'The WebDAV sync path is missing or incomplete. Serlink can rebuild it from local encrypted records.',
            destructive: true,
          ),
          _ => null,
        };
      }
      return null;
    }
    return switch (error.code) {
      'sync.remote_manifest_missing' => const SyncRepairPlan(
        action: SyncRepairAction.initializeEmptyRemote,
        title: 'Initialize remote sync?',
        message:
            'The remote location has no Serlink manifest. Serlink can create one from this encrypted vault.',
        destructive: false,
      ),
      'sync.remote_manifest_wrong_vault' => const SyncRepairPlan(
        action: SyncRepairAction.rebuildRemoteFromLocal,
        title: 'Replace remote vault?',
        message:
            'The remote location belongs to another vault. Replacing it will overwrite that remote Serlink sync set with this encrypted vault.',
        destructive: true,
      ),
      'sync.remote_manifest_invalid' ||
      'sync.remote_manifest_mismatch' => const SyncRepairPlan(
        action: SyncRepairAction.rebuildRemoteFromLocal,
        title: 'Repair remote sync?',
        message:
            'The remote manifest or record objects are incomplete or corrupted. Serlink can rebuild them from local encrypted records.',
        destructive: true,
      ),
      'sync.local_unhealthy' => const SyncRepairPlan(
        action: SyncRepairAction.restoreLocalFromRemote,
        title: 'Restore local sync data?',
        message:
            'Local vault data needs recovery before remote sync can be rebuilt. Serlink can restore local encrypted records from the current remote sync set.',
        destructive: true,
      ),
      _ => null,
    };
  }
}

extension SyncRepairRun on SyncRunService {
  Future<SyncRunResult> runRepair(
    SyncProvider provider,
    SyncRepairAction action,
  ) {
    return switch (action) {
      SyncRepairAction.initializeEmptyRemote ||
      SyncRepairAction.rebuildRemoteFromLocal => pushEncryptedSnapshotForRepair(
        provider,
      ),
      SyncRepairAction.restoreLocalFromRemote =>
        restoreLocalFromRemoteForRepair(provider),
      SyncRepairAction.trustWebDavCertificate ||
      SyncRepairAction.reviewLocalClock => throw UnsupportedError(
        'Sync repair action ${action.name} must be handled by Settings.',
      ),
    };
  }
}
