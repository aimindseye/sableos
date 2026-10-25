import importlib.util
import json
from pathlib import Path
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile

MODULE_PATH = Path(__file__).resolve().parent/'tb2-apk-provenance.py'
spec=importlib.util.spec_from_file_location('bridge',MODULE_PATH)
bridge=importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

def apk(path, signed=False, content=b'A1'):
    path.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_STORED) as z:
        z.writestr('AndroidManifest.xml',b'ARSC')
        z.writestr('classes.dex',content)
        if signed:z.writestr('META-INF/CERT.RSA',b'fake')

def git(root):
    cmds=[['git','init','-q','-b','titan2/nextbuild-q25-app-conformance-20261021'],
          ['git','config','user.email','test@example.com'],
          ['git','config','user.name','Tester'],
          ['git','add','.'],['git','commit','-qm','fixture']]
    for cmd in cmds:subprocess.run(cmd,cwd=root,check=True,stdout=subprocess.DEVNULL)

class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.sable=self.root/'sable';self.sable.mkdir()
        self.android=self.root/'aosp';self.android.mkdir()
        self.evidence=self.root/'evidence';self.evidence.mkdir()
        self.out=self.root/'plan.json'
        self.aapt=self.root/'aapt2'
        self.aapt.write_text('''#!/bin/sh
for arg do last=$arg; done
name=${last##*/}
case "$name" in
  tools-release-unsigned.apk) pkg=org.sableos.tools ;;
  TB2SableCalculator.apk) pkg=org.sableos.calculator ;;
  TB2SableCalendar.apk) pkg=org.sableos.calendar ;;
  TB2SableCamera.apk) pkg=org.sableos.titan2.camera ;;
  TB2SableDisplayCompat.apk) pkg=org.sableos.titan2.displaycompat ;;
  TB2SableHub.apk) pkg=org.sableos.hub ;;
  TB2SableKeyboard.apk) pkg=org.sableos.titan2.keyboard ;;
  TB2SableMail.apk) pkg=org.sableos.mail ;;
  TB2SableMedia.apk) pkg=org.sableos.media ;;
  TB2SableReader.apk) pkg=org.sableos.reader ;;
  TB2SableSetup.apk) pkg=org.sableos.titan2.setup ;;
  TB2SableTextReader.apk) pkg=org.sableos.textreader ;;
  TB2SableTools.apk) pkg=org.sableos.tools ;;
  TB2SableWeather.apk) pkg=org.sableos.weather ;;
  *) pkg=org.wrong ;;
esac
printf "package: name='%s' versionCode='1' versionName='1.0'\\n" "$pkg"
''')
        self.aapt.chmod(0o755)
        self.sable.joinpath('.gitignore').write_text('**/build/\n')
        task=self.sable/bridge.TOOLS_SRC
        task.parent.mkdir(parents=True)
        task.write_text('class TasksController {}\n')
        apk(self.sable/bridge.TOOLS_REL)
        git(self.sable)
        self.tools=self.android/'vendor/sable/tb2-rebuilt'
        self.tools.mkdir(parents=True)
        mk='PRODUCT_PACKAGES += \\\n'+''.join('    '+n+' \\\n' for n in bridge.MODULES)
        (self.tools/'tb2-apps.mk').write_text(mk)
        bp=''
        for n in bridge.MODULES:
            mode='default_dev_cert' if bridge.EXPECTED_SIGNING[n]=='default_dev_cert' else 'presigned'
            bp+=f'android_app_import {{\n name: "{n}",\n apk: "prebuilt/{n}.apk",\n {mode}: true,\n}}\n'
            apk(self.tools/'prebuilt'/f'{n}.apk',content=b'old_'+n.encode())
        (self.tools/'Android.bp').write_text(bp)
        self.pins=(bridge.MK_PIN,bridge.BP_PIN)
        bridge.MK_PIN=bridge.sha(self.tools/'tb2-apps.mk')
        bridge.BP_PIN=bridge.sha(self.tools/'Android.bp')
        self.addCleanup(self.restore_pins)
    def restore_pins(self):bridge.MK_PIN,bridge.BP_PIN=self.pins
    def seal(self):bridge.seal_tools(self.sable,self.evidence,str(self.aapt))
    def passed(self):
        c=bridge.git_commit(self.sable)
        (self.evidence/'LOCAL_CI_SUMMARY.txt').write_text(
            f'SABLE_LOCAL_CI_SUMMARY_STATUS=PASS\nSABLE_LOCAL_CI=PASS\nPROFILE=full\n'
            f'SABLEOS_DEVICE=titan2\nSABLEOS_RELEASE_VERSION=TB2\n'
            f'SOURCE_COMMIT={c}\nCI_EXIT_CODE=0\nSABLE_LOCAL_CI_STAGE_TITAN2_TB2_APPS=PASS\n'
        )
    def planned(self):self.seal();self.passed();bridge.plan(self.sable,self.android,self.evidence,self.out,str(self.aapt));return json.loads(self.out.read_text())

    def test_expected_exact_13(self):
        a=bridge.product_inventory(self.android,str(self.aapt));self.assertEqual(len(a),13)
        self.assertEqual({x['module'] for x in a},set(bridge.MODULES))
    def test_bp_wrong_cert_holds(self):
        p=self.tools/'Android.bp';p.write_text(p.read_text().replace('default_dev_cert: true','presigned: true',1));bridge.BP_PIN=bridge.sha(p)
        with self.assertRaisesRegex(bridge.Hold,'SOONG_SIGNING'):bridge.product_inventory(self.android,str(self.aapt))
    def test_bp_sha_pin_holds(self):
        with (self.tools/'Android.bp').open('a') as f:f.write('oops')
        with self.assertRaisesRegex(bridge.Hold,'ACTIVE_BP_PIN'):bridge.product_inventory(self.android,str(self.aapt))
    def test_mk_pin_holds(self):
        with (self.tools/'tb2-apps.mk').open('a') as f:f.write('oops')
        with self.assertRaisesRegex(bridge.Hold,'ACTIVE_MAKEFILE_PIN'):bridge.product_inventory(self.android,str(self.aapt))
    def test_symlink_prebuilt_holds(self):
        p=self.tools/'prebuilt/TB2SableTools.apk';p.unlink();p.symlink_to(self.sable/bridge.TOOLS_REL)
        with self.assertRaisesRegex(bridge.Hold,'UNSAFE_OR_MISSING_FILE'):bridge.product_inventory(self.android,str(self.aapt))
    def test_module_package_holds(self):
        p=self.aapt
        p.write_text(p.read_text().replace('TB2SableTools.apk) pkg=org.sableos.tools',
                                          'TB2SableTools.apk) pkg=org.wrong'))
        with self.assertRaisesRegex(bridge.Hold,'ACTIVE_PREBUILT_PACKAGE'):
            bridge.product_inventory(self.android,str(self.aapt))
    def test_good_unsigned_tools(self):
        c=bridge.tools_candidate(self.sable,str(self.aapt));self.assertEqual(c['package'],'org.sableos.tools')
    def test_signed_tools_release_holds(self):
        apk(self.sable/bridge.TOOLS_REL,signed=True)
        with self.assertRaisesRegex(bridge.Hold,'ALREADY_SIGNED'):bridge.tools_candidate(self.sable,str(self.aapt))
    def test_bad_zip_holds(self):
        (self.sable/bridge.TOOLS_REL).write_bytes(b'not a zip')
        with self.assertRaises((bridge.Hold,zipfile.BadZipFile)):bridge.tools_candidate(self.sable,str(self.aapt))
    def test_seal_bound_and_readback(self):
        self.seal();r=bridge.read_json(self.evidence/bridge.CI_NAME)
        self.assertEqual(r['source_commit'],bridge.git_commit(self.sable));self.assertFalse(r['release_qualified'])
    def test_seal_rejects_dirty(self):
        (self.sable/'untracked.txt').write_text('dirty')
        with self.assertRaisesRegex(bridge.Hold,'SOURCE_NOT_CLEAN'):self.seal()
    def test_plan_13_no_mutation(self):
        old=bridge.sha(self.tools/'prebuilt/TB2SableTools.apk');p=self.planned()
        self.assertEqual(p['tools_disposition'],'REVIEWED_REPLACEMENT_REQUIRED')
        self.assertEqual(bridge.sha(self.tools/'prebuilt/TB2SableTools.apk'),old)
        self.assertFalse(p['aosp_mutation'])
    def test_ci_summary_required(self):
        self.seal()
        with self.assertRaisesRegex(bridge.Hold,'UNSAFE_OR_MISSING_FILE'):bridge.plan(self.sable,self.android,self.evidence,self.out,str(self.aapt))
    def test_full_ci_commit_mismatch_holds(self):
        self.seal();self.passed()
        f=self.evidence/'LOCAL_CI_SUMMARY.txt';f.write_text(f.read_text().replace(bridge.git_commit(self.sable),'f'*40))
        with self.assertRaisesRegex(bridge.Hold,'CANONICAL_CI'):bridge.plan(self.sable,self.android,self.evidence,self.out,str(self.aapt))
    def test_signed_replacement_rejected(self):
        self.planned();apk(self.sable/bridge.TOOLS_REL,signed=True)
        (self.root/'stage').mkdir()
        with self.assertRaisesRegex(bridge.Hold,'ALREADY_SIGNED'):bridge.stage(self.sable,self.android,self.evidence,self.out,self.root/'stage',str(self.aapt),bridge.ACK,bridge.sha(self.out),'AOSP_BUILD_QUIESCENT_CONFIRMED')
    def test_stage_explicit_ack(self):
        self.planned();out=self.root/'stage';out.mkdir()
        with self.assertRaisesRegex(bridge.Hold,'AUTHORIZATION'):bridge.stage(self.sable,self.android,self.evidence,self.out,out,str(self.aapt),'',bridge.sha(self.out),'AOSP_BUILD_QUIESCENT_CONFIRMED')
    def test_stage_tools_only_and_backup(self):
        p=self.planned();out=self.root/'stage';out.mkdir()
        before=[(x['module'],x['sha256']) for x in p['inventory']]
        bridge.stage(self.sable,self.android,self.evidence,self.out,out,str(self.aapt),bridge.ACK,bridge.sha(self.out),'AOSP_BUILD_QUIESCENT_CONFIRMED')
        self.assertEqual(bridge.sha(self.tools/'prebuilt/TB2SableTools.apk'),p['tools_candidate']['sha256'])
        self.assertEqual(bridge.sha(out/'TB2SableTools.before.apk'),p['tools_selected_before']['sha256'])
        now=[(x['module'],x['sha256']) for x in bridge.product_inventory(self.android,str(self.aapt))]
        self.assertEqual([x for x in before if x[0]!='TB2SableTools'],[x for x in now if x[0]!='TB2SableTools'])
        self.assertEqual(json.loads((out/'STAGE_RESULT.json').read_text())['release_ready'],False)
    def test_stage_destination_drift_holds(self):
        self.planned();p=self.tools/'prebuilt/TB2SableHub.apk';apk(p,content=b'mutation')
        out=self.root/'stage';out.mkdir()
        with self.assertRaisesRegex(bridge.Hold,'REVIEW_SOURCE_OR_DESTINATION_CHANGED'):bridge.stage(self.sable,self.android,self.evidence,self.out,out,str(self.aapt),bridge.ACK,bridge.sha(self.out),'AOSP_BUILD_QUIESCENT_CONFIRMED')
    def test_stage_tampered_plan_holds(self):
        self.planned();self.out.write_text(self.out.read_text()+' ')
        out=self.root/'stage';out.mkdir()
        with self.assertRaisesRegex(bridge.Hold,'REVIEW_PLAN_SHA_DRIFT'):bridge.stage(self.sable,self.android,self.evidence,self.out,out,str(self.aapt),bridge.ACK,'0'*64,'AOSP_BUILD_QUIESCENT_CONFIRMED')

if __name__=='__main__':unittest.main()
