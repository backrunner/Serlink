import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';

const _distributionName = String.fromEnvironment(
  'SERLINK_DISTRIBUTION',
  defaultValue: 'direct',
);

enum SerlinkDistribution { direct, appStore }

SerlinkDistribution _currentDistribution() {
  return switch (_distributionName) {
    'app_store' || 'app-store' || 'appStore' => SerlinkDistribution.appStore,
    _ => SerlinkDistribution.direct,
  };
}

class PlatformCapabilities {
  const PlatformCapabilities({
    required this.operatingSystem,
    required this.targetPlatform,
    this.distribution = SerlinkDistribution.direct,
  });

  factory PlatformCapabilities.current() {
    return PlatformCapabilities(
      operatingSystem: Platform.operatingSystem,
      targetPlatform: defaultTargetPlatform,
      distribution: _currentDistribution(),
    );
  }

  final String operatingSystem;
  final TargetPlatform targetPlatform;
  final SerlinkDistribution distribution;

  bool get isAppStoreDistribution =>
      distribution == SerlinkDistribution.appStore;

  bool get isIOS =>
      operatingSystem == 'ios' || targetPlatform == TargetPlatform.iOS;

  bool get isMacOS =>
      operatingSystem == 'macos' || targetPlatform == TargetPlatform.macOS;

  bool get isWindows => operatingSystem == 'windows';

  bool get isLinux => operatingSystem == 'linux';

  bool get isDesktop => isMacOS || isWindows || isLinux;

  bool get prefersTouchUi =>
      isIOS || operatingSystem == 'android' || operatingSystem == 'fuchsia';

  bool get prefersMobileWorkspaceShell => prefersTouchUi;

  bool get localTerminal => isDesktop && !isAppStoreDistribution;

  bool get customWindowChrome => isDesktop;

  bool get cloudKitSync => isMacOS || isIOS;

  bool get backgroundTransfers => false;

  bool get suspendSessionsOnBackground => isIOS;

  bool get terminalSplit => isDesktop;

  bool get terminalZmodemTransfers => isDesktop;

  bool get sshAgentAuth => isDesktop && !isAppStoreDistribution;

  bool get hardwareKeyAuth => false;

  bool get stableLocalFilePaths => !isIOS;

  bool get localDirectoryTransfer => !isIOS;

  bool get openLocalFile => isDesktop && !isAppStoreDistribution;

  bool get documentExport => true;

  bool get mobileTerminalAccessory => prefersTouchUi;

  FPlatformVariant get foruiPlatformVariant {
    if (isIOS) {
      return FPlatformVariant.iOS;
    }
    if (isMacOS) {
      return FPlatformVariant.macOS;
    }
    if (isWindows) {
      return FPlatformVariant.windows;
    }
    if (isLinux) {
      return FPlatformVariant.linux;
    }
    return FPlatformVariant.android;
  }
}
