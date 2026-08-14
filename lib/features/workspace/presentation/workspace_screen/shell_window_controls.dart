part of '../workspace_screen.dart';

var _windowCloseConfirmationInFlight = false;
var _windowTerminationConfirmed = false;

/// Shows the active-terminal confirmation dialog when terminal panes are
/// still running. Returns true when the close/termination may proceed, and
/// false when the user cancels or a confirmation is already in flight.
Future<bool> _confirmCloseWithActiveTerminals(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_windowCloseConfirmationInFlight) {
    return false;
  }
  final activeTerminalPaneCount = ref
      .read(workspaceTabControllerProvider)
      .activeTerminalPaneCount;
  if (activeTerminalPaneCount == 0) {
    return true;
  }

  _windowCloseConfirmationInFlight = true;
  try {
    final l10n = context.l10n;
    final confirmed = await _confirmDialog(
      context,
      title: l10n.windowCloseActiveTerminalsTitle,
      body: l10n.windowCloseActiveTerminalsBody(activeTerminalPaneCount),
      confirmLabel: l10n.windowCloseWindowAction,
      destructive: true,
    );
    return context.mounted && confirmed;
  } finally {
    _windowCloseConfirmationInFlight = false;
  }
}

Future<void> _requestWindowClose(BuildContext context, WidgetRef ref) async {
  if (!await _confirmCloseWithActiveTerminals(context, ref)) {
    return;
  }
  _windowTerminationConfirmed = true;
  await AppWindow.close();
}

/// Handles a native termination request (macOS Cmd+Q, Dock quit, logout).
/// Returns true when the app may terminate.
Future<bool> _requestApplicationTermination(
  BuildContext context,
  WidgetRef ref,
) async {
  // A termination triggered by a confirmed window close (macOS quits the
  // app when the last window closes) must not ask again. The same applies
  // once the shell is gone: never block quitting when no UI can answer.
  if (_windowTerminationConfirmed || !context.mounted) {
    return true;
  }
  final confirmed = await _confirmCloseWithActiveTerminals(context, ref);
  if (confirmed) {
    _windowTerminationConfirmed = true;
  }
  return confirmed;
}

/// Routes native application termination requests (macOS Cmd+Q, Dock quit)
/// into the same active-terminal confirmation as the window close button.
class _NativeTerminationGuard extends ConsumerStatefulWidget {
  const _NativeTerminationGuard({required this.child});

  final Widget child;

  @override
  ConsumerState<_NativeTerminationGuard> createState() =>
      _NativeTerminationGuardState();
}

class _NativeTerminationGuardState
    extends ConsumerState<_NativeTerminationGuard> {
  @override
  void initState() {
    super.initState();
    AppWindow.setTerminateRequestHandler(_confirmTermination);
  }

  // The handler is intentionally not cleared in dispose: the native side may
  // still request termination while the window (and this widget) tears down
  // after a confirmed close, and _requestApplicationTermination short-
  // circuits to allowing termination once this state is unmounted.

  Future<bool> _confirmTermination() {
    return _requestApplicationTermination(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _MacWindowControls extends ConsumerStatefulWidget {
  const _MacWindowControls();

  @override
  ConsumerState<_MacWindowControls> createState() => _MacWindowControlsState();
}

class _MacWindowControlsState extends ConsumerState<_MacWindowControls> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MacWindowControlButton(
            label: context.l10n.windowCloseLabel,
            color: const Color(0xFFFF5F57),
            pressedColor: const Color(0xFFBF4943),
            borderColor: const Color(0xFFE0443E),
            glyphColor: const Color(0xFF7E0F0A),
            glyph: _MacWindowControlGlyph.close,
            showIcon: _hovered,
            onPressed: () => unawaited(_requestWindowClose(context, ref)),
          ),
          _MacWindowControlButton(
            label: context.l10n.windowMinimizeLabel,
            color: const Color(0xFFFFBD2E),
            pressedColor: const Color(0xFFBF9123),
            borderColor: const Color(0xFFDEA123),
            glyphColor: const Color(0xFF8A5A00),
            glyph: _MacWindowControlGlyph.minimize,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.minimize()),
          ),
          _MacWindowControlButton(
            label: context.l10n.windowZoomLabel,
            color: const Color(0xFF28C840),
            pressedColor: const Color(0xFF1F9E32),
            borderColor: const Color(0xFF1DAC2B),
            glyphColor: const Color(0xFF006400),
            glyph: _MacWindowControlGlyph.zoom,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.toggleMaximize()),
          ),
        ],
      ),
    );
  }
}

