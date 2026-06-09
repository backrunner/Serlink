import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  test('iOS enables CloudKit and disables desktop-only capabilities', () {
    const capabilities = PlatformCapabilities(
      operatingSystem: 'ios',
      targetPlatform: TargetPlatform.iOS,
    );

    expect(capabilities.prefersMobileWorkspaceShell, isTrue);
    expect(capabilities.localTerminal, isFalse);
    expect(capabilities.customWindowChrome, isFalse);
    expect(capabilities.cloudKitSync, isTrue);
    expect(capabilities.terminalSplit, isFalse);
    expect(capabilities.terminalZmodemTransfers, isFalse);
    expect(capabilities.localDirectoryTransfer, isFalse);
    expect(capabilities.openLocalFile, isFalse);
    expect(capabilities.suspendSessionsOnBackground, isTrue);
    expect(capabilities.sshAgentAuth, isFalse);
    expect(capabilities.hardwareKeyAuth, isFalse);
  });

  test('macOS keeps the existing desktop surface area', () {
    const capabilities = PlatformCapabilities(
      operatingSystem: 'macos',
      targetPlatform: TargetPlatform.macOS,
    );

    expect(capabilities.prefersMobileWorkspaceShell, isFalse);
    expect(capabilities.localTerminal, isTrue);
    expect(capabilities.customWindowChrome, isTrue);
    expect(capabilities.cloudKitSync, isTrue);
    expect(capabilities.terminalSplit, isTrue);
    expect(capabilities.terminalZmodemTransfers, isTrue);
    expect(capabilities.localDirectoryTransfer, isTrue);
    expect(capabilities.openLocalFile, isTrue);
    expect(capabilities.suspendSessionsOnBackground, isFalse);
    expect(capabilities.sshAgentAuth, isTrue);
    expect(capabilities.hardwareKeyAuth, isFalse);
  });
}
