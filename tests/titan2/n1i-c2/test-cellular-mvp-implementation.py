#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"
BP = ROOT / "product/titan2/n1i-c2/Android.bp"
MK = ROOT / "product/titan2/n1i-c2/sable-titan2-n1i-c2.mk"
SCRIPT = ROOT / "product/titan2/n1i-c2/sable-titan2-cellular.sh"
RC = ROOT / "product/titan2/n1i-c2/sable-titan2-cellular.rc"
MARKER = ROOT / "product/titan2/n1i-c2/titan2-cellular-mvp"
PHH_PATCH = ROOT / "patches/android-16-n1i-c2/phh/0001-phh-preserve-mtk-ims-for-titan2-cellular-mvp.patch"
TM_PATCH = ROOT / "patches/android-16-n1i-c1/telephony/0001-telephony-add-titan2-legacy-writeRilAnswer-overload.patch"
DRIVER = ROOT / "build/titan2/run-n1i-c2-cellular-mvp.sh"
PREFLIGHT = ROOT / "build/titan2/run-n1i-c2-native-install-preflight.sh"

EXPECTED_PHH_PATCH_BLOB = "d78f41da30514920ff2165d8fe6dea15d0bb5d76"
EXPECTED_TMETRICS_PATCH_BLOB = "ee353caded6dd07318991eb52d66687e06034c30"


def git_blob(path: Path) -> str:
    data = path.read_bytes()
    h = hashlib.sha1()
    h.update(f"blob {len(data)}\0".encode())
    h.update(data)
    return h.hexdigest()


