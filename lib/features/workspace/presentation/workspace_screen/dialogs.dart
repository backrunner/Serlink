part of '../workspace_screen.dart';

const double _dialogWidthCompact = 420;
const double _dialogWidthPrompt = 480;
const double _dialogWidthSmall = 568;
const double _dialogWidthMedium = 608;
const double _dialogWidthDataExchange = 660;
const double _dialogWidthManagement = 688;
const double _dialogWidthWide = 728;
const double _dialogWidthReview = 868;

double _adaptiveDialogWidth(BuildContext context, double preferredWidth) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontalMargin = width < 600 ? 32.0 : 96.0;
  final availableWidth = math.max(288.0, width - horizontalMargin);
  return math.min(preferredWidth, availableWidth);
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showSerlinkDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return SerlinkDialog(
        maxWidth: _adaptiveDialogWidth(context, _dialogWidthPrompt),
        title: Text(title),
        content: destructive ? SerlinkAlert.danger(message: body) : Text(body),
        actions: [
          SerlinkTextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          if (destructive)
            SerlinkFilledButton.danger(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            )
          else
            SerlinkFilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<TransferConflictAction?> _showTransferConflictDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String replaceLabel,
}) {
  return showSerlinkDialog<TransferConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return SerlinkDialog(
        maxWidth: _adaptiveDialogWidth(context, _dialogWidthSmall),
        title: Text(title),
        content: SerlinkAlert.warning(message: body),
        actions: [
          SerlinkTextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.skip),
            child: Text(context.l10n.skipAction),
          ),
          SerlinkTextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.rename),
            child: Text(context.l10n.renameAction),
          ),
          SerlinkFilledButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.replace),
            child: Text(replaceLabel),
          ),
        ],
      );
    },
  );
}

String _backupErrorMessage(AppLocalizations l10n, Object error) {
  if (error is VaultException) {
    return localizedVaultExceptionMessage(l10n, error);
  }
  return l10n.backupOperationFailed;
}

String _diagnosticErrorMessage(AppLocalizations l10n, Object error) {
  return l10n.diagnosticExportFailed;
}

String _openSshConfigExportErrorMessage(AppLocalizations l10n, Object error) {
  return l10n.openSshConfigExportFailed;
}

String _identityMetadataExportErrorMessage(
  AppLocalizations l10n,
  Object error,
) {
  return l10n.identityMetadataExportFailed;
}

String _importErrorMessage(AppLocalizations l10n, Object error) {
  if (error is OpenSshConfigImportException) {
    return error.message;
  }
  if (error is OpenSshCertificateImportException) {
    return error.message;
  }
  if (error is VaultException) {
    return localizedVaultExceptionMessage(l10n, error);
  }
  return l10n.importFailed;
}

/// One entry rendered as a modern card row inside a management dialog.
class _DialogListItem {
  const _DialogListItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
}

/// Shared fixed-height content area for the Devices / Credentials / Known
/// hosts dialogs. The fixed height keeps the dialog from resizing as its
/// future resolves, which removes the empty -> content flash, and renders
/// rows as raised cards consistent with the hosts page.
class _DialogList extends StatelessWidget {
  const _DialogList({this.items, this.empty, this.loading = false});

  final List<_DialogListItem>? items;
  final _DialogState? empty;
  final bool loading;

  static const double _height = 360;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _height, child: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const _DialogStateView(loading: true);
    }
    final rows = items ?? const [];
    if (rows.isEmpty) {
      return _DialogStateView(state: empty);
    }
    return SerlinkScrollFade(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = rows[index];
          return EntranceFade(
            key: ValueKey('dialog-row-${item.title}-$index'),
            delay: Duration(milliseconds: 30 * (index.clamp(0, 8))),
            offsetY: 8,
            child: _DialogRow(item: item),
          );
        },
      ),
    );
  }
}

/// A form section whose surface stays distinct from the surrounding dialog.
class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceBase,
        borderRadius: SerlinkRadii.dialog,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: t.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 12), action!],
            ],
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 14), ...children],
        ],
      ),
    );
  }
}

class _DialogScrollFrame extends StatelessWidget {
  const _DialogScrollFrame({
    super.key,
    required this.width,
    required this.height,
    required this.controller,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.fillHeight = true,
  });

  final double width;
  final double height;
  final ScrollController controller;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Shrink to the content height unless it exceeds [height].
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final scrollView = Scrollbar(
      controller: controller,
      thickness: 4,
      radius: const Radius.circular(2),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SerlinkScrollView(
          controller: controller,
          physics: Theme.of(context).platform == TargetPlatform.iOS
              ? const BouncingScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: padding,
          child: child,
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: fillHeight ? height : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: scrollView,
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.item});

  final _DialogListItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.accentPrimary.withValues(alpha: 0.12),
              borderRadius: SerlinkRadii.control,
            ),
            child: Icon(item.icon, size: 18, color: t.accentPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                if (item.subtitle case final subtitle?) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: t.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.trailing case final trailing?) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// Empty-state descriptor for a management dialog.
class _DialogState {
  const _DialogState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Centered loading or empty view that fills the shared dialog height so the
/// dialog never resizes between states.
class _DialogStateView extends StatelessWidget {
  const _DialogStateView({this.state, this.loading = false});

  final _DialogState? state;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (loading) {
      return Center(
        child: SerlinkLoadingIndicator(
          semanticsLabel: context.l10n.loadingSemantics,
        ),
      );
    }
    final state = this.state;
    if (state == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: t.accentPrimary.withValues(alpha: 0.12),
                borderRadius: SerlinkRadii.control,
                border: Border.all(
                  color: t.accentPrimary.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(state.icon, size: 26, color: t.accentPrimary),
            ),
            const SizedBox(height: 14),
            Text(
              state.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              state.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

String? _defaultImportUsername() {
  final value =
      Platform.environment['USER'] ?? Platform.environment['USERNAME'];
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

const double _mobileBottomNavigationBaseHeight = 56;
const double _mobileBottomNavigationSafeAreaFraction = 2 / 3;

void _showSnackBar(BuildContext context, String message, {Duration? duration}) {
  showSerlinkToast(
    context,
    message,
    closeLabel: context.l10n.closeAction,
    duration: duration ?? const Duration(seconds: 4),
    bottomReservedHeight: _snackBarBottomReservedHeight(context),
  );
}

double _snackBarBottomReservedHeight(BuildContext context) {
  final hasMobileBottomNavigation =
      context.platformVariant.touch &&
      MediaQuery.sizeOf(context).width <
          MobileWorkspaceScreen._tabletBreakpoint;
  if (!hasMobileBottomNavigation) {
    return 0;
  }
  final bottomSafePadding =
      MediaQuery.viewPaddingOf(context).bottom *
      _mobileBottomNavigationSafeAreaFraction;
  return _mobileBottomNavigationBaseHeight + bottomSafePadding;
}

class _PlaceholderSurface extends StatelessWidget {
  const _PlaceholderSurface({
    required this.title,
    required this.body,
    this.icon,
    this.loading = false,
    this.action,
  });

  final String title;
  final String body;

  /// Optional semantic icon in a quiet, rounded tile above the empty state.
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SerlinkEmptyState(
      title: title,
      body: body,
      icon: icon,
      loading: loading,
      loadingLabel: context.l10n.loadingSemantics,
      action: action,
    );
  }
}

class _DynamicStatusText extends StatelessWidget {
  const _DynamicStatusText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: t.textSecondary);
    return Wrap(
      key: const ValueKey('dynamic-status-text'),
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(t.accentPrimary),
          ),
        ),
        Text(label, style: style),
      ],
    );
  }
}
