import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// UIKit owns the material, typography, accessibility and selection animation.
/// A platform view keeps Flutter routes and modal barriers above the native bar.
class IosNativeTabBar extends StatefulWidget {
  const IosNativeTabBar({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
    required this.tint,
    required this.brightness,
    required this.fallback,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final Color tint;
  final Brightness brightness;
  final Widget fallback;

  @override
  State<IosNativeTabBar> createState() => _IosNativeTabBarState();
}

class _IosNativeTabBarState extends State<IosNativeTabBar> {
  static const _platform = MethodChannel('serlink/platform');
  MethodChannel? _channel;
  bool _supported = false;
  double? _nativeHeight;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    try {
      final supported =
          await _platform.invokeMethod<bool>('supportsLiquidGlassTabBar') ??
          false;
      if (mounted) setState(() => _supported = supported);
    } on MissingPluginException {
      // Older runners and widget tests retain the Cupertino bar.
    } on PlatformException {
      // Keep navigation usable if the native bridge is unavailable.
    }
  }

  Map<String, Object> get _configuration => {
    'index': widget.index,
    'labels': widget.labels,
    'tint': widget.tint.toARGB32(),
    'dark': widget.brightness == Brightness.dark,
  };

  @override
  void didUpdateWidget(IosNativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_update());
  }

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', _configuration);
    } on PlatformException {
      if (mounted) setState(() => _supported = false);
    } on MissingPluginException {
      if (mounted) setState(() => _supported = false);
    }
  }

  void _created(int id) {
    if (!mounted) return;
    _channel = MethodChannel('serlink/native_tab_bar/$id');
    _channel!.setMethodCallHandler((call) async {
      if (!mounted || !_supported) return;
      switch (call.method) {
        case 'select':
          final index = call.arguments;
          if (index is int && index >= 0 && index < widget.labels.length) {
            widget.onChanged(index);
          }
        case 'height':
          final height = call.arguments;
          if (height is num &&
              height.isFinite &&
              height > 0 &&
              height.toDouble() != _nativeHeight) {
            setState(() => _nativeHeight = height.toDouble());
          }
      }
    });
    // Reconcile changes that happened while UIKit was creating the view.
    unawaited(_update());
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return widget.fallback;
    return SizedBox(
      height: _nativeHeight ?? 49 + MediaQuery.viewPaddingOf(context).bottom,
      child: UiKitView(
        viewType: 'serlink/native_tab_bar',
        creationParams: _configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
      ),
    );
  }
}
