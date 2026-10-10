#!/usr/bin/env python3
"""Capture production widgets with fictional data in a dedicated iOS simulator.

Native IntegrationTestPlugin captures UIKit screenshots, including safe areas.
This validates native rendering, not a live SSH service or CloudKit account.
The temporary integration dependency and native project files are restored.
"""
import argparse
import json
import pathlib
import re
import shutil
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--flutter", required=True)
parser.add_argument("--device", required=True, help="Dedicated, booted simulator UUID")
parser.add_argument("--family", choices=["iphone", "iphone-large", "ipad"], required=True)
args = parser.parse_args()
work = root / "integration_test" / "_store_capture"
if work.exists():
    raise SystemExit("Temporary capture folder already exists; preserve it before retrying")
work.mkdir(parents=True)
tracked = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines()
saved = {name: (root / name).read_bytes() for name in tracked
         if name in ("pubspec.yaml", "pubspec.lock") or name.startswith(("ios/", "macos/", "android/"))}
try:
    source = (root / "test/workspace_smoke_test.dart").read_text()
    prefix = source[:source.index("void main() {")]
    helpers = source[source.index("Future<_LockedVaultHarness> _pumpLockedVaultApp"):]
    for part in re.findall(r"part '([^']+)';", prefix):
        shutil.copy(root / "test" / part, work / part)
    old = (root / "tool/render_store_screenshots.py").read_text()
    capture = old.split("capture = r'''", 1)[1].split("'''", 1)[0]
    capture = capture[capture.index("  for (final language"):]
    capture = re.sub(r"      tester.view.devicePixelRatio = 2;.*?      tester.platformDispatcher.localesTestValue", "      tester.platformDispatcher.localesTestValue", capture, flags=re.S)
    capture = capture.replace("      addTearDown(tester.view.resetPhysicalSize);\n", "").replace("      addTearDown(tester.view.resetDevicePixelRatio);\n", "")
    capture = capture.replace("store screenshot $language", "native store screenshot $language")
    capture = capture.replace("operatingSystem: 'macos', targetPlatform: TargetPlatform.macOS", "operatingSystem: 'ios', targetPlatform: TargetPlatform.iOS")
    terminal_start = capture.index("      container.read(workspaceRuntimeRegistryProvider).terminalFor")
    terminal_end = capture.index("      await capture('02-terminal'", terminal_start)
    capture = capture[:terminal_start] + r"""      container.read(workspaceRuntimeRegistryProvider).terminalFor(content.primaryPane.sessionId)!.write(
        '\x1b[36mops@web\x1b[0m ~ % hostname\r\n'
        'web.example.test\r\n\r\n'
        '\x1b[36mops@web\x1b[0m ~ % ls /srv/app\r\n'
        'config  releases  README.md\r\n\r\n'
        '\x1b[36mops@web\x1b[0m ~ % df -h /\r\n'
        'Filesystem  Size  Used  Avail  Use%\r\n'
        '/dev/vda1    40G   12G    28G   30%\r\n\r\n'
        '\x1b[36mops@web\x1b[0m ~ % ',
      );
""" + capture[terminal_end:]
    start = capture.index("        final boundary = tester.renderObject")
    end = capture.index("        print('Saved $language/$name');", start)
    capture = capture[:start] + """        await tester.runAsync(() async {
          final bytes = await binding.takeScreenshot('$language/$name');
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/serlink-store-capture/$language/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        });
""" + capture[end:]
    capture = capture.replace("        print('Saved $language/$name');", "        print('Saved $language/$name');\n        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));")
    imports = """import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serlink/features/snippets/domain/snippet.dart';
import 'package:serlink/features/workspace/application/workspace_runtime_registry.dart';
"""
    source = imports + prefix + "void main() {\n  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();\n" + capture + "\n}\n" + helpers
    metadata = json.loads((root / "docs/release/ios/metadata.json").read_text())
    source = source.replace("version: '1.2.3'", "version: '" + metadata["version"] + "'").replace("buildNumber: '45'", "buildNumber: '" + metadata["buildNumber"] + "'")
    source = source.replace("2026, 9, 30", "2026, 10, 11").replace("Sep 30", "Oct 11")
    source = source.replace("autoSyncEnabledProvider.overrideWithValue(false),", "autoSyncEnabledProvider.overrideWithValue(false), terminalFontCatalogProvider.overrideWith((ref) async => TerminalFontCatalog.fallback()),")
    runner = work / "workspace_smoke_test.dart"
    runner.write_text(source)
    pubspec = root / "pubspec.yaml"
    pubspec.write_text(pubspec.read_text().replace("dev_dependencies:\n", "dev_dependencies:\n  integration_test:\n    sdk: flutter\n"))
    subprocess.run([args.flutter, "pub", "get"], cwd=root, check=True)
    output = root / "docs/release/ios/screenshots" / args.family
    command = [args.flutter, "test", str(runner), "-d", args.device, "--dart-define=SERLINK_DISTRIBUTION=app_store", "--reporter=expanded"]
    captured = 0
    with subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
        for line in process.stdout:
            print(line, end="", flush=True)
            match = re.search(r"Saved (en|zh|ja)/(0[1-5]-[a-z]+)", line)
            if match:
                # Flutter uninstalls its integration app on completion. Copy each
                # native capture while the test still owns the app container.
                container = pathlib.Path(subprocess.check_output(["xcrun", "simctl", "get_app_container", args.device, "com.alkinum.serlink", "data"], text=True).strip())
                shot = container / "Library/Caches/serlink-store-capture" / match[1] / (match[2] + ".png")
                target = output / match[1] / (match[2] + ".jpg")
                target.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "92", str(shot), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
                captured += 1
        if process.wait() != 0:
            raise RuntimeError("Native integration capture failed")
    if captured != 15:
        raise RuntimeError(f"Expected 15 native screenshots; got {captured}")
    print(f"Saved 15 native screenshots to {output}")
finally:
    for name, content in saved.items():
        (root / name).write_bytes(content)
    shutil.rmtree(work)
    if not any((root / "integration_test").iterdir()):
        (root / "integration_test").rmdir()
    subprocess.run([args.flutter, "pub", "get"], cwd=root, check=True)
