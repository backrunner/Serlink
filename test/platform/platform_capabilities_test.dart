import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/platform/platform_capabilities.dart';
import 'package:xterm/xterm.dart';

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
    expect(capabilities.sshAgentAuth, isFalse);
    expect(capabilities.hardwareKeyAuth, isFalse);
    expect(capabilities.terminalSoftwareKeyboardDeleteDetection, isTrue);
    expect(capabilities.terminalTargetPlatform, TerminalTargetPlatform.ios);
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
    expect(capabilities.sshAgentAuth, isTrue);
    expect(capabilities.sshConfigImport, isTrue);
    expect(capabilities.hardwareKeyAuth, isFalse);
    expect(capabilities.terminalSoftwareKeyboardDeleteDetection, isFalse);
    expect(capabilities.terminalTargetPlatform, TerminalTargetPlatform.macos);
  });

  test('macOS App Store distribution disables unsandboxed local features', () {
    const capabilities = PlatformCapabilities(
      operatingSystem: 'macos',
      targetPlatform: TargetPlatform.macOS,
      distribution: SerlinkDistribution.appStore,
    );

    expect(capabilities.localTerminal, isFalse);
    expect(capabilities.sshAgentAuth, isFalse);
    expect(capabilities.sshConfigImport, isFalse);
    expect(capabilities.openLocalFile, isFalse);
    expect(capabilities.cloudKitSync, isTrue);
    expect(capabilities.terminalSplit, isTrue);
    expect(capabilities.terminalZmodemTransfers, isTrue);
    expect(capabilities.localDirectoryTransfer, isTrue);
    expect(capabilities.documentExport, isTrue);
  });
}
