import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades only the edges hiding more content. Wrap the scroll viewport itself,
/// keeping headers, actions and scrollbars outside this mask.
class SerlinkScrollFade extends StatefulWidget {
  const SerlinkScrollFade({
    super.key,
    required this.child,
    this.fadeExtent = 20,
  }) : assert(fadeExtent >= 0);

  final Widget child;
  final double fadeExtent;

  @override
  State<SerlinkScrollFade> createState() => _SerlinkScrollFadeState();
}

class _SerlinkScrollFadeState extends State<SerlinkScrollFade> {
  double _leading = 0;
  double _trailing = 0;
  AxisDirection _direction = AxisDirection.down;
  bool _updateScheduled = false;
  ScrollMetrics? _pendingMetrics;

  void _update(ScrollMetrics metrics) {
    // Metrics notifications also arrive during layout (resize/content changes).
    // Coalesce them and repaint after layout, without rebuilding the viewport.
    _pendingMetrics = metrics;
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final metrics = _pendingMetrics!;
      final leading = metrics.extentBefore.clamp(0.0, widget.fadeExtent);
      final trailing = metrics.extentAfter.clamp(0.0, widget.fadeExtent);
      if (_leading != leading ||
          _trailing != trailing ||
          _direction != metrics.axisDirection) {
        setState(() {
          _leading = leading;
          _trailing = trailing;
          _direction = metrics.axisDirection;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _update(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _update(notification.metrics);
          return false;
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final vertical = axisDirectionToAxis(_direction) == Axis.vertical;
            final reversed =
                _direction == AxisDirection.up ||
                _direction == AxisDirection.left;
            final length = vertical ? bounds.height : bounds.width;
            final start = reversed ? _trailing : _leading;
            final end = reversed ? _leading : _trailing;
            final startStop = length > 0 ? math.min(start / length, 0.5) : 0.0;
            final endStop = length > 0 ? math.min(end / length, 0.5) : 0.0;
            return LinearGradient(
              begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [
                start > 0 ? Colors.transparent : Colors.white,
                Colors.white,
                Colors.white,
                end > 0 ? Colors.transparent : Colors.white,
              ],
              stops: [0, startStop, 1 - endStop, 1],
            ).createShader(bounds);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Shared scrolling content for forms, previews and compact menus.
class SerlinkScrollView extends StatelessWidget {
  const SerlinkScrollView({
    super.key,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.padding,
    required this.child,
  });

  final ScrollController? controller;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => SerlinkScrollFade(
    child: SingleChildScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      physics: physics,
      padding: padding,
      child: child,
    ),
  );
}
