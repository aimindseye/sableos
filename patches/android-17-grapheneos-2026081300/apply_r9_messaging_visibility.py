#!/usr/bin/env python3
"""Hide GrapheneOS Messaging from the launcher while preserving SMS/MMS capability.

Target substrate:
  GrapheneOS 2026081300
  external/Messaging HEAD d125442740e85c8c630c6b3c1091046166b99187

Sable Messages / Hub is the intentional launcher-facing communication surface.
The mature GrapheneOS Messaging package remains installed for SMS/MMS role,
receivers, providers, notification routing and CATEGORY_APP_MESSAGING fallback.

Only the LAUNCHER category is removed from ConversationListActivity's alias.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

MESSAGING_REPO = Path("external/Messaging")
MESSAGING_HEAD = "d125442740e85c8c630c6b3c1091046166b99187"
MANIFEST = MESSAGING_REPO / "AndroidManifest.xml"

OLD_ALIAS = """        <activity-alias
            android:name=".ui.conversationlist.ConversationListActivity"
            android:exported="true"
            android:targetActivity=".ui.MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.APP_MESSAGING" />
            </intent-filter>
        </activity-alias>
"""

NEW_ALIAS = """        <activity-alias
            android:name=".ui.conversationlist.ConversationListActivity"
            android:exported="true"
            android:targetActivity=".ui.MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <!-- Sable Messages owns launcher exposure. Keep the system
                     messaging selector so Android/Sable can still route into
                     the mature SMS/MMS client when capability fallback is
                     required. -->
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.APP_MESSAGING" />
            </intent-filter>
        </activity-alias>
"""


class VisibilityError(RuntimeError):
    pass


def run_git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args],
        text=True,
        stderr=subprocess.STDOUT,
    ).strip()


def assert_head(source: Path) -> None:
    repo = source / MESSAGING_REPO
    actual = run_git(repo, "rev-parse", "HEAD")
    if actual != MESSAGING_HEAD:
        raise VisibilityError(
            f"MESSAGING_HEAD_MISMATCH expected={MESSAGING_HEAD} actual={actual}"
        )


def status(source: Path) -> set[str]:
    out = run_git(
        source / MESSAGING_REPO,
        "status",
        "--porcelain",
        "--untracked-files=all",
    )
    return {line for line in out.splitlines() if line}


def transform(text: str) -> str:
    if NEW_ALIAS in text:
        return text
    count = text.count(OLD_ALIAS)
    if count != 1:
        raise VisibilityError(
            f"MESSAGING_ALIAS_PRECONDITION_FAIL count={count}"
        )
    return text.replace(OLD_ALIAS, NEW_ALIAS, 1)


def verify_text(text: str) -> None:
    if NEW_ALIAS not in text:
        raise VisibilityError("MESSAGING_VISIBILITY_PATCH_MISSING")
    alias = text.split(
        'android:name=".ui.conversationlist.ConversationListActivity"',
        1,
    )[1].split("</activity-alias>", 1)[0]
    if "android.intent.category.LAUNCHER" in alias:
        raise VisibilityError("MESSAGING_LAUNCHER_CATEGORY_STILL_PRESENT")
    if "android.intent.category.APP_MESSAGING" not in alias:
        raise VisibilityError("MESSAGING_APP_MESSAGING_FALLBACK_MISSING")
    if "android.intent.category.DEFAULT" not in alias:
        raise VisibilityError("MESSAGING_DEFAULT_CATEGORY_MISSING")

    # Preserve transport/default-app capability surfaces.
    required = (
        "android.provider.Telephony.SMS_DELIVER",
        "android.provider.Telephony.WAP_PUSH_DELIVER",
        "android.intent.action.RESPOND_VIA_MESSAGE",
        'android:scheme="sms"',
        'android:scheme="mms"',
    )
    for needle in required:
        if needle not in text:
            raise VisibilityError(
                f"MESSAGING_TRANSPORT_CAPABILITY_MISSING={needle}"
            )


def apply(source: Path) -> None:
    assert_head(source)
    repo = source / MESSAGING_REPO
    dirt = status(source)
    if dirt:
        raise VisibilityError(
            "MESSAGING_SOURCE_NOT_CLEAN=" + "|".join(sorted(dirt))
        )

    path = source / MANIFEST
    path.write_text(
        transform(path.read_text(encoding="utf-8")),
        encoding="utf-8",
    )
    verify(source)


def verify(source: Path) -> None:
    assert_head(source)
    path = source / MANIFEST
    verify_text(path.read_text(encoding="utf-8"))
    expected = {" M AndroidManifest.xml"}
    actual = status(source)
    if actual != expected:
        raise VisibilityError(
            f"MESSAGING_DIRTY_SCOPE_MISMATCH expected={sorted(expected)!r} "
            f"actual={sorted(actual)!r}"
        )
    print("R9_GRAPHENE_MESSAGING_PACKAGE_RETAINED=PASS")
    print("R9_GRAPHENE_MESSAGING_LAUNCHER_EXPOSURE=PASS_HIDDEN")
    print("R9_GRAPHENE_MESSAGING_APP_MESSAGING_FALLBACK=PASS")
    print("R9_GRAPHENE_MESSAGING_TRANSPORT_SURFACES=PASS")


def self_test() -> None:
    out = transform(OLD_ALIAS)
    verify_text(
        out
        + """
        <receiver><intent-filter>
          <action android:name="android.provider.Telephony.SMS_DELIVER" />
          <action android:name="android.provider.Telephony.WAP_PUSH_DELIVER" />
        </intent-filter></receiver>
        <service><intent-filter>
          <action android:name="android.intent.action.RESPOND_VIA_MESSAGE" />
          <data android:scheme="sms" />
          <data android:scheme="mms" />
        </intent-filter></service>
        """
    )
    if "android.intent.category.LAUNCHER" in out:
        raise VisibilityError("SELF_TEST_LAUNCHER_CATEGORY_PRESENT")
    if "android.intent.category.APP_MESSAGING" not in out:
        raise VisibilityError("SELF_TEST_FALLBACK_REMOVED")
    print("R9_MESSAGING_VISIBILITY_SELF_TEST=PASS")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("mode", nargs="?", choices=("apply", "verify"))
    p.add_argument("--source", type=Path)
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()

    if args.self_test:
        self_test()
        return 0

    if args.mode is None or args.source is None:
        p.error("mode and --source are required unless --self-test is used")

    source = args.source.resolve()
    if not (source / ".repo").exists():
        raise VisibilityError(f"NOT_ANDROID_REPO_ROOT={source}")

    if args.mode == "apply":
        apply(source)
    else:
        verify(source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
