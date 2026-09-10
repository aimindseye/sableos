from __future__ import annotations

import types
import zipfile
from pathlib import Path

import pytest

import SABLE_R1_R0R2_RELEASE_PREFLIGHT as r


class FakeBase(types.ModuleType):
    pass


def make_fake_base(tmp_path: Path):
    base = FakeBase("fake_base")
    base.EXPECTED_DEVICE = "panther"
    base.__file__ = str(tmp_path / "base.py")
    calls = {"original_find": 0, "main": 0}

    def original_subject(path: Path):
        return "ORIGINAL"

    def original_find(zf: zipfile.ZipFile):
        calls["original_find"] += 1
        text = zf.read("SYSTEM/build.prop").decode()
        props = {}
        for line in text.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                props[k] = v
        return props, ["SYSTEM/build.prop"]

    base.parse_key_generator_subject = original_subject
    base.find_build_properties = original_find

    def main(argv=None):
        calls["main"] += 1
        zpath = tmp_path / "fixture.zip"
        with zipfile.ZipFile(zpath) as z:
            props, sources = base.find_build_properties(z)
        assert props["ro.product.device"] == "panther"
        assert "OTA/android-info.txt(product)" in sources
        return 3

    base.main = main
    return base, calls, original_subject, original_find


def make_zip(tmp_path: Path, *, ota=True, product_fallback=False):
    zpath = tmp_path / "fixture.zip"
    with zipfile.ZipFile(zpath, "w") as z:
        z.writestr(
            "SYSTEM/build.prop",
            "ro.build.type=userdebug\n"
            "ro.build.tags=test-keys\n"
            "ro.product.device=generic\n",
        )
        if ota:
            z.writestr("OTA/android-info.txt", "require product=panther\n")
        if product_fallback:
            z.writestr("PRODUCT/build.prop", "ro.product.device=panther\n")
    return zpath


def test_generator_subject_indentation_quotes_comments(tmp_path: Path):
    p = tmp_path / "generate-keys"
    cases = {
        "    CN=GrapheneOS\n": "GrapheneOS",
        "\tCN = SableOS\n": "SableOS",
        "  CN='Sable OS' # subject\n": "Sable OS",
        ' CN="SableOS"\n': "SableOS",
    }
    for text, expected in cases.items():
        p.write_text(text, encoding="utf-8")
        assert r.parse_key_generator_subject(p) == expected


def test_android_info_multiple_products_are_deduplicated():
    text = (
        "require product=panther|cheetah\n"
        "require product=panther,lynx\n"
        "require version-bootloader=foo\n"
    )
    assert r.parse_android_info_products(text) == ("panther", "cheetah", "lynx")


def test_adapter_uses_captured_original_not_mutable_base_global(tmp_path: Path):
    zpath = make_zip(tmp_path)
    base, calls, _, original_find = make_fake_base(tmp_path)
    adapter = r.make_find_build_properties_adapter(base=base, original_find=original_find)

    def explode(_zf):
        raise AssertionError("mutable base.find_build_properties must not be called")

    base.find_build_properties = explode
    with zipfile.ZipFile(zpath) as z:
        props, sources = adapter(z)
    assert props["ro.product.device"] == "panther"
    assert calls["original_find"] == 1
    assert "OTA/android-info.txt(product)" in sources


def test_partition_fallback_rejects_generic_system(tmp_path: Path):
    zpath = make_zip(tmp_path, ota=False, product_fallback=True)
    base, _, _, original_find = make_fake_base(tmp_path)
    adapter = r.make_find_build_properties_adapter(base=base, original_find=original_find)
    with zipfile.ZipFile(zpath) as z:
        props, sources = adapter(z)
    assert props["ro.product.device"] == "panther"
    assert "PRODUCT/build.prop(product)" in sources


def test_run_with_base_exercises_actual_patched_main_path_and_restores(tmp_path: Path):
    make_zip(tmp_path)
    base, calls, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__
    rc = r.run_with_base(base, [])
    assert rc == 3
    assert calls == {"original_find": 1, "main": 1}
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_run_with_base_restores_after_exception(tmp_path: Path):
    make_zip(tmp_path)
    base, _, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__

    def bad_main(argv=None):
        assert base.find_build_properties is not original_find
        raise RuntimeError("synthetic failure")

    base.main = bad_main
    with pytest.raises(RuntimeError, match="synthetic failure"):
        r.run_with_base(base, [])
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_repeated_main_path_has_no_recursion_or_state_leak(tmp_path: Path):
    make_zip(tmp_path)
    base, calls, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__
    for _ in range(250):
        assert r.run_with_base(base, []) == 3
    assert calls["main"] == 250
    assert calls["original_find"] == 250
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_load_bound_base_rejects_hash_mismatch(tmp_path: Path):
    p = tmp_path / "base.py"
    p.write_text("x = 1\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="binding mismatch"):
        r.load_bound_base(p, "0" * 64, "bad_base")


def test_correction_layer_has_no_execution_backend_or_mutation_tokens():
    text = Path(r.__file__).read_text(encoding="utf-8")
    assert "subprocess" not in text
    assert "os.system" not in text
    assert "Popen(" not in text
    forbidden = (
        "adb reboot",
        "fastboot flash",
        "fastboot erase",
        "flashing unlock",
        "flashing lock",
        "set-active",
        "make_key ",
        "sign_target_files_apks ",
        "ota_from_target_files ",
    )
    for token in forbidden:
        assert token not in text


def test_main_loads_bound_base_once(monkeypatch):
    base = types.SimpleNamespace()
    seen = {"load": 0, "run": 0}

    def fake_load():
        seen["load"] += 1
        return base

    def fake_run(got, argv):
        seen["run"] += 1
        assert got is base
        assert argv == ["--x"]
        return 3

    monkeypatch.setattr(r, "load_bound_base", fake_load)
    monkeypatch.setattr(r, "run_with_base", fake_run)
    assert r.main(["--x"]) == 3
    assert seen == {"load": 1, "run": 1}


def test_loaded_module_integration_repeated_main_no_recursion(tmp_path: Path):
    zpath = make_zip(tmp_path)
    base_path = tmp_path / "loaded_base.py"
    base_path.write_text(
        "import zipfile\n"
        "EXPECTED_DEVICE='panther'\n"
        "def parse_key_generator_subject(path): return 'ORIGINAL'\n"
        "def find_build_properties(zf):\n"
        "    text=zf.read('SYSTEM/build.prop').decode()\n"
        "    props={}\n"
        "    for line in text.splitlines():\n"
        "        if '=' in line:\n"
        "            k,v=line.split('=',1); props[k]=v\n"
        "    return props,['SYSTEM/build.prop']\n"
        "def main(argv=None):\n"
        "    with zipfile.ZipFile(argv[0]) as z:\n"
        "        props,sources=find_build_properties(z)\n"
        "    assert props['ro.product.device']=='panther'\n"
        "    assert 'OTA/android-info.txt(product)' in sources\n"
        "    return 3\n",
        encoding="utf-8",
    )
    digest = r.sha256_file(base_path)
    base = r.load_bound_base(base_path, digest, "loaded_integration_base")
    original_find = base.find_build_properties
    original_subject = base.parse_key_generator_subject
    original_file = base.__file__
    for _ in range(100):
        assert r.run_with_base(base, [str(zpath)]) == 3
    assert base.find_build_properties is original_find
    assert base.parse_key_generator_subject is original_subject
    assert base.__file__ == original_file
