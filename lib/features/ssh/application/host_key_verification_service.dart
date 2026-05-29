import 'known_host_repository.dart';
import 'ssh_session_service.dart';

abstract interface class HostKeyVerificationService {
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt);
}

class PersistingHostKeyVerificationService
    implements HostKeyVerificationService {
  PersistingHostKeyVerificationService({
    required KnownHostRepository knownHosts,
    required Future<HostKeyDecision> Function(HostKeyPrompt prompt)
    confirmUnknownHostKey,
  }) : this._(knownHosts, confirmUnknownHostKey);

  PersistingHostKeyVerificationService._(
    this._knownHosts,
    this._confirmUnknownHostKey,
  );

  final KnownHostRepository _knownHosts;
  final Future<HostKeyDecision> Function(HostKeyPrompt prompt)
  _confirmUnknownHostKey;

  @override
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt) async {
    final existing = await _knownHosts.read(prompt.hostId);
    if (existing != null &&
        existing.algorithm == prompt.algorithm &&
        existing.fingerprint == prompt.fingerprint) {
      return HostKeyDecision.trustAndSave;
    }

    final decision = await _confirmUnknownHostKey(
      existing == null
          ? prompt
          : prompt.copyWith(previousFingerprint: existing.fingerprint),
    );
    if (decision == HostKeyDecision.trustAndSave) {
      final now = DateTime.now().toUtc();
      await _knownHosts.save(
        KnownHostRecord(
          hostId: prompt.hostId,
          hostname: prompt.hostname,
          port: prompt.port,
          algorithm: prompt.algorithm,
          fingerprint: prompt.fingerprint,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    return decision;
  }
}
