#!/usr/bin/env python3
"""Render the real app widgets with fictional, in-memory App Store fixtures.

Usage: python3 tool/render_store_screenshots.py /path/to/flutter
Requires macOS system fonts. Never opens the user vault or contacts a server.
"""
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
flutter = pathlib.Path(shutil.which(sys.argv[1] if len(sys.argv) > 1 else "flutter")).resolve()
sdk = flutter.parent.parent
work = ROOT / "build/store-render"
work.mkdir(parents=True, exist_ok=True)
# The headless Flutter engine needs a single TTF face for deterministic CJK glyphs.
# Extract a locally installed font; never redistribute the font with the app.
try:
    from fontTools.ttLib import TTCollection
except ImportError:
    sys.exit("Install fonttools in a Python virtual environment, then run this script with that Python.")
cjk = work / "store-cjk.ttf"
TTCollection("/System/Library/Fonts/Hiragino Sans GB.ttc").fonts[0].save(cjk)
for name in ("workspace_smoke_test_fakes.dart", "workspace_smoke_test_host_groups.dart"):
    shutil.copyfile(ROOT / "test" / name, work / name)
source = (ROOT / "test/workspace_smoke_test.dart").read_text()
source = "import 'dart:io';\nimport 'dart:ui' as ui;\nimport 'package:serlink/features/terminal/application/terminal_font_discovery.dart';\nimport 'package:flutter/rendering.dart';\nimport 'package:serlink/features/snippets/domain/snippet.dart';\nimport 'package:serlink/features/workspace/application/workspace_runtime_registry.dart';\n" + source
capture = r'''
  setUpAll(() async {
    final fonts = <String, List<String>>{
      '.SF UI Display': ['CJK'],
      'CupertinoSystemDisplay': ['CJK'],
      'CupertinoSystemText': ['CJK'],
      '.AppleSystemUIFont': ['CJK'],
      '.SF UI Text': ['CJK'],
      '.SF Pro Text': ['CJK'],
      '.SF Pro Display': ['CJK'],
      'Ahem': ['CJK'],
      'monospace': ['/System/Library/Fonts/SFNSMono.ttf'],
      'packages/forui_lucide/ForuiLucideIcons': ['FORUI_ASSETS/assets/lucide.ttf'],
      'MaterialIcons': ['SDK/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'],
      'packages/cupertino_icons/CupertinoIcons': ['CUPERTINO/assets/CupertinoIcons.ttf'],
      'packages/forui/Inter': ['FORUI/assets/fonts/inter/Inter.ttf'],
    };
    for (final font in fonts.entries) {
      final loader = FontLoader(font.key);
      for (final path in font.value) {
        loader.addFont(File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  for (final language in ['en', 'zh', 'ja']) {
    testWidgets('store screenshot $language', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(2560, 1600);
      tester.platformDispatcher.localesTestValue = [Locale(language)];
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final hosts = _MemoryHostRepository();
      for (var i = 0; i < 4; i++) {
        hosts.hosts.add(_hostConfig(
          id: 'store-$i',
          displayName: ['Production Web', 'Build Runner', 'Database', 'Bastion'][i],
          hostname: ['web', 'build', 'db', 'bastion'][i] + '.example.test',
          createdAt: DateTime.utc(2026, 9, 30),
        ));
      }
      final resolver = StaticConnectionProfileResolver({
        for (final host in hosts.hosts) host.id: StaticConnectionProfile(
          hostId: host.id, hostname: host.hostname, port: 22,
          username: host.username, authMethods: [staticPasswordAuth('fixture-only')],
        ),
      });
      final sshService = _FakeSshSessionService();
      for (final name in ['releases', 'config', 'service.log', 'README.md']) {
        final folder = name == 'releases' || name == 'config';
        sshService.sftp._entries['/$name'] = SftpEntry(
          name: name, path: '/$name', type: folder ? SftpEntryType.directory : SftpEntryType.file,
          size: folder ? 4096 : 12288, modifiedAt: DateTime.utc(2026, 9, 30, 9, 41),
          permissions: SftpPermissions(folder ? '0755' : '0640'), owner: 'deploy', group: 'ops',
        );
      }
      await _pumpLockedVaultApp(tester,
        capabilities: const PlatformCapabilities(
          operatingSystem: 'macos', targetPlatform: TargetPlatform.macOS,
          distribution: SerlinkDistribution.appStore,
        ),
        sshService: sshService, hostRepository: hosts, connectionProfileResolver: resolver,
        syncDevices: [],
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(SerlinkApp)));
      final controller = container.read(workspaceTabControllerProvider.notifier);
      Future<void> capture(String name, {bool dark = false}) async {
        print('Rendering $language/$name');
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('store-capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('OUTPUT/$language/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        print('Saved $language/$name');
      }
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await capture('01-hosts');
      WorkspaceTabState? tab;
      unawaited(controller.openTerminal(hosts.hosts.first.toSummary()).then((value) => tab = value));
      print('Opening terminal');
      await _pumpUntil(tester, () => tab != null && controller.state.tabs.first.lifecycle == SessionLifecycleState.connected);
      print('Terminal connected');
      await tester.pump(const Duration(milliseconds: 200));
      final content = tab!.content as TerminalTabContent;
      container.read(workspaceRuntimeRegistryProvider).terminalFor(content.primaryPane.sessionId)!.write(
        '\x1b[36mops@web.example.test\x1b[0m ~ % uptime\r\n'
        ' 09:41:00 up 12 days, 3:18, 2 users, load average: 0.12, 0.18, 0.16\r\n\r\n'
        '\x1b[36mops@web.example.test\x1b[0m ~ % ls -lh /srv/app\r\n'
        'total 64K\r\n'
        'drwxr-xr-x  4 deploy ops  4.0K Sep 30 09:41 releases\r\n'
        '-rw-r-----  1 deploy ops  2.4K Sep 30 09:41 app.env\r\n'
        '-rw-r-----  1 deploy ops   12K Sep 30 09:41 service.log\r\n\r\n'
        '\x1b[36mops@web.example.test\x1b[0m ~ % ',
      );
      await capture('02-terminal', dark: true);
      controller.openSftp(hosts.hosts.first.toSummary());
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('README.md'));
      await capture('03-sftp');
      final now = DateTime.utc(2026, 9, 30);
      for (var i = 0; i < 3; i++) {
        await container.read(snippetRepositoryProvider).save(CommandSnippet(
          id: SnippetId('store-$i'),
          name: ['Service status', 'Recent logs', 'Disk usage'][i],
          command: ['systemctl status app', 'journalctl -u app -n 50 --no-pager', 'df -h'][i],
          tags: const {'operations'}, confirmBeforeRun: true, createdAt: now, updatedAt: now,
        ));
      }
      container.invalidate(snippetsProvider);
      controller.selectArea(WorkspaceArea.snippets);
      await capture('04-snippets');
      controller.selectArea(WorkspaceArea.settings);
      await capture('05-settings');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
'''
# Resolve package paths through the exact selected SDK's package configuration.
import json
from urllib.parse import urljoin, urlparse, unquote
config_path = ROOT / ".dart_tool/package_config.json"
packages = json.loads(config_path.read_text())["packages"]
for package, token in (("cupertino_icons", "CUPERTINO"), ("forui_lucide", "FORUI_ASSETS"), ("forui", "FORUI")):
    entry = next(p for p in packages if p["name"] == package)
    uri = urljoin(config_path.as_uri(), entry["rootUri"])
    capture = capture.replace(token, unquote(urlparse(uri).path).rstrip("/"))
