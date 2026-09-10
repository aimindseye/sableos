from __future__ import annotations

import importlib.util
import sys
import types
import zipfile
from pathlib import Path

import pytest

SCRIPT = Path(__file__).with_name('SABLE_R1_R0R3_RELEASE_PREFLIGHT.py')
spec = importlib.util.spec_from_file_location('r0r3_local', SCRIPT)
assert spec and spec.loader
r = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = r
spec.loader.exec_module(r)


class FakeBase(types.ModuleType):
    pass


def make_zip(tmp_path: Path, *,
             system_scoped='panther',
             vendor_scoped=None,
             product_scoped=None,
             ota_products=None,
             legacy_device='generic') -> Path:
    zpath = tmp_path / 'fixture.zip'
    with zipfile.ZipFile(zpath, 'w') as z:
        lines = [
            'ro.build.type=userdebug',
            'ro.build.tags=test-keys',
            f'ro.product.device={legacy_device}',
        ]
        if system_scoped is not None:
            lines.append(f'ro.product.system.device={system_scoped}')
        z.writestr('SYSTEM/build.prop', '\n'.join(lines) + '\n')
        if vendor_scoped is not None:
            z.writestr('VENDOR/build.prop', f'ro.product.vendor.device={vendor_scoped}\n')
        if product_scoped is not None:
            z.writestr('PRODUCT/etc/build.prop', f'ro.product.product.device={product_scoped}\n')
        if ota_products is not None:
            z.writestr('OTA/android-info.txt', f'require product={ota_products}\n')
    return zpath


def make_fake_base(tmp_path: Path):
    base = FakeBase('fake_base')
    base.EXPECTED_DEVICE = 'panther'
    base.__file__ = str(tmp_path / 'base.py')
    calls = {'find': 0, 'main': 0}

    def original_subject(path: Path):
        return 'ORIGINAL'

    def original_find(zf: zipfile.ZipFile):
        calls['find'] += 1
        props = r._parse_properties(zf.read('SYSTEM/build.prop').decode())
        return props, ['SYSTEM/build.prop']

    base.parse_key_generator_subject = original_subject
    base.find_build_properties = original_find

    def main(argv=None):
        calls['main'] += 1
        with zipfile.ZipFile(argv[0]) as z:
            props, sources = base.find_build_properties(z)
        assert props['ro.product.device'] == 'panther'
        assert any('ro.product.system.device=panther' in s for s in sources)
        return 3

    base.main = main
    return base, calls, original_subject, original_find


def test_generator_subject_parser_handles_pinned_style(tmp_path: Path):
    p = tmp_path / 'generate-keys'
    p.write_text('    CN=GrapheneOS\n', encoding='utf-8')
    assert r.parse_key_generator_subject(p) == 'GrapheneOS'


def test_live_symptom_generic_legacy_is_overridden_by_system_scoped(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped='panther', legacy_device='generic')
    with zipfile.ZipFile(zpath) as z:
        device, markers = r.resolve_target_device(z, expected_device='panther')
    assert device == 'panther'
    assert 'SYSTEM/build.prop(ro.product.system.device=panther)' in markers


def test_exact_product_etc_path_and_partition_key(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped=None, product_scoped='panther')
    with zipfile.ZipFile(zpath) as z:
        evidence = r.collect_partition_device_evidence(z)
    assert evidence == (('PRODUCT/etc/build.prop', 'ro.product.product.device', 'panther'),)


def test_partition_sources_agree(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped='panther', vendor_scoped='panther', product_scoped='panther')
    with zipfile.ZipFile(zpath) as z:
        device, _ = r.resolve_target_device(z, expected_device='panther')
    assert device == 'panther'


def test_partition_conflict_fails_closed(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped='panther', vendor_scoped='cheetah')
    with zipfile.ZipFile(zpath) as z:
        device, _ = r.resolve_target_device(z, expected_device='panther')
    assert device == 'CONFLICT[cheetah,panther]'


def test_ota_allowed_set_and_partition_agree(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped='panther', ota_products='panther|cheetah')
    with zipfile.ZipFile(zpath) as z:
        device, _ = r.resolve_target_device(z, expected_device='panther')
    assert device == 'panther'


def test_ota_partition_conflict_fails_closed(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped='panther', ota_products='cheetah')
    with zipfile.ZipFile(zpath) as z:
        device, _ = r.resolve_target_device(z, expected_device='panther')
    assert device == 'CONFLICT[cheetah,panther]'


def test_ota_only_expected_is_allowed(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped=None, ota_products='panther|cheetah')
    with zipfile.ZipFile(zpath) as z:
        device, _ = r.resolve_target_device(z, expected_device='panther')
    assert device == 'panther'


def test_no_authoritative_evidence_leaves_base_value_unchanged(tmp_path: Path):
    zpath = make_zip(tmp_path, system_scoped=None, ota_products=None)
    base, _, _, original_find = make_fake_base(tmp_path)
    adapter = r.make_find_build_properties_adapter(base=base, original_find=original_find)
    with zipfile.ZipFile(zpath) as z:
        props, _ = adapter(z)
    assert props['ro.product.device'] == 'generic'