class _MacWindowControlButton extends StatefulWidget {
  const _MacWindowControlButton({
    required this.label,
    required this.color,
    required this.pressedColor,
    required this.borderColor,
    required this.glyphColor,
    required this.glyph,
    required this.showIcon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color pressedColor;
  final Color borderColor;
  final Color glyphColor;
  final _MacWindowControlGlyph glyph;
  final bool showIcon;
  final VoidCallback onPressed;

  static const _hitSize = 20.0;
  static const _dotSize = 12.0;

  @override
  State<_MacWindowControlButton> createState() =>
      _MacWindowControlButtonState();
}

enum _MacWindowControlGlyph { close, minimize, zoom }

class _MacWindowControlButtonState extends State<_MacWindowControlButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() {
      _pressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onPressed,
        child: SizedBox.square(
          dimension: _MacWindowControlButton._hitSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              width: _MacWindowControlButton._dotSize,
              height: _MacWindowControlButton._dotSize,
              decoration: BoxDecoration(
                color: _pressed ? widget.pressedColor : widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: widget.borderColor, width: 0.5),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                opacity: widget.showIcon ? 1 : 0,
                child: CustomPaint(
                  painter: _MacWindowControlGlyphPainter(
                    glyph: widget.glyph,
                    color: widget.glyphColor.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacWindowControlGlyphPainter extends CustomPainter {
  const _MacWindowControlGlyphPainter({
    required this.glyph,
    required this.color,
  });

  final _MacWindowControlGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (glyph) {
      case _MacWindowControlGlyph.close:
        _paintClose(canvas, size);
      case _MacWindowControlGlyph.minimize:
        _paintMinimize(canvas, size);
      case _MacWindowControlGlyph.zoom:
        _paintZoom(canvas, size);
    }
  }

  void _paintClose(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.29, size.height * 0.29),
      Offset(size.width * 0.71, size.height * 0.71),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.71, size.height * 0.29),
      Offset(size.width * 0.29, size.height * 0.71),
      paint,
    );
  }

  void _paintMinimize(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.56),
      Offset(size.width * 0.75, size.height * 0.56),
      paint,
    );
  }

  void _paintZoom(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final first = Path()
      ..moveTo(size.width * 0.25, size.height * 0.25)
      ..lineTo(size.width * 0.71, size.height * 0.25)
      ..lineTo(size.width * 0.25, size.height * 0.71)
      ..close();
    final second = Path()
      ..moveTo(size.width * 0.75, size.height * 0.75)
      ..lineTo(size.width * 0.29, size.height * 0.75)
      ..lineTo(size.width * 0.75, size.height * 0.29)
      ..close();
    canvas.drawPath(first, paint);
    canvas.drawPath(second, paint);
  }

  @override
  bool shouldRepaint(_MacWindowControlGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion();

  @override
  Widget build(BuildContext context) {
    if (!AppWindow.usesCustomChrome) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(AppWindow.startDrag()),
      onDoubleTap: () => unawaited(AppWindow.toggleMaximize()),
      child: const SizedBox.expand(),
    );
  }
}

class _WindowControls extends ConsumerStatefulWidget {
  const _WindowControls();

  @override
  ConsumerState<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends ConsumerState<_WindowControls> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMaximized());
  }

  Future<void> _refreshMaximized() async {
    final maximized = await AppWindow.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  Future<void> _toggleMaximize() async {
    final maximized = await AppWindow.toggleMaximize();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: Icons.remove_rounded,
          onPressed: () => unawaited(AppWindow.minimize()),
        ),
        _WindowControlButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onPressed: () => unawaited(_toggleMaximize()),
        ),
        _WindowControlButton(
          icon: Icons.close_rounded,
          isClose: true,
          onPressed: () => unawaited(_requestWindowClose(context, ref)),
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _hovered
        ? widget.isClose
              ? const Color(0xFFE81123)
              : scheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;
    final foreground = _hovered && widget.isClose
        ? Colors.white
        : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SerlinkPressable(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(6),
          hoverColor: Colors.transparent,
          pressedColor: widget.isClose
              ? Colors.white.withValues(alpha: 0.16)
              : scheme.onSurface.withValues(alpha: 0.12),
          child: SizedBox.square(
            dimension: 34,
            child: Icon(widget.icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}
