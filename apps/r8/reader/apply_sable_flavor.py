#!/usr/bin/env python3
"""Inject the bounded Sable Reader flavor into a pinned Vaachak checkout.

This script deliberately does not rewrite Vaachak's Readium/core implementation.
It adds a product flavor, Sable branding, and an offline-first manifest overlay.
The upstream checkout is ephemeral CI input; the canonical source repository is
not mutated by SableOS qualification.
"""

from __future__ import annotations

import pathlib
import sys


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: apply_sable_flavor.py <vaachak-checkout>")

    root = pathlib.Path(sys.argv[1]).resolve()
    gradle_file = root / "leisure" / "build.gradle.kts"
    if not gradle_file.is_file():
        fail(f"missing {gradle_file}")

    text = gradle_file.read_text(encoding="utf-8")
    anchor = "    val releaseSigningConfig = if (isReleaseLikeTaskRequested) {\n"
    if anchor not in text:
        fail("Vaachak Gradle anchor changed; inspect upstream before updating the pin")
    if 'create("sable")' in text:
        fail("Sable flavor already present; refusing an ambiguous double patch")

    flavor = '''    flavorDimensions += "product"\n    productFlavors {\n        create("vaachak") {\n            dimension = "product"\n            buildConfigField("boolean", "SABLE_PRODUCT", "false")\n        }\n        create("sable") {\n            dimension = "product"\n            applicationId = "org.sableos.reader"\n            buildConfigField("boolean", "SABLE_PRODUCT", "true")\n        }\n    }\n\n'''
    gradle_file.write_text(text.replace(anchor, flavor + anchor, 1), encoding="utf-8")

    values = root / "leisure" / "src" / "sable" / "res" / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "strings.xml").write_text(
        '<resources>\n    <string name="app_name">Sable Reader</string>\n</resources>\n',
        encoding="utf-8",
    )

    manifest_dir = root / "leisure" / "src" / "sable"
    manifest_dir.mkdir(parents=True, exist_ok=True)
    (manifest_dir / "AndroidManifest.xml").write_text(
        '''<?xml version="1.0" encoding="utf-8"?>\n'''
        '''<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'''
        '''    xmlns:tools="http://schemas.android.com/tools">\n'''
        '''    <uses-permission\n'''
        '''        android:name="android.permission.INTERNET"\n'''
        '''        tools:node="remove" />\n'''
        '''</manifest>\n''',
        encoding="utf-8",
    )

    print("SABLE_READER_FLAVOR_PATCH=PASS")
    print("SABLE_READER_NETWORK_PERMISSION=REMOVED_BY_FLAVOR_OVERLAY")
    print("SABLE_READER_UPSTREAM_CORE=UNCHANGED")


if __name__ == "__main__":
    main()