def test_adapter_calls_captured_original_not_mutable_global(tmp_path: Path):
    zpath = make_zip(tmp_path)
    base, calls, _, original_find = make_fake_base(tmp_path)
    adapter = r.make_find_build_properties_adapter(base=base, original_find=original_find)

    def explode(_zf):
        raise AssertionError('mutable base.find_build_properties must not be called')

    base.find_build_properties = explode
    with zipfile.ZipFile(zpath) as z:
        props, _ = adapter(z)
    assert props['ro.product.device'] == 'panther'
    assert calls['find'] == 1


def test_run_with_base_actual_patched_main_and_restore(tmp_path: Path):
    zpath = make_zip(tmp_path)
    base, calls, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__
    assert r.run_with_base(base, [str(zpath)]) == 3
    assert calls == {'find': 1, 'main': 1}
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_run_with_base_restore_after_exception(tmp_path: Path):
    make_zip(tmp_path)
    base, _, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__

    def bad_main(argv=None):
        assert base.find_build_properties is not original_find
        raise RuntimeError('synthetic')

    base.main = bad_main
    with pytest.raises(RuntimeError, match='synthetic'):
        r.run_with_base(base, [])
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_repeated_patched_main_no_recursion_or_state_leak(tmp_path: Path):
    zpath = make_zip(tmp_path)
    base, calls, original_subject, original_find = make_fake_base(tmp_path)
    original_file = base.__file__
    for _ in range(500):
        assert r.run_with_base(base, [str(zpath)]) == 3
    assert calls == {'find': 500, 'main': 500}
    assert base.parse_key_generator_subject is original_subject
    assert base.find_build_properties is original_find
    assert base.__file__ == original_file


def test_load_bound_base_hash_mismatch_fails_closed(tmp_path: Path):
    p = tmp_path / 'base.py'
    p.write_text('x=1\n', encoding='utf-8')
    with pytest.raises(RuntimeError, match='binding mismatch'):
        r.load_bound_base(p, '0' * 64, 'bad_base')


def test_partition_contract_is_exact_and_bounded():
    assert r.PARTITION_DEVICE_SOURCES == (
        ('SYSTEM/build.prop', 'ro.product.system.device'),
        ('SYSTEM/system/build.prop', 'ro.product.system.device'),
        ('VENDOR/build.prop', 'ro.product.vendor.device'),
        ('PRODUCT/etc/build.prop', 'ro.product.product.device'),
        ('ODM/etc/build.prop', 'ro.product.odm.device'),
        ('SYSTEM_EXT/etc/build.prop', 'ro.product.system_ext.device'),
    )


def test_no_execution_backend_or_mutating_commands():
    text = SCRIPT.read_text(encoding='utf-8')
    assert 'subprocess' not in text
    assert 'os.system' not in text
    assert 'Popen(' not in text
    forbidden = (
        'adb reboot', 'fastboot flash', 'fastboot erase', 'flashing unlock',
        'flashing lock', 'set-active', 'make_key ', 'sign_target_files_apks ',
        'ota_from_target_files ',
    )
    for token in forbidden:
        assert token not in text


def test_main_loads_bound_base_once(monkeypatch):
    base = types.SimpleNamespace()
    seen = {'load': 0, 'run': 0}

    def fake_load():
        seen['load'] += 1
        return base

    def fake_run(got, argv):
        seen['run'] += 1
        assert got is base
        assert argv == ['--x']
        return 3

    monkeypatch.setattr(r, 'load_bound_base', fake_load)
    monkeypatch.setattr(r, 'run_with_base', fake_run)
    assert r.main(['--x']) == 3
    assert seen == {'load': 1, 'run': 1}


def test_fresh_process_entrypoint_executes_bound_base_without_recursion(tmp_path: Path):
    import hashlib
    import subprocess

    zpath = make_zip(tmp_path)
    base_path = tmp_path / 'SABLE_R1_R0_RELEASE_PREFLIGHT.py'
    base_path.write_text(
        "import sys,zipfile\n"
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
        "    argv=sys.argv[1:] if argv is None else argv\n"
        "    with zipfile.ZipFile(argv[0]) as z:\n"
        "        props,sources=find_build_properties(z)\n"
        "    assert props['ro.product.device']=='panther'\n"
        "    assert any('ro.product.system.device=panther' in s for s in sources)\n"
        "    print('FRESH_PROCESS_DEVICE=PASS')\n"
        "    return 3\n",
        encoding='utf-8',
    )
    digest = hashlib.sha256(base_path.read_bytes()).hexdigest()
    wrapper_text = SCRIPT.read_text(encoding='utf-8').replace(r.BASE_SCRIPT_SHA256, digest, 1)
    wrapper_path = tmp_path / 'SABLE_R1_R0R3_RELEASE_PREFLIGHT.py'
    wrapper_path.write_text(wrapper_text, encoding='utf-8')

    cp = subprocess.run(
        [sys.executable, str(wrapper_path), str(zpath)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env={'PYTHONDONTWRITEBYTECODE': '1'},
        check=False,
    )
    assert cp.returncode == 3, cp.stderr
    assert 'FRESH_PROCESS_DEVICE=PASS' in cp.stdout
    assert 'RecursionError' not in cp.stderr
