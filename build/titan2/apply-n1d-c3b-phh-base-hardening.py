#!/usr/bin/env python3
"""Apply/verify the C3B security reduction against pinned TrebleDroid base.mk."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import subprocess
import sys

EXPECTED_HEAD = "39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed"
EXPECTED_BASE_BLOB = "a29e402009d449150f1216e5d517ec0c9b36bfbd"
TARGET = pathlib.PurePosixPath("base.mk")

TRANSFORMS: tuple[tuple[str, str, str], ...] = (
    (
        "drop_phh_sepolicy_and_external_overlay",
        r"""SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/phh/treble/sepolicy
PRODUCT_PACKAGE_OVERLAYS += device/phh/treble/overlay

$(call inherit-product, vendor/hardware_overlay/overlay.mk)
""",
        "",
    ),
    (
        "drop_insecure_adb_property",
        "    ro.adb.secure=0 \\\n",
        "",
    ),
    (
        "drop_adb_default_usb",
        "    persist.sys.usb.config=adb \\\n",
        "",
    ),
    (
        "drop_phh_mutation_boot_hooks",
        r"""PRODUCT_COPY_FILES += \
    device/phh/treble/rw-system.sh:system/bin/rw-system.sh \
    device/phh/treble/phh-on-boot.sh:system/bin/phh-on-boot.sh \
    device/phh/treble/phh-on-data.sh:system/bin/phh-on-data.sh \
    device/phh/treble/phh-prop-handler.sh:system/bin/phh-prop-handler.sh \
    device/phh/treble/fixSPL/getSPL.arm:system/bin/getSPL
""",
        r"""PRODUCT_COPY_FILES += \
    device/phh/treble/fixSPL/getSPL.arm:system/bin/getSPL
""",
    ),
    (
        "drop_twrp_busybox",
        r"""PRODUCT_COPY_FILES += \
    device/phh/treble/twrp/twrp.rc:system/etc/init/twrp.rc \
    device/phh/treble/twrp/twrp.sh:system/bin/twrp.sh \
    device/phh/treble/twrp/busybox-armv7l:system/bin/busybox_phh

""",
        "",
    ),
    (
        "drop_neverallow_bypass",
        "SELINUX_IGNORE_NEVERALLOWS := true\n",
        "",
    ),
    (
        "drop_mtk_sms_helper",
        r"""# MTK incoming SMS fix
PRODUCT_PACKAGES += \
    mtk-sms-fwk-ready

""",
        "",
    ),
    (
        "drop_phh_root_ota_mutation",
        r"""PRODUCT_PACKAGES += \
    resetprop_phh

PRODUCT_COPY_FILES += \
    device/phh/treble/phh-securize.sh:system/bin/phh-securize.sh \
    device/phh/treble/files/ota.sh:system/bin/ota.sh \

PRODUCT_COPY_FILES += \
    device/phh/treble/remove-telephony.sh:system/bin/remove-telephony.sh \

""",
        "",
    ),
    (
        "drop_phh_adbd_override",
        r"""PRODUCT_COPY_FILES += \
    device/phh/treble/files/adbd.rc:system/etc/init/adbd.rc

""",
        "",
    ),
    (
        "drop_trebleapp_privilege_files",
        r"""# Privapp-permissions whitelist for PhhTrebleApp
PRODUCT_COPY_FILES += \
    device/phh/treble/privapp-permissions-me.phh.treble.app.xml:system/etc/permissions/privapp-permissions-me.phh.treble.app.xml \
    device/phh/treble/sysconfig-me.phh.treble.app.xml:system/etc/sysconfig/sysconfig-me.phh.treble.app.xml

""",
        "",
    ),
    (
        "drop_phh_remote_debug",
        r"""# Remote debugging
PRODUCT_COPY_FILES += \
    device/phh/treble/remote/dbclient:system/bin/dbclient \
    device/phh/treble/remote/phh-remotectl.rc:system/etc/init/phh-remotectl.rc \
    device/phh/treble/remote/phh-remotectl.sh:system/bin/phh-remotectl.sh \

""",
        "",
    ),
    (
        "drop_phh_ota_service",
        "PRODUCT_PACKAGES += phh-ota\n\n",
        "",
    ),
    (
        "drop_qcom_incall_helper",
        r"""# QCOM in-call audio fix as a standalone app
PRODUCT_PACKAGES += \
    QcRilAm

""",
        "",
    ),
    (
        "drop_vendor_specific_boot_and_mtk_incall_helpers",
        r"""PRODUCT_PACKAGES += \
    slsi-booted \
    Iwlan \
    QualifiedNetworksService \
    MtkInCallService \

