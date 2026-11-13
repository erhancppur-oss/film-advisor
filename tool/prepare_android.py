#!/usr/bin/env python3
"""Generate / patch the Android project so it is ready for Google Play.

* runs `flutter create --platforms=android .` if android/ is missing
* sets applicationId, targetSdk >= 36 (Google Play requirement from 31 Aug 2026)
* adds release signing from android/key.properties (falls back to debug key)
* adds INTERNET permission + <queries> needed by url_launcher on Android 11+
* localized app name (values / values-tr)

Idempotent: safe to run many times.  Usage:
    python3 tool/prepare_android.py [--app-id com.yourname.filmadvisor]
"""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
APP = ANDROID / "app"
MIN_TARGET_SDK = 36

APP_NAME_EN = "Film Advisor"
APP_NAME_TR = "Film Advisor"


def run(cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def patch_gradle_kts(path: pathlib.Path, app_id: str):
    s = path.read_text()
    orig = s

    if "keystoreProperties" not in s:
        header = (
            "import java.io.FileInputStream\n"
            "import java.util.Properties\n\n"
        )
        s = header + s
        loader = (
            "val keystoreProperties = Properties()\n"
            "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        s = s.replace("android {", loader + "android {", 1)

    s = re.sub(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{app_id}"', s)
    s = re.sub(r"compileSdk\s*=\s*flutter\.compileSdkVersion",
               f"compileSdk = maxOf({MIN_TARGET_SDK}, flutter.compileSdkVersion)", s)
    s = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion",
               f"targetSdk = maxOf({MIN_TARGET_SDK}, flutter.targetSdkVersion)", s)

    if 'create("release")' not in s:
        signing = (
            "    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            if (keystorePropertiesFile.exists()) {\n"
            "                keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
            "                keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
            "                storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
            "                storePassword = keystoreProperties[\"storePassword\"] as String\n"
            "            }\n"
            "        }\n"
            "    }\n\n"
            "    buildTypes {"
        )
        s = s.replace("    buildTypes {", signing, 1)

    s = s.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = if (keystorePropertiesFile.exists()) '
        'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
    )

    if s != orig:
        path.write_text(s)
        print(f"patched {path.relative_to(ROOT)}")
    for needle in ("maxOf(36", 'applicationId = "', 'getByName("release")'):
        if needle not in s:
            sys.exit(f"ERROR: could not patch {path} (missing {needle!r}). Edit it manually.")


def patch_manifest(path: pathlib.Path):
    s = path.read_text()
    orig = s
    if "android.permission.INTERNET" not in s:
        s = re.sub(r"(<manifest[^>]*>)",
                   r'\1\n    <uses-permission android:name="android.permission.INTERNET" />',
                   s, count=1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', s, count=1)

    queries = (
        "        <intent>\n"
        "            <action android:name=\"android.intent.action.VIEW\" />\n"
        "            <data android:scheme=\"https\" />\n"
        "        </intent>\n"
        "        <intent>\n"
        "            <action android:name=\"android.intent.action.SENDTO\" />\n"
        "            <data android:scheme=\"mailto\" />\n"
        "        </intent>\n"
    )
    if 'android:scheme="https"' not in s:
        if "<queries>" in s:
            s = s.replace("<queries>", "<queries>\n" + queries, 1)
        else:
            s = s.replace("</manifest>", "    <queries>\n" + queries + "    </queries>\n</manifest>", 1)
    if s != orig:
        path.write_text(s)
        print(f"patched {path.relative_to(ROOT)}")


def write_strings():
    for folder, name in (("values", APP_NAME_EN), ("values-tr", APP_NAME_TR)):
        d = APP / "src" / "main" / "res" / folder
        d.mkdir(parents=True, exist_ok=True)
        f = d / "strings.xml"
        f.write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <string name="app_name">{name}</string>\n'
            "</resources>\n"
        )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app-id", default="com.filmadvisor.app",
                    help="Unique Play Store package name, e.g. com.yourname.filmadvisor")
    args = ap.parse_args()

    if not (ANDROID / "app").exists():
        run(["flutter", "create", "--platforms=android", "--org", "com.filmadvisor",
             "--project-name", "film_advisor", "."])

    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"
    if kts.exists():
        patch_gradle_kts(kts, args.app_id)
    elif groovy.exists():
        sys.exit("ERROR: Groovy build.gradle found. Please upgrade Flutter (>=3.29) "
                 "or delete android/ and re-run this script.")
    else:
        sys.exit("ERROR: android/app/build.gradle(.kts) not found")

    patch_manifest(APP / "src" / "main" / "AndroidManifest.xml")
    write_strings()
    print("Android project ready. applicationId =", args.app_id)


if __name__ == "__main__":
    main()