capture = capture.replace("CJK", str(cjk)).replace("SDK", str(sdk)).replace("OUTPUT", str(ROOT / "docs/release/macos/screenshots"))
source = source.replace("child: const SerlinkApp(),", "child: const RepaintBoundary(key: ValueKey('store-capture'), child: SerlinkApp()),")
source = source.replace("version: '1.2.3'", "version: '1.0.0'").replace("buildNumber: '45'", "buildNumber: '15'")
source = source.replace('autoSyncEnabledProvider.overrideWithValue(false),', 'autoSyncEnabledProvider.overrideWithValue(false), terminalFontCatalogProvider.overrideWith((ref) async => TerminalFontCatalog.fallback()),')
source = source.replace("void main() {", "void main() {\n" + capture, 1)
runner = work / "workspace_smoke_test.dart"
runner.write_text(source)
subprocess.run([str(flutter), "test", str(runner), "--plain-name", "store screenshot", "--concurrency=1", "--reporter=expanded"], cwd=ROOT, check=True)

# Encode upload assets as JPEG so the file format has no alpha channel.
for png in (ROOT / "docs/release/macos/screenshots").glob("*/*.png"):
    subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "best", str(png), "--out", str(png.with_suffix(".jpg"))], check=True, stdout=subprocess.DEVNULL)
    png.unlink()
