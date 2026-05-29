enum SerlinkRuntimeMode { debug, profile, release }

class RuntimeCapabilities {
  const RuntimeCapabilities({
    required this.mode,
    required this.verboseRedactedLogging,
    required this.crashReporting,
    required this.unsafeDiagnosticsAllowed,
  });

  final SerlinkRuntimeMode mode;
  final bool verboseRedactedLogging;
  final bool crashReporting;
  final bool unsafeDiagnosticsAllowed;

  static const current = RuntimeCapabilities(
    mode: bool.fromEnvironment('dart.vm.product')
        ? SerlinkRuntimeMode.release
        : bool.fromEnvironment('dart.vm.profile')
        ? SerlinkRuntimeMode.profile
        : SerlinkRuntimeMode.debug,
    verboseRedactedLogging: !bool.fromEnvironment('dart.vm.product'),
    crashReporting: bool.fromEnvironment('dart.vm.product'),
    unsafeDiagnosticsAllowed: false,
  );
}
