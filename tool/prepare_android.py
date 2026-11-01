#!/usr/bin/env python3
"""Prepares the Android project that `flutter create --platforms=android .` generates for EURO CARS.

The repository keeps only the Dart side of the app; the Android folder is generated in CI (and on a developer
machine) and then adapted here. Every change is idempotent, and the script stops with an error when an expected
anchor is missing, so a Flutter template change can never silently produce an APK without network access.

What it does:
  * AndroidManifest.xml: INTERNET permission (the template only grants it to debug and profile builds, so a
    release APK would have no network at all), the app label "EURO CARS", android:allowBackup="false" (an
    Auto Backup restore brings back encrypted preferences without their Keystore key), and <queries> for
    https / http links so url_launcher can open WhatsApp and the web on Android 11+.
  * app/build.gradle.kts: minSdk of at least 23 and optional release signing from android/key.properties
    (without that file the release build is signed with the debug key, which is installable but not for the Play Store).
  * res: the launcher icons and the dark launch background from branding/android/res.

Usage (from the Flutter project folder):
    python3 tool/prepare_android.py [--project .]
"""

from __future__ import annotations

import argparse
import pathlib
import re
import shutil
import sys

APP_LABEL = "EURO CARS"
MIN_SDK = 23

INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'
POST_NOTIFICATIONS = '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'
QUERY_HTTPS = (
    "        <intent>\n"
    '            <action android:name="android.intent.action.VIEW"/>\n'
    '            <data android:scheme="https"/>\n'
    "        </intent>\n"
)
QUERY_HTTP = (
    "        <intent>\n"
    '            <action android:name="android.intent.action.VIEW"/>\n'
    '            <data android:scheme="http"/>\n'
    "        </intent>\n"
)

APP_LINK_FILTER = """        <intent-filter>
            <action android:name="android.intent.action.VIEW"/>
            <category android:name="android.intent.category.DEFAULT"/>
            <category android:name="android.intent.category.BROWSABLE"/>
            <data android:scheme="eurocars" android:host="referral"/>
        </intent-filter>
"""

GRADLE_IMPORTS = "import java.io.FileInputStream\nimport java.util.Properties\n\n"

GRADLE_KEYSTORE = """// Release signing is optional. With android/key.properties (keyAlias, keyPassword, storeFile, storePassword) the
// APK is signed with that key; without it the debug key is used, so the APK installs but is not for the Play Store.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

"""

GRADLE_SIGNING_CONFIGS = """    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

"""

GRADLE_RELEASE_SIGNING = """signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }"""


class PatchError(Exception):
    """An anchor the patch relies on was not found in a generated file."""


def read(path: pathlib.Path) -> str:
    if not path.is_file():
        raise PatchError(f"{path} does not exist. Run `flutter create --platforms=android .` first.")
    return path.read_text(encoding="utf-8")


def write_if_changed(path: pathlib.Path, text: str) -> bool:
    if path.read_text(encoding="utf-8") == text:
        return False
    path.write_text(text, encoding="utf-8")
    return True


def patch_manifest(path: pathlib.Path) -> bool:
    text = read(path)

    if "android.permission.POST_NOTIFICATIONS" not in text:
        text, count = re.subn(r"(<manifest\b[^>]*>)", r"\1\n    " + POST_NOTIFICATIONS, text, count=1)
        if count != 1:
            raise PatchError("no <manifest> element found for notification permission")

    if "android.permission.INTERNET" not in text:
        text, count = re.subn(r"(<manifest\b[^>]*>)", r"\1\n    " + INTERNET, text, count=1)
        if count != 1:
            raise PatchError("no <manifest> element found in AndroidManifest.xml")

    text, count = re.subn(r'(<application\b[^>]*?\sandroid:label=")[^"]*(")', r"\g<1>" + APP_LABEL + r"\2", text, count=1)
    if count != 1:
        raise PatchError('<application android:label="..."> not found in AndroidManifest.xml')

    if "android:allowBackup" not in text:
        text, count = re.subn(r"<application\b", '<application\n        android:allowBackup="false"', text, count=1)
        if count != 1:
            raise PatchError("<application> not found in AndroidManifest.xml")

    if 'android:scheme="https"' not in text or 'android:scheme="http"' not in text:
        if "</queries>" in text:
            additions = ""
            if 'android:scheme="https"' not in text:
                additions += QUERY_HTTPS
            if 'android:scheme="http"' not in text:
                additions += QUERY_HTTP
            closing = "    </queries>" if "    </queries>" in text else "</queries>"
            text = text.replace(closing, additions + "    </queries>", 1)
        else:
            text = text.replace("</manifest>", "    <queries>\n" + QUERY_HTTPS + QUERY_HTTP + "    </queries>\n</manifest>", 1)

    if 'android:scheme="eurocars"' not in text:
        pattern = r'(<activity\b(?=[^>]*android:name="\.MainActivity")[\s\S]*?</activity>)'
        text, count = re.subn(
            pattern,
            lambda match: match.group(1).replace("</activity>", APP_LINK_FILTER + "    </activity>", 1),
            text,
            count=1,
        )
        if count != 1:
            raise PatchError("Flutter MainActivity block not found for EURO referral deep links")

    changed = write_if_changed(path, text)

    # Fail loudly if anything the app depends on is still missing.
    final = path.read_text(encoding="utf-8")
    for needle in (INTERNET, f'android:label="{APP_LABEL}"', 'android:allowBackup="false"', 'android:scheme="https"', 'android:scheme="eurocars"'):
        if needle not in final:
            raise PatchError(f"AndroidManifest.xml is missing {needle!r} after patching")
    return changed


