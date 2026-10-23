"""Hermetic tests for selected PR347-to-AOSP source convergence; never use real AOSP."""
from __future__ import annotations
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('pr347_convergence', Path(__file__).with_name('pr347-source-convergence.py'))
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)

class ConvergenceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='pr347-conv-')
        self.addCleanup(self.tmp.cleanup)
        r = Path(self.tmp.name)
        self.sable = r/'sable'
        self.android = r/'android'
        self.sable.mkdir(); self.android.mkdir()
        for cmd in (['git','init','-q',str(self.sable)],
                    ['git','-C',str(self.sable),'checkout','-qb',mod.BRANCH]):
            subprocess.run(cmd,check=True,capture_output=True)
        for source,target in mod.PAIRS:
            for i in range(10):
                s=self.sable/source/f'file{i}.kt'
                s.parent.mkdir(parents=True,exist_ok=True)
                s.write_text('package sable\nval v'+str(i)+' = '+str(i)+'\n')
                d=self.android/target/f'file{i}.kt'
                d.parent.mkdir(parents=True,exist_ok=True)
                d.write_bytes(s.read_bytes())
        gsi=self.android/mod.GSI_SOURCE
        gsi.parent.mkdir(parents=True,exist_ok=True)
        gsi.write_text('patched-source\n')
        self.old_sha=mod.GSI_SHA
        mod.GSI_SHA=mod.sha(gsi.read_bytes())
        self.addCleanup(lambda: setattr(mod,'GSI_SHA',self.old_sha))
        subprocess.run(['git','-C',str(self.sable),'add','.'], check=True, capture_output=True)
        subprocess.run(['git','-C',str(self.sable),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture'], check=True, capture_output=True)

    def test_matching_source_verify(self):
        self.assertEqual(mod.main(['verify','--sable',str(self.sable),'--android',str(self.android)]),0)
    def test_plan_outside_no_source_write(self):
        out=Path(self.tmp.name)/'plan'
        before=(self.android/mod.PAIRS[0][1]/'file0.kt').read_bytes()
        self.assertEqual(mod.main(['plan','--sable',str(self.sable),'--android',str(self.android),'--out',str(out)]),0)
        self.assertEqual(json.loads((out/'PLAN.json').read_text())['matched'],20)
        self.assertEqual((self.android/mod.PAIRS[0][1]/'file0.kt').read_bytes(),before)
    def test_create_only_plan(self):
        out=Path(self.tmp.name)/'plan';out.mkdir()
        self.assertEqual(mod.main(['plan','--sable',str(self.sable),'--android',str(self.android),'--out',str(out)]),78)
    def test_source_change_holds_verify(self):
        (self.sable/mod.PAIRS[0][0]/'file0.kt').write_text('new')
        self.assertEqual(mod.main(['verify','--sable',str(self.sable),'--android',str(self.android)]),78)
    def test_absent_target_holds_verify(self):
        (self.android/mod.PAIRS[0][1]/'file0.kt').unlink()
        self.assertEqual(mod.main(['verify','--sable',str(self.sable),'--android',str(self.android)]),78)
    def test_symlink_source_denied(self):
        s=self.sable/mod.PAIRS[0][0]/'file0.kt'; s.unlink();s.symlink_to('/etc/passwd')
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_symlink_target_denied(self):
        d=self.android/mod.PAIRS[0][1]/'file0.kt';d.unlink();d.symlink_to('/etc/passwd')
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_hardlink_target_denied(self):
        d=self.android/mod.PAIRS[0][1]/'file0.kt';os.link(d,self.android/'copy')
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_source_gsi_drift_denied(self):
        (self.android/mod.GSI_SOURCE).write_text('old')
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_wrong_branch_denied(self):
        subprocess.run(['git','-C',str(self.sable),'checkout','-qb','other'],check=True,capture_output=True)
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_root_overlap(self):
        with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.sable)
    def test_source_too_many(self):
        with patch.object(mod,'MAX_FILES',5):
            with self.assertRaises(mod.Hold): mod.inspect(self.sable,self.android)
    def test_stage_requires_owner_acks(self):
        doc=mod.inspect(self.sable,self.android)
        with self.assertRaises(mod.Hold):mod.do_stage(doc,self.sable,self.android,Path(self.tmp.name)/'out')
    def test_stage_rejects_drift(self):
        doc=mod.inspect(self.sable,self.android)
        s=self.sable/mod.PAIRS[0][0]/'file0.kt';s.write_text('different')
        with patch.dict(os.environ,{'PR347_CONVERGENCE_STAGE_ACK':'STAGE_REVIEWED_PR347_AOSP_SOURCE_ONLY','PR347_BUILD_QUIESCENT_ACK':'TRACK_B_ANDROID_BUILD_QUIESCENT_CONFIRMED'}),patch.object(mod,'active_build',return_value=False):
            with self.assertRaises(mod.Hold):mod.do_stage(doc,self.sable,self.android,Path(self.tmp.name)/'out')
    def test_stage_conflict_with_review_and_backups(self):
        d=self.android/mod.PAIRS[0][1]/'file0.kt'
        d.write_text('target old data')
        doc=mod.inspect(self.sable,self.android)
        out=Path(self.tmp.name)/'out'
        with patch.dict(os.environ,{'PR347_CONVERGENCE_STAGE_ACK':'STAGE_REVIEWED_PR347_AOSP_SOURCE_ONLY','PR347_BUILD_QUIESCENT_ACK':'TRACK_B_ANDROID_BUILD_QUIESCENT_CONFIRMED'}),patch.object(mod,'active_build',return_value=False):
            mod.do_stage(doc,self.sable,self.android,out)
        self.assertEqual(d.read_bytes(),(self.sable/mod.PAIRS[0][0]/'file0.kt').read_bytes())
        self.assertEqual((out/'backups'/mod.PAIRS[0][1]/'file0.kt').read_text(),'target old data')
        self.assertEqual(json.loads((out/'RESULT.json').read_text())['changed'],1)
    def test_stage_plan_tamper_sha_denied(self):
        out=Path(self.tmp.name)/'plan'
        mod.main(['plan','--sable',str(self.sable),'--android',str(self.android),'--out',str(out)])
        (out/'PLAN.json').write_text('modified')
        self.assertEqual(mod.main(['stage','--sable',str(self.sable),'--android',str(self.android),'--plan-file',str(out/'PLAN.json'),'--out',str(Path(self.tmp.name)/'stage')]),78)
    def test_perf_250_bounded_inspections(self):
        import time
        start=time.monotonic()
        for _ in range(250):
            self.assertEqual(mod.inspect(self.sable,self.android)['matched'],20)
        elapsed=time.monotonic()-start
        print(f'PR347_CONVERGENCE_250_HOST_FIXTURE_INSPECTIONS_SEC={elapsed:.3f}')
        self.assertLess(elapsed,25)

if __name__=='__main__':unittest.main()
