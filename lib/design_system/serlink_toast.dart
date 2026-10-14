import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_forui.dart';
import 'serlink_primitives.dart';

const double _snackBarMargin = 16;
const double _snackBarCloseButtonSize = 22;
const Duration _snackBarFadeInDuration = Duration(milliseconds: 180);
const Duration _snackBarFadeOutDuration = Duration(milliseconds: 140);
const Duration _snackBarDisplayDuration = Duration(seconds: 4);

_OverlayToastHandle? _activeToast;

/// Remove Chinese sentence endings only; keep internal punctuation, ellipses,
/// file names and URLs intact. Other languages retain their punctuation.
String formatSerlinkToastMessage(
  String message, {
  required String languageCode,
}) {
  return languageCode.startsWith('zh')
      ? message.trimRight().replaceFirst(RegExp(r'[。．｡]+$'), '')
      : message;
}

/// Natural text width including the rendered font and text scale. The maximum
/// is a readable line length, never a fixed toast width; narrower overlays cap
/// the message to their own available space and let it wrap.
void showSerlinkToast(
  BuildContext context,
  String message, {
  required String closeLabel,
  Duration duration = _snackBarDisplayDuration,
  double bottomReservedHeight = 0,
}) {
  final displayMessage = formatSerlinkToastMessage(
    message,
    languageCode: Localizations.localeOf(context).languageCode,
  );
  late final OverlayEntry entry;
  late final _OverlayToastHandle handle;
  _activeToast?.dismissImmediately();
  entry = OverlayEntry(
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final left = _snackBarMargin + media.viewPadding.left;
        final right = _snackBarMargin + media.viewPadding.right;
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - left - right,
        );
        final bottom =
            _snackBarMargin +
            math.max(
              bottomReservedHeight,
              math.max(media.viewPadding.bottom, media.viewInsets.bottom),
            );
        return Stack(
          children: [
            Positioned(
              right: right,
              bottom: bottom,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.min(640, availableWidth),
                ),
                child: IntrinsicWidth(
                  child: _OverlayToast(
                    message: displayMessage,
                    messageStyle: TextStyle(color: context.tokens.textPrimary),
                    duration: duration,
                    closeTooltip: closeLabel,
                    onDismissed: () {
                      handle.dismissImmediately();
                      if (identical(_activeToast, handle)) _activeToast = null;
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  handle = _OverlayToastHandle(entry);
  _activeToast = handle;
  Overlay.of(context).insert(entry);
}

class _OverlayToastHandle {
  _OverlayToastHandle(this.entry);

  final OverlayEntry entry;
  bool _removed = false;

  void dismissImmediately() {
    if (_removed) {
      return;
    }
    _removed = true;
    entry.remove();
    entry.dispose();
  }
}

class _OverlayToast extends StatefulWidget {
  const _OverlayToast({
    required this.message,
    required this.messageStyle,
    required this.duration,
    required this.closeTooltip,
    required this.onDismissed,
  });

  final String message;
  final TextStyle messageStyle;
  final Duration duration;
  final String closeTooltip;
  final VoidCallback onDismissed;

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _snackBarFadeInDuration,
    reverseDuration: _snackBarFadeOutDuration,
  );
  Timer? _autoDismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _autoDismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_dismissing || !mounted) {
      return;
    }
    _dismissing = true;
    _autoDismissTimer?.cancel();
    unawaited(
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onDismissed();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // The toast floats above dialogs in the root overlay, so the visual layer
    // must not absorb pointer events meant for the content behind it; only the
    // close button is hit-testable.
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      child: Stack(
        children: [
          IgnorePointer(
            child: Material(
              key: const ValueKey('app-toast'),
              elevation: 8,
              color: t.surfaceRaised,
              borderRadius: SerlinkRadii.dialog,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  borderRadius: SerlinkRadii.dialog,
                  border: Border.all(color: t.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.message, style: widget.messageStyle),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox.square(dimension: _snackBarCloseButtonSize),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SnackBarCloseButton(
                tooltip: widget.closeTooltip,
                onPressed: _dismiss,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
