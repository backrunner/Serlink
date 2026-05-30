import 'dart:ui';

import 'package:flutter/material.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_tokens.dart';

/// Soft, layered drop shadow for floating panels and cards. [elevation] loosely
/// follows Material dp but is tuned for a calm, premium look (two stacked
/// shadows: a tight contact shadow plus a wide ambient one).
List<BoxShadow> serlinkShadow(
  SerlinkTokens t, {
  double elevation = 12,
  double opacity = 1,
}) {
  final base = t.shadowColor;
  final isDark = base.computeLuminance() < 0.2;
  final ambient = isDark ? 0.44 : 0.16;
  final contact = isDark ? 0.34 : 0.12;
  return [
    BoxShadow(
      color: base.withValues(alpha: ambient * opacity),
      blurRadius: elevation * 2.2,
      spreadRadius: elevation * 0.05,
      offset: Offset(0, elevation * 0.85),
    ),
    BoxShadow(
      color: base.withValues(alpha: contact * opacity),
      blurRadius: elevation * 0.7,
      offset: Offset(0, elevation * 0.25),
    ),
  ];
}

/// A diagonal accent gradient (deep teal -> cyan) used for primary affordances,
/// badges, and focus glows. Starts from [SerlinkTokens.accentStrong] so white
/// [SerlinkTokens.onAccent] foreground stays legible across the whole fill.
LinearGradient serlinkAccentGradient(SerlinkTokens t) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [t.accentStrong, t.accentSecondary],
  );
}

/// The ambient full-window backdrop gradient with a subtle accent glow.
BoxDecoration serlinkBackdrop(SerlinkTokens t) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [t.backdropTop, t.backdropBottom],
    ),
  );
}

/// A frosted-glass surface: blurred translucent fill, hairline highlight
/// border, generous rounding, and a soft drop shadow. Use for floating chrome
/// (panels, dialogs, the vault card) over the [serlinkBackdrop].
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = SerlinkRadii.card,
    this.elevation = 18,
    this.blur = 22,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double elevation;
  final double blur;

  /// Optional fill override. Defaults to [SerlinkTokens.surfaceGlass].
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: serlinkShadow(t, elevation: elevation),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint ?? t.surfaceGlass,
              borderRadius: borderRadius,
              border: Border.all(
                color: t.borderSubtle.withValues(alpha: 0.9),
              ),
            ),
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}

/// Plays a gentle fade + rise + scale entrance for its [child] once, when it
/// first appears. Used to make primary surfaces feel alive without being noisy.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.offsetY = 16,
    this.beginScale = 0.97,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final double beginScale;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offsetY),
            child: Transform.scale(
              scale: widget.beginScale + (1 - widget.beginScale) * v,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
