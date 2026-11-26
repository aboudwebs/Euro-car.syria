#!/usr/bin/env python3
"""Configure R8 for the optional non-Latin ML Kit OCR scripts.

The Euro Parts VIN scanner uses Latin recognition only. The Flutter ML Kit
plugin contains references to optional Chinese, Devanagari, Japanese and
Korean recognizers, which are intentionally not packaged by this app.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
RULES = ROOT / "android" / "app" / "proguard-rules.pro"

OPTIONAL_SCRIPT_RULES = """# Euro Parts uses Latin OCR for VIN/chassis numbers only.
# Other ML Kit script recognizers are optional and are not packaged.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
"""

def main() -> int:
    if not GRADLE.is_file():
        print(f"Missing generated Gradle file: {GRADLE}", file=sys.stderr)
        return 1

    gradle = GRADLE.read_text(encoding="utf-8")
    if "proguard-rules.pro" not in gradle:
        pattern = re.compile(r"(?m)^(\s*)release\s*\{\s*$")
        match = pattern.search(gradle)
        if not match:
            print("Could not find the release block in app/build.gradle.kts", file=sys.stderr)
            return 1
        indent = match.group(1) + "    "
        addition = (
            match.group(0)
            + "\n"
            + indent
            + 'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
        )
        gradle = gradle[:match.start()] + addition + gradle[match.end():]
        GRADLE.write_text(gradle, encoding="utf-8")

    existing = RULES.read_text(encoding="utf-8") if RULES.exists() else ""
    missing = [line for line in OPTIONAL_SCRIPT_RULES.splitlines() if line and line not in existing]
    if missing:
        updated = existing.rstrip()
        if updated:
            updated += "\n"
        updated += "\n".join(missing) + "\n"
        RULES.write_text(updated, encoding="utf-8")

    verified = RULES.read_text(encoding="utf-8")
    for rule in OPTIONAL_SCRIPT_RULES.splitlines():
        if rule.startswith("-dontwarn ") and rule not in verified:
            print(f"Missing R8 rule: {rule}", file=sys.stderr)
            return 1
    if "proguard-rules.pro" not in GRADLE.read_text(encoding="utf-8"):
        print("R8 rules file is not connected to the release build", file=sys.stderr)
        return 1

    print("ML Kit R8 configuration verified (Latin OCR retained; optional scripts excluded).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
