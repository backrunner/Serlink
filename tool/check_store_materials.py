#!/usr/bin/env python3
"""Validate local macOS App Store fields/assets; optionally require live values."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
folder = root / "docs/release/macos"
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
    name = {"en-US": "en", "zh-Hans": "zh", "ja": "ja"}[locale]
    shots = sorted((folder / "screenshots" / name).glob("*.jpg"))
    if len(shots) != 5:
        errors.append(f"{locale}: expected five screenshots, got {len(shots)}")
    for shot in shots:
        output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(shot)], text=True)
        if "pixelWidth: 2560" not in output or "pixelHeight: 1600" not in output or "hasAlpha: no" not in output:
            errors.append(f"{shot.name}: incorrect size or transparency")
icon = folder / "icon-1024.png"
if not icon.exists():
    errors.append("icon-1024.png is missing")
else:
    output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(icon)], text=True)
    if "pixelWidth: 1024" not in output or "pixelHeight: 1024" not in output or "hasAlpha: no" not in output:
        errors.append("icon: incorrect dimensions or alpha channel")
for name in ("privacy.html", "support.html", "review-notes.txt", "encryption.md", "licenses/README.md", "licenses/Serlink-LICENSE.txt",
             "licenses/resolved-packages.txt", "licenses/macos-pods-acknowledgements.plist"):
    if not (folder / name).exists():
        errors.append(f"{name} is missing")
pending = [field for field in ("supportURL", "privacyPolicyURL", "price", "territories", "releaseMethod") if metadata.get(field) is None]
if "{{SUPPORT_CONTACT}}" in (folder / "support.html").read_text():
    pending.append("SUPPORT_CONTACT")
if "--require-publishable" in sys.argv:
    for field in ("supportURL", "privacyPolicyURL"):
        value = metadata.get(field)
        if value and not value.startswith("https://"):
            errors.append(f"{field}: must be an HTTPS URL")
    errors.extend(f"unset release value: {field}" for field in pending)
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("Validated three locales, 15 opaque 2560×1600 screenshots, icon and supporting documents.")
print("Pending publication/business values: " + ", ".join(pending))
print("This check does not verify hosting, signing, CloudKit Production, upload, or review status.")
