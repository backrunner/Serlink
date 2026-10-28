import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../mcp/application/mcp_approval_notifications.dart';
import '../../mcp/application/mcp_request_context.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/l10n.dart';
import '../../snippets/presentation/shell_code_controller.dart';
import '../../ssh/application/ssh_session_service.dart';
import '../../sync/domain/webdav_tls_certificate_details.dart';
import '../application/security_modal_service.dart';

final _notificationControls = RegExp(
  r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]',
);

const double _securityDialogHorizontalPadding = 24;
const double _hostKeyDialogMaxWidth = 520;
const double _hostKeyDialogContentWidth =
    _hostKeyDialogMaxWidth - (_securityDialogHorizontalPadding * 2);
const double _certificateDialogMaxWidth = 608;
const double _certificateDialogContentWidth =
    _certificateDialogMaxWidth - (_securityDialogHorizontalPadding * 2);

class FlutterSecurityModalService implements SecurityModalService {
  FlutterSecurityModalService({
    required GlobalKey<NavigatorState> key,
    this.notifications = const McpApprovalNotifications(),
    this.approvalTimeout = const Duration(seconds: 60),
    // Public named parameters cannot initialize a private field directly.
    // ignore: prefer_initializing_formals
  }) : _key = key;

  final GlobalKey<NavigatorState> _key;
  final McpApprovalNotifications notifications;
  final Duration approvalTimeout;
  Future<void> _approvalQueue = Future<void>.value();

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

  @override
  Future<AgentAccessDecision> confirmAgentAccess(
    AgentAccessPrompt prompt,
  ) async {
    final context = _key.currentContext;
    if (context == null) {
      return AgentAccessDecision.deny;
    }
    final l10n = context.l10n;
    return _confirmAgent(
      context: context,
      builder: (context) => _AgentAccessDialog(prompt: prompt),
      denied: AgentAccessDecision.deny,
      allowed: AgentAccessDecision.allow,
      title: prompt.discoveryStrict != null
          ? l10n.securityAgentDiscoveryTitle
          : l10n.securityAgentAccessTitle,
      body: _agentAccessDescription(l10n, prompt),
      // Data-sharing scopes need the complete disclosure in the app. Alerts
      // still offer Deny / View details; short command approvals remain direct.
      directApproval: false,
    );
  }

  @override
  Future<AgentCommandDecision> confirmAgentCommand(
    AgentCommandPrompt prompt,
  ) async {
    final context = _key.currentContext;
    if (context == null) return AgentCommandDecision.deny;
    final l10n = context.l10n;
    final direct =
        prompt.command.length <= 80 &&
        !_notificationControls.hasMatch(
          '${prompt.command}${prompt.clientName}${prompt.hostDisplayName}',
        ) &&
        prompt.clientName.length + prompt.hostDisplayName.length < 60;
    return _confirmAgent(
      context: context,
      builder: (context) => _AgentCommandDialog(prompt: prompt),
      denied: AgentCommandDecision.deny,
      allowed: AgentCommandDecision.allowOnce,
      title: l10n.securityAgentCommandTitle,
      body:
          '${l10n.securityAgentCommandBody(prompt.clientName, prompt.hostDisplayName)}\n${direct ? prompt.command : l10n.mcpApprovalReviewDetails}',
      directApproval: direct,
    );
  }