def patch_gradle(path: pathlib.Path) -> bool:
    text = read(path)

    if "import java.util.Properties" not in text:
        text = GRADLE_IMPORTS + text

    if "keystorePropertiesFile" not in text:
        text, count = re.subn(r"(?m)^android \{", lambda m: GRADLE_KEYSTORE + "android {", text, count=1)
        if count != 1:
            raise PatchError("`android {` block not found in app/build.gradle.kts")

    if 'create("release")' not in text:
        text, count = re.subn(r"(?m)^    buildTypes \{", lambda m: GRADLE_SIGNING_CONFIGS + "    buildTypes {", text, count=1)
        if count != 1:
            raise PatchError("`buildTypes {` block not found in app/build.gradle.kts")

    if 'signingConfigs.getByName("release")' not in text:
        text, count = re.subn(r'signingConfig = signingConfigs\.getByName\("debug"\)', lambda m: GRADLE_RELEASE_SIGNING, text, count=1)
        if count != 1:
            raise PatchError("the release signingConfig line was not found in app/build.gradle.kts")

    if f"maxOf(flutter.minSdkVersion, {MIN_SDK})" not in text:
        text, count = re.subn(r"minSdk = flutter\.minSdkVersion", f"minSdk = maxOf(flutter.minSdkVersion, {MIN_SDK})", text, count=1)
        if count != 1:
            raise PatchError("`minSdk = flutter.minSdkVersion` not found in app/build.gradle.kts")

    # flutter_local_notifications requires Java 8+ API desugaring on Android.
    if "isCoreLibraryDesugaringEnabled = true" not in text:
        text, count = re.subn(
            r"(?m)^    compileOptions \{\n",
            lambda match: match.group(0) + "        isCoreLibraryDesugaringEnabled = true\n",
            text,
            count=1,
        )
        if count != 1:
            raise PatchError("compileOptions block not found in app/build.gradle.kts")

    desugaring_dependency = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
    if desugaring_dependency not in text:
        text, count = re.subn(
            r"(?m)^dependencies \{\n",
            lambda match: match.group(0) + desugaring_dependency + "\n",
            text,
            count=1,
        )
        if count == 0:
            text += "\ndependencies {\n" + desugaring_dependency + "\n}\n"

    if "isCoreLibraryDesugaringEnabled = true" not in text or desugaring_dependency not in text:
        raise PatchError("core library desugaring configuration could not be applied")

    return write_if_changed(path, text)



def patch_firebase(project: pathlib.Path) -> bool:
    import json
    source = project / "firebase" / "google-services.json"
    if not source.is_file():
        raise PatchError(f"{source} is missing; Firebase Android config is required")
    config = json.loads(source.read_text(encoding="utf-8"))
    package = config.get("client", [{}])[0].get("client_info", {}).get("android_client_info", {}).get("package_name")
    if package != "com.eurocars.euro_cars":
        raise PatchError(f"Firebase package mismatch: expected com.eurocars.euro_cars, got {package!r}")
    target = project / "android" / "app" / "google-services.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    copied = not target.exists() or target.read_bytes() != source.read_bytes()
    if copied:
        shutil.copyfile(source, target)
    settings = project / "android" / "settings.gradle.kts"
    settings_text = read(settings)
    settings_line = '    id("com.google.gms.google-services") version "4.4.2" apply false'
    if settings_line not in settings_text:
        if "plugins {\n" not in settings_text:
            raise PatchError("settings.gradle.kts plugins block not found")
        settings_text = settings_text.replace("plugins {\n", "plugins {\n" + settings_line + "\n", 1)
        write_if_changed(settings, settings_text)
    app_gradle = project / "android" / "app" / "build.gradle.kts"
    app_text = read(app_gradle)
    app_line = '    id("com.google.gms.google-services")'
    if app_line not in app_text:
        if "plugins {\n" not in app_text:
            raise PatchError("app/build.gradle.kts plugins block not found")
        app_text = app_text.replace("plugins {\n", "plugins {\n" + app_line + "\n", 1)
        write_if_changed(app_gradle, app_text)
    return copied

def copy_resources(source: pathlib.Path, target: pathlib.Path) -> int:
    if not source.is_dir():
        raise PatchError(f"{source} does not exist (the committed launcher icons are missing)")
    copied = 0
    for file in sorted(source.rglob("*")):
        if not file.is_file():
            continue
        destination = target / file.relative_to(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or destination.read_bytes() != file.read_bytes():
            shutil.copyfile(file, destination)
            copied += 1
    return copied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", default=".", help="Flutter project folder (default: current folder)")
    args = parser.parse_args()

    project = pathlib.Path(args.project).resolve()
    android = project / "android"
    try:
        if not android.is_dir():
            raise PatchError(f"{android} does not exist. Run `flutter create --platforms=android .` first.")
        manifest_changed = patch_manifest(android / "app" / "src" / "main" / "AndroidManifest.xml")
        gradle_file = android / "app" / "build.gradle.kts"
        if not gradle_file.is_file() and (android / "app" / "build.gradle").is_file():
            raise PatchError("android/app/build.gradle (Groovy) found, but this script expects the Kotlin DSL of Flutter 3.29+")
        gradle_changed = patch_gradle(gradle_file)
        firebase_copied = patch_firebase(project)
        copied = copy_resources(project / "branding" / "android" / "res", android / "app" / "src" / "main" / "res")
    except PatchError as error:
        print(f"prepare_android.py: {error}", file=sys.stderr)
        return 1

    print(
        "prepare_android.py: manifest {}, build.gradle.kts {}, {} resource file(s) copied".format(
            "patched" if manifest_changed else "already patched",
            "patched" if gradle_changed else "already patched",
            copied,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
