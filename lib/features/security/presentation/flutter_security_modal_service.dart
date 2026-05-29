import 'package:flutter/material.dart';

import '../../ssh/application/ssh_session_service.dart';
import '../../sync/domain/webdav_tls_certificate_details.dart';
import '../application/security_modal_service.dart';

class FlutterSecurityModalService implements SecurityModalService {
  const FlutterSecurityModalService({required GlobalKey<NavigatorState> key})
    : this._(key);

  const FlutterSecurityModalService._(this._key);

  final GlobalKey<NavigatorState> _key;

  @override
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt) async {
    final context = _key.currentContext;
    if (context == null) {
      return HostKeyDecision.cancel;
    }
    final decision = await showDialog<HostKeyDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HostKeyDialog(prompt: prompt),
    );
    return decision ?? HostKeyDecision.cancel;
  }

  @override
  Future<CertificateTrustDecision> confirmWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  ) async {
    final context = _key.currentContext;
    if (context == null) {
      return CertificateTrustDecision.cancel;
    }
    final decision = await showDialog<CertificateTrustDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WebDavCertificateDialog(certificate: certificate),
    );
    return decision ?? CertificateTrustDecision.cancel;
  }

  @override
  Future<DestructiveDecision> confirmDestructiveAction(String title) async {
    final context = _key.currentContext;
    if (context == null) {
      return DestructiveDecision.cancel;
    }
    final decision = await showDialog<DestructiveDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DestructiveActionDialog(title: title),
    );
    return decision ?? DestructiveDecision.cancel;
  }

  @override
  Future<ExportDecision> confirmExport(ExportPreview preview) async {
    final context = _key.currentContext;
    if (context == null) {
      return ExportDecision.cancel;
    }
    final decision = await showDialog<ExportDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportDialog(preview: preview),
    );
    return decision ?? ExportDecision.cancel;
  }

  @override
  Future<bool> confirmMultilinePaste(String preview) async {
    final context = _key.currentContext;
    if (context == null) {
      return false;
    }
    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MultilinePasteDialog(preview: preview),
    );
    return decision ?? false;
  }
}

class _WebDavCertificateDialog extends StatelessWidget {
  const _WebDavCertificateDialog({required this.certificate});

  final WebDavTlsCertificateDetails certificate;

  @override
  Widget build(BuildContext context) {
    final changed =
        certificate.expectedFingerprint != null &&
        certificate.expectedFingerprint != certificate.fingerprint;
    return AlertDialog(
      title: Text(
        changed ? 'WebDAV Certificate Changed' : 'Trust WebDAV Certificate?',
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(certificate.endpoint.toString()),
            const SizedBox(height: 12),
            Text('Algorithm: ${certificate.algorithm}'),
            const SizedBox(height: 8),
            SelectableText(certificate.fingerprint),
            if (certificate.expectedFingerprint != null) ...[
              const SizedBox(height: 12),
              Text('Previous: ${certificate.expectedFingerprint}'),
            ],
            const SizedBox(height: 12),
            Text('Subject: ${certificate.subject}'),
            const SizedBox(height: 8),
            Text('Issuer: ${certificate.issuer}'),
            const SizedBox(height: 8),
            Text(
              'Valid: ${_shortUtc(certificate.validFrom)} to ${_shortUtc(certificate.validUntil)}',
            ),
            if (certificate.requiresClockReview) ...[
              const SizedBox(height: 12),
              const Text(
                'This certificate is not valid yet. Check this device clock before trusting it.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(CertificateTrustDecision.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(CertificateTrustDecision.trustAndSave),
          child: const Text('Trust and Save'),
        ),
      ],
    );
  }
}

class _HostKeyDialog extends StatelessWidget {
  const _HostKeyDialog({required this.prompt});

  final HostKeyPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final changed = prompt.previousFingerprint != null;
    return AlertDialog(
      title: Text(changed ? 'Host Key Changed' : 'Confirm Fingerprint'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${prompt.hostname}:${prompt.port}'),
            const SizedBox(height: 12),
            Text('Algorithm: ${prompt.algorithm}'),
            const SizedBox(height: 8),
            SelectableText(prompt.fingerprint),
            if (prompt.previousFingerprint != null) ...[
              const SizedBox(height: 12),
              Text('Previous: ${prompt.previousFingerprint}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(HostKeyDecision.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(HostKeyDecision.trustOnce),
          child: const Text('Trust Once'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(HostKeyDecision.trustAndSave),
          child: const Text('Trust and Save'),
        ),
      ],
    );
  }
}

String _shortUtc(DateTime value) {
  return value.toUtc().toIso8601String().split('.').first;
}

class _ExportDialog extends StatelessWidget {
  const _ExportDialog({required this.preview});

  final ExportPreview preview;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(preview.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preview.encrypted ? 'Encrypted export' : 'Unencrypted export'),
            if (preview.sensitiveFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Sensitive fields: ${preview.sensitiveFields.join(', ')}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ExportDecision.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ExportDecision.confirm),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _DestructiveActionDialog extends StatelessWidget {
  const _DestructiveActionDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DestructiveDecision.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(DestructiveDecision.confirm),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _MultilinePasteDialog extends StatelessWidget {
  const _MultilinePasteDialog({required this.preview});

  final String preview;

  @override
  Widget build(BuildContext context) {
    final lineCount = preview.split('\n').length;
    return AlertDialog(
      title: const Text('Paste multiple lines?'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$lineCount lines will be sent to the active terminal.'),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Paste'),
        ),
      ],
    );
  }
}
