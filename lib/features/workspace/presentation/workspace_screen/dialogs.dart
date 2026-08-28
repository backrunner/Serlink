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
    return ListView.separated(
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
    );
  }
}

class _DialogScrollFrame extends StatefulWidget {
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

  /// When false the frame shrinks to the content height and only starts
  /// scrolling once the content exceeds [height].
  final bool fillHeight;

  @override
  State<_DialogScrollFrame> createState() => _DialogScrollFrameState();
}

class _DialogScrollFrameState extends State<_DialogScrollFrame> {
  bool _showTopFade = false;
  bool _showBottomFade = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant _DialogScrollFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateFades);
      widget.controller.addListener(_updateFades);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateFades);
    super.dispose();
  }

  void _updateFades() {
    if (!mounted || !widget.controller.hasClients) {
      return;
    }
    final position = widget.controller.position;
    final showTop = position.pixels > 0.5;
    final showBottom = position.pixels < position.maxScrollExtent - 0.5;
    if (showTop != _showTopFade || showBottom != _showBottomFade) {
      setState(() {
        _showTopFade = showTop;
        _showBottomFade = showBottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scrollView = ClipRect(
      child: Scrollbar(
        controller: widget.controller,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: widget.controller,
            physics: const ClampingScrollPhysics(),
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
    final framed = widget.fillHeight
        ? SizedBox(
            width: widget.width,
            height: widget.height,
            child: scrollView,
          )
        : SizedBox(
            width: widget.width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.height),
              child: scrollView,
            ),
          );
    return Stack(
      children: [
        framed,
        _ScrollFadeEdge(
          visible: _showTopFade,
          color: t.surfaceRaised,
          alignment: Alignment.topCenter,
        ),
        _ScrollFadeEdge(
          visible: _showBottomFade,
          color: t.surfaceRaised,
          alignment: Alignment.bottomCenter,
        ),
      ],
    );
  }
}

/// Soft gradient that fades scrolled-off content into the dialog background.
class _ScrollFadeEdge extends StatelessWidget {
  const _ScrollFadeEdge({
    required this.visible,
    required this.color,
    required this.alignment,
  });

  final bool visible;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final top = alignment == Alignment.topCenter;
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 8,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: t.textSecondary,
                height: 1.4,
              ),
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

const double _snackBarMaxWidth = 320;
const double _snackBarMargin = 16;
const double _snackBarCloseButtonSize = 22;
const double _mobileBottomNavigationBaseHeight = 56;

/// Fraction of the bottom safe-area inset reserved behind the mobile bottom
/// navigation bar. The bar already covers part of the gesture area visually,
/// so only two thirds of the inset is added on top of the bar height.
const double _mobileBottomNavigationSafeAreaFraction = 2 / 3;

void _showSnackBar(BuildContext context, String message) {
  final t = context.tokens;
  final l10n = context.l10n;
  final bottomMargin = _snackBarMargin + _snackBarBottomReservedHeight(context);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final availableWidth = math.max(0.0, screenWidth - (_snackBarMargin * 2));
  final snackBarWidth = math.min(_snackBarMaxWidth, availableWidth);
  final leftMargin = math.max(
    _snackBarMargin,
    screenWidth - snackBarWidth - _snackBarMargin,
  );
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          leftMargin,
          0,
          _snackBarMargin,
          bottomMargin,
        ),
        backgroundColor: t.surfaceRaised,
        elevation: 8,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        shape: RoundedRectangleBorder(
          borderRadius: SerlinkRadii.dialog,
          side: BorderSide(color: t.borderSubtle),
        ),
        content: Row(
          children: [
            Expanded(
              child: Text(message, style: TextStyle(color: t.textPrimary)),
            ),
            const SizedBox(width: 10),
            _SnackBarCloseButton(
              tooltip: l10n.closeAction,
              onPressed: () {
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.hide,
                );
              },
            ),
          ],
        ),
      ),
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

class _SnackBarCloseButton extends StatelessWidget {
  const _SnackBarCloseButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SerlinkTooltip(
      message: tooltip,
      child: SerlinkPressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        hoverColor: t.accentPrimary.withValues(alpha: 0.08),
        pressedColor: t.accentPrimary.withValues(alpha: 0.14),
        child: SizedBox.square(
          dimension: _snackBarCloseButtonSize,
          child: Icon(Icons.close, size: 12, color: t.textSecondary),
        ),
      ),
    );
  }
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

  /// Optional semantic icon; when present it renders in the same accent
  /// square used by `_DialogStateView` so both empty states share a layout.
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = this.icon;
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary, height: 1.4);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SerlinkLoadingIndicator(
                semanticsLabel: context.l10n.loadingSemantics,
              ),
              const SizedBox(height: 16),
            ],
            if (icon != null) ...[
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
                child: Icon(icon, size: 26, color: t.accentPrimary),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: bodyStyle),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class _DynamicStatusText extends StatelessWidget {
  const _DynamicStatusText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);
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
