"""Hermetic tests for the source/artifact G1/G2/G3 evidence boundary."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

PATH = Path(__file__).with_name('ims_g123_selected_evidence.py')
SPEC = importlib.util.spec_from_file_location('ims_g123', PATH)
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

class ImsG123Tests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        root = Path(self.dir.name)
        self.android = root / 'android'
        (self.android / 'build').mkdir(parents=True)
        (self.android / 'build/envsetup.sh').write_text('# build\n')
        ims = self.android / 'vendor/sable/trackb13ims'
        ims.mkdir(parents=True)
        self.makefile = ims / 'track-b.mk'
        self.makefile.write_text('PRODUCT_PACKAGES += \\\n    PhhIms \\\n    PhhImsOverlay \\\n    Iwlan \\\n    QualifiedNetworksService\n')
        (ims / 'privapp-permissions-me.phh.ims.xml').write_text(
            '<permissions><privapp-permissions package="me.phh.ims">'
            '<permission name="android.permission.READ_PHONE_STATE"/>'
            '</privapp-permissions></permissions>')

    def test_four_selected_modules(self):
        s = mod.inspect_source(self.android)
        self.assertEqual(s['ims_source_selection'], 'PASS_FLOSS_SOURCE_CARDINALITY')
        self.assertTrue(all(v == 1 for v in s['module_counts'].values()))

    def test_duplicate_provider_hold(self):
        self.makefile.write_text(self.makefile.read_text() + '    PhhIms\n')
        self.assertEqual(mod.inspect_source(self.android)['ims_source_selection'], 'HOLD_SOURCE_SELECTION')

    def test_missing_provider_hold(self):
        self.makefile.write_text('PRODUCT_PACKAGES += \\\n    Iwlan\n')
        self.assertEqual(mod.inspect_source(self.android)['ims_source_selection'], 'HOLD_SOURCE_SELECTION')

    def test_candidate_mmtel_binding_is_not_g1_runtime(self):
        (self.makefile.parent / 'overlay.xml').write_text(
            '<resources><string name="config_ims_mmtel_package">me.phh.ims</string></resources>')
        s = mod.inspect_source(self.android)
        self.assertEqual(s['overlay_binding_candidates'][0]['values'], ['me.phh.ims'])
        self.assertTrue(s['g1_effective_compiled_binding'].startswith('OPEN_'))

    def test_targetfiles_cannot_close_g2(self):
        zpath = Path(self.dir.name) / 'target_files.zip'
        with zipfile.ZipFile(zpath, 'w') as z:
            z.writestr('SYSTEM/system_ext/priv-app/PhhIms/PhhIms.apk', b'fixture')
            z.writestr('VENDOR/lib64/libimsbridge.so', b'fixture')
        s = mod.inspect_target_files(zpath)
        self.assertEqual(s['apk_candidates_total'], 1)
        self.assertEqual(s['shared_library_candidates_total'], 1)
        self.assertTrue(s['g2_linker_namespace_abi'].startswith('OPEN_'))

    def test_vendor_configuration_cannot_close_g3(self):
        v = Path(self.dir.name) / 'vendor'
        (v / 'etc/vintf').mkdir(parents=True)
        (v / 'etc/vintf/manifest.xml').write_text('<hal name="vendor.mediatek.hardware.ims"/>')
        s = mod.inspect_vendor(v)
        self.assertEqual(len(s['config_candidates']), 1)
        self.assertTrue(s['g3_vendor_transport'].startswith('OPEN_'))

    def test_existing_output_refused(self):
        out = Path(self.dir.name) / 'report.json'
        out.write_text('{}')
        self.assertEqual(mod.main(['--android', str(self.android), '--out', str(out)]), 78)
        self.assertEqual(out.read_text(), '{}')

    def test_report_is_create_only_and_not_runtime_pass(self):
        out = Path(self.dir.name) / 'report.json'
        self.assertEqual(mod.main(['--android', str(self.android), '--out', str(out)]), 0)
        d = json.loads(out.read_text())
        self.assertEqual(d['g123_runtime_acceptance'], 'OPEN')
        self.assertFalse(d['source_mutation'])
        self.assertEqual(mod.main(['--android', str(self.android), '--out', str(out)]), 78)