""",
        r"""PRODUCT_PACKAGES += \
    Iwlan \
    QualifiedNetworksService \

""",
    ),
)


def git_blob(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def git(*args: str, cwd: pathlib.Path) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()


def transform(text: str) -> str:
    output = text
    for label, old, new in TRANSFORMS:
        count = output.count(old)
        if count != 1:
            raise RuntimeError(f"{label}: expected exactly one source block, found {count}")
        output = output.replace(old, new, 1)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("check", "apply", "verify"))
    parser.add_argument("--repo", required=True, type=pathlib.Path)
    args = parser.parse_args()

    repo = args.repo.resolve()
    target = repo / TARGET

    head = git("rev-parse", "HEAD", cwd=repo)
    if head != EXPECTED_HEAD:
        raise RuntimeError(f"unexpected_head expected={EXPECTED_HEAD} actual={head}")

    base_bytes = subprocess.run(
        ["git", "show", f"HEAD:{TARGET}"],
        cwd=repo,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    base_blob = git_blob(base_bytes)
    if base_blob != EXPECTED_BASE_BLOB:
        raise RuntimeError(
            f"unexpected_base_blob expected={EXPECTED_BASE_BLOB} actual={base_blob}"
        )

    base_text = base_bytes.decode("utf-8")
    hardened_text = transform(base_text)
    hardened_bytes = hardened_text.encode("utf-8")
    hardened_blob = git_blob(hardened_bytes)

    current_bytes = target.read_bytes()
    current_blob = git_blob(current_bytes)

    if args.mode == "check":
        if current_blob != EXPECTED_BASE_BLOB:
            raise RuntimeError(
                f"check_requires_clean_base expected={EXPECTED_BASE_BLOB} actual={current_blob}"
            )
        print(f"N1D_C3B_PHH_BASE_CHECK=PASS base_blob={base_blob}")
        print(f"N1D_C3B_PHH_BASE_EXPECTED_POST_BLOB={hardened_blob}")
        return 0

    if args.mode == "apply":
        if current_blob == hardened_blob:
            print(f"N1D_C3B_PHH_BASE_APPLY=PASS_ALREADY_PRESENT post_blob={hardened_blob}")
            return 0
        if current_blob != EXPECTED_BASE_BLOB:
            raise RuntimeError(
                f"apply_requires_exact_base expected={EXPECTED_BASE_BLOB} actual={current_blob}"
            )
        target.write_bytes(hardened_bytes)
        actual = git_blob(target.read_bytes())
        if actual != hardened_blob:
            raise RuntimeError(
                f"post_write_blob expected={hardened_blob} actual={actual}"
            )
        print(f"N1D_C3B_PHH_BASE_APPLY=PASS post_blob={hardened_blob}")
        return 0

    if current_blob != hardened_blob:
        raise RuntimeError(
            f"verify_post_blob expected={hardened_blob} actual={current_blob}"
        )

    forbidden = (
        "SELINUX_IGNORE_NEVERALLOWS := true",
        "ro.adb.secure=0",
        "persist.sys.usb.config=adb",
        "vendor/hardware_overlay/overlay.mk",
        "device/phh/treble/sepolicy",
        "rw-system.sh",
        "phh-on-boot.sh",
        "phh-on-data.sh",
        "phh-prop-handler.sh",
        "busybox_phh",
        "mtk-sms-fwk-ready",
        "resetprop_phh",
        "phh-securize.sh",
        "files/ota.sh",
        "remove-telephony.sh",
        "files/adbd.rc",
        "privapp-permissions-me.phh.treble.app.xml",
        "sysconfig-me.phh.treble.app.xml",
        "phh-remotectl",
        "phh-ota",
        "QcRilAm",
        "MtkInCallService",
        "slsi-booted",
    )
    for token in forbidden:
        if token in hardened_text:
            raise RuntimeError(f"forbidden_token_present={token}")

    for token in ("Iwlan", "QualifiedNetworksService", "getSPL"):
        if token not in hardened_text:
            raise RuntimeError(f"required_token_missing={token}")

    print(f"N1D_C3B_PHH_BASE_VERIFY=PASS base_blob={base_blob} post_blob={hardened_blob}")
    print(f"N1D_C3B_PHH_BASE_SECURITY_REDUCTIONS=PASS count={len(TRANSFORMS)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.CalledProcessError, UnicodeDecodeError) as exc:
        print(f"N1D_C3B_PHH_BASE_HARDENING=FAIL {exc}", file=sys.stderr)
        raise SystemExit(1)
