import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/l10n.dart';
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
    final decision = await showSerlinkDialog<HostKeyDecision>(
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
    final decision = await showSerlinkDialog<CertificateTrustDecision>(
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
    final decision = await showSerlinkDialog<DestructiveDecision>(
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
    final decision = await showSerlinkDialog<ExportDecision>(
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
    final decision = await showSerlinkDialog<bool>(
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
    final l10n = context.l10n;
    final changed =
        certificate.expectedFingerprint != null &&
        certificate.expectedFingerprint != certificate.fingerprint;
    return SerlinkDialog(
      title: Text(
        changed
            ? l10n.securityWebDavCertificateChangedTitle
            : l10n.securityTrustWebDavCertificateTitle,
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(certificate.endpoint.toString()),
            const SizedBox(height: 12),
            Text(l10n.securityAlgorithmLabel(certificate.algorithm)),
            const SizedBox(height: 8),
            SelectableText(certificate.fingerprint),
            if (certificate.expectedFingerprint != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.securityPreviousLabel(certificate.expectedFingerprint!),
              ),
            ],
            const SizedBox(height: 12),
            Text(l10n.securitySubjectLabel(certificate.subject)),
            const SizedBox(height: 8),
            Text(l10n.securityIssuerLabel(certificate.issuer)),
            const SizedBox(height: 8),
            Text(
              l10n.securityValidRangeLabel(
                _shortUtc(certificate.validFrom),
                _shortUtc(certificate.validUntil),
              ),
            ),
            if (certificate.requiresClockReview) ...[
              const SizedBox(height: 12),
              Text(l10n.securityCertificateClockWarning),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () =>
              Navigator.of(context).pop(CertificateTrustDecision.cancel),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: () =>
              Navigator.of(context).pop(CertificateTrustDecision.trustAndSave),
          child: Text(l10n.securityTrustAndSaveAction),
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
    final l10n = context.l10n;
    final changed = prompt.previousFingerprint != null;
    return SerlinkDialog(
      title: Text(
        changed
            ? l10n.securityHostKeyChangedTitle
            : l10n.securityConfirmFingerprintTitle,
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${prompt.hostname}:${prompt.port}'),
            const SizedBox(height: 12),
            Text(l10n.securityAlgorithmLabel(prompt.algorithm)),
            const SizedBox(height: 8),
            SelectableText(prompt.fingerprint),
            if (prompt.previousFingerprint != null) ...[
              const SizedBox(height: 12),
              Text(l10n.securityPreviousLabel(prompt.previousFingerprint!)),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(HostKeyDecision.cancel),
          child: Text(l10n.cancelAction),
        ),
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(HostKeyDecision.trustOnce),
          child: Text(l10n.securityTrustOnceAction),
        ),
        SerlinkFilledButton(
          onPressed: () =>
              Navigator.of(context).pop(HostKeyDecision.trustAndSave),
          child: Text(l10n.securityTrustAndSaveAction),
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
    final l10n = context.l10n;
    return SerlinkDialog(
      title: Text(preview.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.encrypted
                  ? l10n.securityEncryptedExport
                  : l10n.securityUnencryptedExport,
            ),
            if (preview.sensitiveFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.securitySensitiveFields(
                  preview.sensitiveFields.join(', '),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(ExportDecision.cancel),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(ExportDecision.confirm),
          child: Text(l10n.settingsExportAction),
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
    final l10n = context.l10n;
    return SerlinkDialog(
      title: Text(title),
      content: Text(l10n.securityCannotBeUndone),
      actions: [
        SerlinkTextButton(
          onPressed: () =>
              Navigator.of(context).pop(DestructiveDecision.cancel),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: () =>
              Navigator.of(context).pop(DestructiveDecision.confirm),
          child: Text(l10n.confirmAction),
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
    final l10n = context.l10n;
    final lineCount = preview.split('\n').length;
    return SerlinkDialog(
      title: Text(l10n.securityPasteMultipleLinesTitle),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.securityPasteMultipleLinesBody(lineCount)),
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
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.pasteAction),
        ),
      ],
    );
  }
}