  Future<T> _confirmAgent<T extends Object>({
    required BuildContext context,
    required WidgetBuilder builder,
    required T denied,
    required T allowed,
    required String title,
    required String body,
    required bool directApproval,
  }) async {
    final request = McpRequestContext.current;
    request?.checkActive();
    final result = Completer<T>();
    final id = const Uuid().v4();
    FDialogRoute<T>? route;
    void fail(String code) {
      if (!result.isCompleted) result.completeError(McpApprovalException(code));
    }

    final timer = Timer(approvalTimeout, () => fail('approval_timeout'));
    unawaited(request?.cancelled.then((_) => fail('request_cancelled')));
    final validityTimer = request == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 200), (_) {
            if (result.isCompleted) return;
            try {
              request.checkActive();
            } on Object catch (error, stack) {
              result.completeError(error, stack);
            }
          });
    request?.onWaiting?.call();
    // One active approval at a time: notification details always point to the
    // matching dialog. Queued requests share the same bounded waiting period.
    final previous = _approvalQueue;
    _approvalQueue = previous.then(
      (_) => result.future.then<void>((_) {}, onError: (Object _) {}),
    );
    unawaited(
      previous
          .then((_) async {
            if (result.isCompleted) return;
            if (!context.mounted) {
              fail('request_cancelled');
              return;
            }
            final navigator = Navigator.of(context);
            if (!navigator.mounted) {
              fail('request_cancelled');
              return;
            }
            final l10n = context.l10n;
            route = FDialogRoute<T>(
              style: context.theme.dialogRouteStyle,
              capturedThemes: InheritedTheme.capture(
                from: context,
                to: navigator.context,
              ),
              capturedFTheme: FTheme.capture(
                from: context,
                to: navigator.context,
              ),
              barrierDismissible: false,
              barrierLabel: l10n.denyAction,
              useSafeArea: false,
              builder: (context, animation) => builder(context),
            );
            unawaited(
              navigator.push(route!).then((value) {
                if (!result.isCompleted) result.complete(value ?? denied);
              }),
            );
            final action = await notifications.show({
              'id': id,
              'title': title,
              'body': body,
              'allow': l10n.allowAction,
              'deny': l10n.denyAction,
              'details': l10n.mcpApprovalDetailsAction,
              'directApproval': directApproval,
              'timeoutMs': approvalTimeout.inMilliseconds,
            });
            if (result.isCompleted) return;
            if (action == 'allow' && directApproval) result.complete(allowed);
            if (action == 'deny') result.complete(denied);
            // Details opens the app; unsupported/denied notifications leave the
            // dialog usable until its existing deadline.
          })
          .catchError((Object error, StackTrace stack) {
            if (!result.isCompleted) result.completeError(error, stack);
          }),
    );
    try {
      final value = await result.future;
      request?.checkActive();
      return value;
    } finally {
      timer.cancel();
      validityTimer?.cancel();
      request?.onApprovalFinished?.call();
      final activeRoute = route;
      if (activeRoute != null && activeRoute.isActive) {
        activeRoute.navigator?.removeRoute(activeRoute);
      }
      unawaited(notifications.dismiss(id));
    }
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
      maxWidth: _certificateDialogMaxWidth,
      title: Text(
        changed
            ? l10n.securityWebDavCertificateChangedTitle
            : l10n.securityTrustWebDavCertificateTitle,
      ),
      content: SerlinkScrollView(
        child: SizedBox(
          width: _certificateDialogContentWidth,
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
      maxWidth: _hostKeyDialogMaxWidth,
      title: Text(
        changed
            ? l10n.securityHostKeyChangedTitle
            : l10n.securityConfirmFingerprintTitle,
      ),
      content: SerlinkScrollView(
        child: SizedBox(
          width: _hostKeyDialogContentWidth,
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
      content: SerlinkScrollView(
        child: SizedBox(
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
        SerlinkFilledButton.danger(
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
    final codeController = ShellCodeController(text: preview);
    final code = codeController.buildTextSpan(
      context: context,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.6,
        color: context.tokens.textPrimary,
      ),
      withComposing: false,
    );
    codeController.dispose();
    return SerlinkDialog(
      title: Text(l10n.securityPasteMultipleLinesTitle),
      content: SerlinkScrollView(
        child: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.securityPasteMultipleLinesBody(lineCount)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.tokens.surfaceSunken,
                  borderRadius: SerlinkRadii.control,
                ),
                child: SerlinkScrollView(
                  padding: const EdgeInsets.all(SerlinkSpacing.md),
                  child: SelectableText.rich(
                    code,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
          ),
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

String _agentAccessDescription(
  AppLocalizations l10n,
  AgentAccessPrompt prompt,
) {
  final strict = prompt.discoveryStrict;
  if (strict != null) {
    return '${l10n.securityAgentDiscoveryBody(prompt.clientName)}\n\n'
        '${strict ? l10n.securityAgentDiscoveryStrict : l10n.securityAgentDiscoveryFull}\n\n'
        '${l10n.securityAgentSharingWarning}';
  }
  if (prompt.existingSessionId != null) {
    return '${l10n.securityAgentAttachBody(prompt.clientName, prompt.hostDisplayName)}\n\n'
        '${l10n.securityAgentAttachWarning}\n\n${l10n.securityAgentSharingWarning}';
  }
  return '${l10n.securityAgentAccessBody(prompt.clientName, prompt.hostDisplayName)}\n\n'
      '${l10n.securityAgentAccessWarning}\n\n${l10n.securityAgentSharingWarning}';
}

class _AgentAccessDialog extends StatelessWidget {
  const _AgentAccessDialog({required this.prompt});

  final AgentAccessPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _hostKeyDialogMaxWidth,
      title: Text(
        prompt.discoveryStrict != null
            ? l10n.securityAgentDiscoveryTitle
            : l10n.securityAgentAccessTitle,
      ),
      content: SerlinkScrollView(
        child: SizedBox(
          width: _hostKeyDialogContentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_agentAccessDescription(l10n, prompt)),
              if (prompt.hostId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.securityAgentAccessHostIdLabel(prompt.hostId)),
              ],
              if (prompt.existingSessionId case final id?) ...[
                const SizedBox(height: 8),
                Text(l10n.securityAgentSessionIdLabel(id)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(AgentAccessDecision.deny),
          child: Text(l10n.denyAction),
        ),
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(AgentAccessDecision.allow),
          child: Text(l10n.allowAction),
        ),
      ],
    );
  }
}

class _AgentCommandDialog extends StatelessWidget {
  const _AgentCommandDialog({required this.prompt});

  final AgentCommandPrompt prompt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final codeController = ShellCodeController(text: prompt.command);
    final code = codeController.buildTextSpan(
      context: context,
      style: TextStyle(
        fontFamily: 'JetBrainsMono Nerd Font Mono',
        fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
        fontSize: 13,
        height: 1.6,
        color: context.tokens.textPrimary,
      ),
      withComposing: false,
    );
    codeController.dispose();
    return SerlinkDialog(
      maxWidth: _hostKeyDialogMaxWidth,
      title: Text(l10n.securityAgentCommandTitle),
      content: SerlinkScrollView(
        child: SizedBox(
          width: _hostKeyDialogContentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.securityAgentCommandBody(
                  prompt.clientName,
                  prompt.hostDisplayName,
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.securityAgentCommandRuleLabel(prompt.ruleDescription)),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('agent-command-code-block'),
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.tokens.surfaceSunken,
                  border: Border.all(color: context.tokens.borderSubtle),
                  borderRadius: SerlinkRadii.control,
                ),
                child: SerlinkScrollView(
                  padding: const EdgeInsets.all(SerlinkSpacing.md),
                  child: SelectableText.rich(
                    code,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(AgentCommandDecision.deny),
          child: Text(l10n.denyAction),
        ),
        SerlinkTextButton(
          onPressed: () =>
              Navigator.of(context).pop(AgentCommandDecision.allowOnce),
          child: Text(l10n.securityAgentAllowOnceAction),
        ),
        SerlinkFilledButton(
          onPressed: () =>
              Navigator.of(context).pop(AgentCommandDecision.allowSession),
          child: Text(l10n.securityAgentAllowSessionAction),
        ),
      ],
    );
  }
}