def a4_targets() -> list[str]:
    rows = [
        line.strip()
        for line in A4.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    assert len(rows) == 33
    assert len(set(rows)) == 33
    return rows


def test_native_modules() -> None:
    text = BP.read_text(encoding="utf-8")
    refs = re.findall(
        r'name:\s*"(SableN1IC2NativeM\d{3})".*?'
        r'srcs:\s*\["prebuilt([^"]+\.so)"\]',
        text,
        re.S,
    )
    assert len(refs) == 33, len(refs)
    names = {name for name, _target in refs}
    expected_names = {f"SableN1IC2NativeM{i:03d}" for i in range(7, 40)}
    assert names == expected_names
    targets = {target for _name, target in refs}
    assert targets == set(a4_targets())

    for name, target in refs:
        start = text.index(f'name: "{name}"')
        next_start = text.find("cc_prebuilt_library_shared {", start + 1)
        block = text[start: next_start if next_start >= 0 else len(text)]
        assert 'compile_multilib: "64"' in block
        assert "none: true" in block
        assert "check_elf_files: false" in block
        if target.startswith("/system_ext/"):
            assert "system_ext_specific: true" in block
        elif target.startswith("/product/"):
            assert "product_specific: true" in block
        else:
            assert target.startswith("/system/")


def test_product_composition() -> None:
    text = MK.read_text(encoding="utf-8")
    assert "vendor/sable/titan2/n1i-c1/sable-titan2-n1i-c1.mk" in text
    assert "vendor/sable/titan2/n1i-c2/native-packages.mk" in text
    for i in range(7, 40):
        assert f"SableN1IC2NativeM{i:03d}" not in text
    assert "SableTitan2Cellular" in text
    assert "SableTitan2CellularInit" in text
    assert "SableTitan2CellularConfig" in text
    assert "SableTitan2CellularMarker" in text
    assert "ro.telephony.block_binder_thread_on_incoming_calls=false" in text


def executable_lines(text: str) -> str:
    return "\n".join(
        line for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )


def test_integration_safety() -> None:
    text = SCRIPT.read_text(encoding="utf-8")
    live = executable_lines(text)
    assert "/data/local/tmp/sable-titan2-cellular-healer.enable" in text
    assert "cmd phone ims get-ims-service" in text
    assert "cmd phone ims set-ims-service" in text
    assert "cmd phone ims enable" in text
    assert "active_or_emergency_call" in text
    assert "COOLDOWN_SECONDS=300" in text
    assert "OBSERVE_READINESS" in text
    assert "SABLE_TITAN2_VENDOR_UA_START_MODE" in text
    assert "UA_OK=YES" in text
    assert 'VENDOR_UA_START_MODE" != "disabled"' in text
    assert '"$UA" = "running"' in text

    forbidden = (
        r"\bsetenforce\b",
        r"\breboot\b",
        r"\bkill\s+-9\b",
        r"setprop\s+ctl\.start",
        r"setprop\s+persist\.mtk_ims_support",
        r"setprop\s+persist\.mtk_epdg_support",
        r"svc\s+data",
        r"airplane_mode",
        r"ctl\.restart",
    )
    for pattern in forbidden:
        assert re.search(pattern, live) is None, pattern


def test_init_and_marker() -> None:
    rc = RC.read_text(encoding="utf-8")
    assert "on property:sys.boot_completed=1" in rc
    assert "start sable_titan2_cellular_probe" in rc
    assert "oneshot" in rc
    assert "user shell" in rc
    assert "seclabel u:r:shell:s0" in rc

    marker = MARKER.read_text(encoding="utf-8")
    assert "N1I_C2_CELLULAR_MVP=1" in marker
    assert "HEALER_DEFAULT=DISABLED" in marker


def test_patch_authority() -> None:
    assert git_blob(PHH_PATCH) == EXPECTED_PHH_PATCH_BLOB
    assert git_blob(TM_PATCH) == EXPECTED_TMETRICS_PATCH_BLOB

    text = PHH_PATCH.read_text(encoding="utf-8")
    assert text.count("diff --git ") == 1
    assert "diff --git a/phh-on-boot.sh b/phh-on-boot.sh" in text
    assert "/system_ext/etc/sable/titan2-cellular-mvp" in text
    assert "setprop persist.mtk_ims_support 0" in text
    assert "setprop persist.mtk_epdg_support 0" in text
    assert "reboot" in text


def test_driver_authority() -> None:
    text = DRIVER.read_text(encoding="utf-8")
    assert "source_mutation_requires_authorization" in text
    assert "build_requires_authorization" in text
    assert "MUTATION_COUNT=41" in text
    assert "FROZEN_STOCK_FILE_COUNT=36" in text
    assert "FROZEN_NATIVE_COUNT=33" in text
    assert "IMPLEMENTATION_RECEIPT_ROWS=41" in text
    assert "20261005T231205Z" in text
    assert "SABLE_TITAN2_VENDOR_UA_START_MODE" in text
    assert "N1I_C2_EVIDENCE_SEAL=PASS_EXCLUDES_BUILD_LOG" in text
    assert "adb57fa5bffb24e2fe24f4f0afc6b5550bb570f3" in text
    assert 'PHH_BASE_BLOB="9f65610762fec239638bb269b8c72d6cabfc6d7e"' in text
    assert 'INCOMING_TRACKER_BLOB="5f97183b6f8c80859adf3f4922b3f9f56687bab5"' in text
    assert 'SYSTEM_GROUP_SAFE_CEILING=3263168512' in text
    assert 'C1_SHA="137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160"' in text
    assert 'MTK_MMTEL_OVERLAY_MODULE="treble-overlay-telephony-mtk-ims"' in text
    assert 'MTK_MMTEL_OVERLAY_PACKAGE="me.phh.treble.overlay.mtkims_telephony"' in text
    assert "CELLULAR_MVP_IMPLEMENTATION_RECEIPT.tsv" in text
    assert "N1I_C2_MMTEL_OVERLAY_APK=PASS" in text
    assert "N1I_C2_STOCK_MAP=FAIL_A4_TARGET_SET" in text
    assert "N1I_C2_OEM_IMS_PLATFORM_RESIGN=PASS" in text
    assert "N1I_C2_EMERGENCY_SOURCE_RESTORE=PASS" in text
    assert "OEM_IMS_PLATFORM_RESIGNED=YES" in text
    assert 'python3 "$ROOT/build/gates/build-regression-contract.py"' in text
    assert "N1I_C2_BUILD_REGRESSION_PREFLIGHT=PASS" in text
    assert "NATIVE_ADMISSION_INTEGRATED=NO" in text
    assert "native_admission_not_integrated" in text
    assert text.count("#!/usr/bin/env bash") == 1
    assert text.count("selfcheck() {") == 1
    assert text.count('echo "===== APPLY EXACT C2 SOURCE DELTA ====="') == 1
    assert text.count('echo "===== BUILD ONE ANDROID 16 CELLULAR MVP SYSTEMIMAGE ====="') == 1
    assert text.count('make systemimage -j"$JOBS"') == 1
    assert "DEVICE_CONTACT_AUTHORIZED=NO" in text
    assert "FLASH_AUTHORIZED=NO" in text


def test_native_preflight_authority() -> None:
    text = PREFLIGHT.read_text(encoding="utf-8")
    assert "SOURCE_MUTATION_AUTHORIZED=NO" in text
    assert "BUILD_AUTHORIZED=NO" in text
    assert "DEVICE_CONTACT_AUTHORIZED=NO" in text
    assert "NETWORK_FETCH_AUTHORIZED=NO" in text
    assert "FLASH_AUTHORIZED=NO" in text
    assert "137bc8771c817c0afb3122d9f03e7a94575e03bcccc643b56235edd1075f2160" in text
    assert "36b53950faebc954cadb30756833ae5ec857f054" in text
    assert "audit-n1i-c2-install-collisions.py" in text
    assert "plan-n1i-c2-native-install.py" in text
    assert "native-baseline-probe.tsv" in text
    assert "native-composition.tsv" in text
    assert "/system/lib64/android.hardware.drm-V1-ndk.so" in text
    assert "N1I_C2_NATIVE_INSTALL_PREFLIGHT=PASS" in text
    assert "make systemimage" not in text
    assert "adb " not in text
    assert "fastboot " not in text



def test_receipt_semantics() -> None:
    text = DRIVER.read_text(encoding="utf-8")
    assert 'expected_ids = [f"M{i:03d}" for i in range(1, 42)]' in text
    assert 'status["M004"] = "IMPLEMENTED_EXACT_PATCH"' in text
    assert 'status["M005"] = "IMPLEMENTED_PRODUCT_PROPERTY"' in text
    assert 'status["M006"] = "IMPLEMENTED_EXACT_PATCH"' in text
    assert 'status["M040"] = "IMPLEMENTED_BUILT"' in text
    assert 'status["M041"] = "IMPLEMENTED_DISABLED_BY_DEFAULT"' in text
    assert "PRODUCT_OUT_HASH_EQUALS_MATERIALIZATION" in text
    assert "IMPLEMENTATION_RECEIPT_ROWS=41" in text


def main() -> int:
    test_native_modules()
    test_product_composition()
    test_integration_safety()
    test_init_and_marker()
    test_patch_authority()
    test_driver_authority()
    test_native_preflight_authority()
    test_receipt_semantics()

    print("N1I_C2_IMPLEMENTATION_TEST_NATIVE_MODULE_SET=PASS count=33")
    print("N1I_C2_IMPLEMENTATION_TEST_PRODUCT_COMPOSITION=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_INTEGRATION_SAFETY=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_INIT_MARKER=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_PATCH_AUTHORITY=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_DRIVER_AUTHORITY=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_NATIVE_PREFLIGHT_AUTHORITY=PASS")
    print("N1I_C2_IMPLEMENTATION_TEST_RECEIPT_SEMANTICS=PASS")
    print("N1I_C2_CELLULAR_MVP_IMPLEMENTATION_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
