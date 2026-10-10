#!/usr/bin/env python3
"""Validate local Apple App Store fields/assets; optionally require live values."""
import argparse
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--platform", choices=["macos", "ios"], default="macos")
parser.add_argument("--metadata-only", action="store_true")
parser.add_argument("--require-publishable", action="store_true")
args = parser.parse_args()
folder = root / "docs/release" / args.platform
metadata = json.loads((folder / "metadata.json").read_text())
limits = {"name": 30, "subtitle": 30, "promotionalText": 170, "keywords": 100,
          "description": 4000, "whatsNew": 4000, "betaDescription": 4000,
          "betaWhatToTest": 4000}
errors = []
for locale, fields in metadata["localizations"].items():
    for field, limit in limits.items():
        value = fields.get(field)
        if not isinstance(value, str) or not value.strip() or len(value) > limit:
            errors.append(f"{locale}/{field}: missing or exceeds {limit} characters")
    if len(fields.get("keywords", "").encode("utf-8")) > 100:
        errors.append(f"{locale}/keywords: exceeds 100 UTF-8 bytes")
    if not args.metadata_only:
        name = {"en-US": "en", "zh-Hans": "zh", "ja": "ja"}[locale]
        families = [""] if args.platform == "macos" else ["iphone", "ipad"] + (["iphone-large"] if (folder / "screenshots/iphone-large").exists() else [])
        for family in families:
            shots = sorted((folder / "screenshots" / family / name).glob("*.jpg"))
            if len(shots) != 5:
                errors.append(f"{locale}/{family}: expected five screenshots, got {len(shots)}")
            sizes = {"": (2560, 1600), "iphone": (1206, 2622), "iphone-large": (1320, 2868), "ipad": (2064, 2752)}
            width, height = sizes[family]
            for shot in shots:
                output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(shot)], text=True)
                if f"pixelWidth: {width}" not in output or f"pixelHeight: {height}" not in output or "hasAlpha: no" not in output:
                    errors.append(f"{shot.name}: incorrect size or transparency")
icon = folder / "icon-1024.png"
if not icon.exists():
    errors.append("icon-1024.png is missing")
else:
    output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(icon)], text=True)
    if "pixelWidth: 1024" not in output or "pixelHeight: 1024" not in output or "hasAlpha: no" not in output:
        errors.append("icon: incorrect dimensions or alpha channel")
for name in ("privacy.html", "support.html", "review-notes.txt", "encryption.md", "licenses/README.md", "licenses/Serlink-LICENSE.txt",
             "licenses/resolved-packages.txt", f"licenses/{args.platform}-pods-acknowledgements.plist"):
    if not (folder / name).exists():
        errors.append(f"{name} is missing")
pending = [field for field in ("supportURL", "privacyPolicyURL", "price", "territories", "releaseMethod") if metadata.get(field) is None]
if "{{SUPPORT_CONTACT}}" in (folder / "support.html").read_text():
    pending.append("SUPPORT_CONTACT")
if args.require_publishable:
    for field in ("supportURL", "privacyPolicyURL"):
        value = metadata.get(field)
        if value and not value.startswith("https://"):
            errors.append(f"{field}: must be an HTTPS URL")
    errors.extend(f"unset release value: {field}" for field in pending)
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"Validated {args.platform} three locales, icon and supporting documents" + ("; screenshot validation skipped." if args.metadata_only else "; all screenshot sizes and alpha checks passed."))
print("Pending publication/business values: " + ", ".join(pending))
print("This check does not verify hosting, signing, CloudKit Production, upload, or review status.")
