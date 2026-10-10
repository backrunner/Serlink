#!/usr/bin/env python3
"""Capture production widget frames on the native macOS Flutter engine.

Runs a disposable integration fixture with in-memory data; no user vault/server.
Restores the temporary integration dependency and tracked native project files.
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
args = parser.parse_args()
work = root / "integration_test" / "_store_capture"
if work.exists():
    raise SystemExit("A capture is already running; do not overwrite its sources")
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
    capture = capture.replace("store screenshot $language", "native Mac store screenshot $language")
    output = root / "build/store-native-macos"
    capture = capture.replace("OUTPUT", str(output))
    imports = """import 'dart:ui' as ui;
import 'package:integration_test/integration_test.dart';
import 'package:flutter/rendering.dart';
import 'package:serlink/features/snippets/domain/snippet.dart';
import 'package:serlink/features/workspace/application/workspace_runtime_registry.dart';
"""
    source = imports + prefix + "void main() {\n  IntegrationTestWidgetsFlutterBinding.ensureInitialized();\n" + capture + "\n}\n" + helpers
    source = source.replace("child: const SerlinkApp(),", "child: const RepaintBoundary(key: ValueKey('store-capture'), child: SerlinkApp()),")
    metadata = json.loads((root / "docs/release/macos/metadata.json").read_text())
    source = source.replace("version: '1.2.3'", "version: '" + metadata["version"] + "'").replace("buildNumber: '45'", "buildNumber: '" + metadata["buildNumber"] + "'")
    source = source.replace("2026, 9, 30", "2026, 10, 11").replace("Sep 30", "Oct 11")
    source = source.replace("autoSyncEnabledProvider.overrideWithValue(false),", "autoSyncEnabledProvider.overrideWithValue(false), terminalFontCatalogProvider.overrideWith((ref) async => TerminalFontCatalog.fallback()),")
    runner = work / "workspace_smoke_test.dart"
    runner.write_text(source)
    pubspec = root / "pubspec.yaml"
    pubspec.write_text(pubspec.read_text().replace("dev_dependencies:\n", "dev_dependencies:\n  integration_test:\n    sdk: flutter\n"))
    subprocess.run([args.flutter, "pub", "get"], cwd=root, check=True)
    subprocess.run([args.flutter, "test", str(runner), "-d", "macos", "--dart-define=SERLINK_DISTRIBUTION=app_store", "--reporter=expanded"], cwd=root, check=True)
    shots = list(output.glob("*/*.png"))
    if len(shots) != 15:
        raise RuntimeError(f"Expected 15 native frames; got {len(shots)}")
    for shot in shots:
        target = root / "docs/release/macos/screenshots" / shot.parent.name / (shot.stem + ".jpg")
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "92", str(shot), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
    print("Saved 15 native macOS renderer captures")
finally:
    for name, content in saved.items():
        (root / name).write_bytes(content)
    shutil.rmtree(work)
    if not any((root / "integration_test").iterdir()):
        (root / "integration_test").rmdir()
    subprocess.run([args.flutter, "pub", "get"], cwd=root, check=True)
