#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/audit-n1i-c2-install-collisions.py"

spec = importlib.util.spec_from_file_location("n1i_c2_install_collision", TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        out = root / "out"
        product = out / "target/product/tdgsi_arm64_ab"
        soong = out / "soong"
        soong.mkdir(parents=True)
        product.mkdir(parents=True)

        drm = "/system/lib64/android.hardware.drm-V1-ndk.so"
        mbrain = "/system_ext/lib64/vendor.mediatek.hardware.mbrain-V2-ndk.so"
        drm_final = mod.installed_path(product, drm)
        mbrain_final = mod.installed_path(product, mbrain)

        installs = soong / "installs-fixture.mk"
        installs.write_text(
            "\n".join(
                [
                    f"{drm_final}: {out}/soong/.intermediates/hardware/interfaces/drm/aidl/android.hardware.drm-V1-ndk/android_arm64_armv8-a_shared/android.hardware.drm-V1-ndk.so",
                    "\tcp $< $@",
                    f"{drm_final}: {out}/soong/.intermediates/vendor/sable/titan2/n1i-c2/SableN1IC2NativeM029/prebuilt.so",
                    "\tcp $< $@",
                    f"{mbrain_final}: {out}/soong/.intermediates/vendor/sable/titan2/n1i-c2/SableN1IC2NativeM037/prebuilt.so",
                    "\tcp $< $@",
                    "",
                ]
            ),
            encoding="utf-8",
        )

        drm_rules = mod.rule_locations([installs], drm_final)
        mbrain_rules = mod.rule_locations([installs], mbrain_final)

        assert len(drm_rules) == 2
        assert len(mbrain_rules) == 1
        assert "SableN1IC2NativeM029" in drm_rules[1][2]
        assert mod.owner_hints(drm_rules[0][2]) == "android.hardware.drm-V1-ndk"
        assert mod.owner_hints(drm_rules[1][2]) == "SableN1IC2NativeM029"

    print("N1I_C2_INSTALL_COLLISION_TEST_DUPLICATE_TARGET=PASS")
    print("N1I_C2_INSTALL_COLLISION_TEST_SINGLE_OWNER=PASS")
    print("N1I_C2_INSTALL_COLLISION_TEST_OWNER_HINT=PASS")
    print("N1I_C2_INSTALL_COLLISION_TEST_PLATFORM_OWNER_HINT=PASS")
    print("N1I_C2_INSTALL_COLLISION_AUDIT_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
