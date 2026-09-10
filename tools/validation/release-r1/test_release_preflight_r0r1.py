from __future__ import annotations

import zipfile
from pathlib import Path

import SABLE_R1_R0R1_RELEASE_PREFLIGHT as r


def test_bound_base_sha256():
    assert r.sha256_file(r.BASE_SCRIPT) == r.BASE_SCRIPT_SHA256


def test_generator_subject_accepts_indentation_and_quotes(tmp_path: Path):
    p = tmp_path / "generate-keys"
    p.write_text('    CN=GrapheneOS\n', encoding="utf-8")
    assert r.parse_key_generator_subject(p) == "GrapheneOS"
    p.write_text('  CN="SableOS"\n', encoding="utf-8")
    assert r.parse_key_generator_subject(p) == "SableOS"


def test_android_info_product_parser():
    assert r.parse_android_info_products(
        "require product=panther\nrequire version-bootloader=foo\n"
    ) == ("panther",)
    assert r.parse_android_info_products(
        "require product=panther|cheetah\n"
    ) == ("panther", "cheetah")


def test_ota_product_identity_overrides_generic_system(tmp_path: Path):
    zpath = tmp_path / "tf.zip"
    with zipfile.ZipFile(zpath, "w") as z:
        z.writestr(
            "SYSTEM/build.prop",
            "ro.build.type=userdebug\n"
            "ro.build.tags=test-keys\n"
            "ro.product.device=generic\n",
        )
        z.writestr("OTA/android-info.txt", "require product=panther\n")
    with zipfile.ZipFile(zpath) as z:
        props, sources = r.find_build_properties(z)
    assert props["ro.product.device"] == "panther"
    assert "OTA/android-info.txt(product)" in sources


def test_partition_fallback_rejects_generic_system(tmp_path: Path):
    zpath = tmp_path / "tf.zip"
    with zipfile.ZipFile(zpath, "w") as z:
        z.writestr(
            "SYSTEM/build.prop",
            "ro.build.type=userdebug\n"
            "ro.build.tags=test-keys\n"
            "ro.product.device=generic\n",
        )
        z.writestr("PRODUCT/build.prop", "ro.product.device=panther\n")
    with zipfile.ZipFile(zpath) as z:
        props, sources = r.find_build_properties(z)
    assert props["ro.product.device"] == "panther"
    assert "PRODUCT/build.prop(product)" in sources


def test_correction_layer_has_no_execution_backend():
    text = Path(r.__file__).read_text(encoding="utf-8")
    assert "subprocess" not in text
    assert "os.system" not in text
    assert "Popen(" not in text
